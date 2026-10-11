import 'dart:math';

import '../auth/session.dart';
import '../characters/character.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/schema.dart';
import 'wiki_markdown.dart';
import 'wiki_page.dart';

/// Rubrique du wiki : des catégories du référentiel, plus les pages libres qui la choisissent.
class Rubric {
  const Rubric(this.id, this.label, this.blurb, this.cats);
  final String id;
  final String label;
  final String blurb;
  final List<String> cats;
}

const chronicleRubric = 'chronique';

/// Page virtuelle de la chronologie publique (sous-projet 9b).
const chronologyId = 'chronologie';

const rubrics = [
  Rubric('clans', 'Clans & sectes', 'Histoire, disciplines, faiblesses', ['clans', 'sects']),
  Rubric('disciplines', 'Disciplines', 'Pouvoirs niveau par niveau', ['disciplines']),
  Rubric('rituels', 'Rituels', 'Thaumaturgie, Nécromancie', ['rituals']),
  Rubric('techniques', 'Techniques & pouvoirs d’anciens', 'Prérequis et effets', ['techniques', 'elderPowers']),
  Rubric('atouts', 'Atouts & handicaps', 'Par catégorie et par clan', ['merits', 'flaws']),
  Rubric('historiques', 'Historiques', 'Ce que chaque niveau apporte', ['backgrounds']),
  Rubric('allies', 'Alliés', 'Types, domaines, spécialisations', ['allies']),
  Rubric('equipement', 'Équipement', 'Catégories et qualités', ['equipment']),
  Rubric('lieux', 'Lieux & goules animales', 'Qualités de lieu, qualités animales', ['placeQualities', 'animalQualities']),
  Rubric('competences', 'Compétences', 'Domaines et usages', ['skills']),
  Rubric('moralite', 'Moralité', 'Humanité, voies, dérangements', ['paths', 'derangements']),
  Rubric('systeme', 'Système de jeu', 'Tests, combat, Sang, Volonté', ['generations', 'blood', 'archetypes']),
  Rubric(chronicleRubric, 'La chronique', 'La ville, la cour, les titres', ['titles']),
];

Rubric? findRubric(String id) => rubrics.where((r) => r.id == id).firstOrNull;

/// Rubrique d'affichage : une rubrique inconnue range la page dans « La chronique ».
Rubric rubricById(String id) => findRubric(id) ?? rubrics.last;

String rubricOfCat(String cat) => rubrics.firstWhere((r) => r.cats.contains(cat), orElse: () => rubrics.last).id;

// ---- Audiences ----

const audienceAll = 'all';
const audienceStaff = 'staff';

/// Avec `all`, la requête du joueur reste sous la limite de 30 valeurs de `whereIn`.
const maxAudiences = 29;

String clanAudience(String clan) => 'clan:${nameKey(clan)}';
String sectAudience(String sect) => 'sect:${nameKey(sect)}';

/// Accès réservés d'un joueur : clan de sang et secte de chacune de ses fiches de PJ actives.
List<String> wikiAudiences(Iterable<Character> sheets) {
  final set = <String>{
    for (final c in sheets)
      if (c.kind == CharacterKind.pj && c.status == CharacterStatus.active) ...[
        if (c.bloodClan case final clan? when clan.trim().isNotEmpty) clanAudience(clan),
        if (c.sect case final sect? when sect.trim().isNotEmpty) sectAudience(sect),
      ],
  };
  final list = set.toList()..sort();
  return list.length > maxAudiences ? list.sublist(0, maxAudiences) : list;
}

/// Comptes dont la liste enregistrée diffère de celle des fiches : uid → liste à écrire.
Map<String, List<String>> audienceChanges(List<AppUser> users, List<Character> sheets) {
  final byPlayer = <String, List<Character>>{};
  for (final c in sheets) {
    if (c.playerUid case final uid?) (byPlayer[uid] ??= []).add(c);
  }
  return {
    for (final u in users)
      if (wikiAudiences(byPlayer[u.uid] ?? const []) case final want when want.join('|') != u.wikiAudiences.join('|')) u.uid: want,
  };
}

/// Même test que les règles Firestore.
bool canRead(String audience, List<String> audiences, {required bool staff}) =>
    staff || audience == audienceAll || audiences.contains(audience);

String _nameOf(Rulebook rb, String cat, String key) => rb.all(cat).where((e) => nameKey(e.name) == key).firstOrNull?.name ?? key;

/// « Tous », « Clan Toreador », « Secte Camarilla », « Conte seul ».
String audienceLabel(String audience, Rulebook rb) => switch (audience) {
      audienceAll => 'Tous',
      audienceStaff => 'Conte seul',
      _ when audience.startsWith('clan:') => 'Clan ${_nameOf(rb, 'clans', audience.substring(5))}',
      _ when audience.startsWith('sect:') => 'Secte ${_nameOf(rb, 'sects', audience.substring(5))}',
      _ => audience,
    };

/// Bandeau d'une page réservée ; null pour une page ouverte à tous.
String? reservedBanner(String audience, Rulebook rb) => switch (audience) {
      audienceStaff => 'Réservé au conte.',
      _ when audience.startsWith('clan:') => 'Réservé au clan ${_nameOf(rb, 'clans', audience.substring(5))}.',
      _ when audience.startsWith('sect:') => 'Réservé à la secte ${_nameOf(rb, 'sects', audience.substring(5))}.',
      _ => null,
    };

/// Choix « Visible par » de l'éditeur : (valeur, libellé).
List<(String, String)> audienceOptions(Rulebook rb) => [
      (audienceAll, 'Tous les joueurs'),
      for (final c in rb.all('clans')) (clanAudience(c.name), 'Clan ${c.name}'),
      for (final s in rb.all('sects')) (sectAudience(s.name), 'Secte ${s.name}'),
      (audienceStaff, 'Le conte seul'),
    ];

// ---- Clés ----

const _plainLetters = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', '’': "'",
};

/// Minuscules sans accents, de même longueur que [s] : une position trouvée vaut dans le texte d'origine.
String fold(String s) => s.toLowerCase().split('').map((c) => _plainLetters[c] ?? c).join();

String slug(String s) => fold(s).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

/// Identifiant de l'entrée ; une valeur de base (sans identifiant) prend son nom simplifié.
String entryKey(RuleEntry e) => e.id.isNotEmpty ? e.id : 'base-${slug(e.name)}';

String rulePageId(String cat, RuleEntry e) => 'r_${cat}_${entryKey(e)}';

// ---- Index ----

/// Élément du wiki : page de règle (rédigée ou non), page libre, ou brouillon (équipe).
class WikiItem {
  const WikiItem({required this.id, required this.title, required this.rubric, this.cat, this.entry, this.page, this.draft, this.orphan = false});
  final String id;
  final String title;
  final String rubric;
  final String? cat;
  final RuleEntry? entry;

  /// Version publiée.
  final WikiPage? page;

  /// Brouillon en cours (équipe seulement).
  final WikiPage? draft;

  /// Page de règle dont l'entrée n'existe plus.
  final bool orphan;

  bool get isRule => cat != null;
  bool get written => (page?.body.trim() ?? '').isNotEmpty;
  String get audience => page?.audience ?? draft?.audience ?? audienceAll;
  String? get vo => entry?.vo;
}

/// Éléments lisibles, triés par titre. Joueur : entrées proposées et pages reçues (déjà filtrées par les règles) ;
/// équipe : toutes les entrées, les pages orphelines et les brouillons.
List<WikiItem> wikiIndex(Rulebook rb, List<WikiPage> pages, {required bool staff, List<WikiPage> drafts = const []}) {
  final published = {for (final p in pages) p.id: p};
  final drafted = {for (final d in drafts) d.id: d};
  final items = <WikiItem>[];
  final seen = <String>{};
  for (final r in rubrics) {
    for (final cat in r.cats) {
      for (final e in rb.all(cat)) {
        if (!staff && !e.state.offered) continue;
        final id = rulePageId(cat, e);
        if (!seen.add(id)) continue;
        items.add(WikiItem(id: id, title: e.name, rubric: r.id, cat: cat, entry: e, page: published[id], draft: drafted[id]));
      }
    }
  }
  for (final p in pages) {
    if (seen.contains(p.id) || (p.cat != null && !staff)) continue;
    seen.add(p.id);
    items.add(WikiItem(
      id: p.id,
      title: p.title,
      rubric: p.cat == null ? rubricById(p.rubric).id : rubricOfCat(p.cat!),
      cat: p.cat,
      page: p,
      draft: drafted[p.id],
      orphan: p.cat != null,
    ));
  }
  for (final d in drafts) {
    if (!seen.add(d.id)) continue;
    items.add(WikiItem(
      id: d.id,
      title: d.title,
      rubric: d.cat == null ? rubricById(d.rubric).id : rubricOfCat(d.cat!),
      cat: d.cat,
      draft: d,
      orphan: d.cat != null,
    ));
  }
  if (seen.add(chronologyId)) items.add(const WikiItem(id: chronologyId, title: 'Chronologie publique', rubric: chronicleRubric));
  return items..sort((a, b) => fold(a.title).compareTo(fold(b.title)));
}

/// Ce que montre la lecture : l'équipe voit tout ; l'aperçu joueur, les pages ouvertes à tous et les entrées proposées.
List<WikiItem> readerItems(Rulebook rb, List<WikiPage> pages, {required bool staff, bool preview = false}) => preview
    ? wikiIndex(rb, [for (final p in pages) if (p.audience == audienceAll) p], staff: false)
    : wikiIndex(rb, pages, staff: staff);

enum WikiState {
  published('Publié'),
  draft('Brouillon'),
  empty('À rédiger');

  const WikiState(this.label);
  final String label;
}

WikiState stateOf(WikiItem i) => i.id == chronologyId
    ? WikiState.published
    : i.draft != null
    ? WikiState.draft
    : i.page == null || (i.isRule && !i.written)
        ? WikiState.empty
        : WikiState.published;

String originLabel(WikiItem i) => i.id == chronologyId
    ? 'Événements publics, automatique'
    : i.orphan
    ? 'Entrée supprimée'
    : i.isRule
        ? 'Fiche du référentiel'
        : 'Page libre';

/// Par rubrique : pages de règles publiées non vides sur nombre d'entrées.
List<({String label, int done, int total})> progress(List<WikiItem> items) => [
      for (final r in rubrics)
        if ([for (final i in items) if (i.rubric == r.id && i.isRule && !i.orphan) i] case final rule when rule.isNotEmpty)
          (label: r.label, done: rule.where((i) => i.written).length, total: rule.length),
    ];

List<WikiItem> recentlyUpdated(List<WikiItem> items, {int count = 5}) {
  final dated = [for (final i in items) if (i.page?.updatedAt != null) i]..sort((a, b) => b.page!.updatedAt!.compareTo(a.page!.updatedAt!));
  return dated.take(count).toList();
}

// ---- Recherche et liens ----

class SearchHit {
  const SearchHit(this.item, this.excerpt);
  final WikiItem item;
  final String excerpt;
}

/// Texte cherché : corps sans balises, description, données et pouvoirs de l'entrée.
String searchText(WikiItem i) => [
      if (i.page != null) plainText(i.page!.body),
      if (i.entry case final e?) ...[
        if (e.description.isNotEmpty) e.description,
        for (final (label, value) in dataLines(i.cat!, e)) '$label : $value',
        for (final p in disciplinePowers(e)) '${p.name} ${p.effect}',
      ],
    ].join('\n');

String _excerpt(String text, int at, int length) {
  final start = max(0, at - 40);
  final end = min(text.length, at + length + 60);
  final s = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
  return '${start > 0 ? '… ' : ''}$s${end < text.length ? ' …' : ''}';
}

/// Sans casse ni accents ; les titres (et noms VO) d'abord, puis le texte.
List<SearchHit> search(List<WikiItem> items, String query) {
  final q = fold(query.trim());
  if (q.isEmpty) return const [];
  final byTitle = <SearchHit>[];
  final byText = <SearchHit>[];
  for (final i in items) {
    final text = searchText(i);
    final at = fold(text).indexOf(q);
    final excerpt = at < 0 ? _excerpt(text, 0, 0) : _excerpt(text, at, q.length);
    if (fold(i.title).contains(q) || fold(i.vo ?? '').contains(q)) {
      byTitle.add(SearchHit(i, excerpt));
    } else if (at >= 0) {
      byText.add(SearchHit(i, excerpt));
    }
  }
  return [...byTitle, ...byText];
}

/// Page visible de ce titre : un lien vers une page cachée reste du texte.
WikiItem? resolveLink(String title, List<WikiItem> items) => items.where((i) => nameKey(i.title) == nameKey(title)).firstOrNull;

// ---- Données des entrées ----

String? _fieldText(RuleField f, Object? v) {
  if (f.type == FieldType.flag) return v == true ? 'Oui' : null;
  if (f.type == FieldType.rows) {
    final rows = [
      for (final r in (v as List?) ?? const [])
        if (r is Map)
          [
            for (final rf in f.rowFields)
              if (rf.type != FieldType.flag)
                if (displayValue(rf, r[rf.key]) case final s when s != '—') s,
          ].join(' · '),
    ].where((s) => s.isNotEmpty).toList();
    return rows.isEmpty ? null : rows.join(' ; ');
  }
  final s = displayValue(f, v);
  return s == '—' ? null : s;
}

/// Données de l'entrée affichées sur sa page : (libellé, valeur), champs vides omis.
/// Les pouvoirs d'une discipline sont à part ([disciplinePowers]).
List<(String, String)> dataLines(String cat, RuleEntry e) => [
      for (final f in categoryById(cat)?.fields ?? const <RuleField>[])
        if (!(cat == 'disciplines' && f.key == 'powers'))
          if (_fieldText(f, e.data[f.key]) case final v?) (f.label, v),
    ];

typedef Power = ({int level, String name, String vo, bool elder, String effect});

/// Pouvoirs d'une discipline du référentiel, par niveau.
List<Power> disciplinePowers(RuleEntry e) => [
      for (final p in (e.data['powers'] as List?) ?? const [])
        if (p is Map)
          (
            level: (p['level'] as num?)?.toInt() ?? 0,
            name: '${p['name'] ?? ''}',
            vo: '${p['vo'] ?? ''}',
            elder: p['elder'] == true,
            effect: '${p['effect'] ?? ''}',
          ),
    ]..sort((a, b) => a.level.compareTo(b.level));

/// Ligne sous le titre d'une carte : clans d'une discipline, sinon colonnes du référentiel.
String itemSubtitle(WikiItem i, Rulebook rb) {
  final e = i.entry;
  if (e == null) return '';
  if (i.cat == 'disciplines') {
    final clans = [
      for (final c in rb.all('clans'))
        if (rb.clanDisciplines(c.name).any((d) => nameKey(d) == nameKey(e.name))) c.name,
    ];
    return clans.isEmpty ? (e.data['common'] == true ? 'Commune' : '') : 'En clan : ${clans.join(', ')}';
  }
  final cat = categoryById(i.cat!);
  if (cat == null) return '';
  return [
    for (final k in cat.columns)
      if (cat.fields.where((f) => f.key == k).firstOrNull case final f?)
        ?_fieldText(f, e.data[k]),
  ].join(' · ');
}

/// Puces d'une rubrique : (libellé, test).
List<(String, bool Function(WikiItem))> rubricFilters(Rubric r) => [
      ('Toutes', (WikiItem _) => true),
      if (r.id == 'disciplines') ...[
        ('Communes', (WikiItem i) => i.entry?.data['common'] == true),
        ('Propres à un clan', (WikiItem i) => i.entry != null && i.entry!.data['common'] != true),
      ] else if (r.cats.length > 1)
        for (final c in r.cats) (categoryById(c)?.label ?? c, (WikiItem i) => i.cat == c),
    ];

/// Groupe d'une carte dans sa rubrique : la catégorie, ou « Pages du conte ».
String groupOf(WikiItem i) => i.cat == null ? 'Pages du conte' : categoryById(i.cat!)?.label ?? i.cat!;
