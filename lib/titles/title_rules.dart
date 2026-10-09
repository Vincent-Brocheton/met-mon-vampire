import '../characters/character.dart';
import '../characters/describe_changes.dart';
import '../events/story_event.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import 'court_entry.dart';

/// Catégorie du référentiel des titres.
const titlesCat = 'titles';

/// Un titre du référentiel, lu dans ses champs (`sect`, `count`, `under`, `public`, `onSheet`, `npcOnly`).
class TitleInfo {
  const TitleInfo({required this.name, this.sect = '', this.count = '', this.under = '', this.public = false, this.onSheet = true, this.npcOnly = false});

  final String name;
  final String sect;
  final String count;
  final String under;
  final bool public;
  final bool onSheet;
  final bool npcOnly;

  bool get perClan => nameKey(count) == nameKey('Un par clan');

  /// Nombre de détenteurs au plus ; null : illimité ou un par clan.
  int? get max => nameKey(count) == nameKey('Unique') ? 1 : int.tryParse(count.trim());
}

TitleInfo? titleInfo(Rulebook rb, String? name) {
  final e = rb.find(titlesCat, name);
  if (e == null) return null;
  final d = e.data;
  String text(String k) => '${d[k] ?? ''}'.trim();
  return TitleInfo(
    name: e.name,
    sect: text('sect'),
    count: text('count'),
    under: text('under'),
    public: d['public'] == true,
    onSheet: d['onSheet'] != false,
    npcOnly: d['npcOnly'] == true,
  );
}

/// Titres proposés : disponibles ou sur accord du conte, dans l'ordre du référentiel.
List<String> titleOptions(Rulebook rb) => rb.offeredNames(titlesCat);

bool _same(String? a, String? b) => a != null && b != null && a.trim().isNotEmpty && nameKey(a) == nameKey(b);

/// Fiches actives qui tiennent [title] ; les fiches mortes, retirées ou en création ne comptent pas.
List<Character> titleHolders(String title, List<Character> chars) =>
    [for (final c in chars) if (c.status == CharacterStatus.active && _same(c.title, title)) c];

/// Contrôles d'une attribution ; [title] vide ou null : retrait, sans contrôle.
({List<String> errors, List<String> warnings}) titleChecks(String? title, Character sheet, List<Character> chars, Rulebook rb, {required DateTime? since}) {
  final errors = <String>[];
  final warnings = <String>[];
  if (title == null || title.trim().isEmpty) return (errors: errors, warnings: warnings);
  final info = titleInfo(rb, title);
  final entry = rb.find(titlesCat, title);
  if (info == null || entry == null || !entry.state.offered) {
    return (errors: ['$title : pas un titre de la chronique.'], warnings: warnings);
  }
  final t = info.name;
  final others = [for (final c in titleHolders(t, chars)) if (c.id != sheet.id) c];
  if (info.npcOnly && sheet.kind == CharacterKind.pj) errors.add('$t est réservé aux PNJ.');
  if (info.perClan) {
    final clan = sheet.clan?.trim() ?? '';
    if (clan.isEmpty) {
      warnings.add('Fiche sans clan : le contrôle par clan ne s’applique pas.');
    } else {
      final same = others.where((c) => _same(c.clan, clan)).firstOrNull;
      if (same != null) errors.add('$t est déjà tenu pour le clan $clan par ${same.name}.');
    }
  } else if (info.max == 1 && others.isNotEmpty) {
    errors.add('$t est déjà tenu par ${others.first.name}.');
  } else if (info.max case final n? when n > 1 && others.length >= n) {
    errors.add('$t : $n détenteurs au plus (${others.map((c) => c.name).join(', ')}).');
  }
  if (since == null) errors.add('Date invalide');
  final sect = sheet.sect?.trim() ?? '';
  if (info.sect.isNotEmpty && nameKey(info.sect) != nameKey('Toutes') && sect.isNotEmpty && nameKey(sect) != nameKey(info.sect)) {
    warnings.add('$t relève de ${info.sect} ; la fiche est $sect.');
  }
  return (errors: errors, warnings: warnings);
}

/// Visibilité d'un titre et de ses événements : caché → équipe, public → public, sinon le joueur.
EventVisibility titleVisibility(TitleInfo? info) {
  if (info == null) return EventVisibility.player;
  if (!info.onSheet) return EventVisibility.staff;
  return info.public ? EventVisibility.public : EventVisibility.player;
}

/// Le titre tel que le joueur le voit : null si le référentiel le cache.
String? visibleTitle(Character c, Rulebook rb) {
  final info = titleInfo(rb, c.title);
  return info != null && !info.onSheet ? null : c.title;
}

/// La fiche telle que le joueur la voit : sans titre caché ni date (tout titre si le référentiel manque).
Character playerView(Character c, Rulebook? rb) {
  if (rb != null && visibleTitle(c, rb) == c.title) return c;
  return c.clone()
    ..title = null
    ..titleSince = null;
}

/// Résumé d'historique de l'attribution : neutre si l'ancien ou le nouveau titre est caché.
List<String> titleSummary(Character before, Character after, Rulebook rb) {
  final out = describeChanges(before, after);
  if (visibleTitle(before, rb) == before.title && visibleTitle(after, rb) == after.title) return out;
  bool isTitle(String l) => l.startsWith('Titre : ') || l.startsWith('Titre depuis le ');
  return [...out.where((l) => !isTitle(l)), if (out.any(isTitle)) 'Titre modifié (réservé à l’équipe)'];
}

/// La fiche avec [title] (null ou vide : sans titre) depuis [since].
Character withTitle(Character c, String? title, DateTime? since) {
  final none = title == null || title.trim().isEmpty;
  return c.clone()
    ..title = none ? null : title.trim()
    ..titleSince = none ? null : since;
}

String _clamp80(String s) => s.length <= 80 ? s : s.substring(0, 80);

StoryEvent _event(EventType type, String title, DateTime day, EventVisibility v) => StoryEvent(
      id: '',
      type: type,
      title: _clamp80(title),
      year: day.year,
      month: day.month,
      day: day.day,
      visibility: v,
      auto: true,
    );

/// « Titre perdu » (daté du jour de l'opération, [now]) puis « Titre obtenu » (daté de [since]) ; aucun si le titre ne change pas.
List<StoryEvent> titleEvents(Character before, Character after, DateTime since, Rulebook rb, {DateTime? now}) {
  final a = before.title?.trim() ?? '';
  final b = after.title?.trim() ?? '';
  if (nameKey(a) == nameKey(b)) return const [];
  return [
    if (a.isNotEmpty) _event(EventType.titleLost, 'Perd le titre de $a', now ?? DateTime.now(), titleVisibility(titleInfo(rb, a))),
    if (b.isNotEmpty) _event(EventType.titleGained, 'Obtient le titre de $b', since, titleVisibility(titleInfo(rb, b))),
  ];
}

/// Copie publique attendue pour la fiche ; null si le titre n'est pas public ou pas affiché.
CourtEntry? courtEntry(Character c, Rulebook rb) {
  final info = titleInfo(rb, c.title);
  if (c.status != CharacterStatus.active || info == null || !info.public || !info.onSheet) return null;
  if (!(rb.find(titlesCat, c.title)?.state.offered ?? false)) return null;
  return CourtEntry(characterId: c.id, name: _clamp80(c.name), title: info.name, sect: info.sect, under: info.under, since: c.titleSince);
}

/// La copie de la Cour diffère de ce qu'elle devrait être.
bool courtOutdated(Character c, CourtEntry? stored, Rulebook rb) {
  final expected = courtEntry(c, rb);
  if (expected == null || stored == null) return (expected == null) != (stored == null);
  return expected.name != stored.name || expected.title != stored.title || expected.sect != stored.sect || expected.under != stored.under || expected.since != stored.since;
}

const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// « depuis mars 2026 ».
String sinceText(DateTime d) => 'depuis ${_months[d.month - 1]} ${d.year}';

/// Colonne « Détenu par » du référentiel : noms (« (PNJ) »), « N / M clans », ou « Vacant ».
String holdersLabel(String title, List<Character> chars, {required bool perClan, required int clans}) {
  final h = titleHolders(title, chars);
  if (h.isEmpty) return 'Vacant';
  if (perClan) return '${{for (final c in h) nameKey(c.clan ?? '')}.length} / $clans clans';
  return h.map((c) => c.kind == CharacterKind.pnj ? '${c.name} (PNJ)' : c.name).join(', ');
}

class CourtTitle {
  const CourtTitle(this.title, this.depth, this.holders);
  final String title;
  final int depth;
  final List<CourtEntry> holders;
}

class CourtGroup {
  const CourtGroup(this.sect, this.titles);
  final String sect;
  final List<CourtTitle> titles;
}

/// La Cour : titres groupés par secte (ordre du référentiel), chacun sous son supérieur, en retrait.
List<CourtGroup> courtGroups(List<CourtEntry> entries, Rulebook rb) {
  final order = [for (final e in rb.all(titlesCat)) nameKey(e.name)];
  int index(String t) {
    final i = order.indexOf(nameKey(t));
    return i < 0 ? order.length : i;
  }

  // Chaîne des supérieurs, de la racine au titre (5 niveaux au plus, sans boucle).
  List<String> chain(String title, String under) {
    final out = [title];
    var cur = under;
    final seen = {nameKey(title)};
    while (cur.trim().isNotEmpty && out.length < 6 && seen.add(nameKey(cur))) {
      out.insert(0, cur);
      cur = titleInfo(rb, cur)?.under ?? '';
    }
    return out;
  }

  int compareChains(List<String> a, List<String> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      final c = index(a[i]).compareTo(index(b[i]));
      if (c != 0) return c;
      final n = nameKey(a[i]).compareTo(nameKey(b[i]));
      if (n != 0) return n;
    }
    return a.length.compareTo(b.length);
  }

  final bySect = <String, Map<String, List<CourtEntry>>>{};
  for (final e in entries) {
    final sect = e.sect.trim().isEmpty ? 'Autres' : e.sect;
    (bySect.putIfAbsent(sect, () => {})).putIfAbsent(e.title, () => []).add(e);
  }
  final groups = <CourtGroup>[];
  for (final MapEntry(key: sect, value: titles) in bySect.entries) {
    final rows = [
      for (final MapEntry(key: t, value: holders) in titles.entries)
        (chain: chain(t, holders.first.under), holders: [...holders]..sort((a, b) => nameKey(a.name).compareTo(nameKey(b.name)))),
    ]..sort((a, b) => compareChains(a.chain, b.chain));
    groups.add(CourtGroup(sect, [for (final r in rows) CourtTitle(r.chain.last, r.chain.length - 1, r.holders)]));
  }
  int sectIndex(CourtGroup g) => g.titles.map((t) => index(t.title)).fold(order.length, (a, b) => a < b ? a : b);
  groups.sort((a, b) => sectIndex(a).compareTo(sectIndex(b)));
  return groups;
}
