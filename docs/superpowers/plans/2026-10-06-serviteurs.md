# Serviteurs, goules animales et mortels (sous-projet 6b) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** un personnage a plusieurs serviteurs, achetés en XP comme des historiques. Le conte détaille chaque serviteur et suit les mortels. Le joueur voit les serviteurs de ses personnages.

**Architecture :**
- **Sur la fiche du personnage :** la clé tardive `servants` (`id`, `name`, `kind`, `rank`), touchée par l'XP, C3 et les corrections. L'ancien historique « Serviteurs » est converti à la lecture.
- **Fiche détaillée :** `servants/{id}`, avec `private/note` et `history/{h}`, sur le modèle des lieux : lecture par l'équipe et par le joueur du domitor, écriture par le conte, version contrôlée et historique.
- **Calculs purs :** `servant_rules.dart`.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-06-serviteurs-design.md`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md <N> [test|impl]` ;
  - textes en français ;
  - `dart run build_runner build --delete-conflicting-outputs` après tout fichier `part` ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche :** `serviteurs`, déjà créée.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Écarts assumés avec la spec** (à reporter dans le journal) :
  - **Qualités animales :** stockées comme une liste de noms (`['Costaud']`), pas comme `[{name}]`. Un nom suffit ; le coût et le prérequis viennent du référentiel.
  - **L'historique « Serviteurs » n'est plus proposé :** il disparaît de l'écran XP et de la liste des historiques de C3. Sinon il serait converti, et sa dépense absorbée, à la lecture suivante.
  - **Identifiant d'un nouveau serviteur :** `<characterId>-s<horodatage base 36><compteur>`. La conversion d'un ancien historique utilise `<id>-s1`.
  - **Historique d'un serviteur :** les entrées réutilisent la classe `PlaceEntry` des lieux, qui a la même forme.

## Review Focus

1. **Fiche active avec l'ancien historique « Serviteurs »** : elle est convertie une seule fois. Aucun doublon après un aller-retour ou une copie, et rien ne change pour un brouillon. Test : tâche 1.
2. **Deux nouveaux serviteurs dans une même demande d'XP, puis annulation par une correction** : identifiants distincts, rang rendu, serviteur retiré. Test : tâche 2.
3. **Joueur qui n'est pas celui du domitor** : il ne lit ni la fiche du serviteur ni la note. Un mortel n'est lu que par l'équipe. Test : tâche 4.
4. **Deux conteurs modifient la même fiche de serviteur** : la base est figée à l'ouverture. Le second voit « Modifié entre-temps : rechargez la page. ». Tests : tâches 4 et 5.
5. **Serviteur retiré dans C3** : sa fiche détaillée reçoit `releasedAt`. Le domitor affiche « points indisponibles jusqu'au … ». Tests : tâches 3 et 6.

---

### Task 1 : serviteurs sur la fiche du personnage

**Files :**
- Modify :
  - `lib/characters/character.dart` ;
  - `lib/characters/describe_changes.dart` ;
  - `lib/places/place_rules.dart` ;
  - `test/places/place_rules_test.dart`.
- Test : `test/characters/servants_test.dart`.

**Interfaces :**
- Produces :
  - `ServantKind { human('Goule humaine'), animal('Goule animale') }` ;
  - `Servant(id, name, kind, rank)` avec `fromMap` et `toMap` ;
  - `servantsBackground = 'Serviteurs'` ;
  - `newServantId(characterId)` ;
  - `Character.servants` ;
  - les lignes « Serviteur » de `describeChanges` ;
  - `controlLimit` = 5 + somme des rangs.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 1 test`, puis `flutter test test/characters/servants_test.dart`.

Expected : échec au chargement.

<!-- file: test/characters/servants_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';

import 'character_test.dart' show sample;

void main() {
  test('liste tardive : absente tant que vide, aller-retour, identifiants neufs distincts', () {
    final c = sample();
    expect(c.toMap().containsKey('servants'), isFalse);
    c.servants.add(Servant('x-s1', 'Rex', ServantKind.animal, 2));
    final back = Character.fromMap('x', c.toMap());
    expect(back.servants.single.toMap(), {'id': 'x-s1', 'name': 'Rex', 'kind': 'animal', 'rank': 2});
    back.servants.clear();
    expect(back.toMap()['servants'], isEmpty, reason: 'déjà écrite : la liste vide efface');
    expect(back.laterKeys()['servants'], isEmpty);
    final a = newServantId('x'), b = newServantId('x');
    expect(a, startsWith('x-s'));
    expect(a, isNot(b));
  });

  test('ancien historique Serviteurs : converti sur une fiche active, une seule fois ; pas en brouillon (Review Focus 1)', () {
    final m = {
      ...sample().toMap(),
      'backgrounds': [
        {'name': 'Serviteurs', 'level': 3, 'note': 'Dr Lemaire'},
        {'name': 'Ressources', 'level': 3},
      ],
    };
    final c = Character.fromMap('x', m);
    expect(c.backgrounds.map((b) => b.name), ['Ressources']);
    expect(c.servants.single.toMap(), {'id': 'x-s1', 'name': 'Dr Lemaire', 'kind': 'human', 'rank': 3});
    expect(c.clone().servants, hasLength(1));
    expect(Character.fromMap('x', c.toMap()).servants, hasLength(1));
    final draft = Character.fromMap('x', {...m, 'status': 'draft'});
    expect(draft.servants, isEmpty);
    expect(draft.backgrounds.map((b) => b.name), contains('Serviteurs'));
    final unnamed = Character.fromMap('x', {
      ...m,
      'backgrounds': [
        {'name': 'Serviteurs', 'level': 1},
      ],
    });
    expect(unnamed.servants.single.name, 'Serviteur');
  });

  test('résumé des changements', () {
    final a = sample()..servants = [Servant('x-s1', 'Rex', ServantKind.animal, 2), Servant('x-s2', 'Mila', ServantKind.human, 1)];
    final b = a.clone();
    b.servants.first
      ..name = 'Rex II'
      ..rank = 3;
    b.servants.removeLast();
    b.servants.add(Servant('x-s3', 'Lune', ServantKind.animal, 1));
    expect(describeChanges(a, b), ['Serviteur : Rex → Rex II', 'Serviteur Rex II ●● → ●●●', '+ Serviteur Lune ●', '− Serviteur Mila ●']);
  });
}
```

Dans `test/places/place_rules_test.dart`, la ligne `isaure.backgrounds.add(Trait('Serviteurs', 1));` devient `isaure.servants.add(Servant('x-s1', 'Rex', ServantKind.animal, 1));`.

- [ ] **Step 2 : implémentation**

**`lib/characters/character.dart` :**

1. Avant `/// Clés ajoutées au sous-projet 5`, ajouter :

```dart
enum ServantKind {
  human('Goule humaine'),
  animal('Goule animale');

  const ServantKind(this.label);
  final String label;
}

/// Serviteur acheté comme un historique : la partie que l'XP touche. Le détail vit dans `servants/{id}`.
class Servant {
  Servant(this.id, this.name, this.kind, this.rank);

  factory Servant.fromMap(Map<String, dynamic> m) => Servant(
        m['id'] as String? ?? '',
        m['name'] as String? ?? '',
        ServantKind.values.asNameMap()[m['kind']] ?? ServantKind.human,
        _int(m['rank']),
      );

  final String id;
  String name;
  ServantKind kind;
  int rank;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'kind': kind.name, 'rank': rank};
}

/// Ancien historique, converti en serviteur sur les fiches jouées ou closes (sous-projet 6b).
const servantsBackground = 'Serviteurs';

int _servantSeq = 0;

/// Identifiant d'un nouveau serviteur : jamais réutilisé, même après une libération.
String newServantId(String characterId) =>
    '$characterId-s${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_servantSeq++}';
```

2. `const _laterKeys = ['rituals', 'techniques', 'elderPowers', 'attributeBonus'];` devient `const _laterKeys = ['rituals', 'techniques', 'elderPowers', 'attributeBonus', 'servants'];`.

3. Dans `Character.fromMap`, après `..elderPowers = _maps(m['elderPowers']).map(ElderPower.fromMap).toList()`, ajouter `..servants = _maps(m['servants']).map(Servant.fromMap).toList()`. Remplacer aussi la dernière ligne `..gainedThrough = m['gainedThrough'] as String?;` par :

```dart
      ..gainedThrough = m['gainedThrough'] as String?
      .._convertServants();
```

4. Après `List<ElderPower> elderPowers = [];`, ajouter `List<Servant> servants = [];`.

5. Dans `laterKeys()`, après la ligne `'attributeBonus'`, ajouter `'servants': [for (final s in servants) s.toMap()],`.

6. Dans `toMap()`, après le bloc `attributeBonus`, ajouter :

```dart
        if (servants.isNotEmpty || storedKeys.contains('servants')) 'servants': [for (final s in servants) s.toMap()],
```

7. Avant `Character clone()`, ajouter :

```dart
  /// Fiche jouée ou close : l'historique « Serviteurs » devient un serviteur, enregistré à la prochaine écriture.
  void _convertServants() {
    if (!status.settled) return;
    final b = backgrounds.where((t) => t.name == servantsBackground).firstOrNull;
    if (b == null) return;
    backgrounds.remove(b);
    final note = (b.note ?? '').trim();
    final first = '$id-s1';
    servants.add(Servant(
      servants.any((s) => s.id == first) ? '$id-s${servants.length + 1}' : first,
      note.isEmpty ? 'Serviteur' : note,
      ServantKind.human,
      b.level.clamp(1, 5),
    ));
  }
```

**`lib/characters/describe_changes.dart` :**
- après la ligne `_names(out, 'Pouvoir d’ancien', …);`, ajouter `_servants(out, a.servants, b.servants);` ;
- avant `Map<String, int> xpDelta`, ajouter :

```dart
void _servants(List<String> out, List<Servant> a, List<Servant> b) {
  final before = {for (final s in a) s.id: s};
  final after = {for (final s in b) s.id: s};
  for (final s in b) {
    final old = before[s.id];
    if (old == null) {
      out.add('+ Serviteur ${s.name} ${dots(s.rank)}');
      continue;
    }
    if (old.name != s.name) out.add('Serviteur : ${old.name} → ${s.name}');
    if (old.kind != s.kind) out.add('Serviteur ${s.name} : ${old.kind.label} → ${s.kind.label}');
    if (old.rank != s.rank) out.add('Serviteur ${s.name} ${dots(old.rank)} → ${dots(s.rank)}');
  }
  for (final s in a) {
    if (!after.containsKey(s.id)) out.add('− Serviteur ${s.name} ${dots(s.rank)}');
  }
}
```

**`lib/places/place_rules.dart` :** la fonction `controlLimit` devient :

```dart
/// Lieux qu'un personnage peut contrôler : 5, plus 1 par point de serviteur.
int controlLimit(Character c) => 5 + c.servants.fold<int>(0, (s, x) => s + x.rank);
```

Run : `flutter test test/characters test/places`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: serviteurs sur la fiche (clé tardive, conversion de l’historique, résumé, limite des lieux)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : achat de serviteurs en XP

**Files :**
- Modify :
  - `lib/xp/xp_request.dart` ;
  - `lib/xp/xp_rules.dart` ;
  - `lib/xp/xp_corrections.dart` ;
  - `lib/xp/spend_screen.dart` ;
  - `lib/characters/character_edit_screen.dart` (options des historiques) ;
  - `test/xp/spend_screen_test.dart`.
- Test : `test/xp/servant_xp_test.dart`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `XpKind.servant('Serviteur')` ;
  - `newHumanServant` et `newAnimalServant` (valeurs de la liste « Élément ») ;
  - `servantKindOfNote(note)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 2 test`, puis `flutter test test/xp/servant_xp_test.dart`.

Expected : échec au chargement.

<!-- file: test/xp/servant_xp_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import 'xp_rules_test.dart' show err, req;

void main() {
  test('nouveau serviteur, montée dans la même demande, coût d’historique, application, annulation (Review Focus 2)', () {
    final c = sample();
    final items = <XpItem>[];
    expect(elementOptions(c, XpKind.servant), {newHumanServant: 'Nouvelle goule humaine', newAnimalServant: 'Nouvelle goule animale'});
    expect(noteSpec(XpKind.servant, newAnimalServant), ('Nom du serviteur', true));
    expect(noteSpec(XpKind.servant, 'Rex'), isNull);
    expect(err(c, XpKind.servant, newAnimalServant, note: ' '), 'Précisez le nom du serviteur.');
    final rex = draftItem(c, items, XpKind.servant, newAnimalServant, note: 'Rex');
    expect((rex.name, rex.fromLevel, rex.toLevel, rex.cost, rex.note), ('Rex', 0, 1, 2, 'Goule animale'));
    items.add(rex);
    final up = draftItem(c, items, XpKind.servant, 'Rex');
    expect((up.fromLevel, up.toLevel, up.cost, up.note), (1, 2, 4, null));
    items.add(up);
    final mila = draftItem(c, items, XpKind.servant, newHumanServant, note: 'Mila');
    items.add(mila);
    final after = applyRequest(c, items);
    expect([for (final s in after.servants) (s.name, s.kind, s.rank)], [('Rex', ServantKind.animal, 2), ('Mila', ServantKind.human, 1)]);
    expect(after.servants.first.id, isNot(after.servants.last.id));
    expect(after.xpSpent, c.xpSpent + 8);
    expect(elementOptions(after, XpKind.servant)['Rex'], 'Rex (Goule animale)');
    expect(err(after, XpKind.servant, newHumanServant, note: 'rex'), 'Un serviteur porte déjà ce nom.');
    final undo = applyCorrection(after, CorrectionKind.cancelPurchase, item: up).after!;
    expect(undo.servants.first.rank, 1);
    final gone = applyCorrection(undo, CorrectionKind.cancelPurchase, item: rex).after!;
    expect(gone.servants.map((s) => s.name), ['Mila']);
  });

  test('plafond 5, historique Serviteurs écarté, libellés, contrôle à la validation', () {
    final c = sample()..servants = [Servant('x-s1', 'Mila', ServantKind.human, 5)];
    expect(err(c, XpKind.servant, 'Mila'), 'Plafond atteint (5).');
    expect(elementOptions(c, XpKind.background).containsKey(servantsBackground), isFalse);
    expect(err(c, XpKind.background, servantsBackground), 'Les serviteurs s’achètent avec le type « Serviteur ».');
    expect(levelText(XpKind.servant, 2), '●●');
    expect(const XpItem(XpKind.servant, 'Mila', 1, 2, 4).label, 'Serviteur · Mila');
    expect(costTable(c), contains(('Serviteur', 'Nouveau niveau × 2')));
    final checks = requestChecks(c, req([const XpItem(XpKind.servant, 'Mila', 3, 4, 8)]), reservedOthers: 0);
    expect(checks.map((k) => k.text), contains(startsWith('La fiche a changé')));
  });
}
```

Dans `test/xp/spend_screen_test.dart`, avant `testWidgets('retrait par le haut seulement'`, ajouter :

```dart
  testWidgets('nouveau serviteur : nom demandé, puis montée dans la même demande (6b)', (tester) async {
    await pump(tester);
    await choose(tester, const Key('xp-kind'), 'Serviteur');
    await choose(tester, const ValueKey('xp-name-servant'), 'Nouvelle goule animale');
    await tester.enterText(find.byKey(const Key('xp-note')), 'Rex');
    await tester.pump();
    expect(find.text('— → ● · 2 XP (Nouveau niveau × 2)'), findsOneWidget);
    await tester.tap(find.text('Ajouter à la demande'));
    await tester.pumpAndSettle();
    await choose(tester, const ValueKey('xp-name-servant'), 'Rex (Goule animale)');
    expect(find.text('● → ●● · 4 XP (Nouveau niveau × 2)'), findsOneWidget);
  });

```

- [ ] **Step 2 : implémentation**

**`lib/xp/xp_request.dart` :**
- dans `enum XpKind`, la ligne `flawBuyback('Rachat d’un handicap');` devient `flawBuyback('Rachat d’un handicap'),` suivie de `servant('Serviteur');` ;
- dans `levelText`, `XpKind.skill || XpKind.background || XpKind.discipline => dots(n),` devient `XpKind.skill || XpKind.background || XpKind.discipline || XpKind.servant => dots(n),`.

**`lib/xp/xp_rules.dart` :**

1. Après `const bonusNote = 'point bonus';`, ajouter :

```dart
/// Valeurs de la liste « Élément » pour un nouveau serviteur ; le nom vient du champ de précision.
const newHumanServant = '+humain';
const newAnimalServant = '+animal';

/// Type d'un nouveau serviteur, porté par la note de l'achat ; null pour une montée de rang.
ServantKind? servantKindOfNote(String? note) => ServantKind.values.where((k) => k.label == note).firstOrNull;

Servant? _servant(Character c, String name) => c.servants.where((s) => nameKey(s.name) == nameKey(name)).firstOrNull;
```

2. `levelNow` : ajouter le cas `XpKind.servant => _servant(c, name)?.rank ?? 0,`.

3. `costOf` : `XpKind.skill || XpKind.background => i.toLevel * _row(c, rb).traitFactor,` devient `XpKind.skill || XpKind.background || XpKind.servant => i.toLevel * _row(c, rb).traitFactor,`. Faire de même dans `ruleText` pour la ligne `'Nouveau niveau × …'`.

4. `costTable` : après `('Rachat d’un handicap', '2 × sa valeur'),`, ajouter `('Serviteur', 'Nouveau niveau × ${row.traitFactor}'),`.

5. `noteSpec` : ajouter le cas :

```dart
      XpKind.servant => name == newHumanServant || name == newAnimalServant ? ('Nom du serviteur', true) : null,
```

6. `elementOptions` :
   - dans le cas `XpKind.background`, la condition `if (n != generationName)` devient `if (n != generationName && n != servantsBackground)` ;
   - ajouter le cas :

```dart
    XpKind.servant => {
        newHumanServant: 'Nouvelle goule humaine',
        newAnimalServant: 'Nouvelle goule animale',
        for (final s in c.servants) s.name: '${s.name} (${s.kind.label})',
      },
```

7. `draftItem` : au tout début de la fonction, ajouter :

```dart
  if (k == XpKind.servant && (name == newHumanServant || name == newAnimalServant)) {
    final real = (note ?? '').trim();
    final from = levelWith(c, items, k, real);
    final kind = name == newAnimalServant ? ServantKind.animal : ServantKind.human;
    final draft = XpItem(k, real, from, from + 1, 0, note: kind.label);
    return XpItem(k, real, from, from + 1, costOf(c, draft, rb: rb), note: kind.label);
  }
```

8. `itemError` :
   - juste après le contrôle de la Génération, ajouter :

```dart
  if (item.kind == XpKind.background && item.name == servantsBackground) {
    return 'Les serviteurs s’achètent avec le type « Serviteur ».';
  }
```

   - dans le `switch (item.kind)`, avant `default:`, ajouter :

```dart
    case XpKind.servant:
      if (item.name.trim().isEmpty) return 'Précisez le nom du serviteur.';
      if (servantKindOfNote(item.note) != null && item.fromLevel > 0) return 'Un serviteur porte déjà ce nom.';
      if (item.toLevel > 5) return 'Plafond atteint (5).';
```

9. `applyRequest` : avant `case XpKind.humanity:`, ajouter :

```dart
      case XpKind.servant:
        final s = _servant(n, i.name);
        if (s == null) {
          n.servants.add(Servant(newServantId(n.id), i.name, servantKindOfNote(i.note) ?? ServantKind.human, i.toLevel));
        } else {
          s.rank = i.toLevel;
        }
```

**`lib/xp/xp_corrections.dart` :** dans `_revert`, avant `case XpKind.humanity:`, ajouter :

```dart
    case XpKind.servant:
      if (i.fromLevel == 0) {
        n.servants.removeWhere((s) => s.name == i.name);
      } else {
        n.servants.firstWhere((s) => s.name == i.name).rank = i.fromLevel;
      }
```

**`lib/xp/spend_screen.dart` :** la ligne `final options = elementOptions(c, _kind, rb: rb);` devient :

```dart
    // Un serviteur ajouté à la demande peut y monter de rang.
    final options = elementOptions(_kind == XpKind.servant ? applyRequest(c, r.items, rb: rb) : c, _kind, rb: rb);
```

**`lib/characters/character_edit_screen.dart` :** dans la section `Historiques`, `options: names('backgrounds')` devient `options: [for (final n in names('backgrounds')) if (n != servantsBackground) n]`.

Run : `flutter analyze`, puis `flutter test test/xp test/characters`.

Expected : tout passe, l'analyseur est propre. Un `switch` non exhaustif sur `XpKind` est signalé par l'analyseur : il faut le compléter avec le comportement d'un historique.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: serviteurs achetés en XP (nouveau, montée, annulation)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : fiche détaillée et calculs

**Files :** Create `lib/servants/servant_file.dart`, `lib/servants/servant_rules.dart`. Test : `test/servants/servant_rules_test.dart`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `ServantFile` (`fromMap`, `toMap`, `copy`, `isMortal`) ;
  - `servantKindLabel(kind)` ;
  - `pool` ;
  - `dueDate`, `DueState`, `dueState` ;
  - `unavailableUntil` ;
  - `animalPoints` ;
  - `specialtyOptions` ;
  - `servantWarnings` ;
  - `servantChanges` ;
  - `ServantRow` et `servantRows`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 3 test`, puis `flutter test test/servants`.

Expected : échec au chargement.

<!-- file: test/servants/servant_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servant_rules.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'animalQualities': [
    RuleEntry(name: 'Costaud', data: {'cost': 1}),
    RuleEntry(name: 'Monture', data: {'cost': 3, 'requires': 'Costaud'}),
    RuleEntry(name: 'Venimeux', state: RuleState.forbidden, data: {'cost': 2}),
  ],
});

Character isaure() => sample()..servants = [Servant('x-s1', 'Rex', ServantKind.animal, 2), Servant('x-s2', 'Mila', ServantKind.human, 1)];

ServantFile rexFile() => ServantFile(
      id: 'x-s1',
      kind: 'animal',
      name: 'Rex',
      domitorId: 'x',
      domitorName: 'Isaure de Valcourt',
      holderPlayers: ['u1'],
      specialties: ['Bagarre'],
      qualities: ['Costaud'],
      vitae: 2,
      bond: 1,
      lastDrink: DateTime(2026, 9, 26),
      description: 'Garde le salon.',
      version: 1,
    );

void main() {
  test('réserve, échéance, indisponibilité, points animaux', () {
    expect(pool(3), 6);
    expect(dueDate(DateTime(2026, 9, 26)), DateTime(2026, 10, 26));
    expect(dueState(DateTime(2026, 9, 26), DateTime(2026, 10, 1)), DueState.ok);
    expect(dueState(DateTime(2026, 9, 26), DateTime(2026, 10, 20)), DueState.soon);
    expect(dueState(DateTime(2026, 9, 26), DateTime(2026, 10, 27)), DueState.late);
    expect(dueState(null, DateTime(2026, 10, 27)), isNull);
    expect(unavailableUntil(DateTime(2026, 10, 1)), DateTime(2026, 11, 12));
    expect(animalPoints(['Costaud', 'Monture', 'Inconnue'], rb), 4);
    expect(specialtyOptions(isaure(), rb), containsAll(['Médecine', 'Auspex', 'Présence']));
    expect(servantKindLabel('mortal'), 'Mortel');
  });

  test('aller-retour et copie indépendante', () {
    final f = rexFile();
    expect(ServantFile.fromMap('x-s1', f.toMap()).toMap(), f.toMap());
    f.copy().specialties.add('Furtivité');
    expect(f.specialties, ['Bagarre']);
  });

  test('avertissements', () {
    final c = isaure();
    final f = rexFile()
      ..specialties.addAll(['Domination', 'Auspex'])
      ..qualities.addAll(['Monture', 'Venimeux', 'Disparue'])
      ..qualities.remove('Costaud')
      ..lastDrink = DateTime(2026, 8, 1);
    c.status = CharacterStatus.dead;
    c.playerUid = 'u2';
    expect(servantWarnings(f, rb, entry: c.servants.first, domitor: c, now: DateTime(2026, 10, 5)), [
      '3 spécialités sur 2',
      'Domination : discipline hors du clan du domitor',
      'Qualités animales : 5 points sur 2',
      'Monture demande Costaud',
      'Venimeux est interdite dans la chronique',
      'Disparue : hors du référentiel',
      'Plus de vitae depuis le ${formatDay(DateTime(2026, 8, 1))} : son âge le rattrape',
      'Le domitor est une fiche retirée ou morte',
      'Le joueur du domitor a changé : enregistrez pour mettre à jour l’accès',
    ]);
    expect(servantWarnings(rexFile(), rb, entry: isaure().servants.first, domitor: isaure(), now: DateTime(2026, 10, 1)), isEmpty);
  });

  test('résumé des changements', () {
    final a = rexFile();
    final b = a.copy()
      ..vitae = 3
      ..bond = 2
      ..lastDrink = DateTime(2026, 10, 2)
      ..description = 'Autre'
      ..releasedAt = DateTime(2026, 10, 3);
    b.specialties
      ..remove('Bagarre')
      ..add('Furtivité');
    b.qualities.add('Monture');
    expect(servantChanges(a, b), [
      '+ Spécialité Furtivité',
      '− Spécialité Bagarre',
      '+ Qualité Monture',
      'Vitae 2 → 3',
      'Lien 1 → 2',
      'Gorgée du ${formatDay(DateTime(2026, 10, 2))}',
      'Description modifiée',
      'Libéré de la fiche du domitor',
    ]);
  });

  test('lignes de la liste : serviteurs des fiches, fiches libérées, mortels, à compléter', () {
    final c = isaure();
    final mortal = ServantFile(id: 'm1', kind: 'mortal', name: 'Jeanne', attachment: 'Voisine du refuge');
    final released = ServantFile(id: 'x-old', kind: 'human', name: 'Bruno', domitorId: 'x', releasedAt: DateTime(2026, 9, 1));
    final rows = servantRows([c], [rexFile(), mortal, released]);
    expect([for (final r in rows) (r.id, r.name, r.typeLabel, r.toComplete, r.released)], [
      ('x-s1', 'Rex', 'Goule animale', false, false),
      ('x-s2', 'Mila', 'Goule humaine', true, false),
      ('m1', 'Jeanne', 'Mortel', false, false),
      ('x-old', 'Bruno', 'Goule humaine', false, true),
    ]);
    expect(rows.first.owner, 'Isaure de Valcourt');
    expect(rows[2].owner, 'Voisine du refuge');
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 3 impl`.

<!-- file: lib/servants/servant_file.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// « Goule humaine », « Goule animale », « Mortel ».
String servantKindLabel(String kind) => switch (kind) {
      'animal' => 'Goule animale',
      'mortal' => 'Mortel',
      _ => 'Goule humaine',
    };

List<String> _names(Object? v) => [for (final e in (v as List?) ?? const []) '$e'];

/// Fiche détaillée d'un serviteur ou d'un mortel (`servants/{id}`). Mutable : l'édition travaille sur une [copy].
class ServantFile {
  ServantFile({
    required this.id,
    this.kind = 'human',
    this.name = '',
    this.domitorId,
    this.domitorName,
    this.attachment = '',
    List<String>? holderPlayers,
    List<String>? specialties,
    List<String>? qualities,
    this.vitae = 0,
    this.bond = 0,
    this.lastDrink,
    this.description = '',
    this.releasedAt,
    this.version = 0,
    this.updatedAt,
    this.updatedByName,
  })  : holderPlayers = holderPlayers ?? [],
        specialties = specialties ?? [],
        qualities = qualities ?? [];

  factory ServantFile.fromMap(String id, Map<String, dynamic> m) => ServantFile(
        id: id,
        kind: m['kind'] as String? ?? 'human',
        name: m['name'] as String? ?? '',
        domitorId: m['domitorId'] as String?,
        domitorName: m['domitorName'] as String?,
        attachment: m['attachment'] as String? ?? '',
        holderPlayers: _names(m['holderPlayers']),
        specialties: _names(m['specialties']),
        qualities: _names(m['qualities']),
        vitae: (m['vitae'] as num?)?.toInt() ?? 0,
        bond: (m['bond'] as num?)?.toInt() ?? 0,
        lastDrink: (m['lastDrink'] as Timestamp?)?.toDate(),
        description: m['description'] as String? ?? '',
        releasedAt: (m['releasedAt'] as Timestamp?)?.toDate(),
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String kind;
  String name;
  String? domitorId;
  String? domitorName;
  String attachment;

  /// Joueur du domitor : son droit de lecture (règles Firestore).
  List<String> holderPlayers;
  List<String> specialties;
  List<String> qualities;
  int vitae;
  int bond;
  DateTime? lastDrink;
  String description;
  DateTime? releasedAt;
  final int version;
  final DateTime? updatedAt;
  final String? updatedByName;

  bool get isMortal => kind == 'mortal';

  /// Clés écrites par l'application (version, historique et dates ajoutés par le dépôt).
  Map<String, dynamic> toMap() => {
        'kind': kind,
        'name': name,
        'domitorId': domitorId,
        'domitorName': domitorName,
        'attachment': attachment,
        'holderPlayers': holderPlayers,
        'specialties': specialties,
        'qualities': qualities,
        'vitae': vitae,
        'bond': bond,
        'lastDrink': lastDrink == null ? null : Timestamp.fromDate(lastDrink!),
        'description': description,
        'releasedAt': releasedAt == null ? null : Timestamp.fromDate(releasedAt!),
      };

  ServantFile copy() => ServantFile.fromMap(id, {...toMap(), 'version': version});
}
```

<!-- file: lib/servants/servant_rules.dart -->
```dart
import '../characters/character.dart';
import '../core/widgets.dart' show formatDay;
import '../rulebook/rulebook.dart';
import 'servant_file.dart';

/// Réserve de test d'un serviteur.
int pool(int rank) => 2 * rank;

/// Un mois après la dernière gorgée.
DateTime dueDate(DateTime lastDrink) => DateTime(lastDrink.year, lastDrink.month + 1, lastDrink.day);

enum DueState { ok, soon, late }

/// État de l'échéance : « proche » dans les 7 jours qui la précèdent ; null sans gorgée notée.
DueState? dueState(DateTime? lastDrink, DateTime now) {
  if (lastDrink == null) return null;
  final due = dueDate(lastDrink);
  if (now.isAfter(due)) return DueState.late;
  if (now.isAfter(DateTime(due.year, due.month, due.day - 7))) return DueState.soon;
  return DueState.ok;
}

/// Points indisponibles pour le domitor : 6 semaines après la libération.
DateTime unavailableUntil(DateTime releasedAt) =>
    DateTime(releasedAt.year, releasedAt.month, releasedAt.day + 42, releasedAt.hour, releasedAt.minute); // jours de calendrier : sans décalage à l'heure d'hiver

int animalPoints(List<String> qualities, Rulebook rb) => qualities.fold(0, (s, q) => s + (rb.cost('animalQualities', q) ?? 0));

/// Compétences proposées, plus les disciplines du clan du domitor.
List<String> specialtyOptions(Character? domitor, Rulebook rb) => {...rb.offeredNames('skills'), ...rb.clanDisciplines(domitor?.clan)}.toList();

/// Avertissements (le conte peut quand même enregistrer). [entry] : le serviteur sur la fiche du domitor.
List<String> servantWarnings(ServantFile f, Rulebook rb, {Servant? entry, Character? domitor, required DateTime now}) {
  final out = <String>[];
  final rank = entry?.rank ?? 0;
  if (!f.isMortal && f.specialties.length > rank) out.add('${f.specialties.length} spécialités sur $rank');
  final clan = rb.clanDisciplines(domitor?.clan);
  for (final s in f.specialties) {
    if (domitor != null && rb.find('disciplines', s) != null && !clan.contains(s)) out.add('$s : discipline hors du clan du domitor');
  }
  if (f.kind == 'animal') {
    final points = animalPoints(f.qualities, rb);
    if (points > rank) out.add('Qualités animales : $points points sur $rank');
    for (final q in f.qualities) {
      final e = rb.find('animalQualities', q);
      if (e == null) {
        out.add('$q : hors du référentiel');
        continue;
      }
      final requires = (e.data['requires'] as String? ?? '').trim();
      if (requires.isNotEmpty && !f.qualities.contains(requires)) out.add('$q demande $requires');
      if (!e.state.offered) out.add('$q est interdite dans la chronique');
    }
  }
  if (dueState(f.lastDrink, now) == DueState.late) out.add('Plus de vitae depuis le ${formatDay(f.lastDrink)} : son âge le rattrape');
  if (domitor != null) {
    if (domitor.status == CharacterStatus.retired || domitor.status == CharacterStatus.dead) out.add('Le domitor est une fiche retirée ou morte');
    if (f.version > 0 && domitor.playerUid != null && !f.holderPlayers.contains(domitor.playerUid)) {
      out.add('Le joueur du domitor a changé : enregistrez pour mettre à jour l’accès');
    }
  }
  return out;
}

/// Une ligne par changement, pour l'historique du serviteur.
List<String> servantChanges(ServantFile a, ServantFile b) {
  final out = <String>[];
  if (a.name != b.name) out.add('Nom : ${a.name} → ${b.name}');
  if (a.attachment != b.attachment) out.add('Rattachement : ${a.attachment} → ${b.attachment}');
  for (final s in b.specialties) {
    if (!a.specialties.contains(s)) out.add('+ Spécialité $s');
  }
  for (final s in a.specialties) {
    if (!b.specialties.contains(s)) out.add('− Spécialité $s');
  }
  for (final q in b.qualities) {
    if (!a.qualities.contains(q)) out.add('+ Qualité $q');
  }
  for (final q in a.qualities) {
    if (!b.qualities.contains(q)) out.add('− Qualité $q');
  }
  if (a.vitae != b.vitae) out.add('Vitae ${a.vitae} → ${b.vitae}');
  if (a.bond != b.bond) out.add('Lien ${a.bond} → ${b.bond}');
  if (a.lastDrink != b.lastDrink && b.lastDrink != null) out.add('Gorgée du ${formatDay(b.lastDrink)}');
  if (a.description != b.description) out.add('Description modifiée');
  if (a.releasedAt == null && b.releasedAt != null) out.add('Libéré de la fiche du domitor');
  return out;
}

/// Ligne de « Goules et mortels » : serviteur d'une fiche (avec ou sans fiche détaillée), fiche libérée ou mortel.
class ServantRow {
  const ServantRow({this.entry, this.domitor, this.file});
  final Servant? entry;
  final Character? domitor;
  final ServantFile? file;

  String get id => entry?.id ?? file?.id ?? '';
  String get name => entry?.name ?? file?.name ?? '';
  String get kind => entry?.kind.name ?? file?.kind ?? 'mortal';
  String get typeLabel => servantKindLabel(kind);
  int get rank => entry?.rank ?? 0;

  /// Nouveau mortel, pas encore enregistré.
  bool get isNew => entry == null && file == null;

  /// Acheté, pas encore détaillé par le conte.
  bool get toComplete => entry != null && file == null;

  /// Fiche détaillée d'un serviteur qui n'est plus sur la fiche de son domitor.
  bool get released => entry == null && file != null && !file!.isMortal;

  /// Domitor, ou rattachement d'un mortel.
  String get owner => domitor?.name ?? file?.domitorName ?? file?.attachment ?? '';
}

List<ServantRow> servantRows(List<Character> characters, List<ServantFile> files) {
  final byId = {for (final f in files) f.id: f};
  final listed = <String>{};
  final rows = <ServantRow>[];
  for (final c in characters) {
    for (final s in c.servants) {
      listed.add(s.id);
      rows.add(ServantRow(entry: s, domitor: c, file: byId[s.id]));
    }
  }
  final rest = [for (final f in files) if (!listed.contains(f.id)) f]..sort((a, b) => (a.isMortal ? 0 : 1).compareTo(b.isMortal ? 0 : 1));
  for (final f in rest) {
    rows.add(ServantRow(domitor: characters.where((c) => c.id == f.domitorId).firstOrNull, file: f));
  }
  return rows;
}
```

Run : `flutter test test/servants`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib/servants test/servants
git commit -m "feat: serviteurs — fiche détaillée et calculs (échéance, avertissements, historique, lignes)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : règles Firestore, dépôt, providers, fake

**Files :**
- Modify : `firestore.rules`, `test/fakes.dart`.
- Create : `lib/servants/servants_repository.dart`, `rules_test/servants.test.js`.

**Interfaces :**
- Consumes : la tâche 3, `firestoreProvider`, `currentUserProvider`, `Actor`, `PlaceEntry` (lieux).
- Produces :
  - `ServantsRepository` : `watchAll`, `watchForDomitor(id)`, `watchForPlayer(uid)`, `watchNote(id)`, `watchHistory(id)`, `save(before, file, by, {note, noteBefore, reason})` qui renvoie l'id, `release(id, by)` et `delete(id)` ;
  - les providers `servantsRepositoryProvider`, `allServantFilesProvider`, `characterServantFilesProvider(characterId)`, `servantNoteProvider(id)` et `servantHistoryProvider(id)` ;
  - `FakeServantsRepository` (`calls`, `lastSaved`, `lastBefore`, `lastNote`, `lastReason`, `error`) et `noServantFiles` (override pour 'x').

- [ ] **Step 1 : tests des règles (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 4 test`, puis les tests des règles.

Expected : les tests de `servants.test.js` échouent ; les autres passent.

<!-- file: rules_test/servants.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, deleteDoc, writeBatch, serverTimestamp, collection, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const file = (over) => ({
  kind: 'animal', name: 'Rex', domitorId: 'c1', domitorName: 'Isaure', attachment: '', holderPlayers: ['zoe'],
  specialties: [], qualities: [], vitae: 2, bond: 1, lastDrink: null, description: '', releasedAt: null,
  version: 1, lastHistoryId: 'h1', ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'servants/s1'), file({}));
    await setDoc(doc(db, 'servants/s1/private/note'), { text: 'Secret' });
    await setDoc(doc(db, 'servants/s1/history/h1'), { at: new Date(), byUid: 'lea', byName: 'lea', summary: ['Fiche créée'], reason: '' });
    await setDoc(doc(db, 'servants/m1'), file({ kind: 'mortal', name: 'Jeanne', domitorId: null, holderPlayers: [] }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/// Fiche et son entrée d'historique dans un même lot.
function saved(uid, id, data, { history = true } = {}) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `servants/${id}`), { ...data, lastHistoryId: 'hx' });
  if (history) b.set(doc(db, `servants/${id}/history/hx`), { at: serverTimestamp(), byUid: uid, byName: uid, summary: [], reason: '' });
  return b.commit();
}

test('lecture : joueur du domitor, équipe ; ni les autres, ni la note, ni un mortel (Review Focus 3)', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'servants/s1')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'servants'), where('holderPlayers', 'array-contains', 'zoe'))));
  await assertFails(getDoc(doc(as('max'), 'servants/s1')));
  await assertFails(getDoc(doc(as('zoe'), 'servants/m1')));
  await assertFails(getDoc(doc(as('zoe'), 'servants/s1/private/note')));
  await assertFails(getDoc(doc(as('zoe'), 'servants/s1/history/h1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'servants/m1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'servants/s1/private/note')));
});

test('modification : conte seulement, version + 1 et historique dans le même lot (Review Focus 4)', async () => {
  await assertFails(saved('lea', 's1', file({ version: 2 }), { history: false }));
  await assertFails(saved('lea', 's1', file({ version: 3 })));
  await assertFails(saved('julien', 's1', file({ version: 2 })));
  await assertFails(saved('zoe', 's1', file({ version: 2 })));
  await assertSucceeds(saved('lea', 's1', file({ version: 2, vitae: 3 })));
});

test('fiche invalide refusée, création valide, suppression par le conte', async () => {
  await assertFails(saved('lea', 's9', file({ vitae: 6 })));
  await assertFails(saved('lea', 's9', file({ bond: 4 })));
  await assertFails(saved('lea', 's9', file({ kind: 'dragon' })));
  await assertFails(saved('lea', 's9', file({ name: '' })));
  await assertFails(saved('lea', 's9', file({ version: 2 })));
  await assertSucceeds(saved('lea', 's9', file({})));
  await assertFails(deleteDoc(doc(as('julien'), 'servants/s9')));
  await assertFails(deleteDoc(doc(as('julien'), 'servants/s1/history/h1')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'servants/s1/history/h1')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'servants/s9')));
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules`, juste avant `match /invitations/{email} {`, ajouter :

```
    // Serviteurs et mortels (sous-projet 6b) : lus par l'équipe et le joueur du domitor.
    function servantValid() {
      let d = request.resource.data;
      return d.kind in ['human', 'animal', 'mortal']
        && d.name is string && d.name.size() > 0 && d.name.size() <= 80
        && d.vitae is int && d.vitae >= 0 && d.vitae <= 5
        && d.bond is int && d.bond >= 0 && d.bond <= 3
        && d.specialties is list && d.qualities is list && d.holderPlayers is list;
    }
    function servantHistoryOk(id) {
      let h = getAfter(/databases/$(database)/documents/servants/$(id)/history/$(request.resource.data.lastHistoryId)).data;
      return h.byUid == request.auth.uid && h.at == request.time;
    }

    match /servants/{id} {
      allow read: if isStaff() || (signedIn() && request.auth.uid in resource.data.holderPlayers);
      allow create: if managesAccounts() && servantValid() && request.resource.data.version == 1 && servantHistoryOk(id);
      allow update: if managesAccounts() && servantValid()
        && request.resource.data.version == resource.data.version + 1 && servantHistoryOk(id);
      allow delete: if managesAccounts();

      match /private/{doc} {
        allow read: if isStaff();
        allow write: if managesAccounts();
      }

      match /history/{h} {
        allow read: if isStaff();
        allow create: if managesAccounts()
          && request.resource.data.byUid == request.auth.uid
          && request.resource.data.at == request.time
          && getAfter(/databases/$(database)/documents/servants/$(id)).data.lastHistoryId == h;
        allow delete: if managesAccounts();
      }
    }

```

Run : les tests des règles.

Expected : `fail 0`.

- [ ] **Step 3 : dépôt, providers, fake**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 4 impl`.

<!-- file: lib/servants/servants_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../places/place.dart' show PlaceEntry;
import 'servant_file.dart';
import 'servant_rules.dart';

part 'servants_repository.g.dart';

/// `servants/{id}` : fiches détaillées des serviteurs et des mortels, avec note secrète et historique.
class ServantsRepository {
  ServantsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('servants');

  List<ServantFile> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) ServantFile.fromMap(d.id, d.data())]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Équipe : toutes les fiches.
  Stream<List<ServantFile>> watchAll() => _col.snapshots().map(_sorted);

  /// Équipe : les serviteurs d'un personnage.
  Stream<List<ServantFile>> watchForDomitor(String characterId) => _col.where('domitorId', isEqualTo: characterId).snapshots().map(_sorted);

  /// Joueur : les serviteurs de ses personnages (requête permise par les règles).
  Stream<List<ServantFile>> watchForPlayer(String uid) => _col.where('holderPlayers', arrayContains: uid).snapshots().map(_sorted);

  Stream<String> watchNote(String id) =>
      _col.doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Stream<List<PlaceEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) PlaceEntry.fromMap(d.data())]);

  /// Crée ([before] en version 0) ou modifie [f] dans un lot : fiche (version + 1), historique, note. Renvoie l'id.
  /// Un mortel neuf a un id vide : Firestore en génère un.
  Future<String> save(ServantFile before, ServantFile f, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    final creating = before.version == 0;
    final ref = f.id.isEmpty ? _col.doc() : _col.doc(f.id);
    final h = ref.collection('history').doc();
    final now = FieldValue.serverTimestamp();
    final noteChanged = note != null && note.trim() != noteBefore.trim();
    final summary = creating ? ['Fiche créée'] : [...servantChanges(before, f), if (noteChanged) 'Note secrète modifiée'];
    final batch = _db.batch()
      ..set(
        ref,
        {
          ...f.toMap(),
          'version': creating ? 1 : before.version + 1,
          'lastHistoryId': h.id,
          'updatedAt': now,
          'updatedByName': by.name,
          if (creating) 'createdAt': now,
        },
        SetOptions(merge: !creating), // fusion : garde createdAt ; toutes les autres clés sont réécrites
      )
      ..set(h, {
        'at': now,
        'byUid': by.uid,
        'byName': by.name,
        'summary': summary.isEmpty ? ['Enregistré sans changement'] : summary,
        'reason': reason.trim(),
      });
    if (note != null && noteChanged) batch.set(ref.collection('private').doc('note'), {'text': note.trim()});
    await batch.commit();
    return ref.id;
  }

  /// Serviteur retiré de la fiche de son domitor : la fiche détaillée, si elle existe, est marquée libérée.
  Future<void> release(String id, Actor by) async {
    final d = await _col.doc(id).get();
    final data = d.data();
    if (data == null || data['releasedAt'] != null) return;
    final before = ServantFile.fromMap(id, data);
    await save(before, before.copy()..releasedAt = DateTime.now(), by, reason: 'Retiré de la fiche du domitor');
  }

  /// Supprime la fiche, sa note et son historique.
  Future<void> delete(String id) async {
    // ponytail: un seul lot, limité à 500 écritures ; découper si une fiche a plus de 498 entrées d'historique.
    final history = await _col.doc(id).collection('history').get();
    final batch = _db.batch()
      ..delete(_col.doc(id).collection('private').doc('note'))
      ..delete(_col.doc(id));
    for (final d in history.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}

@Riverpod(keepAlive: true)
ServantsRepository servantsRepository(Ref ref) => ServantsRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<ServantFile>> allServantFiles(Ref ref) => ref.watch(servantsRepositoryProvider).watchAll();

/// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.
@riverpod
Stream<List<ServantFile>> characterServantFiles(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const Stream.empty();
  final repo = ref.watch(servantsRepositoryProvider);
  if (me.role.isStaff) return repo.watchForDomitor(characterId);
  return repo.watchForPlayer(me.uid).map((l) => [for (final f in l) if (f.domitorId == characterId) f]);
}

@riverpod
Stream<String> servantNote(Ref ref, String id) => ref.watch(servantsRepositoryProvider).watchNote(id);

@riverpod
Stream<List<PlaceEntry>> servantHistory(Ref ref, String id) => ref.watch(servantsRepositoryProvider).watchHistory(id);
```

Dans `test/fakes.dart` :
- ajouter les imports `package:portail_met/servants/servant_file.dart` et `package:portail_met/servants/servants_repository.dart`, dans l'ordre alphabétique ;
- ajouter à la fin :

```dart
class FakeServantsRepository implements ServantsRepository {
  final calls = <String>[];
  ServantFile? lastSaved;
  ServantFile? lastBefore;
  String? lastNote;
  String? lastReason;
  Object? error;

  @override
  Stream<String> watchNote(String id) => Stream.value('');

  @override
  Stream<List<PlaceEntry>> watchHistory(String id) => Stream.value(const []);

  @override
  Future<String> save(ServantFile before, ServantFile f, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    calls.add('save:${f.name}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = f;
    lastNote = note;
    lastReason = reason;
    return f.id.isEmpty ? 'new-servant' : f.id;
  }

  @override
  Future<void> release(String id, Actor by) async => calls.add('release:$id');

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucune fiche détaillée de serviteur pour la fiche 'x'.
final noServantFiles = characterServantFilesProvider('x').overrideWith((ref) => Stream.value(const <ServantFile>[]));
```

`PlaceEntry` vient de `package:portail_met/places/place.dart`, déjà importé.

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add firestore.rules rules_test/servants.test.js lib/servants test/fakes.dart
git commit -m "feat: serviteurs — règles Firestore, dépôt et providers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : écran du conte « Goules et mortels »

**Files :**
- Create : `lib/servants/servants_screen.dart`.
- Modify : `lib/router.dart`, `lib/characters/characters_list_screen.dart`.
- Test : `test/servants/servants_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1, 3 et 4, `allCharactersProvider`, `rulebookProvider`, `actorOf`.
- Produces : `ServantsScreen` (`/conteur/goules`), avec les clés :
  - liste et filtres : `sv-new-mortal`, `sv-search` ;
  - champs : `sv-name`, `sv-attachment`, `sv-add-specialty`, `sv-add-quality`, `sv-vitae`, `sv-bond`, `sv-description`, `sv-note`, `sv-reason` ;
  - boutons : `sv-drink`, `sv-save`, `sv-delete`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 5 test`, puis `flutter test test/servants/servants_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/servants/servants_screen_test.dart -->
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servants_repository.dart';
import 'package:portail_met/servants/servants_screen.dart';

import '../fakes.dart';
import 'servant_rules_test.dart' show isaure, rb, rexFile;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Future<FakeServantsRepository> pump(WidgetTester tester, {AppUser user = lea, List<ServantFile>? files, Stream<List<ServantFile>>? stream}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeServantsRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        servantsRepositoryProvider.overrideWith((ref) => repo),
        allServantFilesProvider.overrideWith((ref) => stream ?? Stream.value(files ?? [rexFile()])),
        allCharactersProvider.overrideWith((ref) => Stream.value([isaure()])),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ServantsScreen())),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('liste : serviteurs des fiches, à compléter, recherche', (tester) async {
    await pump(tester);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mila'), findsOneWidget);
    expect(find.text('À compléter'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sv-search')), 'rex');
    await tester.pump();
    expect(find.text('Mila'), findsNothing);
  });

  testWidgets('compléter un serviteur : spécialité, gorgée, accès du joueur du domitor', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Mila'));
    await tester.pumpAndSettle();
    expect(find.text('Réserve 2 · santé 1 · pas de Volonté'), findsOneWidget);
    await choose(tester, 'sv-add-specialty', 'Médecine');
    await tester.tap(find.byKey(const Key('sv-drink')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    final f = repo.lastSaved!;
    expect((f.id, f.kind, f.name, f.domitorId, f.holderPlayers, f.specialties, f.vitae), ('x-s2', 'human', 'Mila', 'x', ['u1'], ['Médecine'], 1));
    expect(f.lastDrink, isNotNull);
    expect(repo.lastBefore!.version, 0, reason: 'première fiche détaillée : création');
  });

  testWidgets('goule animale : qualités et avertissement de points', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    await choose(tester, 'sv-add-quality', 'Monture (3)');
    expect(find.text('Qualités animales : 4 points sur 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.qualities, ['Costaud', 'Monture']);
  });

  testWidgets('modifié par un autre conteur pendant l’édition : base figée, message (Review Focus 4)', (tester) async {
    final files = StreamController<List<ServantFile>>();
    addTearDown(files.close);
    files.add([rexFile()]);
    final repo = await pump(tester, stream: files.stream);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    files.add([ServantFile.fromMap('x-s1', {...rexFile().toMap(), 'version': 2})]);
    await tester.pumpAndSettle();
    repo.error = Exception('version');
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    expect(repo.lastBefore!.version, 1);
    expect(find.text('Modifié entre-temps : rechargez la page.'), findsOneWidget);
  });

  testWidgets('nouveau mortel, puis suppression', (tester) async {
    final repo = await pump(tester, files: [ServantFile(id: 'm1', kind: 'mortal', name: 'Jeanne', attachment: 'Voisine', version: 1)]);
    await tester.tap(find.byKey(const Key('sv-new-mortal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sv-name')), 'Paul');
    await tester.enterText(find.byKey(const Key('sv-attachment')), 'Indic de la police');
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.kind, repo.lastSaved!.name, repo.lastSaved!.holderPlayers), ('mortal', 'Paul', <String>[]));
    await tester.tap(find.text('Jeanne'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sv-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:m1');
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('sv-new-mortal')), findsNothing);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sv-save')), findsNothing);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 5 impl`.

<!-- file: lib/servants/servants_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'servant_file.dart';
import 'servant_rules.dart';
import 'servants_repository.dart';

/// « Goules et mortels » (C-Goules, C-Animaux) : serviteurs des fiches, fiches libérées, mortels.
class ServantsScreen extends ConsumerStatefulWidget {
  const ServantsScreen({super.key});

  @override
  ConsumerState<ServantsScreen> createState() => _ServantsScreenState();
}

class _ServantsScreenState extends ConsumerState<ServantsScreen> {
  /// Ligne ouverte : id, '' pour un nouveau mortel, null pour aucune.
  String? _selectedId;
  int _version = 0;
  String _filter = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(String? id) => setState(() {
        _selectedId = id;
        _version++;
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final rb = ref.watch(rulebookProvider);
    if (me == null || rb == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les serviteurs sont gérés par le conte.');
    }
    return asyncView(
      ref.watch(allServantFilesProvider),
      (files) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, !me.role.managesAccounts, rb, servantRows(chars, files)),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allServantFilesProvider),
    );
  }

  Widget _body(BuildContext context, bool readOnly, Rulebook rb, List<ServantRow> rows) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final r in rows)
        if (switch (_filter) {
              'late' => dueState(r.file?.lastDrink, now) == DueState.late,
              'toComplete' => r.toComplete,
              'mortal' => r.kind == 'mortal',
              _ => true,
            } &&
            (q.isEmpty || r.name.toLowerCase().contains(q) || r.owner.toLowerCase().contains(q)))
          r,
    ];
    final ServantRow? selected = switch (_selectedId) {
      null => null,
      '' => const ServantRow(),
      final id => rows.where((r) => r.id == id).firstOrNull,
    };

    String due(ServantRow r) {
      if (r.toComplete) return 'À compléter';
      if (r.released) return 'Libéré le ${formatDay(r.file!.releasedAt)}';
      final last = r.file?.lastDrink;
      return last == null ? '—' : formatDay(dueDate(last));
    }

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        'Goules et mortels',
        subtitle: 'Serviteurs achetés par les personnages, goules animales, et mortels suivis par le conte.',
        action: readOnly ? null : FilledButton(key: const Key('sv-new-mortal'), onPressed: () => _open(''), child: const Text('+ Nouveau mortel')),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        DropdownButton<String>(
          value: _filter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous')),
            DropdownMenuItem(value: 'late', child: Text('Échéance dépassée')),
            DropdownMenuItem(value: 'toComplete', child: Text('À compléter')),
            DropdownMenuItem(value: 'mortal', child: Text('Mortels')),
          ],
          onChanged: (v) => setState(() => _filter = v ?? 'all'),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('sv-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Nom, domitor…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucune fiche.', style: t.bodyMedium)),
          for (final r in shown)
            InkWell(
              onTap: () => _open(r.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: r.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 200, child: Text(r.name, style: t.titleSmall)),
                  SizedBox(width: 120, child: Text(r.typeLabel, style: t.bodySmall)),
                  SizedBox(width: 200, child: Text(r.owner, style: t.bodySmall)),
                  SizedBox(width: 70, child: Text(r.rank == 0 ? '—' : dots(r.rank), style: const TextStyle(color: AppColors.gold, letterSpacing: 2))),
                  SizedBox(width: 60, child: Text(r.file == null || r.kind == 'mortal' ? '—' : '${r.file!.vitae} / 5', style: t.bodySmall)),
                  Text(due(r), style: t.bodySmall?.copyWith(color: dueState(r.file?.lastDrink, now) == DueState.late ? AppColors.linkHover : null)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(
        'Serviteur de rang N : N spécialités, réserve 2 × N, N niveaux de santé, pas de Volonté. '
        'Goule animale : N points de qualités animales en plus. Sans vitae pendant un mois, son âge le rattrape.',
        style: t.bodySmall,
      ),
    ]);

    Widget? editor;
    if (selected != null) {
      editor = Panel(
        child: _ServantEditor(
          key: ValueKey('${selected.id}/$_version'),
          row: selected,
          rb: rb,
          readOnly: readOnly,
          onSaved: _open,
          onDeleted: () => setState(() => _selectedId = null),
        ),
      );
    }

    if (!isWide(context)) {
      if (editor != null) {
        return PageBody(children: [
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _open(null), child: const Text('← Retour à la liste'))),
          editor,
        ]);
      }
      return PageBody(children: [list]);
    }
    return PageBody(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: list),
        if (editor != null) ...[const SizedBox(width: 24), SizedBox(width: 440, child: editor)],
      ]),
    ]);
  }
}

class _ServantEditor extends ConsumerStatefulWidget {
  const _ServantEditor({
    super.key,
    required this.row,
    required this.rb,
    required this.readOnly,
    required this.onSaved,
    required this.onDeleted,
  });

  final ServantRow row;
  final Rulebook rb;
  final bool readOnly;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ServantEditor> createState() => _ServantEditorState();
}

class _ServantEditorState extends ConsumerState<_ServantEditor> {
  /// Version ouverte : base de l'enregistrement (le flux peut apporter une version plus récente entre-temps).
  late final ServantFile _base;
  late final ServantFile _d;
  late final TextEditingController _name;
  late final TextEditingController _attachment;
  late final TextEditingController _description;
  final _note = TextEditingController();
  final _reason = TextEditingController();
  String _noteBefore = '';
  bool _noteLoaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _base = r.file ?? ServantFile(id: r.id, kind: r.kind);
    _d = _base.copy();
    _name = TextEditingController(text: _d.name);
    _attachment = TextEditingController(text: _d.attachment);
    _description = TextEditingController(text: _d.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _attachment.dispose();
    _description.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final r = widget.row;
    final entry = r.entry;
    final domitor = r.domitor;
    if (entry != null && domitor != null) {
      // Nom, type et domitor suivent la fiche du personnage ; l'accès suit son joueur.
      _d
        ..name = entry.name
        ..kind = entry.kind.name
        ..domitorId = domitor.id
        ..domitorName = domitor.name
        ..holderPlayers = [?domitor.playerUid];
    } else if (_d.isMortal) {
      _d
        ..name = _name.text.trim()
        ..attachment = _attachment.text.trim();
    }
    _d.description = _description.text.trim();
    if (_d.name.isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref
          .read(servantsRepositoryProvider)
          .save(_base, _d, by, note: _note.text, noteBefore: _noteBefore, reason: _reason.text);
      messenger.showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      widget.onSaved(id);
    } catch (_) {
      final latest = ref.read(allServantFilesProvider).value?.where((f) => f.id == _base.id).firstOrNull;
      final moved = latest != null && latest.version != _base.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = widget.rb;
    final ro = widget.readOnly;
    final r = widget.row;
    if (_base.version > 0 && !_noteLoaded) {
      final note = ref.watch(servantNoteProvider(_base.id));
      // Sans la note, enregistrer l'effacerait : pas de formulaire tant qu'elle n'est pas lue.
      if (note.hasError) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Note secrète illisible.'),
          TextButton(onPressed: () => ref.invalidate(servantNoteProvider(_base.id)), child: const Text('Réessayer')),
        ]);
      }
      if (!note.hasValue) return const Center(child: CircularProgressIndicator());
      _noteBefore = note.value!;
      _note.text = _noteBefore;
      _noteLoaded = true;
    }
    final mortal = _d.isMortal;
    final animal = _d.kind == 'animal';
    final rank = r.rank;
    final warnings = servantWarnings(_d, rb, entry: r.entry, domitor: r.domitor, now: DateTime.now());
    final specialtyChoices = [for (final s in specialtyOptions(r.domitor, rb)) if (!_d.specialties.contains(s)) s];
    final qualityChoices = [for (final e in rb.offered('animalQualities')) if (!_d.qualities.contains(e.name)) e];
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(r.isNew ? 'Nouveau mortel' : (mortal ? 'Fiche du mortel' : 'Fiche du serviteur')),
      const SizedBox(height: 12),
      if (mortal) ...[
        gap(TextField(key: const Key('sv-name'), controller: _name, enabled: !ro, maxLength: 80, decoration: const InputDecoration(labelText: 'Nom'))),
        gap(TextField(
          key: const Key('sv-attachment'),
          controller: _attachment,
          enabled: !ro,
          decoration: const InputDecoration(labelText: 'Rattachement (lieu, personnage, groupe)'),
        )),
      ] else ...[
        Text(r.name, style: t.headlineSmall),
        Text('${r.typeLabel} · ${rank == 0 ? 'rang inconnu' : 'rang $rank'} · ${r.owner}', style: t.bodyMedium),
        if (rank > 0) Text('Réserve ${pool(rank)} · santé $rank · pas de Volonté', style: t.bodySmall),
        if (r.released) Text('Libéré le ${formatDay(_d.releasedAt)}', style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        const SizedBox(height: 12),
        Text('Spécialités', style: t.labelMedium),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (_d.specialties.isEmpty) Text('Aucune.', style: t.bodySmall),
          for (final s in _d.specialties) InputChip(label: Text(s), onDeleted: ro ? null : () => setState(() => _d.specialties.remove(s))),
        ]),
        const SizedBox(height: 8),
        if (!ro)
          gap(KeyedSubtree(
            key: ValueKey('specialties-${_d.specialties.length}'),
            child: DropdownButtonFormField<String>(
              key: const Key('sv-add-specialty'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: '+ Ajouter une compétence ou une discipline'),
              items: [for (final s in specialtyChoices) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (s) {
                if (s != null) setState(() => _d.specialties.add(s));
              },
            ),
          )),
        if (animal) ...[
          Row(children: [
            Expanded(child: Text('Qualités animales', style: t.labelMedium)),
            Text('${animalPoints(_d.qualities, rb)} points sur $rank', style: t.bodySmall),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in _d.qualities) InputChip(label: Text(q), onDeleted: ro ? null : () => setState(() => _d.qualities.remove(q))),
          ]),
          const SizedBox(height: 8),
          if (!ro)
            gap(KeyedSubtree(
              key: ValueKey('qualities-${_d.qualities.length}'),
              child: DropdownButtonFormField<String>(
                key: const Key('sv-add-quality'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: '+ Ajouter une qualité animale'),
                items: [
                  for (final e in qualityChoices) DropdownMenuItem(value: e.name, child: Text('${e.name} (${rb.cost('animalQualities', e.name) ?? 0})')),
                ],
                onChanged: (q) {
                  if (q != null) setState(() => _d.qualities.add(q));
                },
              ),
            )),
        ],
        gap(Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('sv-vitae'),
              isExpanded: true,
              initialValue: _d.vitae.clamp(0, 5),
              decoration: const InputDecoration(labelText: 'Vitae (sur 5)'),
              items: [for (var v = 0; v <= 5; v++) DropdownMenuItem(value: v, child: Text('$v'))],
              onChanged: ro ? null : (v) => setState(() => _d.vitae = v ?? _d.vitae),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('sv-bond'),
              isExpanded: true,
              initialValue: _d.bond.clamp(0, 3),
              decoration: const InputDecoration(labelText: 'Lien de sang'),
              items: [for (var v = 0; v <= 3; v++) DropdownMenuItem(value: v, child: Text(v == 0 ? 'Aucun' : dots(v)))],
              onChanged: ro ? null : (v) => setState(() => _d.bond = v ?? _d.bond),
            ),
          ),
        ])),
        Row(children: [
          Expanded(
            child: Text(
              _d.lastDrink == null
                  ? 'Aucune gorgée notée'
                  : 'Dernière gorgée : ${formatDay(_d.lastDrink)} · échéance ${formatDay(dueDate(_d.lastDrink!))}',
              style: t.bodyMedium,
            ),
          ),
          if (!ro)
            OutlinedButton(
              key: const Key('sv-drink'),
              onPressed: () => setState(() {
                _d.lastDrink = DateTime.now();
                _d.vitae = (_d.vitae + 1).clamp(0, 5);
              }),
              child: const Text('+ Gorgée'),
            ),
        ]),
        const SizedBox(height: 12),
      ],
      gap(TextField(
        key: const Key('sv-description'),
        controller: _description,
        enabled: !ro,
        maxLines: 3,
        decoration: InputDecoration(labelText: mortal ? 'Description' : 'Description et consignes (lue par le joueur)'),
      )),
      gap(TextField(
        key: const Key('sv-note'),
        controller: _note,
        enabled: !ro,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note secrète du conte'),
      )),
      for (final w in warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      if (!ro) ...[
        const SizedBox(height: 8),
        gap(TextField(key: const Key('sv-reason'), controller: _reason, decoration: const InputDecoration(labelText: 'Motif (facultatif)'))),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(key: const Key('sv-save'), onPressed: _busy ? null : _save, child: const Text('Enregistrer')),
          if (mortal && _base.version > 0)
            TextButton(
              key: const Key('sv-delete'),
              onPressed: _busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (!await _confirm('Supprimer « ${_d.name} » ?', 'Cette suppression est définitive.', 'Supprimer')) return;
                      setState(() => _busy = true);
                      try {
                        await ref.read(servantsRepositoryProvider).delete(_base.id);
                        widget.onDeleted();
                      } catch (_) {
                        messenger.showSnackBar(const SnackBar(content: Text('Suppression refusée : réessayez.')));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Supprimer'),
            ),
        ]),
      ],
      if (_base.version > 0) ...[
        const SizedBox(height: 16),
        const SectionTitle('Historique'),
        const SizedBox(height: 8),
        asyncView(ref.watch(servantHistoryProvider(_base.id)), (entries) {
          if (entries.isEmpty) return Text('Aucune entrée.', style: t.bodySmall);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${formatDay(e.at)} · ${e.byName}', style: t.bodySmall),
                  for (final s in e.summary) Text(s, style: t.bodyMedium),
                  if (e.reason.isNotEmpty) Text('Motif : ${e.reason}', style: t.bodySmall),
                ]),
              ),
          ]);
        }),
      ],
    ]);
  }
}
```

**`lib/router.dart` :**
- ajouter l'import `servants/servants_screen.dart`, à sa place alphabétique (après `rulebook/referential_screen.dart`) ;
- après `page('/conteur/lieux', const PlacesScreen()),`, ajouter `page('/conteur/goules', const ServantsScreen()),`.

**`lib/characters/characters_list_screen.dart` :** dans le `Wrap` de l'`action` du `PageTitle`, après le bouton « Lieux d'intérêt », ajouter :

```dart
            OutlinedButton(onPressed: () => context.go('/conteur/goules'), child: const Text('Goules et mortels')),
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/servants
git commit -m "feat: serviteurs — écran du conte « Goules et mortels »" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : C3, section « Serviteurs » des fiches, écran du joueur

**Files :**
- Create : `lib/servants/servants_section.dart`.
- Modify :
  - `lib/characters/edit_widgets.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `lib/characters/character_screen.dart` ;
  - `lib/router.dart`.
- Tests :
  - `test/servants/servants_section_test.dart` (nouveau) ;
  - `test/characters/character_screen_test.dart`, `test/characters/character_edit_test.dart` et `test/characters/edit_fixes_test.dart` (ajout de `noServantFiles`).

**Interfaces :**
- Consumes : les tâches 1, 3 et 4.
- Produces :
  - `ServantListEditor(characterId, items, onChanged)` ;
  - `ServantsSection(character, linkOf)` ;
  - `ServantScreen(characterId, servantId)` sur `/joueur/personnages/:id/serviteurs/:sid` ;
  - la libération dans C3.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 6 test`, puis `flutter test test/servants/servants_section_test.dart`.

Expected : échec au chargement.

<!-- file: test/servants/servants_section_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/edit_widgets.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servant_rules.dart';
import 'package:portail_met/servants/servants_repository.dart';
import 'package:portail_met/servants/servants_section.dart';

import 'servant_rules_test.dart' show isaure, rexFile;

void main() {
  final released = ServantFile(id: 'x-old', kind: 'human', name: 'Bruno', domitorId: 'x', releasedAt: DateTime.now(), version: 2);

  Widget app(Widget child) => ProviderScope(
        overrides: [
          characterProvider('x').overrideWith((ref) => Stream.value(isaure())),
          characterServantFilesProvider('x').overrideWith((ref) => Stream.value([rexFile(), released])),
        ],
        child: MaterialApp.router(
          theme: buildTheme(withFonts: false),
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child))),
            GoRoute(path: '/s/:sid', builder: (_, s) => Text('serviteur ${s.pathParameters['sid']}')),
          ]),
        ),
      );

  testWidgets('section : serviteurs, à compléter, points indisponibles, lien (Review Focus 5)', (tester) async {
    await tester.pumpWidget(app(ServantsSection(character: isaure(), linkOf: (id) => '/s/$id')));
    await tester.pumpAndSettle();
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mila'), findsOneWidget);
    expect(find.text('à compléter'), findsOneWidget);
    expect(find.text('Bruno : points indisponibles jusqu’au ${formatDay(unavailableUntil(released.releasedAt!))}'), findsOneWidget);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    expect(find.text('serviteur x-s1'), findsOneWidget);
  });

  testWidgets('fiche du joueur : détail sans note secrète', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const ServantScreen(characterId: 'x', servantId: 'x-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Rex'), findsWidgets);
    expect(find.text('Réserve 4 · santé 2 · pas de Volonté'), findsOneWidget);
    expect(find.text('Spécialités : Bagarre'), findsOneWidget);
    expect(find.text('Qualités animales : Costaud'), findsOneWidget);
    expect(find.text('Garde le salon.'), findsOneWidget);
    expect(find.textContaining('Note secrète'), findsNothing);
  });

  testWidgets('C3 : ajouter, renommer, retirer un serviteur', (tester) async {
    final items = <Servant>[Servant('x-s1', 'Rex', ServantKind.animal, 2)];
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: ServantListEditor(characterId: 'x', items: items, onChanged: () => setState(() => changes++)),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('+ Serviteur'));
    await tester.pump();
    expect(items, hasLength(2));
    expect(items.last.id, startsWith('x-s'));
    await tester.enterText(find.byKey(ValueKey('servant-name-${items.last.id}')), 'Mila');
    await tester.pump();
    expect(items.last.name, 'Mila');
    await tester.tap(find.byTooltip('Retirer Rex'));
    await tester.pump();
    expect(items.map((s) => s.name), ['Mila']);
    expect(changes, greaterThanOrEqualTo(3));
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-06-serviteurs.md 6 impl`.

<!-- file: lib/servants/servants_section.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'servant_file.dart';
import 'servant_rules.dart';
import 'servants_repository.dart';

/// Section « Serviteurs » d'une fiche (J2, C3) : serviteurs, échéances, points indisponibles.
class ServantsSection extends ConsumerWidget {
  const ServantsSection({super.key, required this.character, required this.linkOf});
  final Character character;

  /// Lien vers la fiche d'un serviteur, selon l'écran.
  final String Function(String servantId) linkOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final files = ref.watch(characterServantFilesProvider(character.id)).value ?? const <ServantFile>[];
    final byId = {for (final f in files) f.id: f};
    final now = DateTime.now();
    final ids = {for (final s in character.servants) s.id};
    final released = [
      for (final f in files)
        if (!ids.contains(f.id) && f.releasedAt != null && now.isBefore(unavailableUntil(f.releasedAt!))) f,
    ];
    String status(Servant s) {
      final f = byId[s.id];
      if (f == null) return 'à compléter';
      return switch (dueState(f.lastDrink, now)) {
        null => 'aucune gorgée notée',
        DueState.late => 'échéance dépassée : son âge le rattrape',
        DueState.soon => 'échéance le ${formatDay(dueDate(f.lastDrink!))}',
        DueState.ok => 'vitae ${f.vitae} / 5',
      };
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Serviteurs'),
        const SizedBox(height: 8),
        if (character.servants.isEmpty) Text('Aucun serviteur.', style: t.bodySmall),
        for (final s in character.servants)
          InkWell(
            onTap: () => context.go(linkOf(s.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(s.name, style: t.titleSmall),
                Text('${s.kind.label} ${dots(s.rank)}', style: t.bodySmall),
                Text(status(s), style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
              ]),
            ),
          ),
        for (final f in released)
          Text('${f.name} : points indisponibles jusqu’au ${formatDay(unavailableUntil(f.releasedAt!))}', style: t.bodySmall),
      ]),
    );
  }
}

/// Fiche d'un serviteur en lecture, pour le joueur (sans la note secrète).
class ServantScreen extends ConsumerWidget {
  const ServantScreen({super.key, required this.characterId, required this.servantId});
  final String characterId;
  final String servantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(characterProvider(characterId)), (c) {
      final s = c?.servants.where((x) => x.id == servantId).firstOrNull;
      if (c == null || s == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Serviteur introuvable', message: 'Il n’est plus sur la fiche du personnage.');
      }
      return asyncView(ref.watch(characterServantFilesProvider(characterId)), (files) {
        final f = files.where((x) => x.id == servantId).firstOrNull;
        return PageBody(children: [
          PageTitle(s.name, subtitle: '${s.kind.label} de ${c.name} · rang ${s.rank}'),
          const SizedBox(height: 20),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Réserve ${pool(s.rank)} · santé ${s.rank} · pas de Volonté', style: t.bodyMedium),
              const SizedBox(height: 10),
              if (f == null)
                Text('Le conte n’a pas encore détaillé ce serviteur.', style: t.bodySmall)
              else ...[
                Text('Spécialités : ${f.specialties.isEmpty ? 'aucune' : f.specialties.join(' · ')}', style: t.bodyMedium),
                if (s.kind == ServantKind.animal) Text('Qualités animales : ${f.qualities.isEmpty ? 'aucune' : f.qualities.join(' · ')}', style: t.bodyMedium),
                Text('Vitae ${f.vitae} / 5 · lien de sang ${f.bond == 0 ? 'aucun' : dots(f.bond)}', style: t.bodyMedium),
                Text(
                  f.lastDrink == null
                      ? 'Aucune gorgée notée.'
                      : 'Dernière gorgée le ${formatDay(f.lastDrink)}. Buvez avant le ${formatDay(dueDate(f.lastDrink!))}, sinon son âge le rattrape : 10 ans par jour.',
                  style: t.bodySmall,
                ),
                if (f.description.isNotEmpty) ...[const SizedBox(height: 10), Text(f.description, style: t.bodyMedium)],
              ],
            ]),
          ),
        ]);
      }, onRetry: () => ref.invalidate(characterServantFilesProvider(characterId)));
    }, onRetry: () => ref.invalidate(characterProvider(characterId)));
  }
}
```

**`lib/characters/edit_widgets.dart` :** à la fin du fichier, ajouter :

```dart
/// Serviteurs (C3) : nom, type, rang ; l'identifiant reste celui de la fiche détaillée.
class ServantListEditor extends StatelessWidget {
  const ServantListEditor({super.key, required this.characterId, required this.items, required this.onChanged});

  final String characterId;
  final List<Servant> items;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final s in items)
        Container(
          key: ObjectKey(s),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('servant-name-${s.id}'),
                  initialValue: s.name,
                  decoration: const InputDecoration(labelText: 'Nom', isDense: true),
                  onChanged: (v) {
                    s.name = v.trim();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<ServantKind>(
                  initialValue: s.kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true),
                  items: [for (final k in ServantKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
                  onChanged: (k) {
                    s.kind = k ?? s.kind;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Retirer ${s.name}',
                onPressed: () {
                  items.remove(s);
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ]),
            PointsField(
              label: 'Rang',
              value: s.rank,
              max: 5,
              onChanged: (v) {
                s.rank = v.clamp(1, 5);
                onChanged();
              },
            ),
          ]),
        ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () {
            items.add(Servant(newServantId(characterId), 'Nouveau serviteur', ServantKind.human, 1));
            onChanged();
          },
          child: const Text('+ Serviteur'),
        ),
      ),
    ]);
  }
}
```

Vérifier que `edit_widgets.dart` importe `character.dart` et `../core/theme.dart`, et que `PointsField` accepte ces paramètres (`label`, `value`, `max`, `onChanged`) ; ajuster les noms sinon.

**`lib/characters/character_edit_screen.dart` :**

1. Ajouter les imports `dart:async` (s'il manque), `../servants/servants_repository.dart` et `../servants/servants_section.dart`.

2. Dans la liste des sections de `_Editor`, après la section « Historiques », ajouter :

```dart
      section('Serviteurs', [ServantListEditor(characterId: c.id, items: c.servants, onChanged: onChanged)]),
```

3. Dans l'enregistrement, juste après `await ref.read(characterRepositoryProvider).saveEdit(_base!, _draft!, reason, by);`, ajouter :

```dart
      // Serviteurs retirés : leur fiche détaillée est marquée libérée (lot séparé, sans bloquer l'enregistrement).
      final kept = {for (final s in _draft!.servants) s.id};
      for (final s in _base!.servants) {
        if (!kept.contains(s.id)) unawaited(ref.read(servantsRepositoryProvider).release(s.id, by).catchError((_) {}));
      }
```

4. Après `PlacesSection(characterId: latest.id, link: '/conteur/lieux'),`, ajouter :

```dart
              const SizedBox(height: 20),
              ServantsSection(character: latest, linkOf: (_) => '/conteur/goules'),
```

**`lib/characters/character_screen.dart` :**
- ajouter l'import `../servants/servants_section.dart` ;
- dans le bloc `else ...[`, après la ligne `PlacesSection(...)`, ajouter :

```dart
          const SizedBox(height: 20),
          ServantsSection(
            character: c,
            linkOf: (sid) => basePath.startsWith('/joueur') ? '$basePath/serviteurs/$sid' : '/conteur/goules',
          ),
```

**`lib/router.dart` :**
- ajouter l'import `servants/servants_section.dart` ;
- après la route `/joueur/personnages/:id/lieux`, ajouter :

```dart
          GoRoute(
            path: '/joueur/personnages/:id/serviteurs/:sid',
            builder: (_, s) => ServantScreen(characterId: s.pathParameters['id']!, servantId: s.pathParameters['sid']!),
          ),
```

**Tests existants :** dans les `overrides` de `test/characters/character_screen_test.dart`, `test/characters/character_edit_test.dart` et `test/characters/edit_fixes_test.dart`, ajouter `noServantFiles,` après `noPlaces,`.

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: serviteurs — C3, section des fiches, fiche du joueur" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7 : revue, puis déploiement (avec accord)

- [ ] **Vérifications :**
  - tests des règles : `fail 0` ;
  - `flutter analyze` propre ;
  - `flutter test` : tous les tests passent.
- [ ] **Revue finale de la branche** par un relecteur neuf (opus). Les points Critical et Important sont corrigés, chacun avec un test qui échoue d'abord.
- [ ] **Avec l'accord de l'utilisateur :**
  - `firebase deploy --only firestore:rules --project met-mon-vampire` ;
  - `flutter build web --release` ;
  - `firebase deploy --only hosting --project met-mon-vampire` ;
  - puis fusion de `serviteurs` dans `main`.
