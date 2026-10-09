# Impression de la fiche (sous-projet 8b) : plan d’implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** le joueur imprime sa fiche en A4 (version figée pendant un gel, sinon version actuelle) ; le conte imprime une fiche depuis C3.

**Architecture :**
- **Calcul pur** `lib/print/print_sheet.dart` : `printSheet(...)` transforme une fiche et ses données annexes en `PrintSheet`, une structure de textes prêts à imprimer. Toute la logique est là.
- **Rendu PDF** `lib/print/sheet_pdf.dart` : dessine une `PrintSheet` avec le paquet `pdf` (A4, pastilles et cases dessinées), polices embarquées.
- **Écran** `lib/print/print_screen.dart` : choix de la version pendant un gel, aperçu `PdfPreview` du paquet `printing`.
- **Provider** `frozenSheetProvider(characterId, gameId)` : lecture d’une version figée.

**Tech Stack :** ajout de `pdf` 3.13 et `printing` 5.15 ; polices TTF statiques Source Sans 3 et Cormorant Garamond (licence OFL) dans `assets/fonts/`.

**Spec :** `docs/superpowers/specs/2026-10-18-impression-design.md`.

**Maquettes :** canvas https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planches `Impression-1.dc.html`, `Impression-2.dc.html`, `J-Imprimer.dc.html` (outil Artifact, `action: read`, `path: project/<planche>`).

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md <N> [test|impl]` (fichiers complets seulement ; les modifications de fichiers existants sont décrites et se font à la main) ;
  - textes en français, apostrophe typographique ’ dans les textes affichés et imprimés ;
  - analyseur propre, pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` exactement ;
  - ne jamais commiter `bash.exe.stackdump`, `rules_test/bash.exe.stackdump`, `CLAUDE.md` ni `firestore-debug.log`.
- **Branche :** `impression`, déjà créée (la spec y est commitée).
- **Code généré :** `dart run build_runner build --delete-conflicting-outputs` après un nouveau `@riverpod`. Si des `.g.dart` sans rapport changent (empreintes seulement), les commiter avec la tâche.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Noir et blanc :** aucune couleur dans le PDF, seulement le noir `#1A1414`, le gris `#5A504A` et le gris clair `#D6CEC4`.
- **Pas de glyphe ● dans le PDF :** les pastilles et les cases sont dessinées (cercles et carrés), les polices n’ont pas ces glyphes.
- **Textes fixes :**
  - cartouche : « Version figée » / « Partie du samedi 3 oct. 2026 » / « Figée le 29 sept. à 20h » ; « Version actuelle » / « Non valable en jeu » ; « Version du 17 oct. 2026 » ;
  - rappel de page 2 : « Version figée · partie du samedi 3 oct. 2026 », « Version actuelle · non valable en jeu », « Version du 17 oct. 2026 » ;
  - fichier : « Isaure de Valcourt – partie du 2026-10-03.pdf », « Isaure de Valcourt – 2026-10-17.pdf » ;
  - « Joueur : <nom> · Titre : <titre ou aucun> · Sire : <sire ou inconnu> » ;
  - « Atouts · N », « Handicaps · N », « Aucun » pour un bloc vide ;
  - « Traits de Bête ce soir » (note « à 5, perte d’un point »), « Traits de dérangement », « Santé » (Sain, Blessé, Incapacité), « Vitae » ;
  - « Disponible » : « 20 · dont 12 réservés » ;
  - écran : « Imprimer la fiche », « Version figée · partie du samedi 3 oct. », « Version actuelle · non valable en jeu », « Chargement de la version figée… », « Impossible de préparer le PDF : réessayez. », « Réessayer », « Imprimer ».
- **Leçons des lots précédents :**
  - lire un dépôt dans une action et non dans `build` ;
  - un `ref.read` d’un provider auto-supprimé sans écoute renvoie null : le surveiller dans `build` ;
  - rangées de boutons en `Wrap` (390 px) ;
  - tout écran qui lit un nouveau provider oblige ses tests à le surcharger.

## Review Focus

1. **Titre caché au joueur :** il ne s’imprime pas, même quand le conte imprime. Test : tâche 1.
2. **Liens de sang inconnus du joueur :** ils ne s’impriment pas, même quand le conte imprime (le provider de l’équipe renvoie tous les liens). Test : tâche 1.
3. **Version figée demandée sans gel, ou absente :** l’app imprime la version actuelle, sans mention « non valable en jeu ». Tests : tâches 1 et 3.
4. **Fiche longue :** elle passe sur une page de plus sans erreur ; une fiche vide tient en deux pages. Test : tâche 2.
5. **Joueur sur la fiche d’un autre :** « Cette fiche n’est pas la vôtre ». Test : tâche 3.

---

### Task 1 : calcul pur de la fiche imprimable

**Files :**
- Create : `lib/print/print_sheet.dart`.
- Test : `test/print/print_sheet_test.dart`.

**Interfaces :**
- Consumes :
  - `shortDay`, `hourText` (`lib/games/game_rules.dart`), `Game` (`lib/games/game.dart`) ;
  - `playerView` (`lib/titles/title_rules.dart`) ;
  - `moralityName`, `moralityLabel`, `moralityMax`, `lossThreshold` (`lib/morality/morality_rules.dart`) ;
  - `formatDay` (`lib/core/dates.dart`).
- Produces :
  - `enum PrintVersion { frozen, current }` ;
  - `PrintRow(label, {detail, dots, dotsMax, value})`, `PrintGauge(label, {boxes, note, filled, round, groups})`, `PrintAttribute(name, value, focus)`, `PrintSheet` ;
  - `healthGroups(String health)` → `List<(String, int)>` ;
  - `printSheet(Character sheet, {required PrintVersion version, Game? game, required DateTime now, required Rulebook rb, List<Item> items, List<Place> places, List<Bond> bonds, int reserved, String chronicle})` ;
  - dans le test, exportés : `full()` (fiche complète) et `printed({...})`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md 1 test`, puis `flutter test test/print/print_sheet_test.dart`.

Expected : échec de compilation (`print_sheet.dart` absent).

<!-- file: test/print/print_sheet_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/print/print_sheet.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show ghoulState;
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;

/// Fiche complète : Isaure de Valcourt, Harpie, avec allié et goule.
Character full() => sample()
  ..archetype = 'Architecte'
  ..title = 'Harpie'
  ..blood = 12
  ..bloodPerTurn = 2
  ..willpower = 6
  ..humanity = 5
  ..concept = 'Cantatrice lyrique devenue faiseuse de réputations.'
  ..story = 'Soprano admirée de l’opéra municipal.'
  ..allies = [Ally('a1', 'Maëlle Garnier', level: 1, type: 'Critique', domain: 'Média')]
  ..servants = [Servant('s1', 'Mila Ferreira', ServantKind.human, 2)];

final _now = DateTime(2026, 10, 17, 15);

PrintSheet printed({
  Character? c,
  PrintVersion version = PrintVersion.current,
  bool frozen = false,
  List<Item> items = const [],
  List<Place> places = const [],
  List<Bond> bonds = const [],
  int reserved = 0,
  String chronicle = 'Nuits de Lyon',
}) =>
    printSheet(
      c ?? full(),
      version: version,
      game: frozen ? frozenGame() : null,
      now: _now,
      rb: rbTitles,
      items: items,
      places: places,
      bonds: bonds,
      reserved: reserved,
      chronicle: chronicle,
    );

Bond bond({required String regnant, required String thrall, String regnantName = '', String thrallName = '', int level = 1, bool known = true, bool regnantKnows = true}) => Bond(
      regnantId: regnant,
      regnantName: regnantName,
      thrallId: thrall,
      thrallName: thrallName,
      level: level,
      lastDrink: DateTime(2026, 8, 2),
      lastContact: DateTime(2026, 8, 2),
      known: known,
      regnantKnows: regnantKnows,
    );

void main() {
  test('en-tête, cartouche, rappel, fichier et pied de page : version figée', () {
    final s = printed(version: PrintVersion.frozen, frozen: true);
    expect(s.name, 'Isaure de Valcourt');
    expect(s.identity, 'Toreador · Camarilla · Ancilla, 10e génération · Architecte');
    expect(s.people, 'Joueur : Camille R. · Titre : Harpie · Sire : inconnu');
    expect(s.stamp, ['Version figée', 'Partie du samedi 3 oct. 2026', 'Figée le 29 sept. à 20h']);
    expect(s.reminder, 'Version figée · partie du samedi 3 oct. 2026');
    expect(s.fileName, 'Isaure de Valcourt – partie du 2026-10-03.pdf');
    expect(s.footer, 'Isaure de Valcourt · Camille R. · Nuits de Lyon');
  });

  test('version actuelle pendant un gel : non valable en jeu', () {
    final s = printed(frozen: true);
    expect(s.stamp, ['Version actuelle', 'Non valable en jeu']);
    expect(s.reminder, 'Version actuelle · non valable en jeu');
    expect(s.fileName, 'Isaure de Valcourt – 2026-10-17.pdf');
  });

  test('hors gel, ou version figée demandée sans gel : version du jour (Review Focus 3)', () {
    for (final s in [printed(), printed(version: PrintVersion.frozen)]) {
      expect(s.stamp, ['Version du 17 oct. 2026']);
      expect(s.reminder, 'Version du 17 oct. 2026');
      expect(s.fileName, 'Isaure de Valcourt – 2026-10-17.pdf');
    }
  });

  test('titre caché au joueur : absent, même pour le conte (Review Focus 1)', () {
    final s = printed(c: full()..title = 'Main du Prince');
    expect(s.people, 'Joueur : Camille R. · Titre : aucun · Sire : inconnu');
    expect(s.morality.last.label, 'Titre');
    expect(s.morality.last.value, 'Aucun');
  });

  test('attributs, compétences, disciplines, atouts et handicaps', () {
    final s = printed();
    expect([for (final a in s.attributes) a.name], ['Physique', 'Social', 'Mental']);
    expect(s.attributes[1].value, 7);
    expect(s.attributes[1].focus, 'Charisme');
    expect(s.attributes[0].focus, '—');
    expect(s.skills.single.label, 'Représentation');
    expect(s.skills.single.detail, 'chant lyrique');
    expect(s.skills.single.dots, 4);
    final d = s.disciplines.single;
    expect(d.label, 'Auspex');
    expect(d.detail, 'Sens exacerbés');
    expect(d.dots, 3);
    expect(d.value, 'en clan');
    expect(s.meritsTitle, 'Atouts · 1');
    expect(s.flawsTitle, 'Handicaps · 2');
    expect(s.flaws.single.label, 'Curiosité');
    expect(s.flaws.single.value, '2');
  });

  test('à cocher en jeu : sang, volonté, santé, moralité, traits', () {
    final s = printed();
    expect([for (final g in s.gauges) g.label], [
      'Sang · 12',
      'Volonté · 6',
      'Santé',
      'Humanité · 5 Normale',
      'Traits de Bête ce soir',
      'Traits de dérangement',
    ]);
    expect(s.gauges[0].boxes, 12);
    expect(s.gauges[0].note, '2 par tour');
    expect(s.gauges[1].boxes, 6);
    expect(s.gauges[2].groups, [('Sain', 3), ('Blessé', 3), ('Incapacité', 3)]);
    expect(s.gauges[3].boxes, 6);
    expect(s.gauges[3].filled, 5);
    expect(s.gauges[3].round, isTrue);
    expect(s.gauges[4].boxes, 5);
    expect(s.gauges[4].note, 'à 5, perte d’un point');
    expect(s.gauges[5].boxes, 3);
  });

  test('santé : lue dans le champ, 3 par défaut', () {
    expect(healthGroups('2 · 4'), [('Sain', 2), ('Blessé', 4), ('Incapacité', 3)]);
    expect(healthGroups('n’importe quoi'), [('Sain', 3), ('Blessé', 3), ('Incapacité', 3)]);
  });

  test('fiche de goule : domitor dans l’en-tête, vitae au lieu du sang', () {
    final s = printed(c: full()..ghoul = ghoulState());
    expect(s.identity, contains('Goule de '));
    expect(s.identity, isNot(contains('génération')));
    expect(s.gauges.first.label, 'Vitae');
    expect(s.gauges.first.boxes, 5);
  });

  test('historiques, alliés, serviteurs', () {
    final s = printed();
    expect([for (final r in s.backgrounds) r.label], ['Ressources', 'Allié · Maëlle Garnier', 'Goule humaine · Mila Ferreira']);
    expect(s.backgrounds[0].detail, '4 500 € par mois');
    expect(s.backgrounds[0].dots, 3);
    expect(s.backgrounds[1].detail, 'Critique · Média');
    expect(s.backgrounds[2].dots, 2);
  });

  test('moralité, dérangements', () {
    final s = printed(c: full()..derangements = [Derangement('d1', 'Paranoïa')]);
    expect(s.morality[0].label, 'Humanité');
    expect(s.morality[0].value, '5 · Normale');
    expect(s.morality[1].value, 'Paranoïa');
    expect(s.morality[2].value, 'Harpie');
  });

  test('liens de sang : seulement ceux connus du joueur (Review Focus 2)', () {
    final s = printed(bonds: [
      bond(regnant: 'oct', regnantName: 'Octave Marchetti', thrall: 'x', level: 1),
      bond(regnant: 'cel', regnantName: 'Céleste', thrall: 'x', level: 2, known: false),
      bond(regnant: 'x', thrall: 'mil', thrallName: 'Mila Ferreira', level: 3),
      bond(regnant: 'x', thrall: 'jon', thrallName: 'Jonas', level: 1, regnantKnows: false),
      bond(regnant: 'pau', regnantName: 'Paul', thrall: 'x', level: 0),
    ]);
    expect([for (final r in s.bonds) r.label], ['Envers Octave Marchetti', 'Mila Ferreira, lié à vous']);
    expect(s.bonds[0].dots, 1);
    expect(s.bonds[0].dotsMax, 3);
    expect(s.bonds[1].dots, 3);
  });

  test('équipement et lieux', () {
    final s = printed(
      items: [Item(name: 'Canne-épée', qualities: ['Dissimulable', 'Antique'])],
      places: [Place(name: 'Le salon de l’Opéra', rank: 2, qualities: [PlaceQuality('Luxe'), PlaceQuality('Salle', 2)])],
    );
    expect(s.items.single.label, 'Canne-épée');
    expect(s.items.single.detail, 'Dissimulable, Antique');
    expect(s.places.single.label, 'Le salon de l’Opéra');
    expect(s.places.single.detail, 'Standard, Luxe, Salle ×2');
    expect(s.places.single.dots, 2);
  });

  test('expérience, avec ou sans XP réservée', () {
    expect(printed().xp, [('Initiale', '33'), ('Gagnée', '33'), ('Dépensée', '46'), ('Disponible', '20')]);
    expect(printed(reserved: 12).xp.last, ('Disponible', '20 · dont 12 réservés'));
  });

  test('concept, récit, pied de page sans nom de chronique', () {
    final s = printed(chronicle: '');
    expect(s.concept, 'Cantatrice lyrique devenue faiseuse de réputations.');
    expect(s.story, 'Soprano admirée de l’opéra municipal.');
    expect(s.footer, 'Isaure de Valcourt · Camille R.');
  });

  test('blocs vides : « Aucun »', () {
    final s = printed(c: Character(id: 'e', name: 'Vide', kind: CharacterKind.pj, status: CharacterStatus.active));
    for (final rows in [s.skills, s.disciplines, s.merits, s.flaws, s.backgrounds, s.bonds, s.items, s.places]) {
      expect(rows.single.label, 'Aucun');
    }
    expect(s.morality[1].value, 'Aucun');
    expect(s.people, 'Joueur : PNJ · Titre : aucun · Sire : inconnu');
    expect(s.identity, '');
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md 1 impl`.

<!-- file: lib/print/print_sheet.dart -->
```dart
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
```

- [ ] **Step 3 : vérification**

Run : `flutter test test/print/print_sheet_test.dart`, puis `flutter analyze`, puis `flutter test`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 4 : commit**

```
git add lib/print test/print
git commit -m "feat: impression — fiche imprimable (calcul pur)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : rendu PDF, polices, lecture de la version figée

**Files :**
- Create :
  - `lib/print/sheet_pdf.dart` ;
  - `assets/fonts/SourceSans3-Regular.ttf`, `assets/fonts/SourceSans3-Bold.ttf`, `assets/fonts/CormorantGaramond-Bold.ttf`, `assets/fonts/CormorantGaramond-Italic.ttf` (téléchargés) ;
  - `assets/fonts/OFL-SourceSans3.md`, `assets/fonts/OFL-Cormorant.txt` (licences, téléchargées) ;
  - `test/print/sheet_pdf_test.dart`.
- Modify : `pubspec.yaml`, `pubspec.lock`, `lib/games/games_repository.dart` (et son `.g.dart`).

**Interfaces :**
- Consumes : la tâche 1 (`PrintSheet`, `printSheet`, `full()`, `printed()`).
- Produces :
  - `PdfFonts({regular, bold, serif, serifItalic})` (polices `pw.Font`) ;
  - `loadPdfFonts()` → `Future<PdfFonts>` (assets, mis en cache) ;
  - `sheetDocument(PrintSheet, PdfFonts)` → `pw.Document` ; `sheetPdf(PrintSheet, PdfFonts)` → `Future<Uint8List>` ;
  - `GamesRepository.watchSnapshot(String characterId, String gameId)` → `Stream<FrozenSheet?>` ;
  - `frozenSheetProvider(String characterId, String gameId)` (`Stream<FrozenSheet?>`) ;
  - dans le test, exporté : `testFonts()` (polices lues sur disque).

- [ ] **Step 1 : dépendances et polices**

Run :

```
flutter pub add pdf:^3.13.1 printing:^5.15.1
mkdir -p assets/fonts
curl -sSfL -o assets/fonts/SourceSans3-Regular.ttf https://github.com/adobe-fonts/source-sans/raw/release/TTF/SourceSans3-Regular.ttf
curl -sSfL -o assets/fonts/SourceSans3-Bold.ttf https://github.com/adobe-fonts/source-sans/raw/release/TTF/SourceSans3-Bold.ttf
curl -sSfL -o assets/fonts/OFL-SourceSans3.md https://github.com/adobe-fonts/source-sans/raw/release/LICENSE.md
curl -sSfL -o assets/fonts/CormorantGaramond-Bold.ttf https://github.com/CatharsisFonts/Cormorant/raw/master/fonts/ttf/CormorantGaramond-Bold.ttf
curl -sSfL -o assets/fonts/CormorantGaramond-Italic.ttf https://github.com/CatharsisFonts/Cormorant/raw/master/fonts/ttf/CormorantGaramond-Italic.ttf
curl -sSfL -o assets/fonts/OFL-Cormorant.txt https://github.com/CatharsisFonts/Cormorant/raw/master/OFL.txt
```

Expected : quatre `.ttf` de plus de 400 Ko chacun (`ls -l assets/fonts`). Ce sont des polices **statiques** : ne pas les remplacer par les fichiers variables `[wght]` de Google Fonts, que le paquet `pdf` gère mal.

Dans `pubspec.yaml`, sous `flutter:` (après `uses-material-design: true`), ajouter :

```yaml
  assets:
    - assets/fonts/SourceSans3-Regular.ttf
    - assets/fonts/SourceSans3-Bold.ttf
    - assets/fonts/CormorantGaramond-Bold.ttf
    - assets/fonts/CormorantGaramond-Italic.ttf
```

- [ ] **Step 2 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md 2 test`, puis `flutter test test/print/sheet_pdf_test.dart`.

Expected : échec de compilation (`sheet_pdf.dart` absent).

<!-- file: test/print/sheet_pdf_test.dart -->
```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/print/print_sheet.dart';
import 'package:portail_met/print/sheet_pdf.dart';

import 'print_sheet_test.dart' show full, printed;

/// Polices lues sur disque : les tests n'ont pas besoin du bundle d'assets.
PdfFonts testFonts() {
  pw.Font font(String name) => pw.Font.ttf(ByteData.sublistView(File('assets/fonts/$name.ttf').readAsBytesSync()));
  return PdfFonts(
    regular: font('SourceSans3-Regular'),
    bold: font('SourceSans3-Bold'),
    serif: font('CormorantGaramond-Bold'),
    serifItalic: font('CormorantGaramond-Italic'),
  );
}

Future<int> pages(PrintSheet s) async {
  final doc = sheetDocument(s, testFonts());
  final bytes = await doc.save();
  expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  return doc.document.pdfPageList.pages.length;
}

void main() {
  test('fiche complète : un PDF de deux pages, version figée', () async {
    expect(await pages(printed(version: PrintVersion.frozen, frozen: true)), 2);
  });

  test('fiche vide : deux pages (Review Focus 4)', () async {
    expect(await pages(printed(c: Character(id: 'e', name: 'Vide', kind: CharacterKind.pj, status: CharacterStatus.active))), 2);
  });

  test('fiche longue : une page de plus, sans erreur (Review Focus 4)', () async {
    final long = full()
      ..backgrounds = [for (var i = 0; i < 30; i++) Trait('Historique $i', 2, note: 'précision du point $i')]
      ..story = List.filled(300, 'Une longue nuit à l’opéra, sous les lustres.').join(' ');
    expect(await pages(printed(c: long)), greaterThan(2));
  });

  test('sheetPdf renvoie les octets du document', () async {
    final bytes = await sheetPdf(printed(), testFonts());
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
```

- [ ] **Step 3 : implémentation du rendu**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md 2 impl`.

<!-- file: lib/print/sheet_pdf.dart -->
```dart
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'print_sheet.dart';

/// Polices embarquées : Source Sans 3 (texte), Cormorant Garamond (noms, concept).
class PdfFonts {
  const PdfFonts({required this.regular, required this.bold, required this.serif, required this.serifItalic});
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font serif;
  final pw.Font serifItalic;
}

Future<PdfFonts>? _fonts;

/// Polices lues dans les assets, une fois ; un échec n'est pas gardé en cache.
Future<PdfFonts> loadPdfFonts() => _fonts ??= _loadFonts().catchError((Object e) {
      _fonts = null;
      throw e;
    });

Future<PdfFonts> _loadFonts() async {
  Future<pw.Font> font(String name) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
  return PdfFonts(
    regular: await font('SourceSans3-Regular'),
    bold: await font('SourceSans3-Bold'),
    serif: await font('CormorantGaramond-Bold'),
    serifItalic: await font('CormorantGaramond-Italic'),
  );
}

// Noir et blanc : encre, gris des précisions, gris clair des filets.
const _ink = PdfColor.fromInt(0xFF1A1414);
const _muted = PdfColor.fromInt(0xFF5A504A);
const _rule = PdfColor.fromInt(0xFFD6CEC4);

/// La fiche en A4 portrait : page 1, saut de page, page 2 (et suivantes si la fiche est longue).
pw.Document sheetDocument(PrintSheet s, PdfFonts f) {
  final doc = pw.Document(title: s.name, theme: pw.ThemeData.withFont(base: f.regular, bold: f.bold));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 26),
    header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _reminder(s, f),
    footer: (ctx) => _footer(s, ctx),
    build: (ctx) => [..._page1(s, f), pw.NewPage(), ..._page2(s, f)],
  ));
  return doc;
}

Future<Uint8List> sheetPdf(PrintSheet s, PdfFonts f) => sheetDocument(s, f).save();

pw.Widget _title(String t) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 3),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2))),
      child: pw.Text(t.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
    );

/// [n] ronds pleins, complétés jusqu'à [max] par des ronds vides.
pw.Widget _dots(int n, {int max = 0}) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      for (var i = 0; i < (max > n ? max : n); i++)
        pw.Container(
          width: 6,
          height: 6,
          margin: const pw.EdgeInsets.only(left: 1.5),
          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: i < n ? _ink : null, border: pw.Border.all(color: _ink, width: 0.8)),
        ),
    ]);

pw.Widget _row(PrintRow r) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(style: const pw.TextStyle(fontSize: 9.5, color: _ink), children: [
              pw.TextSpan(text: r.label),
              if (r.detail.isNotEmpty) pw.TextSpan(text: '  ${r.detail}', style: const pw.TextStyle(color: _muted)),
            ]),
          ),
        ),
        if (r.dots > 0 || r.dotsMax > 0) pw.Padding(padding: const pw.EdgeInsets.only(left: 6, top: 2.5), child: _dots(r.dots, max: r.dotsMax)),
        if (r.value.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 6),
            child: pw.Text(r.value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ),
      ]),
    );

pw.Widget _section(String title, List<PrintRow> rows) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [_title(title), for (final r in rows) _row(r)]);

pw.Widget _boxes(int n, {int filled = 0, bool round = false}) => pw.Wrap(spacing: 2.5, runSpacing: 2.5, children: [
      for (var i = 0; i < n; i++)
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            shape: round ? pw.BoxShape.circle : pw.BoxShape.rectangle,
            color: i < filled ? _ink : null,
            border: pw.Border.all(color: _ink, width: 1),
          ),
        ),
    ]);

pw.Widget _gauge(PrintGauge g) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.RichText(
          text: pw.TextSpan(style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink), children: [
            pw.TextSpan(text: g.label),
            if (g.note.isNotEmpty) pw.TextSpan(text: ' · ${g.note}', style: const pw.TextStyle(fontWeight: pw.FontWeight.normal, color: _muted)),
          ]),
        ),
        pw.SizedBox(height: 3),
        if (g.groups.isEmpty)
          _boxes(g.boxes, filled: g.filled, round: g.round)
        else
          pw.Row(children: [
            for (final (label, n) in g.groups)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 12),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _boxes(n),
                  pw.SizedBox(height: 2),
                  pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
          ]),
      ]),
    );

pw.Widget _frame(pw.Widget child, {pw.EdgeInsets margin = pw.EdgeInsets.zero}) => pw.Container(
      margin: margin,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
      child: child,
    );

// ponytail: les rangées à deux colonnes ne se coupent pas entre deux pages ; une liste de compétences
// plus haute qu'une page lèverait une erreur. Passer ces colonnes en sections pleine largeur si cela arrive.
List<pw.Widget> _page1(PrintSheet s, PdfFonts f) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(s.name, style: pw.TextStyle(font: f.serif, fontSize: 26)),
            if (s.identity.isNotEmpty) pw.Text(s.identity, style: const pw.TextStyle(fontSize: 10.5)),
            pw.Text(s.people, style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
          ]),
        ),
        _frame(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          for (final (i, line) in s.stamp.indexed)
            pw.Text(
              i == 0 ? line.toUpperCase() : line,
              style: i == 0 ? pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1) : const pw.TextStyle(fontSize: 9),
            ),
        ])),
      ]),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        for (final (i, a) in s.attributes.indexed)
          pw.Expanded(
            child: _frame(
              margin: pw.EdgeInsets.only(left: i == 0 ? 0 : 6),
              pw.Row(children: [
                pw.Text('${a.value}', style: pw.TextStyle(font: f.serif, fontSize: 24)),
                pw.SizedBox(width: 8),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(a.name.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                  pw.Text('Focus : ${a.focus}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                ]),
              ]),
            ),
          ),
      ]),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section('Compétences', s.skills)),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 200,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [_title('À cocher en jeu'), for (final g in s.gauges) _gauge(g)]),
        ),
      ]),
      _title('Disciplines'),
      for (final r in s.disciplines) _row(r),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section(s.meritsTitle, s.merits)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _section(s.flawsTitle, s.flaws)),
      ]),
    ];

List<pw.Widget> _page2(PrintSheet s, PdfFonts f) => [
      _title('Historiques'),
      for (final r in s.backgrounds) _row(r),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section('Moralité', s.morality)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _section('Liens de sang connus', s.bonds)),
      ]),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section('Équipement', s.items)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _section('Lieux', s.places)),
      ]),
      _title('Expérience'),
      pw.Row(children: [
        for (final (label, value) in s.xp)
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
      ]),
      _title('Concept'),
      if (s.concept.isNotEmpty) pw.Text(s.concept, style: pw.TextStyle(font: f.serifItalic, fontSize: 13)),
      if (s.story.isNotEmpty) ...[pw.SizedBox(height: 4), pw.Text(s.story, style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2))],
      if (s.concept.isEmpty && s.story.isEmpty) pw.Text('Aucun', style: const pw.TextStyle(fontSize: 9.5)),
      _title('Notes de partie'),
      for (var i = 0; i < 9; i++)
        pw.Container(height: 20, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.8)))),
    ];

pw.Widget _reminder(PrintSheet s, PdfFonts f) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _muted, width: 0.8))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(s.name, style: pw.TextStyle(font: f.serif, fontSize: 15)),
        pw.Text(s.reminder, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ]),
    );

pw.Widget _footer(PrintSheet s, pw.Context ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _muted, width: 0.8))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(s.footer, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
      ]),
    );
```

Si `pw.Text` d’un long récit ne se coupe pas entre deux pages avec la version installée du paquet, remplacer ce `pw.Text` par `pw.Paragraph(text: s.story, style: …)` (le test de la fiche longue le vérifie).

- [ ] **Step 4 : lecture d’une version figée**

Dans `lib/games/games_repository.dart` :
- dans `GamesRepository`, après `watchSnapshots(...)`, ajouter :

```dart
  /// Version figée d'une fiche pour une partie ; null si elle manque (fiche validée pendant le gel).
  Stream<FrozenSheet?> watchSnapshot(String characterId, String gameId) => _snapshot(characterId, gameId)
      .snapshots()
      .map((d) => d.exists ? FrozenSheet.fromMap(characterId, gameId, d.data()!) : null);
```

- à la fin du fichier, ajouter :

```dart
@riverpod
Stream<FrozenSheet?> frozenSheet(Ref ref, String characterId, String gameId) =>
    ref.watch(gamesRepositoryProvider).watchSnapshot(characterId, gameId);
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter test test/print`, puis `flutter analyze`, puis `flutter test`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 5 : commit**

```
git add pubspec.yaml pubspec.lock assets/fonts lib/print/sheet_pdf.dart lib/games/games_repository.dart lib/games/games_repository.g.dart test/print/sheet_pdf_test.dart
git commit -m "feat: impression — rendu PDF A4, polices embarquées, lecture de la version figée" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Si d’autres `.g.dart` ont changé (empreintes seulement), les ajouter au commit.

---

### Task 3 : écran « Imprimer la fiche », routes et boutons

**Files :**
- Create : `lib/print/print_screen.dart`.
- Modify :
  - `lib/router.dart` ;
  - `lib/games/freeze_banner.dart` ;
  - `lib/characters/character_screen.dart` ;
  - `lib/characters/character_edit_screen.dart`.
- Test :
  - `test/print/print_screen_test.dart` (nouveau) ;
  - `test/characters/character_screen_test.dart`, `test/characters/character_edit_test.dart` (ajouts).

**Interfaces :**
- Consumes :
  - tâches 1 et 2 (`printSheet`, `PrintVersion`, `PrintSheet`, `sheetPdf`, `loadPdfFonts`, `frozenSheetProvider`) ;
  - `gamesProvider`, `frozenBy`, `shortDay` (lot 8a) ; `characterProvider`, `currentUserProvider`, `rulebookProvider`, `chronicleProvider`, `characterItemsProvider`, `characterPlacesProvider`, `characterBondsProvider`, `myRequestsProvider`, `characterRequestsProvider` ; `isDenied` (`lib/characters/sheet_widgets.dart`).
- Produces :
  - `PrintScreen({required String characterId, required String basePath, Widget Function(PrintSheet)? preview})` ;
  - routes `/joueur/personnages/:id/imprimer` et `/conteur/fiches/:id/imprimer` ;
  - `FreezeBanner(text, {action})` ;
  - clés `print-frozen`, `print-current`, `c3-print`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md 3 test`.

<!-- file: test/print/print_screen_test.dart -->
```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/print/print_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  // Gel en cours (2099 : l'écran lit l'heure de l'appareil).
  final game = frozenGame(year: 2099);

  Future<void> pump(
    WidgetTester tester, {
    Stream<Character?>? sheet,
    List<Game> games = const [],
    Stream<FrozenSheet?>? frozen,
    Size size = const Size(1440, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        characterProvider('x').overrideWith((ref) => sheet ?? Stream.value(sample())),
        rulebookProvider.overrideWith((ref) => rbTitles),
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        frozenSheetProvider('x', game.id).overrideWith((ref) => frozen ?? Stream.value(null)),
        noItems,
        noPlaces,
        characterBondsProvider('x').overrideWith((ref) async => const <Bond>[]),
        myRequestsProvider.overrideWith((ref) => Stream.value(const <XpRequest>[])),
        chronicleProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(
          body: PrintScreen(
            characterId: 'x',
            basePath: '/joueur/personnages/x',
            preview: (s) => Text('aperçu ${s.stamp.first}', key: const Key('preview')),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  FrozenSheet snapshot() => FrozenSheet(characterId: 'x', gameId: game.id, sheet: sample().toMap(), version: 4, gameDate: game.date);

  testWidgets('hors gel : version du jour, pas de choix', (tester) async {
    await pump(tester);
    expect(find.text('Imprimer la fiche'), findsOneWidget);
    expect(find.textContaining('aperçu Version du '), findsOneWidget);
    expect(find.byKey(const Key('print-frozen')), findsNothing);
  });

  testWidgets('pendant un gel : version figée par défaut, puis version actuelle', (tester) async {
    await pump(tester, games: [game], frozen: Stream.value(snapshot()));
    expect(find.text('Version figée · partie du samedi 3 oct.'), findsOneWidget);
    expect(find.text('aperçu Version figée'), findsOneWidget);
    await tester.tap(find.byKey(const Key('print-current')));
    await tester.pump();
    expect(find.text('aperçu Version actuelle'), findsOneWidget);
  });

  testWidgets('pendant un gel, version figée absente : version actuelle seule (Review Focus 3)', (tester) async {
    await pump(tester, games: [game]);
    expect(find.byKey(const Key('print-frozen')), findsNothing);
    expect(find.text('aperçu Version actuelle'), findsOneWidget);
  });

  testWidgets('pendant un gel, version figée en cours de lecture', (tester) async {
    final pending = StreamController<FrozenSheet?>();
    addTearDown(pending.close);
    await pump(tester, games: [game], frozen: pending.stream);
    expect(find.text('Chargement de la version figée…'), findsOneWidget);
    expect(find.byKey(const Key('preview')), findsNothing);
  });

  testWidgets('fiche d’un autre joueur : refus (Review Focus 5)', (tester) async {
    await pump(tester, sheet: Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')));
    expect(find.text('Cette fiche n’est pas la vôtre'), findsOneWidget);
  });

  testWidgets('390 px : sans débordement', (tester) async {
    await pump(tester, games: [game], frozen: Stream.value(snapshot()), size: const Size(390, 1200));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('print-frozen')), findsOneWidget);
  });
}
```

**`test/characters/character_screen_test.dart`**, ajouter :

```dart
  testWidgets('J2 : bouton « Imprimer », aussi dans le bandeau du gel (sous-projet 8b)', (tester) async {
    await pump(tester, Stream.value(sample()));
    expect(find.text('Imprimer'), findsOneWidget);
    await pump(tester, Stream.value(sample()), games: [frozenGame(year: 2099)]);
    expect(find.text('Imprimer'), findsNWidgets(2));
  });
```

**`test/characters/character_edit_test.dart`**, ajouter :

```dart
  testWidgets('C3 : bouton « Imprimer » (sous-projet 8b)', (tester) async {
    await pump(tester, withHumanity());
    expect(find.byKey(const Key('c3-print')), findsOneWidget);
  });
```

Run : `flutter test test/print/print_screen_test.dart test/characters/character_screen_test.dart test/characters/character_edit_test.dart`.

Expected : `print_screen_test.dart` ne compile pas (`print_screen.dart` absent) ; les deux autres nouveaux tests échouent (aucun bouton « Imprimer »).

- [ ] **Step 2 : écran**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-18-impression.md 3 impl`.

<!-- file: lib/print/print_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../auth/session_providers.dart';
import '../bonds/bonds_repository.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../items/items_repository.dart';
import '../places/places_repository.dart';
import '../rulebook/rulebook_provider.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'print_sheet.dart';
import 'sheet_pdf.dart';

/// « Imprimer la fiche » (J-Imprimer, simplifié) : choix de la version pendant un gel, aperçu du PDF.
class PrintScreen extends ConsumerStatefulWidget {
  const PrintScreen({super.key, required this.characterId, required this.basePath, this.preview});
  final String characterId;
  final String basePath;

  /// Aperçu ; remplacé dans les tests, car `PdfPreview` passe par des canaux de plateforme.
  final Widget Function(PrintSheet sheet)? preview;

  @override
  ConsumerState<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends ConsumerState<PrintScreen> {
  PrintVersion? _choice;
  int _attempt = 0;

  Widget _pdfPreview(PrintSheet sheet) => PdfPreview(
        key: ValueKey('${sheet.fileName}-$_attempt'),
        build: (_) async => sheetPdf(sheet, await loadPdfFonts()),
        pdfFileName: sheet.fileName,
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        onError: (context, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Impossible de préparer le PDF : réessayez.'),
            const SizedBox(height: 8),
            TextButton(onPressed: () => setState(() => _attempt++), child: const Text('Réessayer')),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(characterProvider(widget.characterId));
    // Riverpod 3 relance un provider en erreur : on lit l'erreur même pendant la relance.
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    return asyncView(value, (live) {
      if (live == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      final rb = ref.watch(rulebookProvider);
      if (rb == null) return const Center(child: CircularProgressIndicator());
      final now = DateTime.now();
      final game = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], live.id, now);
      final frozenAsync = game == null ? null : ref.watch(frozenSheetProvider(live.id, game.id));
      final frozen = frozenAsync?.value;
      final loadingFrozen = frozenAsync != null && frozenAsync.isLoading && !frozenAsync.hasValue;
      final version = frozen != null ? (_choice ?? PrintVersion.frozen) : PrintVersion.current;
      final staff = widget.basePath.startsWith('/conteur');
      final requests = staff ? ref.watch(characterRequestsProvider(live.id)).value : ref.watch(myRequestsProvider).value;
      final reserved = [
        for (final r in requests ?? const <XpRequest>[])
          if (r.characterId == live.id && r.status.open) r,
      ].fold<int>(0, (s, r) => s + r.total);
      final sheet = printSheet(
        version == PrintVersion.frozen ? frozen!.character : live,
        version: version,
        game: game,
        now: now,
        rb: rb,
        items: ref.watch(characterItemsProvider(live.id)).value ?? const [],
        places: ref.watch(characterPlacesProvider(live.id)).value ?? const [],
        bonds: ref.watch(characterBondsProvider(live.id)).value ?? const [],
        reserved: reserved,
        chronicle: ref.watch(chronicleProvider).value?.name ?? '',
      );
      final t = Theme.of(context).textTheme;
      return Padding(
        padding: isWide(context) ? const EdgeInsets.fromLTRB(56, 24, 56, 24) : const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton(onPressed: () => context.go(widget.basePath), child: Text(live.name)),
            Text('/ Imprimer', style: t.bodySmall),
          ]),
          Text('Imprimer la fiche', style: isWide(context) ? t.displaySmall : t.headlineMedium),
          const SizedBox(height: 12),
          if (game != null && frozen != null) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              ChoiceChip(
                key: const Key('print-frozen'),
                label: Text('Version figée · partie du ${shortDay(game.date)}'),
                selected: version == PrintVersion.frozen,
                onSelected: (_) => setState(() => _choice = PrintVersion.frozen),
              ),
              ChoiceChip(
                key: const Key('print-current'),
                label: const Text('Version actuelle · non valable en jeu'),
                selected: version == PrintVersion.current,
                onSelected: (_) => setState(() => _choice = PrintVersion.current),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: loadingFrozen
                ? Center(child: Text('Chargement de la version figée…', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)))
                : (widget.preview ?? _pdfPreview)(sheet),
          ),
        ]),
      );
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }
}
```

**`lib/router.dart` :**
- import `'print/print_screen.dart'` (ordre alphabétique, après `places/places_screen.dart`) ;
- juste après la route `/joueur/personnages/:id/xp` :

```dart
          GoRoute(
            path: '/joueur/personnages/:id/imprimer',
            builder: (_, s) => PrintScreen(characterId: s.pathParameters['id']!, basePath: '/joueur/personnages/${s.pathParameters['id']}'),
          ),
```

- juste après la route `/conteur/fiches/:id/recit` :

```dart
          GoRoute(
            path: '/conteur/fiches/:id/imprimer',
            builder: (_, s) => PrintScreen(characterId: s.pathParameters['id']!, basePath: '/conteur/fiches/${s.pathParameters['id']}'),
          ),
```

**`lib/games/freeze_banner.dart`** : le constructeur devient `const FreezeBanner(this.text, {super.key, this.action});`, avec le champ `final Widget? action;` ; dans la `Row`, après `Expanded(child: Text(...))`, ajouter `?action,`.

**`lib/characters/character_screen.dart`** :
- le bandeau du gel devient :

```dart
          FreezeBanner(
            playerFreezeText(frozen),
            action: TextButton(onPressed: () => context.go('$basePath/imprimer'), child: const Text('Imprimer')),
          ),
```

- le bloc du bouton « Dépenser de l’XP » (l’`Align` et son `FilledButton`) devient :

```dart
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton(onPressed: () => context.go('$basePath/xp'), child: const Text('Dépenser de l’XP')),
            OutlinedButton.icon(
              onPressed: () => context.go('$basePath/imprimer'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimer'),
            ),
          ]),
```

**`lib/characters/character_edit_screen.dart`** : dans les deux branches (lecture seule et édition), juste après le bloc `if (frozen != null) ...[ … FreezeBanner(staffFreezeText(frozen)), ]`, ajouter :

```dart
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('c3-print'),
              onPressed: () => context.go('/conteur/fiches/${latest.id}/imprimer'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimer'),
            ),
          ),
```

Dans la branche d’édition, le bouton est désactivé (`onPressed: null`) tant que `changes` n’est pas vide : quitter l’éditeur perdrait les modifications (même règle que « Changer le titre »).

Run : `flutter test test/print test/characters/character_screen_test.dart test/characters/character_edit_test.dart`, puis `flutter analyze`, puis `flutter test`.

Expected : tous les tests passent ; analyseur propre. Si d’autres tests échouent faute de surcharge d’un provider lu par l’écran, ajouter la surcharge.

- [ ] **Step 3 : vérification à l’écran (par l’utilisateur)**

`flutter run -d chrome --dart-define=EMULATORS=true` : ouvrir une fiche de joueur, « Imprimer », vérifier l’aperçu (accents, ’, « », pastilles, cases), télécharger le PDF. Cette étape est faite par l’utilisateur ; un sous-agent la signale sans la faire.

- [ ] **Step 4 : commit**

```
git add lib/print/print_screen.dart lib/router.dart lib/games/freeze_banner.dart lib/characters/character_screen.dart lib/characters/character_edit_screen.dart test/print/print_screen_test.dart test/characters
git commit -m "feat: impression — écran « Imprimer la fiche », routes et boutons" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : revue, puis déploiement (avec accord)

- [ ] **Step 1 :** revue finale de la branche contre la spec (sous-agent le plus capable).
- [ ] **Step 2 :** suite complète : `flutter analyze`, `flutter test`.
- [ ] **Step 3 :** avec l’accord de l’utilisateur seulement :
  - fusion de `impression` dans `main`, puis `git push` ;
  - `flutter build web` puis `firebase deploy --only hosting` (aucune règle Firestore ne change ; le déploiement est lancé par l’utilisateur, le mode automatique le bloque).
