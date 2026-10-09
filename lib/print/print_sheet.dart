import '../bonds/bond.dart';
import '../characters/character.dart';
import '../core/dates.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show hourText, shortDay;
import '../items/item.dart';
import '../morality/morality_rules.dart';
import '../places/place.dart';
import '../rulebook/rulebook.dart';
import '../titles/title_rules.dart' show playerView;

/// Version imprimée : la version figée du gel en cours, ou la fiche actuelle.
enum PrintVersion { frozen, current }

/// Ligne d'une section : libellé, précision grisée, pastilles ([dots] pleines sur [dotsMax]) et valeur à droite.
class PrintRow {
  const PrintRow(this.label, {this.detail = '', this.dots = 0, this.dotsMax = 0, this.value = ''});
  final String label;
  final String detail;
  final int dots;
  final int dotsMax;
  final String value;
}

/// Jauge à cocher en jeu : [boxes] cases (rondes si [round], pleines jusqu'à [filled]), ou des groupes nommés (santé).
class PrintGauge {
  const PrintGauge(this.label, {this.boxes = 0, this.note = '', this.filled = 0, this.round = false, this.groups = const []});
  final String label;
  final int boxes;
  final String note;
  final int filled;
  final bool round;
  final List<(String, int)> groups;
}

class PrintAttribute {
  const PrintAttribute(this.name, this.value, this.focus);
  final String name;
  final int value;
  final String focus;
}

/// La fiche prête à imprimer : tous les textes et les nombres de cases, sans mise en page.
class PrintSheet {
  const PrintSheet({
    required this.name,
    required this.identity,
    required this.people,
    required this.stamp,
    required this.reminder,
    required this.fileName,
    required this.footer,
    required this.attributes,
    required this.skills,
    required this.gauges,
    required this.disciplines,
    required this.meritsTitle,
    required this.merits,
    required this.flawsTitle,
    required this.flaws,
    required this.backgrounds,
    required this.morality,
    required this.bonds,
    required this.items,
    required this.places,
    required this.xp,
    required this.concept,
    required this.story,
  });

  final String name;
  final String identity;
  final String people;

  /// Cartouche de la page 1 : la première ligne est le titre.
  final List<String> stamp;

  /// Rappel en tête des pages suivantes.
  final String reminder;
  final String fileName;
  final String footer;
  final List<PrintAttribute> attributes;
  final List<PrintRow> skills;
  final List<PrintGauge> gauges;
  final List<PrintRow> disciplines;
  final String meritsTitle;
  final List<PrintRow> merits;
  final String flawsTitle;
  final List<PrintRow> flaws;

  /// Historiques, puis alliés, puis serviteurs.
  final List<PrintRow> backgrounds;
  final List<PrintRow> morality;
  final List<PrintRow> bonds;
  final List<PrintRow> items;
  final List<PrintRow> places;
  final List<(String, String)> xp;
  final String concept;
  final String story;
}

const _none = [PrintRow('Aucun')];

List<PrintRow> _orNone(List<PrintRow> rows) => rows.isEmpty ? _none : rows;

String _two(int n) => n.toString().padLeft(2, '0');

String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _or(String? s, String fallback) => (s ?? '').trim().isEmpty ? fallback : s!.trim();

/// Santé « 3 · 3 · 3 » : cases Sain, Blessé, Incapacité ; 3 pour un nombre illisible.
List<(String, int)> healthGroups(String health) {
  final parts = [for (final p in health.split('·')) int.tryParse(p.trim())];
  int at(int i) => i < parts.length && parts[i] != null && parts[i]! >= 0 ? parts[i]! : 3;
  return [('Sain', at(0)), ('Blessé', at(1)), ('Incapacité', at(2))];
}

/// Fiche imprimable. [sheet] est la version choisie (figée ou actuelle) ; [game] le gel en cours qui la fige.
/// Le titre suit la vue du joueur ; seuls les liens connus du joueur s'impriment.
PrintSheet printSheet(
  Character sheet, {
  required PrintVersion version,
  Game? game,
  required DateTime now,
  required Rulebook rb,
  List<Item> items = const [],
  List<Place> places = const [],
  List<Bond> bonds = const [],
  int reserved = 0,
  String chronicle = '',
}) {
  final c = playerView(sheet, rb);
  final frozenBy = version == PrintVersion.frozen ? game : null;
  final ghoul = c.ghoul;
  final player = c.playerName ?? 'PNJ';

  final generation = c.genRank == null ? null : '${c.genRank!.label}${c.genNumber == null ? '' : ', ${c.genNumber}e génération'}';
  final identity = [c.clan, c.sect, ghoul != null ? 'Goule de ${ghoul.domitorName}' : generation, c.archetype]
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .join(' · ');

  final String reminder;
  final List<String> stamp;
  final String fileName;
  if (frozenBy != null) {
    final gameDay = '${shortDay(frozenBy.date)} ${frozenBy.date.year}';
    stamp = ['Version figée', 'Partie du $gameDay', 'Figée le ${formatDay(frozenBy.frozenAt)} à ${hourText(frozenBy.frozenAt)}'];
    reminder = 'Version figée · partie du $gameDay';
    fileName = '${c.name} – partie du ${_iso(frozenBy.date)}.pdf';
  } else {
    stamp = game != null ? ['Version actuelle', 'Non valable en jeu'] : ['Version du ${formatDay(now)} ${now.year}'];
    reminder = game != null ? 'Version actuelle · non valable en jeu' : stamp.single;
    fileName = '${c.name} – ${_iso(now)}.pdf';
  }

  final max = moralityMax(c, rb);
  int total(List<Trait> l) => l.fold(0, (s, t) => s + t.level);

  return PrintSheet(
    name: c.name,
    identity: identity,
    people: 'Joueur : $player · Titre : ${_or(c.title, 'aucun')} · Sire : ${_or(c.sire, 'inconnu')}',
    stamp: stamp,
    reminder: reminder,
    fileName: fileName,
    footer: [c.name, player, chronicle].where((s) => s.trim().isNotEmpty).join(' · '),
    attributes: [for (final a in AttrCategory.values) PrintAttribute(a.label, c.attributes[a]!.value, _or(c.attributes[a]!.focus, '—'))],
    skills: _orNone([for (final s in c.skills) PrintRow(s.name, detail: s.note ?? '', dots: s.level)]),
    gauges: [
      if (ghoul != null) const PrintGauge('Vitae', boxes: 5) else PrintGauge('Sang · ${c.blood}', boxes: c.blood, note: '${c.bloodPerTurn} par tour'),
      PrintGauge('Volonté · ${c.willpower}', boxes: c.willpower),
      PrintGauge('Santé', groups: healthGroups(c.health)),
      PrintGauge('${moralityName(c)} · ${c.humanity} ${moralityLabel(c.humanity)}', boxes: max, filled: c.humanity.clamp(0, max), round: true),
      const PrintGauge('Traits de Bête ce soir', boxes: lossThreshold, note: 'à 5, perte d’un point'),
      const PrintGauge('Traits de dérangement', boxes: 3),
    ],
    disciplines: _orNone([
      for (final d in c.disciplines) PrintRow(d.name, detail: d.powers.join(' · '), dots: d.level, value: d.inClan ? 'en clan' : 'hors clan'),
    ]),
    meritsTitle: 'Atouts · ${total(c.merits)}',
    merits: _orNone([for (final m in c.merits) PrintRow(m.name, value: '${m.level}')]),
    flawsTitle: 'Handicaps · ${total(c.flaws)}',
    flaws: _orNone([for (final f in c.flaws) PrintRow(f.name, value: '${f.level}')]),
    backgrounds: _orNone([
      for (final b in c.backgrounds) PrintRow(b.name, detail: b.note ?? '', dots: b.level),
      for (final a in c.allies)
        PrintRow('Allié · ${a.name}', detail: [a.type, a.domain].where((s) => s.trim().isNotEmpty).join(' · '), dots: a.level),
      for (final s in c.servants) PrintRow('${s.kind.label} · ${s.name}', dots: s.rank),
    ]),
    morality: [
      PrintRow(moralityName(c), value: '${c.humanity} · ${moralityLabel(c.humanity)}'),
      PrintRow('Dérangements', value: c.derangements.isEmpty ? 'Aucun' : c.derangements.map((d) => d.name).join(', ')),
      PrintRow('Titre', value: _or(c.title, 'Aucun')),
    ],
    bonds: _orNone([
      for (final b in bonds)
        if (b.level > 0 && b.thrallId == c.id && b.known)
          PrintRow('Envers ${b.regnantName}', dots: b.level, dotsMax: 3)
        else if (b.level > 0 && b.regnantId == c.id && b.regnantKnows)
          PrintRow('${b.thrallName}, lié à vous', dots: b.level, dotsMax: 3),
    ]),
    items: _orNone([
      for (final i in items)
        PrintRow(i.name, detail: [...i.qualities, if ((i.extraQuality ?? '').trim().isNotEmpty) i.extraQuality!.trim()].join(', ')),
    ]),
    places: _orNone([
      for (final p in places)
        PrintRow(p.name, detail: [p.type.label, for (final q in p.qualities) q.count > 1 ? '${q.name} ×${q.count}' : q.name].join(', '), dots: p.rank),
    ]),
    xp: [
      ('Initiale', '${c.xpInitial}'),
      ('Gagnée', '${c.xpEarned}'),
      ('Dépensée', '${c.xpSpent}'),
      ('Disponible', reserved > 0 ? '${c.xpAvailable} · dont $reserved réservés' : '${c.xpAvailable}'),
    ],
    concept: (c.concept ?? '').trim(),
    story: (c.story ?? '').trim(),
  );
}
