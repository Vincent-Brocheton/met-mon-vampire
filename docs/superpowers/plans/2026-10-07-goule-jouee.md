# Goule jouée (sous-projet 6c) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** un joueur incarne une goule. Le conte crée la fiche et choisit le domitor. Le joueur la remplit dans la création guidée adaptée, puis dépense son XP selon les règles de goule. La fiche montre l'état de goule.

**Architecture :**
- **Sur la fiche du personnage :** la clé tardive `ghoul` porte la copie du domitor (nom, clan, disciplines) et le sang (lien, vitae, dernière gorgée).
- **Rang de goule :** `Rulebook.ghoulRow()` / `rowFor(c)` remplacent le rang de génération pour une goule.
- **Création, XP, C3 et fiche :** ils testent `c.ghoul != null`.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-07-goule-jouee-design.md`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md <N> [test|impl]` ;
  - textes en français ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche :** `goule-jouee`, déjà créée.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Écarts assumés avec la spec** (à reporter dans le journal) :
  - **Disciplines de goule :** elles sont rangées dans `disciplines` avec `inClan: true`. La fiche les affiche sans la mention « hors clan ».
  - **Avertissement « domitor retiré ou mort » :** seulement dans C3, où l'équipe lit toutes les fiches. Le joueur ne lit pas la fiche du domitor.

## Review Focus

1. **Fiche de vampire existante :** elle n'a jamais de clé `ghoul`. Un brouillon du joueur, une soumission ou une édition C3 ne l'ajoute pas, même vide. Tests : tâches 1 et 4.
2. **Joueur qui tente de modifier `ghoul` dans son brouillon** (copie du domitor, vitae) : refusé par les règles. Test : tâche 4.
3. **Achat de discipline, de technique ou de pouvoir d'ancien pour une goule** : refusé à la création, dans l'écran XP et à la validation d'une demande écrite hors de l'application. Tests : tâches 2 et 3.
4. **Disciplines de goule au-delà du domitor, ou absentes chez lui** : erreur bloquante à la soumission. Test : tâche 2.
5. **Humanité d'une goule baissée dans C3** : enregistrement refusé avec un message. Test : tâche 5.

---

### Task 1 : modèle de goule et ligne « Goule » du référentiel

**Files :**
- Modify :
  - `lib/characters/character.dart` ;
  - `lib/characters/describe_changes.dart` ;
  - `lib/rulebook/rulebook.dart` ;
  - `lib/rulebook/schema.dart`.
- Test : `test/characters/ghoul_test.dart`.

**Interfaces :**
- Produces :
  - `DomitorDiscipline(name, level)` ;
  - `GhoulState` (`fromMap`, `toMap`, `GhoulState.of(domitor)`) ;
  - `ghoulLine(g)` ;
  - `Character.ghoul` ;
  - `Rulebook.ghoulRow()` et `Rulebook.rowFor(c)` ;
  - `ghoulRank = 'ghoul'` ;
  - les lignes de goule de `describeChanges`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md 1 test`, puis `flutter test test/characters/ghoul_test.dart`.

Expected : échec au chargement.

<!-- file: test/characters/ghoul_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import 'character_test.dart' show sample;

GhoulState ghoulState() => GhoulState(
      domitorId: 'x',
      domitorName: 'Isaure de Valcourt',
      domitorClan: 'Toreador',
      domitorDisciplines: [const DomitorDiscipline('Auspex', 3), const DomitorDiscipline('Présence', 2)],
      bond: 1,
      vitae: 4,
      lastDrink: DateTime(2026, 9, 26),
    );

/// Goule en brouillon, joueuse u2.
Character mila() => Character(id: 'g', name: 'Mila Ferreira', kind: CharacterKind.pj, playerUid: 'u2', playerName: 'Inès T.')
  ..ghoul = ghoulState();

void main() {
  test('clé tardive : absente sur un vampire, aller-retour sur une goule (Review Focus 1)', () {
    expect(sample().toMap().containsKey('ghoul'), isFalse);
    expect(sample().laterKeys().containsKey('ghoul'), isFalse);
    final m = mila();
    final back = Character.fromMap('g', m.toMap());
    expect(back.toMap()['ghoul'], m.toMap()['ghoul']);
    expect([for (final d in back.ghoul!.domitorDisciplines) (d.name, d.level)], [('Auspex', 3), ('Présence', 2)]);
    expect(back.clone().ghoul!.vitae, 4);
    expect(m.laterKeys()['ghoul'], m.toMap()['ghoul']);
    expect(ghoulLine(m.ghoul!), 'Goule de Isaure de Valcourt · clan du domitor : Toreador');
  });

  test('copie du domitor', () {
    final g = GhoulState.of(sample());
    expect((g.domitorId, g.domitorName, g.domitorClan), ('x', 'Isaure de Valcourt', 'Toreador'));
    expect([for (final d in g.domitorDisciplines) (d.name, d.level)], [('Auspex', 3)]);
  });

  test('ligne « Goule » : valeurs par défaut, puis celle du référentiel', () {
    const rb = Rulebook();
    final row = rb.ghoulRow();
    expect((row.blood, row.bloodPerTurn, row.techniqueCost, row.eldersAllowed), (10, 1, 0, false));
    expect(row.traitFactor, rb.gen(GenRank.neonate).traitFactor);
    expect(rb.rowFor(mila()).blood, 10);
    expect(rb.rowFor(sample()).blood, rb.gen(GenRank.ancilla).blood);
    final own = Rulebook({
      'generations': [
        RuleEntry(name: 'Goule', data: {'rank': ghoulRank, 'blood': 8, 'bloodPerTurn': 1, 'traitFactor': 2}),
      ],
    });
    expect((own.ghoulRow().blood, own.ghoulRow().traitFactor), (8, 2));
    expect(own.gen(GenRank.ancilla).blood, rb.gen(GenRank.ancilla).blood, reason: 'les autres rangs gardent leurs valeurs de base');
  });

  test('résumé des changements d’une goule', () {
    final a = mila();
    final b = a.clone();
    b.ghoul!
      ..vitae = 5
      ..bond = 2
      ..lastDrink = DateTime(2026, 10, 2)
      ..domitorDisciplines = [const DomitorDiscipline('Auspex', 4)];
    expect(describeChanges(a, b), [
      'Vitae 4 → 5',
      'Lien de sang 1 → 2',
      'Gorgée du ${formatDay(DateTime(2026, 10, 2))}',
      'Disciplines du domitor recopiées',
    ]);
  });
}
```

- [ ] **Step 2 : implémentation**

**`lib/characters/character.dart` :**

1. Avant `/// Clés ajoutées au sous-projet 5`, ajouter :

```dart
/// Discipline du domitor, recopiée sur la fiche de sa goule.
class DomitorDiscipline {
  const DomitorDiscipline(this.name, this.level);

  factory DomitorDiscipline.fromMap(Map<String, dynamic> m) => DomitorDiscipline(m['name'] as String? ?? '', _int(m['level']));

  final String name;
  final int level;

  Map<String, dynamic> toMap() => {'name': name, 'level': level};
}

/// Goule jouée (sous-projet 6c) : copie du domitor, faite par le conte (le joueur ne lit pas sa fiche), et sang.
class GhoulState {
  GhoulState({
    required this.domitorId,
    required this.domitorName,
    this.domitorClan,
    List<DomitorDiscipline>? domitorDisciplines,
    this.bond = 0,
    this.vitae = 0,
    this.lastDrink,
  }) : domitorDisciplines = domitorDisciplines ?? [];

  factory GhoulState.fromMap(Map<String, dynamic> m) => GhoulState(
        domitorId: m['domitorId'] as String? ?? '',
        domitorName: m['domitorName'] as String? ?? '',
        domitorClan: m['domitorClan'] as String?,
        domitorDisciplines: _maps(m['domitorDisciplines']).map(DomitorDiscipline.fromMap).toList(),
        bond: _int(m['bond']),
        vitae: _int(m['vitae']),
        lastDrink: _date(m['lastDrink']),
      );

  /// Copie du clan et des disciplines du domitor.
  factory GhoulState.of(Character domitor) => GhoulState(
        domitorId: domitor.id,
        domitorName: domitor.name,
        domitorClan: domitor.clan,
        domitorDisciplines: [for (final d in domitor.disciplines) if (d.level > 0) DomitorDiscipline(d.name, d.level)],
      );

  String domitorId;
  String domitorName;
  String? domitorClan;
  List<DomitorDiscipline> domitorDisciplines;
  int bond;
  int vitae;
  DateTime? lastDrink;

  Map<String, dynamic> toMap() => {
        'domitorId': domitorId,
        'domitorName': domitorName,
        'domitorClan': domitorClan,
        'domitorDisciplines': [for (final d in domitorDisciplines) d.toMap()],
        'bond': bond,
        'vitae': vitae,
        'lastDrink': _ts(lastDrink),
      };
}

/// « Goule de Isaure de Valcourt · clan du domitor : Toreador ».
String ghoulLine(GhoulState g) => 'Goule de ${g.domitorName}${g.domitorClan == null ? '' : ' · clan du domitor : ${g.domitorClan}'}';
```

2. `_laterKeys` reçoit `'ghoul'` en dernier élément.

3. Dans `Character.fromMap`, après la ligne `..servants = _maps(m['servants']).map(Servant.fromMap).toList()`, ajouter :

```dart
      ..ghoul = m['ghoul'] is Map ? GhoulState.fromMap(_map(m['ghoul'])) : null
```

4. Après `List<Servant> servants = [];`, ajouter :

```dart
  /// Fiche de goule jouée (sous-projet 6c) ; null pour un vampire.
  GhoulState? ghoul;
```

5. Dans `laterKeys()`, après la ligne `'servants'`, ajouter `if (ghoul != null) 'ghoul': ghoul!.toMap(),`.

6. Dans `toMap()`, après la ligne conditionnelle `'servants'`, ajouter `if (ghoul != null) 'ghoul': ghoul!.toMap(),`.

**`lib/characters/describe_changes.dart` :**
- ajouter `import '../core/widgets.dart' show formatDay;` ;
- après `_servants(out, a.servants, b.servants);`, ajouter `_ghoul(out, a.ghoul, b.ghoul);` ;
- avant `/// Ligne d'historique de la conversion`, ajouter :

```dart
void _ghoul(List<String> out, GhoulState? a, GhoulState? b) {
  if (a == null || b == null) return;
  if (a.vitae != b.vitae) out.add('Vitae ${a.vitae} → ${b.vitae}');
  if (a.bond != b.bond) out.add('Lien de sang ${a.bond} → ${b.bond}');
  if (a.lastDrink != b.lastDrink && b.lastDrink != null) out.add('Gorgée du ${formatDay(b.lastDrink)}');
  String copy(GhoulState g) => [g.domitorName, g.domitorClan, for (final d in g.domitorDisciplines) '${d.name}:${d.level}'].join('|');
  if (copy(a) != copy(b)) out.add('Disciplines du domitor recopiées');
}
```

**`lib/rulebook/rulebook.dart` :**
- avant `class Rulebook {`, ajouter :

```dart
/// Rang « Goule » du tableau des générations (sous-projet 6c).
const ghoulRank = 'ghoul';
```

- après la méthode `gen(GenRank rank)`, ajouter :

```dart
  /// Valeurs d'une goule : la ligne « Goule » du tableau des générations, ou celles d'un Neonate
  /// avec Sang 10, 1 par tour, sans technique ni pouvoir d'ancien.
  GenRow ghoulRow() {
    final base = GenRow.fromData(const {'blood': 10, 'bloodPerTurn': 1, 'techniqueCost': 0}, _baseRows[GenRank.neonate]!);
    final e = all('generations').where((e) => e.state.offered && e.data['rank'] == ghoulRank).firstOrNull;
    return e == null ? base : GenRow.fromData(e.data, base);
  }

  /// Valeurs de la fiche : goule, ou rang de génération (Neonate par défaut).
  GenRow rowFor(Character c) => c.ghoul != null ? ghoulRow() : gen(c.genRank ?? GenRank.neonate);
```

**`lib/rulebook/schema.dart` :** dans la catégorie `generations`, les options du champ `rank` deviennent `[('neonate', 'Neonate'), ('ancilla', 'Ancilla'), ('pretender', 'Pretender Elder'), ('ghoul', 'Goule')]`.

Run : `flutter test test/characters test/rulebook`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: goule jouée — modèle, copie du domitor, ligne « Goule » du référentiel" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : création guidée d'une goule

**Files :**
- Modify : `lib/rules/creation_rules.dart`, `lib/creation/creation_steps.dart`, `lib/creation/creation_screen.dart`.
- Test : `test/creation/ghoul_creation_test.dart`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `creationRow(c, {rb})` ;
  - `ghoulDisciplinePoints = 5` ;
  - `ghoulPurchaseError(c, kind, name)` ;
  - `setGhoulDiscipline(c, name, level)` ;
  - `stepIntroOf(step, v, {ghoul})`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md 2 test`, puis `flutter test test/creation/ghoul_creation_test.dart`.

Expected : échec au chargement.

<!-- file: test/creation/ghoul_creation_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/creation/creation_steps.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rules/creation_rules.dart';

import '../characters/ghoul_test.dart' show mila;

List<(CheckLevel, String)> at(Character c, int step) => [for (final k in creationChecks(c)) if (k.step == step) (k.level, k.text)];

void main() {
  test('clan, génération et disciplines de goule (Review Focus 4)', () {
    final c = mila();
    expect(at(c, 3), [(CheckLevel.ok, 'Goule de Isaure de Valcourt · clan du domitor : Toreador')]);
    expect(at(c, 6).where((k) => k.$2.contains('Génération') || k.$2.contains('mortel')), isEmpty);
    setGhoulDiscipline(c, 'Auspex', 3);
    expect(at(c, 7), [(CheckLevel.todo, 'Disciplines de goule : 3 points sur 5')]);
    setGhoulDiscipline(c, 'Présence', 2);
    expect(at(c, 7), [(CheckLevel.ok, 'Disciplines de goule : 5 points sur 5')]);
    setGhoulDiscipline(c, 'Présence', 3);
    setGhoulDiscipline(c, 'Domination', 1);
    expect(at(c, 7), [
      (CheckLevel.error, 'Disciplines de goule : 7 points sur 5'),
      (CheckLevel.error, 'Présence : niveau 3 au-delà de celui du domitor (2)'),
      (CheckLevel.error, 'Domination : le domitor ne la possède pas'),
    ]);
    setGhoulDiscipline(c, 'Domination', 0);
    expect(c.disciplines.map((d) => d.name), ['Auspex', 'Présence']);
    c.backgrounds.add(Trait(generationName, 1));
    expect(at(c, 6), contains((CheckLevel.error, 'Une goule n’a pas de Génération')));
  });

  test('achats interdits, coûts Neonate, sang de goule (Review Focus 3)', () {
    final c = mila();
    expect(addPurchase(c, Buy.discipline, 'Auspex'), 'Les disciplines d’une goule ne s’achètent pas avec l’XP.');
    expect(addPurchase(c, Buy.technique, 'Regard ardent'), 'Une goule n’apprend ni technique ni pouvoir d’ancien.');
    expect(addPurchase(c, Buy.background, generationName), 'Une goule n’a pas de Génération.');
    expect(addPurchase(c, Buy.skill, 'Médecine'), isNull);
    expect(c.purchases.single.cost, 1, reason: 'Neonate : nouveau niveau × 1');
    applyDerived(c);
    expect((c.blood, c.bloodPerTurn, c.genRank, c.genNumber), (10, 1, null, null));
    expect(at(c, 9).where((k) => k.$2.contains('incohérentes')), isEmpty);
    expect(stepIntroOf(7, const CreationValues(), ghoul: true), contains('5 points'));
  });

  testWidgets('étapes : clan en lecture, disciplines du domitor, achats sans discipline', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mila();
    var step = 3;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return SingleChildScrollView(child: creationStep(step, c, () => setState(() {})));
        }),
      ),
    ));
    expect(find.text('Goule de Isaure de Valcourt · clan du domitor : Toreador'), findsOneWidget);
    rebuild(() => step = 7);
    await tester.pump();
    expect(find.text('0 / 5 points'), findsOneWidget);
    await tester.tap(find.byTooltip('Auspex : 3'));
    await tester.pump();
    expect(find.text('3 / 5 points'), findsOneWidget);
    expect(find.byTooltip('Présence : 3'), findsNothing, reason: 'plafond du domitor : 2');
    rebuild(() => step = 9);
    await tester.pump();
    await tester.tap(find.byKey(const Key('buy-kind')));
    await tester.pumpAndSettle();
    expect(find.text('Discipline'), findsNothing);
    expect(find.text('Technique'), findsOneWidget, reason: 'seulement la ligne du tableau des coûts, pas le menu');
    expect(find.text('COÛTS POUR UNE GOULE'), findsOneWidget, reason: 'titre de section en majuscules');
  });
}
```

- [ ] **Step 2 : implémentation**

**`lib/rules/creation_rules.dart` :**

1. Après la fonction `isInClan`, ajouter :

```dart
/// Valeurs de création : la ligne « Goule » pour une goule, sinon le rang de la Génération choisie.
GenRow creationRow(Character c, {Rulebook rb = const Rulebook()}) => c.ghoul != null ? rb.ghoulRow() : rb.gen(rankFor(c) ?? GenRank.neonate);

/// Points de disciplines d'une goule, pris chez son domitor.
const ghoulDisciplinePoints = 5;

/// Achat impossible pour une goule, à la création comme ensuite ; null sinon.
String? ghoulPurchaseError(Character c, String kind, String name) {
  if (c.ghoul == null) return null;
  return switch (kind) {
    Buy.discipline => 'Les disciplines d’une goule ne s’achètent pas avec l’XP.',
    Buy.technique || Buy.elderPower => 'Une goule n’apprend ni technique ni pouvoir d’ancien.',
    Buy.background when name == generationName => 'Une goule n’a pas de Génération.',
    _ => null,
  };
}

/// Niveau d'une discipline de goule (0 la retire).
void setGhoulDiscipline(Character c, String name, int level) {
  c.disciplines.removeWhere((d) => d.name == name);
  if (level > 0) c.disciplines.add(Discipline(name, level, inClan: true));
}
```

2. Remplacer les trois occurrences de `rb.gen(rankFor(c) ?? GenRank.neonate)` (dans `purchaseCost`, `_bonusLeftFor` et `creationChecks`) par `creationRow(c, rb: rb)`.

3. Dans `addPurchase`, première ligne du corps : ajouter :

```dart
  final ghoulError = ghoulPurchaseError(c, kind, name);
  if (ghoulError != null) return ghoulError;
```

4. Dans `applyDerived`, les lignes :

```dart
  final rank = rankFor(c);
  c.genRank = rank;
  final row = rank == null ? null : rb.gen(rank);
  if (row == null || !row.numbers.contains(c.genNumber)) c.genNumber = null;
```

deviennent :

```dart
  final ghoul = c.ghoul != null;
  final rank = ghoul ? null : rankFor(c);
  c.genRank = rank;
  final row = ghoul ? rb.ghoulRow() : (rank == null ? null : rb.gen(rank));
  if (ghoul || row == null || !row.numbers.contains(c.genNumber)) c.genNumber = null;
```

5. Dans `creationChecks` :
   - `if (c.clan == null) {` (étape 3) devient :

```dart
  if (c.ghoul != null) {
    add(3, CheckLevel.ok, ghoulLine(c.ghoul!));
  } else if (c.clan == null) {
```

   - `if (generationLevel(c) == 0) {` (étape 6) devient :

```dart
  if (c.ghoul != null) {
    if (generationLevel(c) > 0) add(6, CheckLevel.error, 'Une goule n’a pas de Génération');
  } else if (generationLevel(c) == 0) {
```

   - `if (inClan.length != 3) {` (étape 7) devient :

```dart
  if (c.ghoul != null) {
    _ghoulDisciplines(out, c);
  } else if (inClan.length != 3) {
```

   - `for (final d in c.disciplines.where((d) => !d.inClan)) {` devient `for (final d in c.disciplines.where((d) => !d.inClan && c.ghoul == null)) {` ;
   - avant `bool canSubmit(`, ajouter :

```dart
void _ghoulDisciplines(List<Check> out, Character c) {
  final g = c.ghoul!;
  final total = _sum(c.disciplines.map((d) => d.level));
  final level = total < ghoulDisciplinePoints ? CheckLevel.todo : (total > ghoulDisciplinePoints ? CheckLevel.error : CheckLevel.ok);
  out.add(Check(7, level, 'Disciplines de goule : $total points sur $ghoulDisciplinePoints'));
  for (final d in c.disciplines) {
    final own = g.domitorDisciplines.where((x) => x.name == d.name).firstOrNull;
    if (own == null) {
      out.add(Check(7, CheckLevel.error, '${d.name} : le domitor ne la possède pas'));
    } else if (d.level > own.level) {
      out.add(Check(7, CheckLevel.error, '${d.name} : niveau ${d.level} au-delà de celui du domitor (${own.level})'));
    }
  }
}
```

**`lib/creation/creation_steps.dart` :**

1. `String stepIntroOf(int step, CreationValues v) {` devient `String stepIntroOf(int step, CreationValues v, {bool ghoul = false}) {`. Au début du `switch`, ajouter :

```dart
    3 when ghoul => 'Une goule n’a pas de clan : elle sert son domitor, dont elle tire ses disciplines.',
    6 when ghoul => 'Répartissez vos points gratuits : ${v.backgroundSlots.join(' / ')}. Une goule n’a pas de Génération.',
    7 when ghoul => 'Répartissez $ghoulDisciplinePoints points entre les disciplines de votre domitor, sans dépasser son niveau. '
        'Elles ne s’achètent pas avec l’XP.',
```

2. Dans `creationStep`, `3 => _ClanStep(c, rb, changed),` devient `3 => c.ghoul != null ? _GhoulClanStep(c) : _ClanStep(c, rb, changed),` et `7 => _DisciplinesStep(c, rb, changed),` devient `7 => c.ghoul != null ? _GhoulDisciplinesStep(c, changed) : _DisciplinesStep(c, rb, changed),`.

3. Avant `class _ClanStep`, ajouter :

```dart
/// Étape 3 d'une goule : son domitor, en lecture.
class _GhoulClanStep extends StatelessWidget {
  const _GhoulClanStep(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _section(context, 'Domitor', [
      Text(ghoulLine(c.ghoul!), style: t.titleMedium),
      const SizedBox(height: 6),
      Text('Le domitor est choisi par le conte. Ses disciplines sont celles que vous pourrez apprendre.', style: t.bodySmall),
    ]);
  }
}

/// Étape 7 d'une goule : 5 points entre les disciplines du domitor, au plus son niveau.
class _GhoulDisciplinesStep extends StatelessWidget {
  const _GhoulDisciplinesStep(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = c.disciplines.fold<int>(0, (s, d) => s + d.level);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$total / $ghoulDisciplinePoints points', style: t.titleMedium?.copyWith(color: AppColors.gold)),
      const SizedBox(height: 12),
      for (final own in c.ghoul!.domitorDisciplines)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Text('${own.name} (domitor : ${own.level})', style: t.titleMedium)),
              DotPicker(
                label: own.name,
                value: c.disciplines.where((d) => d.name == own.name).firstOrNull?.level ?? 0,
                max: own.level,
                onChanged: (v) {
                  setGhoulDiscipline(c, own.name, v);
                  changed();
                },
              ),
            ]),
          ),
        ),
      if (c.ghoul!.domitorDisciplines.isEmpty) Text('Le domitor n’a aucune discipline recopiée : demandez au conte.', style: t.bodyMedium),
    ]);
  }
}
```

4. Dans `_BackgroundsStep.build` :
   - `names: rb.offeredNames('backgrounds'),` devient `names: [for (final n in rb.offeredNames('backgrounds')) if (c.ghoul == null || n != generationName) n],` ;
   - le bloc `_section(context, 'Génération', [ … ]),` est précédé de `if (c.ghoul != null) _section(context, 'Sang', [Text('Goule · Sang ${rb.ghoulRow().blood}, ${rb.ghoulRow().bloodPerTurn} par tour', style: t.bodyMedium)]) else` (le bloc existant devient la branche `else`).

5. Dans `_PurchasesStepState.build` :
   - `final rank = rankFor(c) ?? GenRank.neonate;` et `final row = rb.gen(rank);` deviennent :

```dart
    final rank = rankFor(c) ?? GenRank.neonate;
    final row = creationRow(c, rb: rb);
    final ghoul = c.ghoul != null;
```

   - les `items` du menu `buy-kind` deviennent `[for (final e in _kinds.entries) if (ghoulPurchaseError(c, e.key, '') == null) DropdownMenuItem(value: e.key, child: Text(e.value))],` ;
   - le titre `'Coûts ${rank.label}'` devient `ghoul ? 'Coûts pour une goule' : 'Coûts ${rank.label}'` ;
   - dans le tableau des coûts, les valeurs de `'Discipline en clan'`, `'Hors clan (…)'`, `'Technique'` et `'Pouvoir d’ancien'` deviennent `ghoul ? 'Jamais en XP' : <valeur actuelle>`, et celle de `'Génération'` devient `ghoul ? 'Interdite' : 'Niveau × 2'`.

**`lib/creation/creation_screen.dart` :** `stepIntroOf(_step, rb.creation)` devient `stepIntroOf(_step, rb.creation, ghoul: <la fiche affichée>.ghoul != null)`. Utiliser la variable de fiche déjà disponible à cet endroit, `c` ou `_c!`.

Run : `flutter analyze`, puis `flutter test test/creation test/characters`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: goule jouée — création guidée (domitor, disciplines, sang, achats interdits)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : XP d'une goule

**Files :**
- Modify : `lib/xp/xp_rules.dart`, `lib/xp/spend_screen.dart`, `test/xp/spend_screen_test.dart`.
- Test : `test/xp/ghoul_xp_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2.
- Produces : `ghoulForbiddenXp`, `ghoulXpError(c, kind)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md 3 test`, puis `flutter test test/xp/ghoul_xp_test.dart`.

Expected : échec au chargement.

<!-- file: test/xp/ghoul_xp_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/ghoul_test.dart' show mila;
import 'xp_rules_test.dart' show err, req;

void main() {
  test('goule : coûts Neonate ; disciplines, techniques et pouvoirs d’anciens refusés (Review Focus 3)', () {
    final c = mila()
      ..status = CharacterStatus.active
      ..xpEarned = 30;
    expect(err(c, XpKind.discipline, 'Auspex'), 'Les disciplines d’une goule ne s’achètent pas avec l’XP.');
    expect(err(c, XpKind.technique, 'Regard ardent'), 'Une goule n’apprend ni technique ni pouvoir d’ancien.');
    expect(err(c, XpKind.elderPower, 'Clairvoyance'), 'Une goule n’apprend ni technique ni pouvoir d’ancien.');
    expect(elementOptions(c, XpKind.discipline), isEmpty);
    expect(draftItem(c, const [], XpKind.skill, 'Médecine').cost, 1);
    expect(
      costTable(c),
      containsAll([('Discipline en clan', 'Jamais en XP'), ('Discipline hors clan', 'Jamais en XP'), ('Technique', 'Jamais en XP'), ('Pouvoir d’ancien', 'Jamais en XP')]),
    );
    final checks = requestChecks(c, req([const XpItem(XpKind.discipline, 'Auspex', 0, 1, 3)]), reservedOthers: 0);
    expect(checks.map((k) => k.text), contains('Les disciplines d’une goule ne s’achètent pas avec l’XP.'));
  });
}
```

Dans `test/xp/spend_screen_test.dart` :
- ajouter `import '../characters/ghoul_test.dart' show mila;` ;
- avant `testWidgets('retrait par le haut seulement'`, ajouter :

```dart
  testWidgets('goule : types interdits absents, coûts pour une goule (6c)', (tester) async {
    await pump(tester, sheet: mila()
      ..status = CharacterStatus.active
      ..playerUid = 'u1');
    await tester.tap(find.byKey(const Key('xp-kind')));
    await tester.pumpAndSettle();
    expect(find.text('Discipline'), findsNothing);
    expect(find.text('Technique'), findsNothing);
    await tester.tap(find.text('Compétence').last);
    await tester.pumpAndSettle();
    expect(find.text('COÛTS POUR UNE GOULE'), findsOneWidget);
  });

```

- [ ] **Step 2 : implémentation**

**`lib/xp/xp_rules.dart` :**

1. `GenRow _row(Character c, Rulebook rb) => rb.gen(c.genRank ?? GenRank.neonate);` devient `GenRow _row(Character c, Rulebook rb) => rb.rowFor(c);`.

2. Après la définition de `_row`, ajouter :

```dart
/// Achats jamais faits en XP par une goule.
const ghoulForbiddenXp = {XpKind.discipline, XpKind.technique, XpKind.elderPower};

/// Message si une goule ne peut pas acheter ce type ; null sinon.
String? ghoulXpError(Character c, XpKind k) {
  if (c.ghoul == null || !ghoulForbiddenXp.contains(k)) return null;
  return k == XpKind.discipline ? 'Les disciplines d’une goule ne s’achètent pas avec l’XP.' : 'Une goule n’apprend ni technique ni pouvoir d’ancien.';
}
```

3. `costTable` : après `final row = _row(c, rb);`, ajouter `final never = c.ghoul != null;`. Les valeurs de `'Discipline en clan'`, `'Discipline hors clan'`, `'Technique'` et `'Pouvoir d’ancien'` deviennent `never ? 'Jamais en XP' : <valeur actuelle>`.

4. `elementOptions` : première ligne du corps, ajouter `if (ghoulXpError(c, k) != null) return const {};`.

5. `itemError` : première ligne du corps, ajouter :

```dart
  final ghoulError = ghoulXpError(c, item.kind);
  if (ghoulError != null) return ghoulError;
```

6. `requestChecks` : au début du corps de `for (final i in r.items) {`, ajouter :

```dart
    final ghoulError = ghoulXpError(c, i.kind);
    if (ghoulError != null) out.add(Check(0, CheckLevel.error, ghoulError));
```

**`lib/xp/spend_screen.dart` :**
- les `items` du menu `xp-kind` deviennent `[for (final k in XpKind.values) if (ghoulXpError(c, k) == null) DropdownMenuItem(value: k, child: Text(k.label))]` ;
- `SectionTitle('Coûts pour un $rank')` devient `SectionTitle(c.ghoul != null ? 'Coûts pour une goule' : 'Coûts pour un $rank')` ;
- dans le texte « Le coût est calculé selon la génération du personnage ($rank). … », remplacer `la génération du personnage ($rank)` par `${c.ghoul != null ? 'les règles de goule' : 'la génération du personnage ($rank)'}`.

Run : `flutter analyze`, puis `flutter test test/xp`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: goule jouée — XP (coûts de goule, achats interdits refusés et bloqués à la validation)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : règles Firestore et création de la fiche par le conte

**Files :**
- Modify :
  - `firestore.rules` ;
  - `lib/characters/character_repository.dart` ;
  - `lib/characters/characters_list_screen.dart` ;
  - `test/fakes.dart` ;
  - `test/characters/characters_list_test.dart`.
- Create : `rules_test/ghoul.test.js`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - le paramètre `ghoul` de `CharacterRepository.create` ;
  - `FakeCharacterRepository.lastGhoul` ;
  - les clés `new-player` et `new-domitor`.

- [ ] **Step 1 : tests des règles (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md 4 test`, puis les tests des règles.

Expected : le test du brouillon de goule échoue (le joueur peut encore modifier `ghoul`) ; les autres passent.

<!-- file: rules_test/ghoul.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const creation = { purchases: [], step: 1, submittedAt: null, decidedAt: null, decidedByUid: null, comment: null };
const ghoul = { domitorId: 'c1', domitorName: 'Isaure', domitorClan: 'Toreador', domitorDisciplines: [{ name: 'Auspex', level: 3 }], bond: 0, vitae: 0, lastDrink: null };
const char = (over) => ({
  name: 'Mila', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'draft', clan: null,
  xpBonus: 0, xpInitial: 0, xpEarned: 0, xpSpent: 0, creation, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'characters/g'), char({ ghoul }));
    await setDoc(doc(db, 'characters/v'), char({ name: 'Nikolaï' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const save = (uid, id, changes) => updateDoc(doc(as(uid), `characters/${id}`), { ...changes, version: 2 });

test('brouillon de goule : le joueur remplit sa fiche, sans toucher à la copie du domitor (Review Focus 1 et 2)', async () => {
  await assertFails(save('zoe', 'g', { 'ghoul.domitorDisciplines': [{ name: 'Auspex', level: 5 }] }));
  await assertFails(save('zoe', 'g', { 'ghoul.vitae': 5 }));
  await assertFails(save('zoe', 'v', { ghoul }));
  await assertSucceeds(save('zoe', 'g', { sect: 'Camarilla', ghoul }));
});

test('le conte crée une fiche de goule', async () => {
  const db = as('lea');
  const b = writeBatch(db);
  b.set(doc(db, 'characters/new'), char({ ghoul }));
  b.set(doc(db, 'characters/new/history/h1'), { at: serverTimestamp(), byUid: 'lea', kind: 'creation', reason: '', summary: [] });
  await assertSucceeds(b.commit());
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules`, fonction `playerDraftSave`, la liste `.hasAny(['playerUid', 'playerName', 'kind', 'xpBonus', 'status', 'createdAt', 'lastHistoryId', 'gainedThrough'])` devient `.hasAny(['playerUid', 'playerName', 'kind', 'xpBonus', 'status', 'createdAt', 'lastHistoryId', 'gainedThrough', 'ghoul'])`.

Run : les tests des règles.

Expected : `fail 0`.

- [ ] **Step 3 : test de la fenêtre « Nouvelle fiche » (échec attendu)**

Dans `test/characters/characters_list_test.dart`, à la fin de `main`, ajouter :

```dart
  testWidgets('C2 : nouvelle goule, avec son joueur et son domitor (6c)', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
    const ines = AppUser(uid: 'u2', displayName: 'Inès T.', email: 'i@ex.fr', role: Role.joueur);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea, ines])),
        characterRepositoryProvider.overrideWith((ref) => repo),
        allCharactersProvider.overrideWith((ref) => Stream.value([
              Character(id: '1', name: 'Isaure', kind: CharacterKind.pj, playerName: 'Camille R.', status: CharacterStatus.active)
                ..clan = 'Toreador'
                ..disciplines = [Discipline('Auspex', 3, inClan: true)],
            ])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: CharactersListScreen())),
          GoRoute(path: '/conteur/fiches/:id', builder: (_, s) => Text('édition ${s.pathParameters['id']}')),
        ]),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Nouvelle fiche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goule').last);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Mila Ferreira');
    await tester.tap(find.byKey(const Key('new-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inès T.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-domitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isaure').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['create:pj:Mila Ferreira']);
    expect((repo.lastGhoul!.domitorName, repo.lastGhoul!.domitorClan), ('Isaure', 'Toreador'));
  });
```

Run : `flutter test test/characters/characters_list_test.dart`.

Expected : échec (pas de segment « Goule »).

- [ ] **Step 4 : implémentation**

**`lib/characters/character_repository.dart`, `create` :**
- ajouter le paramètre nommé `GhoulState? ghoul,` après `String? playerName,` ;
- la cascade `..version = 1\n      ..lastHistoryId = h.id;` devient `..version = 1\n      ..lastHistoryId = h.id\n      ..ghoul = kind == CharacterKind.pj ? ghoul : null;` ;
- le résumé `['Fiche créée']` devient `[c.ghoul != null ? 'Fiche de goule créée' : 'Fiche créée']`.

**`test/fakes.dart`, `FakeCharacterRepository` :**
- ajouter le champ `GhoulState? lastGhoul;` ;
- la signature de `create` reçoit `GhoulState? ghoul,` ;
- le corps enregistre `lastGhoul = ghoul;`.

**`lib/characters/characters_list_screen.dart`, `_NewCharacterDialogState` :**
1. Ajouter les champs `bool _ghoul = false;` et `Character? _domitor;`.
2. Dans `_create`, l'appel à `create` reçoit `ghoul: _ghoul && _domitor != null ? GhoulState.of(_domitor!) : null,`.
3. Le `SegmentedButton<CharacterKind>` est remplacé par :

```dart
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pj', label: Text('PJ')),
                ButtonSegment(value: 'ghoul', label: Text('Goule')),
                ButtonSegment(value: 'pnj', label: Text('PNJ')),
              ],
              selected: {_ghoul ? 'ghoul' : _kind.name},
              onSelectionChanged: (s) => setState(() {
                _ghoul = s.first == 'ghoul';
                _kind = s.first == 'pnj' ? CharacterKind.pnj : CharacterKind.pj;
              }),
            ),
```

4. Le texte d'aide sous le segment devient : `_ghoul ? 'Une goule jouée : choisissez son joueur et son domitor. Le joueur remplira sa fiche par la création guidée.' : (le texte actuel)`.
5. Le `DropdownButtonFormField<AppUser>` reçoit `key: const Key('new-player'),`. Juste après lui, toujours dans le `if (_kind == CharacterKind.pj) ...[`, ajouter :

```dart
              if (_ghoul) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<Character>(
                  key: const Key('new-domitor'),
                  initialValue: _domitor,
                  decoration: const InputDecoration(labelText: 'Domitor'),
                  items: [
                    for (final c in ref.watch(allCharactersProvider).value ?? const <Character>[])
                      if (c.ghoul == null && c.status == CharacterStatus.active) DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (c) => setState(() => _domitor = c),
                  validator: (c) => c == null ? 'Choisissez le domitor.' : null,
                ),
              ],
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 5 : commit**

```
git add firestore.rules rules_test/ghoul.test.js lib test
git commit -m "feat: goule jouée — règles (copie du domitor protégée), création par le conte" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : fiche de goule (J2, C3)

**Files :**
- Create : `lib/characters/ghoul_panel.dart`.
- Modify :
  - `lib/characters/sheet_widgets.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `test/characters/character_edit_test.dart`.
- Test : `test/characters/ghoul_panel_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 4, `dueDate` et `dueState` (`lib/servants/servant_rules.dart`), `allCharactersProvider`.
- Produces : `GhoulPanel(g, {now})`, la section C3 « État de goule » (clés `ghoul-vitae`, `ghoul-bond`, `ghoul-drink`, `ghoul-refresh`), et le blocage de l'Humanité.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md 5 test`, puis `flutter test test/characters/ghoul_panel_test.dart`.

Expected : échec au chargement.

<!-- file: test/characters/ghoul_panel_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/ghoul_panel.dart';
import 'package:portail_met/characters/sheet_widgets.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;

import 'ghoul_test.dart' show ghoulState, mila;

void main() {
  testWidgets('état de goule : domitor, sang, échéance proche', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: GhoulPanel(ghoulState(), now: DateTime(2026, 10, 20)))),
    ));
    expect(find.text('Goule de Isaure de Valcourt · clan du domitor : Toreador'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('Buvez avant le ${formatDay(DateTime(2026, 10, 26))}, sinon son âge le rattrape : 10 ans par jour.'), findsOneWidget);
    expect(find.text('ne peut pas baisser'), findsOneWidget);
    expect(identityLine(mila()), 'Goule de Isaure de Valcourt');
  });

  testWidgets('fiche en lecture d’une goule : panneau affiché', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: CharacterSheetView(mila()))),
    ));
    expect(find.text('ÉTAT DE GOULE'), findsOneWidget);
  });
}
```

Dans `test/characters/character_edit_test.dart` :
- ajouter l'import `import 'ghoul_test.dart' show ghoulState;` ;
- dans les `overrides` de `pump`, ajouter `allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),` ;
- avant `testWidgets('Annuler restaure exactement la fiche lue (Review Focus 5)'`, ajouter :

```dart
  /// Goule active dont le domitor est 'x' : ici la fiche elle-même, ce qui suffit à vérifier la recopie
  /// (Auspex 3 remplace Présence 2).
  Character ghoulSheet() => sample()
    ..ghoul = (ghoulState()..domitorDisciplines = [const DomitorDiscipline('Présence', 2)])
    ..clan = null
    ..humanity = 5;

  testWidgets('goule : Humanité qui ne baisse pas (Review Focus 5)', (tester) async {
    final repo = await pump(tester, ghoulSheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retirer un point : Humanité'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('L’Humanité d’une goule ne peut pas baisser.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('goule : gorgée et copie du domitor dans C3', (tester) async {
    final repo = await pump(tester, ghoulSheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ghoul-drink')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ghoul-refresh')));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Vitae 4 → 5'), findsOneWidget);
    expect(find.text('Disciplines du domitor recopiées'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reason')), 'Gorgée');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveEdit:Gorgée']);
  });

```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-07-goule-jouee.md 5 impl`.

<!-- file: lib/characters/ghoul_panel.dart -->
```dart
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../servants/servant_rules.dart' show DueState, dueDate, dueState;
import 'character.dart';
import 'describe_changes.dart' show dots;
import 'sheet_widgets.dart' show InfoRow;

/// « État de goule » (J-Goule) : domitor, lien, vitae, échéance, rappels des règles.
class GhoulPanel extends StatelessWidget {
  const GhoulPanel(this.g, {super.key, this.now});
  final GhoulState g;

  /// Date du jour (tests) ; maintenant par défaut.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = g.lastDrink;
    final state = dueState(last, now ?? DateTime.now());
    final alert = switch (state) {
      DueState.late => 'Échéance dépassée le ${formatDay(dueDate(last!))} : son âge le rattrape, 10 ans par jour.',
      DueState.soon => 'Buvez avant le ${formatDay(dueDate(last!))}, sinon son âge le rattrape : 10 ans par jour.',
      _ => null,
    };
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('État de goule'),
        const SizedBox(height: 10),
        Text(ghoulLine(g), style: t.titleSmall),
        const SizedBox(height: 6),
        InfoRow('Lien envers ${g.domitorName}', g.bond == 0 ? 'aucun' : dots(g.bond)),
        InfoRow('Vitae', '${g.vitae} / 5'),
        InfoRow('Dernière gorgée', last == null ? '—' : formatDay(last)),
        if (alert != null) Text(alert, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        const InfoRow('Génération', 'aucune'),
        const InfoRow('Traits de Bête', 'jamais'),
        const InfoRow('Humanité', 'ne peut pas baisser'),
      ]),
    );
  }
}
```

**`lib/characters/sheet_widgets.dart` :**
- ajouter l'import `ghoul_panel.dart` ;
- `identityLine` devient :

```dart
String identityLine(Character c) =>
    [if (c.ghoul != null) 'Goule de ${c.ghoul!.domitorName}', c.clan, c.sect, c.genRank?.label].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
```

- dans `CharacterSheetView.build`, avant `Widget column(`, ajouter `final ghoul = c.ghoul == null ? null : GhoulPanel(c.ghoul!);`. Puis ajouter `?ghoul` en tête des deux listes de colonnes : `column([?ghoul, identity, derived, xp, …])` pour l'écran étroit, et `column([?ghoul, identity, derived, xp])` pour l'écran large.

Si `const InfoRow(...)` est refusé (constructeur non `const`), retirer `const`.

**`lib/characters/character_edit_screen.dart` :**

1. Ajouter l'import `../core/widgets.dart` s'il manque (pour `formatDay`).

2. Dans `_save`, juste après `if (by == null || changes.isEmpty || _saving) return;`, ajouter :

```dart
    if (_draft!.ghoul != null && _draft!.humanity < _base!.humanity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L’Humanité d’une goule ne peut pas baisser.')));
      return;
    }
```

3. Dans `_Editor.build`, après la définition de `derived`, ajouter :

```dart
    final g = c.ghoul;
    final domitor = g == null ? null : ref.watch(allCharactersProvider).value?.where((x) => x.id == g.domitorId).firstOrNull;
    final ghoulSection = g == null
        ? null
        : section('État de goule', [
            Text(ghoulLine(g), style: Theme.of(context).textTheme.titleSmall),
            KeyedSubtree(
              key: ValueKey('vitae-${g.vitae}'),
              child: DropdownButtonFormField<int>(
                key: const Key('ghoul-vitae'),
                initialValue: g.vitae.clamp(0, 5),
                decoration: const InputDecoration(labelText: 'Vitae (sur 5)'),
                items: [for (var v = 0; v <= 5; v++) DropdownMenuItem(value: v, child: Text('$v'))],
                onChanged: (v) => set(() => g.vitae = v ?? g.vitae),
              ),
            ),
            DropdownButtonFormField<int>(
              key: const Key('ghoul-bond'),
              initialValue: g.bond.clamp(0, 3),
              decoration: const InputDecoration(labelText: 'Lien de sang'),
              items: [for (var v = 0; v <= 3; v++) DropdownMenuItem(value: v, child: Text(v == 0 ? 'Aucun' : dots(v)))],
              onChanged: (v) => set(() => g.bond = v ?? g.bond),
            ),
            Row(children: [
              Expanded(child: Text(g.lastDrink == null ? 'Aucune gorgée notée' : 'Dernière gorgée : ${formatDay(g.lastDrink)}')),
              OutlinedButton(
                key: const Key('ghoul-drink'),
                onPressed: () => set(() {
                  g.lastDrink = DateTime.now();
                  g.vitae = (g.vitae + 1).clamp(0, 5);
                }),
                child: const Text('+ Gorgée'),
              ),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('ghoul-refresh'),
                onPressed: domitor == null
                    ? null
                    : () => set(() {
                          final copy = GhoulState.of(domitor);
                          g
                            ..domitorName = copy.domitorName
                            ..domitorClan = copy.domitorClan
                            ..domitorDisciplines = copy.domitorDisciplines;
                        }),
                child: const Text('Recopier les disciplines du domitor'),
              ),
            ),
            if (domitor != null && (domitor.status == CharacterStatus.retired || domitor.status == CharacterStatus.dead))
              const Text('Le domitor est une fiche retirée ou morte', style: TextStyle(color: AppColors.goldLight)),
          ]);
```

4. Dans les deux appels de mise en page, ajouter `?ghoulSection` après `derived` : `column([identity, attributes, derived, ?ghoulSection, ...lists])` et `column([identity, derived, ?ghoulSection])`.

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: goule jouée — état de goule sur la fiche, C3 (gorgée, copie du domitor, Humanité)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : revue, puis déploiement (avec accord)

- [ ] **Vérifications :**
  - tests des règles : `fail 0` ;
  - `flutter analyze` propre ;
  - `flutter test` : tous les tests passent.
- [ ] **Revue finale de la branche** par un relecteur neuf (opus). Les points Critical et Important sont corrigés, chacun avec un test qui échoue d'abord.
- [ ] **Avec l'accord de l'utilisateur :**
  - `firebase deploy --only firestore:rules --project met-mon-vampire` ;
  - `flutter build web --release` ;
  - `firebase deploy --only hosting --project met-mon-vampire` ;
  - puis fusion de `goule-jouee` dans `main`.
