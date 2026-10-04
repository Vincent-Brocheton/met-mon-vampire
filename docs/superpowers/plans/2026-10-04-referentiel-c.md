# Référentiel — Plan C (rituels, techniques, pouvoirs d'anciens, points bonus) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :**
- **Trois nouveaux achats** : rituels, techniques et pouvoirs d'anciens. Ils s'achètent à l'étape 9 de la création et dans « Dépenser de l'XP », avec leurs contrôles.
- **Points bonus d'attribut** (reportés du plan B) : un point placé dans une catégorie porte son plafond à 10 + ce point.
- **Fiche :** ces éléments s'affichent sur la fiche du joueur et du conte, et le conte les modifie directement depuis l'édition (C3).

**Architecture :**
- **Fiche :** quatre champs nouveaux sur `Character` : `rituals`, `techniques`, `elderPowers` et `attributeBonus`. `toMap` ne les écrit que s'ils sont non vides ou déjà présents dans le document lu (`storedKeys`). Les règles Firestore restent donc inchangées : une fiche existante ne voit jamais ces clés apparaître vides, et une soumission ne peut pas les modifier (`hasOnly`).
- **Contrôles purs** dans `lib/rules/powers_rules.dart`, partagés par la création et l'XP. Une demande d'XP contrôle chaque achat sur la fiche prévue après les achats précédents de la même demande.
- **`Rulebook`** reçoit les réglages des catégories (coût par niveau des rituels) et des recherches pour les rituels, les techniques et les pouvoirs d'anciens.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-03-referentiel-design.md`, sections « Rituels, techniques, pouvoirs d'anciens », « Fiche : nouveaux champs », « Sécurité » et « Points bonus d'attribut ».

## Global Constraints

- **Contraintes des plans précédents :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-c.md <N> [test|impl]` ;
  - textes en français ;
  - `build_runner` après tout fichier `part` ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche** `referentiel-c`, créée avec le plan.
- **Écarts assumés avec la spec** (à reporter dans le journal) :
  - **Tolérance des nouvelles clés par le client et non par les règles.** `toMap` n'écrit une clé tardive que si elle est non vide ou déjà présente (comme `gainedThrough` au sous-projet 4). Les fiches s'écrivent par `update`, donc une clé absente n'est jamais effacée. Effet identique à la spec (« inchangée, ou absente → vide »), sans modifier `firestore.rules`. Un test d'émulateur le vérifie.
  - **Prérequis des techniques en texte :** une alternative par ligne, du type « Présence 2 + Auspex 1 » (plan A). Une ligne illisible est ignorée. Si aucune n'est lisible, la technique est refusée avec « à vérifier par le conte ».
  - **Points bonus d'attribut à la création :** ils se déduisent des valeurs (`max(0, valeur − 10)` par catégorie).
  - **Points bonus d'attribut en XP :** un achat qui dépasse le plafond porte la note `point bonus`, posée automatiquement. La validation l'applique.
- **Pas de changement des règles Firestore.**

## Review Focus

1. **Fiche existante sans les nouvelles clés :** soumission, bonus et décision restent acceptés. Une soumission qui ajoute une clé tardive est refusée. Les tests sont à la tâche 1 (modèle et émulateur).
2. **Rituel acheté, puis voie qui baisse :** la limite est dépassée après coup, et l'erreur apparaît au contrôle suivant. Le test est à la tâche 2.
3. **Deux achats liés dans une même demande** (discipline à 5, puis pouvoir d'ancien ; deux rituels) : chacun est contrôlé sur la fiche prévue après les précédents. Le test est à la tâche 4.
4. **Points bonus d'attribut :** un achat au-delà du plafond sans point restant est refusé. L'annulation d'un achat bonus rend le point. Les tests sont à la tâche 4.
5. **Technique dont un prérequis est perdu avant la validation :** erreur dans les contrôles du conte. Le test est à la tâche 4.

---

### Task 1 : champs de fiche, résumé des changements, rebase, règles

**Files :**
- Modify : `lib/characters/character.dart`, `lib/characters/describe_changes.dart`, `rules_test/creation.test.js`.
- Test : `test/characters/later_keys_test.dart`.

**Interfaces :**
- Produces :
  - `Ritual(name, school, level)` et `ElderPower(name, discipline)` ;
  - `Character.rituals`, `techniques` (`List<String>`), `elderPowers`, `attributeBonus` (`Map<AttrCategory, int>`), `storedKeys`.

- [ ] **Step 1 : test (échec attendu)**

Run : `git switch referentiel-c`, puis `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-c.md 1 test`, puis `flutter test test/characters/later_keys_test.dart`.

Expected : échec à la compilation.

<!-- file: test/characters/later_keys_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';

import 'character_test.dart' show sample;

void main() {
  test('clés tardives : absentes tant que vides, gardées une fois écrites (Review Focus 1)', () {
    final c = sample();
    expect(c.toMap().keys, isNot(anyOf(contains('rituals'), contains('techniques'), contains('elderPowers'), contains('attributeBonus'))));
    c.rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1));
    c.techniques.add('Regard ardent');
    c.elderPowers.add(ElderPower('Clairvoyance', 'Auspex'));
    c.attributeBonus[AttrCategory.mental] = 1;
    final back = Character.fromMap('x', c.toMap());
    expect(back.toMap(), c.toMap());
    expect(back.rituals.single.level, 1);
    expect(back.attributeBonus[AttrCategory.mental], 1);
    back.rituals.clear();
    expect(back.toMap()['rituals'], isEmpty, reason: 'déjà écrite : la liste vide est écrite pour retirer le rituel');
    expect(back.clone().toMap()['rituals'], isEmpty);
  });

  test('résumé des changements et rebase des listes tardives', () {
    final a = sample();
    final b = a.clone()
      ..rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1))
      ..techniques.add('Regard ardent');
    b.attributeBonus[AttrCategory.mental] = 1;
    expect(describeChanges(a, b), containsAll(['+ Rituel Goût du sang', '+ Technique Regard ardent', 'Points bonus Mental 0 → 1']));
    final merged = rebase(a, b, a.clone()..version = 5);
    expect(merged.rituals.single.name, 'Goût du sang');
    expect(merged.techniques, ['Regard ardent']);
    expect(merged.version, 5);
  });
}
```

- [ ] **Step 2 : implémentation**

**`lib/characters/character.dart` :**

1. Après la classe `Purchase`, ajouter :
```dart
/// Rituel appris ; école et niveau recopiés du référentiel.
class Ritual {
  Ritual(this.name, this.school, this.level);

  factory Ritual.fromMap(Map<String, dynamic> m) => Ritual(m['name'] as String? ?? '', m['school'] as String? ?? '', _int(m['level']));

  final String name;
  final String school;
  final int level;

  Map<String, dynamic> toMap() => {'name': name, 'school': school, 'level': level};
}

/// Pouvoir d'ancien appris, et sa discipline.
class ElderPower {
  ElderPower(this.name, this.discipline);

  factory ElderPower.fromMap(Map<String, dynamic> m) => ElderPower(m['name'] as String? ?? '', m['discipline'] as String? ?? '');

  final String name;
  final String discipline;

  Map<String, dynamic> toMap() => {'name': name, 'discipline': discipline};
}

/// Clés ajoutées au sous-projet 5 : écrites seulement si non vides ou déjà présentes dans le document lu.
/// Les règles à liste de clés fermée (soumission, bonus, décision) acceptent ainsi les fiches existantes.
const _laterKeys = ['rituals', 'techniques', 'elderPowers', 'attributeBonus'];
```
2. Dans `Character.fromMap`, après `..flaws = …`, ajouter :
```dart
      ..rituals = _maps(m['rituals']).map(Ritual.fromMap).toList()
      ..techniques = [for (final t in (m['techniques'] as List?) ?? const []) '$t']
      ..elderPowers = _maps(m['elderPowers']).map(ElderPower.fromMap).toList()
      ..attributeBonus = {for (final a in AttrCategory.values) a: _int(_map(m['attributeBonus'])[a.name])}
      ..storedKeys = {for (final k in _laterKeys) if (m.containsKey(k)) k}
```
3. Après `List<Trait> flaws = [];`, ajouter :
```dart
  List<Ritual> rituals = [];
  List<String> techniques = [];
  List<ElderPower> elderPowers = [];

  /// Points bonus de Génération placés : le plafond de la catégorie passe à 10 + ce nombre.
  Map<AttrCategory, int> attributeBonus = {for (final a in AttrCategory.values) a: 0};

  /// Clés tardives présentes dans le document lu (voir _laterKeys).
  Set<String> storedKeys = {};
```
4. Dans `toMap`, après la ligne `'flaws': …,`, ajouter :
```dart
        if (rituals.isNotEmpty || storedKeys.contains('rituals')) 'rituals': [for (final r in rituals) r.toMap()],
        if (techniques.isNotEmpty || storedKeys.contains('techniques')) 'techniques': [...techniques],
        if (elderPowers.isNotEmpty || storedKeys.contains('elderPowers')) 'elderPowers': [for (final e in elderPowers) e.toMap()],
        if (attributeBonus.values.any((v) => v != 0) || storedKeys.contains('attributeBonus'))
          'attributeBonus': {for (final e in attributeBonus.entries) e.key.name: e.value},
```

**`lib/characters/describe_changes.dart` :**
1. Dans `describeChanges`, après `_points(out, 'Handicap', a.flaws, b.flaws);`, ajouter :
```dart
  _names(out, 'Rituel', [for (final r in a.rituals) r.name], [for (final r in b.rituals) r.name]);
  _names(out, 'Technique', a.techniques, b.techniques);
  _names(out, 'Pouvoir d’ancien', [for (final e in a.elderPowers) e.name], [for (final e in b.elderPowers) e.name]);
  for (final cat in AttrCategory.values) {
    number('Points bonus ${cat.label}', a.attributeBonus[cat] ?? 0, b.attributeBonus[cat] ?? 0);
  }
```
2. Après `_points`, ajouter :
```dart
void _names(List<String> out, String label, List<String> a, List<String> b) {
  for (final n in b) {
    if (!a.contains(n)) out.add('+ $label $n');
  }
  for (final n in a) {
    if (!b.contains(n)) out.add('− $label $n');
  }
}
```
3. Dans `rebase`, `{for (final k in n.keys) …}` devient `{for (final k in {...n.keys, ...d.keys}) …}`. Une clé tardive écrite par le brouillon local, mais absente de la version reçue, est ainsi gardée.

**`rules_test/creation.test.js`**, ajouter à la fin :
```js
test('listes tardives : libres au brouillon, refusées dans une soumission (plan C, Review Focus 1)', async () => {
  await assertFails(traced('zoe', 'draft', { status: 'review', techniques: ['Regard ardent'] }, 'submission'));
  await assertSucceeds(save('zoe', 'draft', {
    rituals: [{ name: 'Goût du sang', school: 'thaumaturgy', level: 1 }],
    attributeBonus: { physical: 0, social: 0, mental: 1 },
  }));
});
```
Ce test passe sans changer les règles : il garde ce comportement.

Run : `flutter test`, puis `flutter analyze`, puis, depuis `rules_test`, `JAVA_HOME=… npm test`.

Expected : tous les tests passent, y compris les tests existants de fiche (aller-retour `toMap`), et `fail 0` pour les règles.

- [ ] **Step 3 : commit**

```
git add lib test rules_test/creation.test.js
git commit -m "feat: fiche — rituels, techniques, pouvoirs d’anciens, points bonus d’attribut (clés tardives)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : référentiel et contrôles des nouveaux achats

**Files :**
- Modify : `lib/rulebook/rulebook.dart`, `lib/rulebook/rulebook_provider.dart`, `test/rulebook/rulebook_test.dart`.
- Create : `lib/rules/powers_rules.dart`.
- Test : `test/rules/powers_rules_test.dart`.

**Interfaces :**
- Consumes : la tâche 1, `dots`, `nameKey`.
- Produces :
  - `Rulebook([entries, creation, settings])` et ses nouvelles recherches :
    - rituels : `ritualCostPerLevel`, `ritualLevel`, `ritualSchool`, `schoolDisciplines` ;
    - techniques : `techniquePrerequisites`, `hasPrerequisites` ;
    - pouvoirs d'anciens : `elderDiscipline`, `elderCost(name, inClan:)` ;
  - dans `powers_rules.dart` :
    - `schoolLabels`, `schoolDots` ;
    - `ritualError`, `techniqueError`, `prerequisiteError`, `elderError`, `powerProblems` ;
    - `ritualCost`, `techniqueCost`, `elderCost`, `elderInClan`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-c.md 2 test`, puis `flutter test test/rules/powers_rules_test.dart`.

Expected : échec à la compilation.

<!-- file: test/rules/powers_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rules/powers_rules.dart';

import '../characters/character_test.dart' show sample;

Rulebook rulebook({Map<String, List<RuleEntry>> more = const {}}) => Rulebook({
      'disciplines': [...baseEntries('disciplines'), RuleEntry(name: 'Voie du Sang', data: {'parent': 'Thaumaturgie'})],
      'rituals': [
        RuleEntry(name: 'Goût du sang', data: {'school': 'thaumaturgy', 'level': 1, 'atCreation': true, 'withXp': true}),
        RuleEntry(name: 'Défense du refuge', data: {'school': 'thaumaturgy', 'level': 2, 'atCreation': true, 'withXp': true}),
        RuleEntry(name: 'Communion avec Kindred', data: {'school': 'thaumaturgy', 'level': 1, 'withXp': true}),
        RuleEntry(name: 'Appel des morts', data: {'school': 'necromancy', 'level': 1, 'withXp': true}),
      ],
      'techniques': [
        RuleEntry(name: 'Regard ardent', data: {'prerequisites': ['Présence 2 + Auspex 1', 'Domination 3']}),
        RuleEntry(name: 'Illisible', data: {'prerequisites': ['Présence deux']}),
      ],
      'elderPowers': [
        RuleEntry(name: 'Clairvoyance', data: {'discipline': 'Auspex', 'costInClan': 18, 'costOutOfClan': 24}),
        RuleEntry(name: 'Prophétie', data: {'discipline': 'Auspex'}),
        RuleEntry(name: 'Possession', data: {'discipline': 'Domination'}),
      ],
      ...more,
    }, const CreationValues(), {
      'rituals': {'costPerLevel': 3},
    });

/// Toreador Ancilla, Thaumaturgie ● et Voie du Sang ● (école : 2 points), Auspex ●●● en clan.
Character thaumaturge() => sample()
  ..disciplines = [
    Discipline('Thaumaturgie', 1, inClan: true),
    Discipline('Voie du Sang', 1),
    Discipline('Auspex', 3, inClan: true),
  ];

void main() {
  test('rituels : école, nombre, niveaux inférieurs, doublon, coût', () {
    final rb = rulebook();
    final c = thaumaturge();
    expect(schoolDots(c, 'thaumaturgy', rb), 2);
    expect(ritualError(c, 'Appel des morts', rb), 'Il faut une discipline ou une voie de l’école Nécromancie.');
    expect(ritualError(c, 'Défense du refuge', rb), 'Il manque un rituel de niveau 1');
    expect(ritualError(c, 'Goût du sang', rb), isNull);
    c.rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1));
    expect(ritualError(c, 'Goût du sang', rb), 'Rituel déjà connu.');
    expect(ritualError(c, 'Défense du refuge', rb), isNull);
    c.rituals.add(Ritual('Défense du refuge', 'thaumaturgy', 2));
    expect(ritualError(c, 'Communion avec Kindred', rb), 'Thaumaturgie ●● : 2 rituels au plus, vous en avez 2');
    expect(ritualCost('Défense du refuge', rb), 6);
  });

  test('voie qui baisse après coup : limite et niveaux signalés (Review Focus 2)', () {
    final rb = rulebook();
    final c = thaumaturge()
      ..rituals = [Ritual('Goût du sang', 'thaumaturgy', 1), Ritual('Défense du refuge', 'thaumaturgy', 2)];
    expect(powerProblems(c, rb), isEmpty);
    c.disciplines[1].level = 0;
    expect(powerProblems(c, rb), ['Thaumaturgie ● : 1 rituel au plus, vous en avez 2']);
    c.rituals.removeAt(0);
    expect(powerProblems(c, rb), contains('Il manque un rituel de niveau 1 (Thaumaturgie)'));
  });

  test('techniques : rang, alternatives de prérequis, ligne illisible', () {
    final rb = rulebook();
    final c = thaumaturge();
    expect(techniqueError(c, 'Regard ardent', rb), 'Prérequis manquant : Présence ●●');
    c.disciplines.add(Discipline('Présence', 2));
    expect(techniqueError(c, 'Regard ardent', rb), isNull);
    expect(techniqueError(c, 'Illisible', rb), 'Prérequis de Illisible illisibles : à vérifier par le conte.');
    c.techniques.add('Regard ardent');
    expect(techniqueError(c, 'Regard ardent', rb), 'Technique déjà connue.');
    final closed = rulebook(more: {
      'generations': [RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'techniqueCost': 0})],
    });
    expect(techniqueError(thaumaturge(), 'Regard ardent', closed), 'Techniques interdites au rang Ancilla.');
    expect(techniqueCost(thaumaturge(), rb), 12);
    c.disciplines.removeLast();
    expect(powerProblems(c, rb), ['Regard ardent : prérequis manquant : Présence ●●']);
  });

  test('pouvoirs d’anciens : rang, 5 points, nombre, coût en clan ou hors clan', () {
    final rb = rulebook();
    final c = thaumaturge();
    expect(elderError(c, 'Clairvoyance', rb), 'Pouvoirs d’anciens interdits au rang Ancilla.');
    c.genRank = GenRank.pretender;
    expect(elderError(c, 'Clairvoyance', rb), 'Pouvoir d’ancien : 5 points de Auspex requis');
    c.disciplines.last.level = 5;
    expect(elderError(c, 'Clairvoyance', rb), isNull);
    expect((elderCost(c, 'Clairvoyance', rb), elderInClan(c, 'Clairvoyance', rb)), (18, true));
    expect(elderCost(c, 'Possession', rb), 24);
    c.elderPowers.add(ElderPower('Clairvoyance', 'Auspex'));
    expect(elderError(c, 'Prophétie', rb), 'Pouvoirs d’anciens : 1 au plus au rang Pretender Elder.');
    c.disciplines.last.level = 4;
    expect(powerProblems(c, rb), ['Clairvoyance : 5 points de Auspex requis']);
  });
}
```

Dans `test/rulebook/rulebook_test.dart`, le test du provider doit aussi surcharger les réglages :
- ajouter `allRuleSettingsProvider.overrideWith((ref) => Stream.value({'rituals': {'costPerLevel': 3}})),` dans ses `overrides` ;
- après le dernier `expect` du test, ajouter `expect(rb.ritualCostPerLevel, 3);`.

- [ ] **Step 2 : implémentation**

**`lib/rulebook/rulebook.dart` :**
1. Le constructeur devient `const Rulebook([this._entries = const {}, this.creation = const CreationValues(), this.settings = const {}]);`, avec le champ :
```dart
  /// Réglages des catégories (`rules/{cat}`), par exemple le coût par niveau des rituels.
  final Map<String, Map<String, dynamic>> settings;
```
2. Avant `gen`, ajouter :
```dart
  /// Coût d'un rituel par niveau (réglage de la catégorie, 2 par défaut).
  int get ritualCostPerLevel => _count(settings['rituals']?['costPerLevel']) ?? 2;

  int ritualLevel(String name) => (_int('rituals', name, 'level') ?? 1).clamp(1, 5);

  String? ritualSchool(String name) => switch (find('rituals', name)?.data['school']) {
        final String s => s,
        _ => null,
      };

  /// Disciplines et voies d'une école : la leur, ou celle de leur discipline mère.
  List<String> schoolDisciplines(String school) {
    String? schoolOf(RuleEntry? e) => switch (e?.data['school']) {
          final String s => s,
          _ => null,
        };
    String? parent(RuleEntry e) => switch (e.data['parent']) {
          final String p => p,
          _ => null,
        };
    return [
      for (final e in all('disciplines'))
        if (schoolOf(e) == school || schoolOf(find('disciplines', parent(e))) == school) e.name,
    ];
  }

  bool hasPrerequisites(String technique) => ((find('techniques', technique)?.data['prerequisites'] as List?) ?? const []).isNotEmpty;

  /// Alternatives de prérequis : chaque ligne « Présence 2 + Auspex 1 » donne une liste (discipline, niveau).
  /// Une ligne illisible est ignorée.
  List<List<(String, int)>> techniquePrerequisites(String technique) {
    final out = <List<(String, int)>>[];
    for (final line in (find('techniques', technique)?.data['prerequisites'] as List?) ?? const []) {
      final parts = <(String, int)>[];
      var readable = true;
      for (final p in '$line'.split('+')) {
        final m = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(p.trim());
        if (m == null) {
          readable = false;
          break;
        }
        parts.add((m.group(1)!.trim(), int.parse(m.group(2)!)));
      }
      if (readable && parts.isNotEmpty) out.add(parts);
    }
    return out;
  }

  String? elderDiscipline(String name) => switch (find('elderPowers', name)?.data['discipline']) {
        final String d => d,
        _ => null,
      };

  int elderCost(String name, {required bool inClan}) =>
      _int('elderPowers', name, inClan ? 'costInClan' : 'costOutOfClan') ?? (inClan ? 18 : 24);
```

**`lib/rulebook/rulebook_provider.dart` :** le provider lit aussi les réglages.
```dart
  final settings = ref.watch(xpSettingsProvider);
  final categories = ref.watch(allRuleSettingsProvider);
  bool waiting(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;
  if (waiting(entries) || waiting(settings) || waiting(categories)) return null;
  return Rulebook(entries.value ?? const {}, settings.value?.creation ?? const CreationValues(), categories.value ?? const {});
```

Puis `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-c.md 2 impl`.

<!-- file: lib/rules/powers_rules.dart -->
```dart
import '../characters/character.dart';
import '../characters/describe_changes.dart' show dots;
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';

/// Écoles de magie du référentiel (champ `school`).
const schoolLabels = {'thaumaturgy': 'Thaumaturgie', 'necromancy': 'Nécromancie', 'abyss': 'Mysticisme de l’Abysse'};

String _school(String s) => schoolLabels[s] ?? s;

int _level(Character c, String discipline) =>
    c.disciplines.where((d) => nameKey(d.name) == nameKey(discipline)).fold(0, (s, d) => s + d.level);

bool _knows(Iterable<String> names, String name) => names.any((n) => nameKey(n) == nameKey(name));

String _limit(String school, int points, int count) =>
    '${_school(school)} ${dots(points)} : $points rituel${points > 1 ? 's' : ''} au plus, vous en avez $count';

/// Points des disciplines et voies de l'école sur la fiche.
int schoolDots(Character c, String school, Rulebook rb) => rb.schoolDisciplines(school).fold(0, (s, d) => s + _level(c, d));

/// Pourquoi la fiche ne peut pas apprendre le rituel ; null si elle le peut.
String? ritualError(Character c, String name, Rulebook rb) {
  if (_knows(c.rituals.map((r) => r.name), name)) return 'Rituel déjà connu.';
  final school = rb.ritualSchool(name);
  if (school == null) return 'Rituel sans école dans le référentiel : à demander au conte.';
  final points = schoolDots(c, school, rb);
  if (points == 0) return 'Il faut une discipline ou une voie de l’école ${_school(school)}.';
  final count = c.rituals.where((r) => r.school == school).length;
  if (count + 1 > points) return _limit(school, points, count);
  final level = rb.ritualLevel(name);
  for (var l = 1; l < level; l++) {
    if (!c.rituals.any((r) => r.school == school && r.level == l)) return 'Il manque un rituel de niveau $l';
  }
  return null;
}

/// Prérequis d'une technique : null si au moins une alternative est remplie.
String? prerequisiteError(Character c, String name, Rulebook rb) {
  final alternatives = rb.techniquePrerequisites(name);
  if (alternatives.isEmpty) return rb.hasPrerequisites(name) ? 'Prérequis de $name illisibles : à vérifier par le conte.' : null;
  List<(String, int)> missing(List<(String, int)> alt) => [for (final (d, l) in alt) if (_level(c, d) < l) (d, l)];
  var best = missing(alternatives.first);
  for (final alt in alternatives.skip(1)) {
    final m = missing(alt);
    if (m.length < best.length) best = m;
  }
  if (best.isEmpty) return null;
  return 'Prérequis manquant : ${[for (final (d, l) in best) '$d ${dots(l)}'].join(', ')}';
}

String? techniqueError(Character c, String name, Rulebook rb) {
  if (_knows(c.techniques, name)) return 'Technique déjà connue.';
  final rank = c.genRank ?? GenRank.neonate;
  if (rb.gen(rank).techniqueCost == 0) return 'Techniques interdites au rang ${rank.label}.';
  return prerequisiteError(c, name, rb);
}

String? elderError(Character c, String name, Rulebook rb) {
  if (_knows(c.elderPowers.map((e) => e.name), name)) return 'Pouvoir d’ancien déjà connu.';
  final rank = c.genRank ?? GenRank.neonate;
  final row = rb.gen(rank);
  if (!row.eldersAllowed) return 'Pouvoirs d’anciens interdits au rang ${rank.label}.';
  final discipline = rb.elderDiscipline(name);
  if (discipline == null) return 'Pouvoir d’ancien sans discipline dans le référentiel : à demander au conte.';
  if (_level(c, discipline) < 5) return 'Pouvoir d’ancien : 5 points de $discipline requis';
  if (c.elderPowers.length + 1 > row.eldersLimit) return 'Pouvoirs d’anciens : ${row.eldersLimit} au plus au rang ${rank.label}.';
  return null;
}

/// Ce qui ne tient plus sur la fiche (voie baissée, prérequis perdus, rang changé) : une ligne par problème.
List<String> powerProblems(Character c, Rulebook rb) {
  final out = <String>[];
  for (final school in {for (final r in c.rituals) r.school}) {
    final mine = [for (final r in c.rituals) if (r.school == school) r];
    final points = schoolDots(c, school, rb);
    if (mine.length > points) out.add(_limit(school, points, mine.length));
    final levels = {for (final r in mine) r.level};
    final gaps = {for (final l in levels) for (var k = 1; k < l; k++) if (!levels.contains(k)) k};
    for (final k in gaps.toList()..sort()) {
      out.add('Il manque un rituel de niveau $k (${_school(school)})');
    }
  }
  final rank = c.genRank ?? GenRank.neonate;
  final row = rb.gen(rank);
  if (c.techniques.isNotEmpty && row.techniqueCost == 0) out.add('Techniques interdites au rang ${rank.label}.');
  for (final t in c.techniques) {
    final e = prerequisiteError(c, t, rb);
    if (e != null) out.add('$t : ${e[0].toLowerCase()}${e.substring(1)}');
  }
  if (c.elderPowers.isNotEmpty && !row.eldersAllowed) out.add('Pouvoirs d’anciens interdits au rang ${rank.label}.');
  if (row.eldersAllowed && c.elderPowers.length > row.eldersLimit) {
    out.add('Pouvoirs d’anciens : ${row.eldersLimit} au plus au rang ${rank.label}.');
  }
  for (final e in c.elderPowers) {
    if (_level(c, e.discipline) < 5) out.add('${e.name} : 5 points de ${e.discipline} requis');
  }
  return out;
}

int ritualCost(String name, Rulebook rb) => rb.ritualLevel(name) * rb.ritualCostPerLevel;

int techniqueCost(Character c, Rulebook rb) => rb.gen(c.genRank ?? GenRank.neonate).techniqueCost;

/// La discipline du pouvoir est en clan pour la fiche (ou pour son clan, si elle ne l'a pas).
bool elderInClan(Character c, String name, Rulebook rb) {
  final d = rb.elderDiscipline(name);
  if (d == null) return false;
  return c.disciplines.where((x) => nameKey(x.name) == nameKey(d)).firstOrNull?.inClan ?? rb.clanDisciplines(c.clan).contains(d);
}

int elderCost(Character c, String name, Rulebook rb) => rb.elderCost(name, inClan: elderInClan(c, name, rb));
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter test test/rules test/rulebook`, puis `flutter analyze`.

Expected : tous les tests passent, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: référentiel — rituels, techniques, pouvoirs d’anciens : recherches et contrôles" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : création — nouveaux achats et points bonus d'attribut

**Files :**
- Modify : `lib/rules/creation_rules.dart`, `lib/creation/creation_steps.dart`.
- Tests : `test/creation/creation_rules_test.dart`, `test/creation/creation_steps_test.dart`.

**Interfaces :**
- Consumes : la tâche 2.
- Produces : `Buy.ritual`, `Buy.technique`, `Buy.elderPower`. Les points bonus d'attribut se déduisent dans `applyDerived` et sont contrôlés à l'étape 4.

- [ ] **Step 1 : tests (échec attendu)**

Dans `test/creation/creation_rules_test.dart`, ajouter à la fin du groupe `référentiel` (avant sa dernière accolade `});`) :

```dart
    Rulebook magic() => Rulebook({
          'rituals': [
            RuleEntry(name: 'Goût du sang', data: {'school': 'thaumaturgy', 'level': 1, 'atCreation': true}),
            RuleEntry(name: 'Défense du refuge', data: {'school': 'thaumaturgy', 'level': 2, 'atCreation': true}),
            RuleEntry(name: 'Rituel tardif', data: {'school': 'thaumaturgy', 'level': 1}),
          ],
          'techniques': [
            RuleEntry(name: 'Regard ardent', data: {'prerequisites': ['Thaumaturgie 2']}),
          ],
        });

    test('rituels et techniques à la création : contrôles, coût, avertissement du conte', () {
      final rb = magic();
      final c = valid();
      expect(addPurchase(c, Buy.ritual, 'Défense du refuge', rb: rb), 'Il manque un rituel de niveau 1');
      expect(addPurchase(c, Buy.ritual, 'Rituel tardif', rb: rb), 'Ce rituel ne s’apprend pas à la création.');
      expect(addPurchase(c, Buy.ritual, 'Goût du sang', rb: rb), isNull);
      expect(c.rituals.single.level, 1);
      expect(c.purchases.last.cost, 2);
      expect(addPurchase(c, Buy.technique, 'Regard ardent', rb: rb), isNull);
      expect(c.purchases.last.cost, 12);
      applyDerived(c, rb: rb);
      expect(warnings(c, rb), contains('Rituels choisis à la création : à confirmer par le conte'));
      expect(removePurchase(c, c.purchases.length - 1, rb: rb), isNull);
      expect(c.techniques, isEmpty);
    });

    test('pouvoir d’ancien refusé hors du rang Pretender Elder', () {
      final rb = Rulebook({
        'elderPowers': [RuleEntry(name: 'Clairvoyance', data: {'discipline': 'Auspex'})],
      });
      expect(addPurchase(valid(), Buy.elderPower, 'Clairvoyance', rb: rb), 'Pouvoirs d’anciens interdits au rang Neonate.');
    });

    test('points bonus d’attribut : plafond 10 + point du rang, contrôle du total', () {
      final c = valid();
      for (var i = 0; i < 3; i++) {
        expect(addPurchase(c, Buy.attribute, AttrCategory.mental.name), isNull);
      }
      expect(addPurchase(c, Buy.attribute, AttrCategory.mental.name), isNull, reason: '11 : le point bonus du Neonate');
      expect(addPurchase(c, Buy.attribute, AttrCategory.mental.name), 'Plafond atteint (11).');
      applyDerived(c);
      expect(c.attributeBonus[AttrCategory.mental], 1);
      expect(blockingWith(c, const Rulebook()), isNot(contains(startsWith('Points bonus'))));
      c.attributes[AttrCategory.social]!.value = 11;
      c.attributeBonus[AttrCategory.social] = 1;
      expect(
          creationChecks(c).where((k) => k.level == CheckLevel.error).map((k) => k.text), contains('Points bonus d’attribut : 2 placés, 1 au plus'));
    });
```

Dans `test/creation/creation_steps_test.dart`, ajouter :

```dart
  testWidgets('étape 9 : rituel refusé puis accepté', (tester) async {
    final rb = Rulebook({
      'rituals': [
        RuleEntry(name: 'Goût du sang', data: {'school': 'thaumaturgy', 'level': 1, 'atCreation': true}),
        RuleEntry(name: 'Défense du refuge', data: {'school': 'thaumaturgy', 'level': 2, 'atCreation': true}),
      ],
    });
    final c = valid();
    await pumpStep(tester, 9, c, rb: rb);
    Future<void> choose(Key key, String text) async {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    await choose(const Key('buy-kind'), 'Rituel');
    await choose(const Key('buy-name-ritual'), 'Défense du refuge (niveau 2)');
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('Il manque un rituel de niveau 1'), findsOneWidget);
    expect(c.rituals, isEmpty);
    await choose(const Key('buy-name-ritual'), 'Goût du sang (niveau 1)');
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(c.rituals.single.name, 'Goût du sang');
  });
```

Run : `flutter test test/creation`.

Expected : échec à la compilation (`Buy.ritual` inconnu).

- [ ] **Step 2 : moteur de création** (`lib/rules/creation_rules.dart`)

1. Ajouter l'import `powers_rules.dart`.
2. Dans `Buy`, ajouter :
```dart
  static const ritual = 'ritual';
  static const technique = 'technique';
  static const elderPower = 'elderPower';
```
3. Dans `levelOf`, avant `_ => 0`, ajouter :
```dart
      Buy.ritual => c.rituals.any((r) => nameKey(r.name) == nameKey(name)) ? 1 : 0,
      Buy.technique => c.techniques.any((t) => nameKey(t) == nameKey(name)) ? 1 : 0,
      Buy.elderPower => c.elderPowers.any((e) => nameKey(e.name) == nameKey(name)) ? 1 : 0,
```
4. Dans `purchaseCost`, avant `_ => 0`, ajouter :
```dart
    Buy.ritual => ritualCost(name, rb),
    Buy.technique => row.techniqueCost,
    Buy.elderPower => elderCost(c, name, rb),
```
5. `capFor` devient :
```dart
int capFor(Character c, String kind, String name, {Rulebook rb = const Rulebook()}) => switch (kind) {
      Buy.attribute => 10 + _bonusLeftFor(c, AttrCategory.values.byName(name), rb),
      Buy.humanity => 6,
      Buy.background when name == generationName => 3,
      Buy.skill => rb.skillCap(name, rankFor(c)),
      Buy.background => rb.backgroundCap(name),
      Buy.ritual || Buy.technique || Buy.elderPower => 1,
      _ => 5,
    };

/// Points bonus du rang que la catégorie [cat] peut encore prendre (les autres catégories gardent les leurs).
int _bonusLeftFor(Character c, AttrCategory cat, Rulebook rb) {
  final placed = _sum([for (final a in AttrCategory.values) if (a != cat) max(0, c.attributes[a]!.value - 10)]);
  return max(0, rb.gen(rankFor(c) ?? GenRank.neonate).attributeBonus - placed);
}
```
6. Dans `_setLevel`, avant `case Buy.humanity:`, ajouter :
```dart
    case Buy.ritual:
      c.rituals.removeWhere((r) => nameKey(r.name) == nameKey(name));
      if (level > 0) c.rituals.add(Ritual(name, rb.ritualSchool(name) ?? '', rb.ritualLevel(name)));
    case Buy.technique:
      c.techniques.removeWhere((t) => nameKey(t) == nameKey(name));
      if (level > 0) c.techniques.add(name);
    case Buy.elderPower:
      c.elderPowers.removeWhere((e) => nameKey(e.name) == nameKey(name));
      if (level > 0) c.elderPowers.add(ElderPower(name, rb.elderDiscipline(name) ?? ''));
```
7. Dans `addPurchase`, juste après `final to = levelOf(c, kind, name) + 1;`, ajouter :
```dart
  final ritual = kind == Buy.ritual ? rb.find('rituals', name) : null;
  if (ritual != null && ritual.data['atCreation'] != true) return 'Ce rituel ne s’apprend pas à la création.';
  final powerError = switch (kind) {
    Buy.ritual => ritualError(c, name, rb),
    Buy.technique => techniqueError(c, name, rb),
    Buy.elderPower => elderError(c, name, rb),
    _ => null,
  };
  if (powerError != null) return powerError;
```
8. Dans `applyDerived`, après la boucle des attributs, ajouter :
```dart
  // Création : les points bonus placés se lisent dans les valeurs (au-delà de 10).
  c.attributeBonus = {for (final cat in AttrCategory.values) cat: max(0, c.attributes[cat]!.value - 10)};
```
9. Dans `creationChecks` :
   - **Étape 4.** Après la ligne `add(4, …)`, ajouter :
```dart
  final bonus = _sum(c.attributeBonus.values);
  final allowed = rb.gen(rankFor(c) ?? GenRank.neonate).attributeBonus;
  if (bonus > allowed) add(4, CheckLevel.error, 'Points bonus d’attribut : $bonus placés, $allowed au plus');
```
   - **Étape 9.** Juste avant `// Les règles Firestore ne recalculent rien`, ajouter :
```dart
  for (final r in c.rituals) {
    state(9, 'rituals', 'Rituel', r.name);
  }
  for (final t in c.techniques) {
    state(9, 'techniques', 'Technique', t);
  }
  for (final e in c.elderPowers) {
    state(9, 'elderPowers', 'Pouvoir d’ancien', e.name);
    if (!elderInClan(c, e.name, rb)) add(9, CheckLevel.warn, 'Professeur nécessaire : ${e.name} hors clan, à confirmer par le conte');
  }
  for (final p in powerProblems(c, rb)) {
    add(9, CheckLevel.error, p);
  }
  if (c.rituals.isNotEmpty) add(9, CheckLevel.warn, 'Rituels choisis à la création : à confirmer par le conte');
```

- [ ] **Step 3 : étape 9** (`lib/creation/creation_steps.dart`, `_PurchasesStepState`)

1. Dans `_kinds`, après `Buy.discipline: 'Discipline',`, ajouter :
```dart
    Buy.ritual: 'Rituel',
    Buy.technique: 'Technique',
    Buy.elderPower: 'Pouvoir d’ancien',
```
2. Dans `_cat`, avant `_ => null`, ajouter :
```dart
        Buy.ritual => 'rituals',
        Buy.technique => 'techniques',
        Buy.elderPower => 'elderPowers',
```
3. Dans `_names`, avant `_ => {humanityName: humanityName},`, ajouter :
```dart
        Buy.ritual => {
            for (final e in rb.offered('rituals'))
              if (e.data['atCreation'] == true && levelOf(c, Buy.ritual, e.name) == 0)
                e.name: '${e.name} (niveau ${rb.ritualLevel(e.name)})${_approval(rb, 'rituals', e.name)}',
          },
        Buy.technique => {
            for (final e in rb.offered('techniques'))
              if (levelOf(c, Buy.technique, e.name) == 0) e.name: '${e.name}${_approval(rb, 'techniques', e.name)}',
          },
        Buy.elderPower => {
            for (final e in rb.offered('elderPowers'))
              if (levelOf(c, Buy.elderPower, e.name) == 0) e.name: '${e.name}${_approval(rb, 'elderPowers', e.name)}',
          },
```
4. Dans `_label`, avant `_ => p.name,`, ajouter :
```dart
        Buy.ritual => 'Rituel · ${p.name}',
        Buy.technique => 'Technique · ${p.name}',
        Buy.elderPower => 'Pouvoir d’ancien · ${p.name}',
```
5. Dans le tableau « Coûts », après `('Humanité', '10 XP le point, 6 au plus'),`, ajouter :
```dart
          ('Rituel', 'Niveau × ${rb.ritualCostPerLevel}'),
          ('Technique', row.techniqueCost == 0 ? 'Interdite à ce rang' : '${row.techniqueCost} XP'),
          ('Pouvoir d’ancien', row.eldersAllowed ? 'Selon le pouvoir' : 'Interdit à ce rang'),
```

- [ ] **Step 4 : tester, analyser**

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 5 : commit**

```
git add lib test
git commit -m "feat: création — rituels, techniques, pouvoirs d’anciens, points bonus d’attribut" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : XP — nouveaux achats, points bonus, corrections

**Files :**
- Modify : `lib/xp/xp_request.dart`, `lib/xp/xp_rules.dart`, `lib/xp/xp_corrections.dart`.
- Test : `test/xp/xp_rules_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2.
- Produces :
  - `XpKind.ritual`, `XpKind.technique`, `XpKind.elderPower` ;
  - `bonusNote` (`'point bonus'`), `attributeCap(c, items, cat)`, `bonusLeft(c, items, rb)`.

- [ ] **Step 1 : tests (échec attendu)**

Dans `test/xp/xp_rules_test.dart`, ajouter les imports `../rules/powers_rules_test.dart` (`show rulebook, thaumaturge`) et `package:portail_met/xp/xp_corrections.dart`. Puis, à la fin de `main()` :

```dart
  group('rituels, techniques, pouvoirs d’anciens, points bonus', () {
    test('deux rituels dans une même demande : le second voit le premier (Review Focus 3)', () {
      final rb = rulebook();
      final c = thaumaturge()..disciplines[1].level = 0;
      final items = <XpItem>[];
      final first = draftItem(c, items, XpKind.ritual, 'Goût du sang', rb: rb);
      expect((first.fromLevel, first.toLevel, first.cost), (0, 1, 3));
      expect(itemError(c, items, first, usable: 100, rb: rb), isNull);
      items.add(first);
      final second = draftItem(c, items, XpKind.ritual, 'Défense du refuge', rb: rb);
      expect(itemError(c, items, second, usable: 100, rb: rb), 'Thaumaturgie ● : 1 rituel au plus, vous en avez 1');
      final after = applyRequest(c, items, rb: rb);
      expect(after.rituals.single.name, 'Goût du sang');
      expect(after.xpSpent, c.xpSpent + 3);
    });

    test('discipline à 5 puis pouvoir d’ancien dans la même demande ; coût hors clan', () {
      final rb = rulebook();
      final c = thaumaturge()..genRank = GenRank.pretender;
      c.disciplines.last.level = 4;
      final items = [draftItem(c, const [], XpKind.discipline, 'Auspex', rb: rb)];
      final elder = draftItem(c, items, XpKind.elderPower, 'Clairvoyance', rb: rb);
      expect(elder.cost, 18);
      expect(itemError(c, items, elder, usable: 100, rb: rb), isNull);
      final r = req([...items, elder]);
      expect(requestChecks(c, r, reservedOthers: 0, rb: rb).where((k) => k.level == CheckLevel.error), isEmpty);
      expect(draftItem(c, const [], XpKind.elderPower, 'Possession', rb: rb).cost, 24);
    });

    test('technique : prérequis perdu avant la validation (Review Focus 5)', () {
      final rb = rulebook();
      final c = thaumaturge()..disciplines.add(Discipline('Présence', 2));
      final r = req([draftItem(c, const [], XpKind.technique, 'Regard ardent', rb: rb)]);
      expect(requestChecks(c, r, reservedOthers: 0, rb: rb).where((k) => k.level == CheckLevel.error), isEmpty);
      c.disciplines.removeLast();
      expect(requestChecks(c, r, reservedOthers: 0, rb: rb).map((k) => k.text), contains('Prérequis manquant : Présence ●●'));
    });

    test('point bonus d’attribut : posé au-delà du plafond, refusé sans point restant (Review Focus 4)', () {
      final c = sample();
      c.attributes[AttrCategory.social]!.value = 10;
      final item = draftItem(c, const [], XpKind.attribute, 'social');
      expect((item.toLevel, item.note, item.cost), (11, bonusNote, 3));
      expect(itemError(c, const [], item, usable: 100), isNull);
      final after = applyRequest(c, [item]);
      expect((after.attributes[AttrCategory.social]!.value, after.attributeBonus[AttrCategory.social]), (11, 1));
      after.attributeBonus[AttrCategory.mental] = 1;
      final more = draftItem(after, const [], XpKind.attribute, 'social');
      expect(itemError(after, const [], more, usable: 100), 'Plus de point bonus d’attribut : Social 11 au plus.');
      final undone = applyCorrection(after, CorrectionKind.cancelPurchase, item: item).after!;
      expect((undone.attributes[AttrCategory.social]!.value, undone.attributeBonus[AttrCategory.social]), (10, 0));
    });

    test('annuler l’achat d’un rituel le retire', () {
      final rb = rulebook();
      final c = thaumaturge();
      final item = draftItem(c, const [], XpKind.ritual, 'Goût du sang', rb: rb);
      final after = applyRequest(c, [item], rb: rb);
      final undone = applyCorrection(after, CorrectionKind.cancelPurchase, item: item).after!;
      expect(undone.rituals, isEmpty);
    });
  });
```

Run : `flutter test test/xp/xp_rules_test.dart`.

Expected : échec à la compilation (`XpKind.ritual` inconnu).

- [ ] **Step 2 : modèle et moteur**

**`lib/xp/xp_request.dart` :**
- dans `XpKind`, après `merit('Atout'),`, ajouter `ritual('Rituel'),`, `technique('Technique'),` et `elderPower('Pouvoir d’ancien'),` (une valeur par ligne) ;
- dans `levelText`, avant `_ => '$n'`, ajouter :
  `XpKind.ritual || XpKind.technique || XpKind.elderPower => n > 0 ? 'appris' : '—',`

**`lib/xp/xp_rules.dart` :**
1. **Imports et aides.** Ajouter l'import `../rules/powers_rules.dart`. Après `GenRow _row(…)`, ajouter :
```dart
/// Note d'un achat d'attribut qui place un point bonus de Génération (plafond 10 + 1).
const bonusNote = 'point bonus';

bool _isBonus(XpItem i) => i.kind == XpKind.attribute && i.note == bonusNote;

/// Plafond de la catégorie : 10 + points bonus placés sur la fiche et dans la demande.
int attributeCap(Character c, List<XpItem> items, AttrCategory cat) =>
    10 + (c.attributeBonus[cat] ?? 0) + items.where((i) => _isBonus(i) && i.name == cat.name).length;

/// Points bonus du rang encore libres, compte tenu de la demande.
int bonusLeft(Character c, List<XpItem> items, Rulebook rb) =>
    _row(c, rb).attributeBonus - c.attributeBonus.values.fold(0, (a, b) => a + b) - items.where(_isBonus).length;

bool _knows(Iterable<String> names, String name) => names.any((n) => nameKey(n) == nameKey(name));

bool _isPower(XpKind k) => k == XpKind.ritual || k == XpKind.technique || k == XpKind.elderPower;

/// Contrôle d'un nouveau rituel, d'une technique ou d'un pouvoir d'ancien sur la fiche [c].
String? _powerError(Character c, XpItem i, Rulebook rb) => switch (i.kind) {
      XpKind.ritual => ritualError(c, i.name, rb),
      XpKind.technique => techniqueError(c, i.name, rb),
      XpKind.elderPower => elderError(c, i.name, rb),
      _ => null,
    };
```
2. **`levelNow`.** Ajouter :
```dart
      XpKind.ritual => _knows(c.rituals.map((r) => r.name), name) ? 1 : 0,
      XpKind.technique => _knows(c.techniques, name) ? 1 : 0,
      XpKind.elderPower => _knows(c.elderPowers.map((e) => e.name), name) ? 1 : 0,
```
3. **`ruleCategoryOf`.** Avant `_ => null`, ajouter :
```dart
      XpKind.ritual => 'rituals',
      XpKind.technique => 'techniques',
      XpKind.elderPower => 'elderPowers',
```
4. **`costOf`.** Ajouter :
```dart
      XpKind.ritual => ritualCost(i.name, rb),
      XpKind.technique => techniqueCost(c, rb),
      XpKind.elderPower => elderCost(c, i.name, rb),
```
5. **`ruleText`.** Ajouter :
```dart
      XpKind.ritual => 'Niveau du rituel × ${rb.ritualCostPerLevel}',
      XpKind.technique => 'Selon le rang',
      XpKind.elderPower => elderInClan(c, i.name, rb) ? 'En clan' : 'Hors clan',
```
6. **`costTable`.** Avant `('Rachat d’un handicap', …)`, ajouter :
```dart
    ('Rituel', 'Niveau × ${rb.ritualCostPerLevel}'),
    ('Technique', row.techniqueCost == 0 ? 'Interdite à ce rang' : '${row.techniqueCost} XP'),
    ('Pouvoir d’ancien', row.eldersAllowed ? 'Selon le pouvoir' : 'Interdit à ce rang'),
```
7. **`elementOptions`.** Avant `XpKind.humanity => …`, ajouter :
```dart
    XpKind.ritual => {
        for (final e in rb.offered('rituals'))
          if (e.data['withXp'] == true && !_knows(c.rituals.map((r) => r.name), e.name))
            e.name: label('rituals', e.name, ' (niveau ${rb.ritualLevel(e.name)})'),
      },
    XpKind.technique => {
        for (final e in rb.offered('techniques'))
          if (!_knows(c.techniques, e.name)) e.name: label('techniques', e.name),
      },
    XpKind.elderPower => {
        for (final e in rb.offered('elderPowers'))
          if (!_knows(c.elderPowers.map((x) => x.name), e.name)) e.name: label('elderPowers', e.name),
      },
```
8. **`draftItem`.** Dans son `switch`, avant `_ => from + 1,`, ajouter `XpKind.ritual || XpKind.technique || XpKind.elderPower => 1,`. Remplacer la ligne `final draft = XpItem(k, name, from, to, 0, note: n.isEmpty ? null : n);` par :
```dart
  final cat = k == XpKind.attribute ? AttrCategory.values.asNameMap()[name] : null;
  // Au-delà du plafond, l'achat place un point bonus de Génération.
  final note = cat != null ? (to > attributeCap(c, items, cat) ? bonusNote : null) : (n.isEmpty ? null : n);
  final draft = XpItem(k, name, from, to, 0, note: note);
```
9. **`itemError`.** Dans son `switch`, avant `default:`, ajouter :
```dart
    case XpKind.ritual || XpKind.technique || XpKind.elderPower:
      if (item.fromLevel > 0) return 'Déjà appris.';
      if (item.kind == XpKind.ritual && entry?.data['withXp'] != true) return 'Ce rituel ne s’achète pas avec l’XP gagnée.';
      final e = _powerError(applyRequest(c, items, rb: rb), item, rb);
      if (e != null) return e;
    case XpKind.attribute:
      final cat = AttrCategory.values.byName(item.name);
      if (_isBonus(item) && bonusLeft(c, items, rb) <= 0) {
        return 'Plus de point bonus d’attribut : ${cat.label} ${attributeCap(c, items, cat)} au plus.';
      }
```
10. **`wellFormed`.** La ligne de l'attribut devient :
```dart
      XpKind.attribute => AttrCategory.values.asNameMap().containsKey(i.name) &&
          i.toLevel == i.fromLevel + 1 &&
          (i.note == null || i.note == bonusNote),
```
   Ajouter `XpKind.ritual || XpKind.technique || XpKind.elderPower => i.fromLevel == 0 && i.toLevel == 1,`.
11. **`requestChecks`.**
   - Le contrôle de plafond `if (i.kind != XpKind.merit && i.kind != XpKind.flawBuyback) {` devient `if (i.kind != XpKind.merit && i.kind != XpKind.flawBuyback && i.kind != XpKind.attribute && !_isPower(i.kind)) {`.
   - Ajouter, juste avant `// Livre de base p. 108` :
```dart
    if (i.kind == XpKind.attribute) {
      final cat = AttrCategory.values.byName(i.name);
      if (i.toLevel > attributeCap(c, seen, cat) + (_isBonus(i) ? 1 : 0)) {
        out.add(Check(0, CheckLevel.error, 'Plafond dépassé : ${i.label} (${attributeCap(c, seen, cat)} au plus)'));
      }
      if (_isBonus(i) && bonusLeft(c, seen, rb) <= 0) out.add(Check(0, CheckLevel.error, 'Plus de point bonus d’attribut pour ${i.label}'));
    }
    if (_isPower(i.kind)) {
      final e = _powerError(applyRequest(c, seen, rb: rb), i, rb);
      if (e != null) out.add(Check(0, CheckLevel.error, e));
      if (i.kind == XpKind.elderPower && !elderInClan(c, i.name, rb)) {
        out.add(Check(0, CheckLevel.warn, 'Professeur nécessaire : ${i.name} hors clan, à confirmer par le conte'));
      }
    }
```
12. **`applyRequest`.**
   - Dans `case XpKind.attribute:`, ajouter après l'affectation de la valeur :
```dart
        final cat = AttrCategory.values.byName(i.name);
        if (_isBonus(i)) n.attributeBonus[cat] = (n.attributeBonus[cat] ?? 0) + 1;
```
   - Avant `case XpKind.humanity:`, ajouter :
```dart
      case XpKind.ritual:
        n.rituals.add(Ritual(i.name, rb.ritualSchool(i.name) ?? '', rb.ritualLevel(i.name)));
      case XpKind.technique:
        n.techniques.add(i.name);
      case XpKind.elderPower:
        n.elderPowers.add(ElderPower(i.name, rb.elderDiscipline(i.name) ?? ''));
```

**`lib/xp/xp_corrections.dart`** (`_revert`) :
- `case XpKind.attribute:` devient :
```dart
    case XpKind.attribute:
      final cat = AttrCategory.values.byName(i.name);
      n.attributes[cat]!.value = i.fromLevel;
      // Annuler un achat qui avait placé un point bonus le rend.
      if (i.note == bonusNote) n.attributeBonus[cat] = ((n.attributeBonus[cat] ?? 0) - 1).clamp(0, 99);
```
- avant `case XpKind.humanity:`, ajouter :
```dart
    case XpKind.ritual:
      n.rituals.removeWhere((r) => r.name == i.name);
    case XpKind.technique:
      n.techniques.remove(i.name);
    case XpKind.elderPower:
      n.elderPowers.removeWhere((e) => e.name == i.name);
```

Les autres `switch` sur `XpKind` qui ne compileraient plus reçoivent les trois cas, sur le même modèle. L'analyseur les liste.

- [ ] **Step 3 : tester, analyser**

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add lib test
git commit -m "feat: XP — rituels, techniques, pouvoirs d’anciens, points bonus d’attribut ; corrections" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : affichage sur la fiche et édition par le conte (C3)

**Files :**
- Modify : `lib/characters/sheet_widgets.dart`, `lib/characters/edit_widgets.dart`, `lib/characters/character_edit_screen.dart`.
- Tests : `test/characters/later_keys_test.dart`, `test/characters/character_edit_test.dart`.

**Interfaces :**
- Produces : `NameListEditor(label, items, options, onAdd, onRemove)`.

- [ ] **Step 1 : tests (échec attendu)**

Dans `test/characters/later_keys_test.dart`, ajouter les imports :
- `package:flutter/material.dart` ;
- `package:portail_met/characters/sheet_widgets.dart` ;
- `package:portail_met/core/theme.dart`.

Puis ajouter :
```dart
  testWidgets('fiche : rituels, techniques, pouvoirs d’anciens, points bonus', (tester) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = sample()
      ..rituals = [Ritual('Goût du sang', 'thaumaturgy', 1)]
      ..techniques = ['Regard ardent']
      ..elderPowers = [ElderPower('Clairvoyance', 'Auspex')];
    c.attributeBonus[AttrCategory.social] = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: CharacterSheetView(c))),
    ));
    expect(find.text('Rituel · Goût du sang'), findsOneWidget);
    expect(find.text('Regard ardent'), findsOneWidget);
    expect(find.text('Pouvoir d’ancien · Clairvoyance'), findsOneWidget);
    expect(find.textContaining('1 point bonus'), findsOneWidget);
  });
```

Dans `test/characters/character_edit_test.dart`, ajouter :
```dart
  testWidgets('C3 : ajouter un rituel du référentiel', (tester) async {
    final rb = Rulebook({
      'rituals': [RuleEntry(name: 'Goût du sang', data: {'school': 'thaumaturgy', 'level': 1})],
    });
    await pump(tester, sample(), rb: rb);
    await tester.tap(find.byKey(const ValueKey('add-Rituels-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goût du sang').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirer Goût du sang'), findsOneWidget);
  });
```

Run : `flutter test test/characters`.

Expected : les deux nouveaux tests échouent.

- [ ] **Step 2 : écrans**

**`lib/characters/edit_widgets.dart`**, ajouter à la fin :
```dart
/// Rituels, techniques, pouvoirs d'anciens : des noms, ajoutés depuis le référentiel ou saisis.
class NameListEditor extends StatelessWidget {
  const NameListEditor({super.key, required this.label, required this.items, required this.options, required this.onAdd, required this.onRemove});

  final String label;
  final List<String> items;
  final List<String> options;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final remaining = options.where((o) => !items.contains(o)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (items.isEmpty) Text('Aucun.', style: Theme.of(context).textTheme.bodySmall),
      for (final n in items)
        Row(children: [
          Expanded(child: Text(n)),
          IconButton(tooltip: 'Retirer $n', onPressed: () => onRemove(n), icon: const Icon(Icons.close, size: 18)),
        ]),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: ValueKey('add-$label-${items.length}'),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ajouter…'),
        items: [
          for (final o in remaining) DropdownMenuItem(value: o, child: Text(o)),
          const DropdownMenuItem(value: _other, child: Text('Autre…')),
        ],
        onChanged: (o) async {
          final name = o == _other ? await _askOther(context, label) : o;
          if (name != null) onAdd(name);
        },
      ),
    ]);
  }
}
```

**`lib/characters/character_edit_screen.dart` :**
1. **Attributs.** Le `PointsField` de chaque attribut reçoit `max: 10 + (c.attributeBonus[cat] ?? 0),`. Après le `ChoiceField` du focus, ajouter :
```dart
        PointsField(
          label: 'Points bonus ${cat.label}',
          value: c.attributeBonus[cat] ?? 0,
          max: 3,
          asDots: false,
          onChanged: (v) => set(() => c.attributeBonus[cat] = v),
        ),
```
2. **Listes.** Dans `lists`, après la section « Handicaps », ajouter :
```dart
      section('Rituels', [
        NameListEditor(
          label: 'Rituels',
          items: [for (final r in c.rituals) r.name],
          options: names('rituals'),
          onAdd: (n) => set(() => c.rituals.add(Ritual(n, rb.ritualSchool(n) ?? '', rb.ritualLevel(n)))),
          onRemove: (n) => set(() => c.rituals.removeWhere((r) => r.name == n)),
        ),
      ]),
      section('Techniques', [
        NameListEditor(
          label: 'Techniques',
          items: c.techniques,
          options: names('techniques'),
          onAdd: (n) => set(() => c.techniques.add(n)),
          onRemove: (n) => set(() => c.techniques.remove(n)),
        ),
      ]),
      section('Pouvoirs d’anciens', [
        NameListEditor(
          label: 'Pouvoirs d’anciens',
          items: [for (final e in c.elderPowers) e.name],
          options: names('elderPowers'),
          onAdd: (n) => set(() => c.elderPowers.add(ElderPower(n, rb.elderDiscipline(n) ?? ''))),
          onRemove: (n) => set(() => c.elderPowers.removeWhere((e) => e.name == n)),
        ),
      ]),
```

**`lib/characters/sheet_widgets.dart`** (`CharacterSheetView`) :
1. **Attributs.** Après `List<Trait> sorted(…)`, ajouter `String? joined(List<String> parts) => parts.isEmpty ? null : parts.join(' · ');`. La note de chaque attribut devient :
```dart
          note: joined([
            if (c.attributes[cat]!.focus != null) 'Focus : ${c.attributes[cat]!.focus}',
            if ((c.attributeBonus[cat] ?? 0) > 0) '${c.attributeBonus[cat]} point${c.attributeBonus[cat]! > 1 ? 's' : ''} bonus',
          ]),
```
2. **Nouvelle section.** Après `meritsFlaws`, ajouter :
```dart
    final powers = c.rituals.isEmpty && c.techniques.isEmpty && c.elderPowers.isEmpty
        ? null
        : section('Rituels, techniques et pouvoirs d’anciens', [
            for (final r in c.rituals) InfoRow('Rituel · ${r.name}', 'niveau ${r.level}'),
            for (final t in c.techniques) InfoRow('Technique', t),
            for (final e in c.elderPowers) InfoRow('Pouvoir d’ancien · ${e.name}', e.discipline),
          ]);
```
3. **Colonnes.** Dans les deux appels de `column([...])` qui contiennent `meritsFlaws`, ajouter `?powers` juste après.

- [ ] **Step 3 : tester, analyser**

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add lib test
git commit -m "feat: fiche et C3 — rituels, techniques, pouvoirs d’anciens, points bonus" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : revue, puis déploiement (avec accord)

- [ ] **Vérifier les appels des écrans.** Relancer la recherche du plan B (tâche 6) : chaque appel d'écran passe `rb`.
- [ ] **Règles Firestore.** Depuis `rules_test`, `JAVA_HOME=… npm test` (règles inchangées, nouveau test de la tâche 1).
- [ ] **Revue finale de la branche.** Corriger les points Critical et Important, avec un test chacun.
- [ ] **Avec l'accord de l'utilisateur :**
  - `flutter build web --release` ;
  - `firebase deploy --only hosting --project met-mon-vampire` ;
  - puis fusion de `referentiel-c` dans `main`.
