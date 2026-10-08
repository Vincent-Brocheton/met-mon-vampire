# Dérangements (sous-projet 7b2) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** la fiche porte des dérangements détaillés, gérés par le conte et demandés par le joueur sans gain d'XP, avec un compteur de traits de dérangement en jeu.

**Architecture :**
- **Deux clés tardives** sur la fiche, `derangements` et `derangementTraits`, protégées dans le brouillon du joueur.
- **Calculs purs** dans `lib/morality/derangement_rules.dart` ; modèle `Derangement` dans `lib/characters/character.dart` (comme `Ally`).
- **Demande du joueur :** un achat `XpKind.derangement` à 0 XP, qui porte le détail, sur le modèle des alliés (6g).
- **Écrans :** deux blocs dans l'onglet « Moralité & liens » :
  - `StaffDerangements` (`lib/morality/derangements_staff.dart`) ;
  - `PlayerDerangements` (`lib/morality/derangements_player.dart`) ;
  - un formulaire commun, `DerangementForm` (`lib/morality/derangement_form.dart`).

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-14-derangements-design.md`.

**Maquettes :** canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planches `C-Moralite.dc.html` et `J-Moralite.dc.html` (bloc Dérangements), `C-Derangements.dc.html` (référentiel). Pour les lire : outil Artifact, `action: read`, `path: project/<planche>`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md <N> [test|impl]` ;
  - textes en français ;
  - analyseur propre, pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche :** `derangements`, déjà créée.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Valeurs fixes :**
  - types `belief` Croyance, `incapacity` Incapacité, `compulsion` Compulsion, `phobia` Phobie, `destruction` Destruction, `obsession` Obsession ;
  - nom de 80 caractères au plus ; déclencheur de 200 caractères au plus ;
  - 2 points, ou 3 si sévère ;
  - compteur de 0 à 3, plancher 1 pour un Malkavien ;
  - motif automatique du compteur : « Traits de dérangement » ;
  - conflit de version : « Modifié entre-temps : rechargez la page. » ; autres refus : « Enregistrement refusé : réessayez. ».
- **Leçon du 6g :** les clés protégées ne doivent jamais partir dans le brouillon du joueur. `draftData` les retire des deux cartes.

## Review Focus

1. **Brouillon du joueur et nouvelles clés :** le brouillon ne les écrit jamais, et les règles les refusent. Tests : tâches 1 et 2.
2. **Demande en double** (déjà sur la fiche, ou déjà demandée) : le formulaire et la validation la refusent. Tests : tâches 2 et 4.
3. **Malkavien :** le compteur ne descend jamais sous 1, ni à l'affichage ni à l'écriture. Tests : tâches 1 et 3.
4. **Modification d'un dérangement sans changer son nom :** pas de faux doublon avec lui-même. Tests : tâches 1 et 3.
5. **Fiche en brouillon ou en validation :** la liste et le compteur sont en lecture seule pour le conte, puisque les règles refuseraient l'écriture. Test : tâche 3.

---

### Task 1 : dérangement sur la fiche, calculs purs

**Files :**
- Create : `lib/morality/derangement_rules.dart`.
- Modify :
  - `lib/characters/character.dart` ;
  - `lib/characters/describe_changes.dart` ;
  - `lib/characters/character_repository.dart` ;
  - `lib/xp/xp_request.dart` (le seul champ `derangement` de `XpItem`).
- Test : `test/morality/derangement_rules_test.dart`.

**Interfaces :**
- Produces :
  - `Derangement(id, name, {type = 'belief', trigger = '', severe = false, clan = false})`, avec `fromMap`, `toMap` et `copy` ;
  - `Character.derangements`, `Character.derangementTraits` et `newDerangementId(characterId)` ;
  - `XpItem.derangement` (`Map<String, dynamic>?`, paramètre nommé du constructeur) ;
  - dans `derangement_rules.dart` : `derangementsCat`, `derangementTypes`, `derangementChecks(d, existing)`, `derangementPoints(d)`, `derangementLine(d)`, `traitsFloor(c)`, `clampTraits(c, n)`, `toDetail(c, rb)`, `fromModel(rb, name, {id})`, `derangementData(d)` et `derangementOfItem(i, {id})`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 1 test`, puis `flutter test test/morality/derangement_rules_test.dart`.

Expected : échec au chargement.

<!-- file: test/morality/derangement_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart' show draftData;
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/morality/derangement_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'derangements': [
    RuleEntry(name: 'Peur du feu', data: {'type': 'phobia'}),
    RuleEntry(name: 'Mégalomanie', data: {'type': 'belief'}),
  ],
});

Derangement fire() => Derangement('x-d1', 'Peur du feu', type: 'phobia', trigger: 'Le feu, même une bougie.', severe: true);

void main() {
  test('contrôles, dont le doublon et la modification de soi-même (Review Focus 4)', () {
    expect(derangementChecks(fire(), const []), isEmpty);
    expect(derangementChecks(Derangement('', ' '), const []), ['Nom obligatoire']);
    expect(derangementChecks(Derangement('', 'x' * 81), const []), ['Nom : 80 caractères au plus']);
    expect(derangementChecks(Derangement('', 'A', type: 'lune'), const []), ['Type inconnu']);
    expect(derangementChecks(Derangement('', 'A', trigger: 'x' * 201), const []), ['Déclencheur : 200 caractères au plus']);
    expect(derangementChecks(Derangement('', 'peur du feu'), [fire()]), ['Un dérangement porte déjà ce nom']);
    expect(derangementChecks(fire()..trigger = 'Les flammes', [fire()]), isEmpty);
  });

  test('points, ligne, plancher Malkavien, bornes du compteur (Review Focus 3)', () {
    expect((derangementPoints(fire()), derangementPoints(fire()..severe = false)), (3, 2));
    expect([derangementLine(fire()), derangementLine(fire()..severe = false), derangementLine(fire()..clan = true)],
        ['Sévère · 3 pts', '2 pts', 'Principal · clan']);
    final malk = sample()..clan = 'Malkavien';
    expect((traitsFloor(sample()), traitsFloor(malk)), (0, 1));
    expect([clampTraits(malk, 0), clampTraits(sample(), 0), clampTraits(sample(), 5), clampTraits(malk, 2)], [1, 0, 3, 2]);
    expect(derangementTypes['phobia'], 'Phobie');
  });

  test('à détailler : handicap d’un modèle, fiche jouée, pas déjà détaillé ; prérempli', () {
    final c = sample()..flaws = [Trait('Peur du feu', 2), Trait('Curiosité', 2)];
    expect([for (final t in toDetail(c, rb)) t.name], ['Peur du feu']);
    expect(toDetail(c.clone()..derangements = [fire()], rb), isEmpty);
    final draft = sample()
      ..status = CharacterStatus.draft
      ..flaws = [Trait('Peur du feu', 2)];
    expect(toDetail(draft, rb), isEmpty);
    final m = fromModel(rb, 'Mégalomanie', id: 'x-d2');
    expect((m.id, m.name, m.type, m.severe, m.clan), ('x-d2', 'Mégalomanie', 'belief', false, false));
  });

  test('achat : détail porté', () {
    expect(derangementData(fire()), {'type': 'phobia', 'trigger': 'Le feu, même une bougie.', 'severe': true, 'clan': false});
  });

  test('fiche : clés tardives, jamais dans le brouillon, changements tracés (Review Focus 1)', () {
    expect(sample().toMap().keys, isNot(anyOf(contains('derangements'), contains('derangementTraits'))));
    final c = sample()
      ..derangements = [fire()]
      ..derangementTraits = 2;
    final back = Character.fromMap('x', c.toMap());
    expect(back.derangements.single.toMap(), fire().toMap());
    expect(back.derangementTraits, 2);
    expect(sample().laterKeys().keys, containsAll(['derangements', 'derangementTraits']));
    expect(draftData(c).keys, isNot(anyOf(contains('derangements'), contains('derangementTraits'))));
    expect(newDerangementId('x'), startsWith('x-d'));
    expect(describeChanges(sample(), c), containsAll(['+ Dérangement Peur du feu', 'Traits de dérangement : 0 → 2']));
    final edited = c.clone();
    edited.derangements.single.trigger = 'Les flammes';
    expect(describeChanges(c, edited), contains('Dérangement Peur du feu modifié'));
    expect(describeChanges(c, sample()), contains('− Dérangement Peur du feu'));
  });
}
```

- [ ] **Step 2 : implémentation**

**`lib/characters/character.dart` :**
- après la fonction `newAllyId`, ajouter :

```dart

/// Dérangement détaillé (sous-projet 7b2) : handicap de 2 points, 3 si sévère ; celui du clan est incurable.
class Derangement {
  Derangement(this.id, this.name, {this.type = 'belief', this.trigger = '', this.severe = false, this.clan = false});

  factory Derangement.fromMap(Map<String, dynamic> m) => Derangement(
        m['id'] as String? ?? '',
        m['name'] as String? ?? '',
        type: m['type'] as String? ?? 'belief',
        trigger: m['trigger'] as String? ?? '',
        severe: m['severe'] == true,
        clan: m['clan'] == true,
      );

  final String id;
  String name;

  /// Valeur du champ `type` du référentiel : belief, incapacity, compulsion, phobia, destruction, obsession.
  String type;
  String trigger;
  bool severe;
  bool clan;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'trigger': trigger, 'severe': severe, 'clan': clan};

  Derangement copy() => Derangement.fromMap(toMap());
}

int _derangementSeq = 0;

/// Identifiant d'un nouveau dérangement : jamais réutilisé.
String newDerangementId(String characterId) =>
    '$characterId-d${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_derangementSeq++}';
```

- `_laterKeys` reçoit `'derangements', 'derangementTraits'` à la fin ;
- après le champ `List<Ally> allies = [];`, ajouter :

```dart
  List<Derangement> derangements = [];

  /// Traits de dérangement en jeu, de 0 à 3 (plancher 1 pour un Malkavien).
  int derangementTraits = 0;
```

- dans `Character.fromMap`, après `..allies = …`, ajouter `..derangements = _maps(m['derangements']).map(Derangement.fromMap).toList()` et `..derangementTraits = _int(m['derangementTraits'])` ;
- dans `laterKeys()`, après la ligne `'path'`, ajouter `'derangements': [for (final d in derangements) d.toMap()],` et `'derangementTraits': derangementTraits,` ;
- dans `toMap()`, après la ligne `path`, ajouter :

```dart
        if (derangements.isNotEmpty || storedKeys.contains('derangements')) 'derangements': [for (final d in derangements) d.toMap()],
        if (derangementTraits != 0 || storedKeys.contains('derangementTraits')) 'derangementTraits': derangementTraits,
```

**`lib/characters/describe_changes.dart` :**
- après `_allies(out, a.allies, b.allies);`, ajouter :

```dart
  _derangements(out, a.derangements, b.derangements);
  if (a.derangementTraits != b.derangementTraits) out.add('Traits de dérangement : ${a.derangementTraits} → ${b.derangementTraits}');
```

- après la fonction `_allies`, ajouter :

```dart
void _derangements(List<String> out, List<Derangement> a, List<Derangement> b) {
  final before = {for (final x in a) x.id: x};
  final after = {for (final x in b) x.id: x};
  for (final x in b) {
    final old = before[x.id];
    if (old == null) {
      out.add('+ Dérangement ${x.name}');
    } else if (old.toMap().toString() != x.toMap().toString()) {
      out.add('Dérangement ${x.name} modifié');
    }
  }
  for (final x in a) {
    if (!after.containsKey(x.id)) out.add('− Dérangement ${x.name}');
  }
}
```

**`lib/characters/character_repository.dart` :** `draftData` et son commentaire deviennent :

```dart
/// Sans `allies`, `path`, `derangements` ni `derangementTraits` : clés protégées, que seul le conte écrit (règle playerDraftSave).
Map<String, dynamic> draftData(Character c) {
  const protected = ['allies', 'path', 'derangements', 'derangementTraits'];
  return {
    ...c.toMap()..removeWhere((k, _) => protected.contains(k)),
    ...c.laterKeys()..removeWhere((k, _) => protected.contains(k)),
  };
}
```

**`lib/xp/xp_request.dart` :** dans `XpItem`, ajouter le paramètre nommé `this.derangement` au constructeur, et le champ :

```dart
  /// Dérangement demandé (type, déclencheur, sévère, clan) ; null pour les autres achats.
  final Map<String, dynamic>? derangement;
```

(La lecture et l'écriture de ce champ dans `fromMap` et `toMap` viennent à la tâche 2.)

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 1 impl`.

<!-- file: lib/morality/derangement_rules.dart -->
```dart
import '../characters/character.dart';
import '../rulebook/rule_entry.dart' show nameKey;
import '../rulebook/rulebook.dart';
import '../xp/xp_request.dart';

/// Catégorie du référentiel : modèles de dérangements (champ `type`).
const derangementsCat = 'derangements';

/// Types de dérangements : valeur stockée → libellé.
const derangementTypes = {
  'belief': 'Croyance',
  'incapacity': 'Incapacité',
  'compulsion': 'Compulsion',
  'phobia': 'Phobie',
  'destruction': 'Destruction',
  'obsession': 'Obsession',
};

/// Erreurs d'un dérangement ; [existing] : ceux de la fiche (le dérangement lui-même est ignoré).
List<String> derangementChecks(Derangement d, List<Derangement> existing) {
  final name = d.name.trim();
  return [
    if (name.isEmpty) 'Nom obligatoire',
    if (name.length > 80) 'Nom : 80 caractères au plus',
    if (!derangementTypes.containsKey(d.type)) 'Type inconnu',
    if (d.trigger.length > 200) 'Déclencheur : 200 caractères au plus',
    if (name.isNotEmpty && existing.any((x) => x.id != d.id && nameKey(x.name) == nameKey(name))) 'Un dérangement porte déjà ce nom',
  ];
}

int derangementPoints(Derangement d) => d.severe ? 3 : 2;

/// « Principal · clan », « Sévère · 3 pts » ou « 2 pts ».
String derangementLine(Derangement d) => d.clan ? 'Principal · clan' : (d.severe ? 'Sévère · 3 pts' : '2 pts');

/// Plancher des traits de dérangement : 1 pour un Malkavien.
int traitsFloor(Character c) => nameKey(c.clan ?? '') == nameKey('Malkavien') ? 1 : 0;

int clampTraits(Character c, int n) => n.clamp(traitsFloor(c), 3);

/// Handicaps d'une fiche jouée (ou d'un PNJ) qui correspondent à un modèle et n'ont pas encore de dérangement détaillé.
List<Trait> toDetail(Character c, Rulebook rb) {
  if (!(c.kind == CharacterKind.pnj || c.status.settled)) return const [];
  return [
    for (final f in c.flaws)
      if (rb.find(derangementsCat, f.name) != null && !c.derangements.any((d) => nameKey(d.name) == nameKey(f.name))) f,
  ];
}

/// Dérangement prérempli depuis un modèle du référentiel.
Derangement fromModel(Rulebook rb, String name, {required String id}) {
  final e = rb.find(derangementsCat, name);
  final type = '${e?.data['type'] ?? ''}';
  return Derangement(id, e?.name ?? name, type: derangementTypes.containsKey(type) ? type : 'belief');
}

/// Détail d'un dérangement demandé, porté par l'achat.
Map<String, dynamic> derangementData(Derangement d) => {'type': d.type, 'trigger': d.trigger, 'severe': d.severe, 'clan': d.clan};

/// Le dérangement tel que l'achat le demande.
Derangement derangementOfItem(XpItem i, {String id = ''}) => Derangement.fromMap({...?i.derangement, 'id': id, 'name': i.name});
```

Run : `flutter test test/morality test/characters`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test/morality
git commit -m "feat: dérangements — dérangement sur la fiche, compteur, calculs et à détailler" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : demande par l'XP à 0, règles Firestore

**Files :**
- Modify :
  - `lib/xp/xp_request.dart` ;
  - `lib/xp/xp_rules.dart` ;
  - `lib/xp/xp_corrections.dart` ;
  - `lib/xp/spend_screen.dart` ;
  - `firestore.rules`.
- Test : `test/morality/derangement_xp_test.dart`, `rules_test/derangements.test.js`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces : `XpKind.derangement` (« Dérangement »), au coût de 0, appliqué à la validation et retiré par l'annulation.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 2 test`, puis `flutter test test/morality/derangement_xp_test.dart` et les tests des règles.

Expected : échec.

<!-- file: test/morality/derangement_xp_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/morality/derangement_rules.dart';
import 'package:portail_met/rules/creation_rules.dart' show CheckLevel;
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import '../xp/xp_rules_test.dart' show req;
import 'derangement_rules_test.dart' show fire, rb;

XpItem ask(Derangement d) => XpItem(XpKind.derangement, d.name, 0, 1, 0, derangement: derangementData(d));

List<String> errorsOf(Character c, XpItem i) =>
    [for (final k in requestChecks(c, req([i]), reservedOthers: 0, rb: rb)) if (k.level == CheckLevel.error) k.text];

void main() {
  test('demande à 0 XP : aller-retour, application, annulation', () {
    final c = sample();
    final item = ask(fire());
    expect(costOf(c, item, rb: rb), 0);
    expect(XpItem.fromMap(item.toMap()).derangement, derangementData(fire()));
    expect(item.label, 'Dérangement · Peur du feu');
    expect(errorsOf(c, item), isEmpty);
    final after = applyRequest(c, [item], rb: rb);
    final d = after.derangements.single;
    expect((d.name, d.type, d.trigger, d.severe, d.clan, after.xpSpent), ('Peur du feu', 'phobia', 'Le feu, même une bougie.', true, false, c.xpSpent));
    expect(d.id, startsWith('x-d'));
    expect(applyCorrection(after, CorrectionKind.cancelPurchase, item: item).after!.derangements, isEmpty);
  });

  test('validation : doublon et données invalides refusés (Review Focus 2)', () {
    final c = sample()..derangements = [fire()];
    expect(errorsOf(c, ask(Derangement('', 'peur du feu', type: 'phobia'))), contains('Un dérangement porte déjà ce nom'));
    expect(errorsOf(sample(), ask(Derangement('', 'Rite', type: 'lune'))), contains('Type inconnu'));
    expect(errorsOf(sample(), const XpItem(XpKind.derangement, 'Sans détail', 0, 1, 0)), isNotEmpty);
  });

  test('écran XP : pas de type « Dérangement »', () {
    expect(elementOptions(sample(), XpKind.derangement, rb: rb), isEmpty);
  });
}
```

<!-- file: rules_test/derangements.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/zoe'), { displayName: 'zoe', email: 'zoe@ex.fr', role: 'joueur' });
    await setDoc(doc(db, 'characters/d1'), { name: 'Brouillon', kind: 'pj', playerUid: 'zoe', status: 'draft', version: 1, creation: {} });
  });
});

const zoe = () => env.authenticatedContext('zoe', { email: 'zoe@ex.fr', email_verified: true }).firestore();

test('brouillon du joueur : derangements et derangementTraits protégés (Review Focus 1)', async () => {
  await assertSucceeds(updateDoc(doc(zoe(), 'characters/d1'), { concept: 'Avocate', version: 2 }));
  await assertFails(updateDoc(doc(zoe(), 'characters/d1'), { derangements: [{ id: 'd1-d1', name: 'Peur du feu' }], version: 3 }));
  await assertFails(updateDoc(doc(zoe(), 'characters/d1'), { derangementTraits: 2, version: 3 }));
});
```

> Les deux refus utilisent `version: 3`, car la première mise à jour a porté la version à 2. Le refus vient donc bien des clés, et non de la règle de version (leçon du 6g).

- [ ] **Step 2 : implémentation**

**`firestore.rules` :** dans `playerDraftSave`, la liste des clés protégées se termine par `'allies', 'path', 'derangements', 'derangementTraits'])`.

**`lib/xp/xp_request.dart` :**
- `XpKind` reçoit `derangement('Dérangement')` à la fin (remplacer le `;` final de la dernière valeur par `,`) ;
- `levelText` : `XpKind.derangement => n > 0 ? 'oui' : '—',` ;
- `XpItem` (le champ et le paramètre existent depuis la tâche 1) :
  - dans `fromMap` : `derangement: m['derangement'] is Map ? Map<String, dynamic>.from(m['derangement'] as Map) : null,` ;
  - dans `toMap` : `if (derangement != null) 'derangement': derangement,` ;
- dans le résumé des achats : `XpKind.derangement => 'Dérangement ${i.name}',` ;
- toute autre expression `switch` exhaustive sur `XpKind` reçoit `XpKind.derangement` (l'analyseur les signale).

**`lib/xp/xp_rules.dart` :**
- ajouter l'import `../morality/derangement_rules.dart` ;
- `levelNow` : `XpKind.derangement => c.derangements.any((d) => nameKey(d.name) == nameKey(name)) ? 1 : 0,` ;
- `levelWith`, dans `same()` : la comparaison sans casse vaut aussi pour `XpKind.derangement` (à côté de `servant` et `ally`) ;
- `costOf` : `XpKind.derangement => 0,` ;
- `ruleText` : `XpKind.derangement => 'Sans coût',` ;
- `elementOptions` : `XpKind.derangement => const {},` ;
- `capOf`, `noteSpec`, `ruleCategoryOf` et les autres `switch` : `XpKind.derangement` rejoint le cas par défaut. `ruleCategoryOf` doit rendre `null` pour lui ;
- `itemError`, après le cas des alliés :

```dart
  if (item.kind == XpKind.derangement) return 'Les dérangements se demandent depuis la page Moralité.';
```

- `wellFormed` : `XpKind.derangement => i.fromLevel == 0 && i.toLevel == 1 && i.derangement != null,` ;
- `requestChecks`, dans la boucle, juste après le bloc des alliés :

```dart
    if (i.kind == XpKind.derangement) {
      for (final e in derangementChecks(derangementOfItem(i), applyRequest(c, seen, rb: rb).derangements)) {
        out.add(Check(0, CheckLevel.error, e));
      }
    }
```

- la vérification du plafond générique exclut aussi `XpKind.derangement` ;
- `applyRequest`, nouveau cas :

```dart
      case XpKind.derangement:
        if (!n.derangements.any((d) => nameKey(d.name) == nameKey(i.name))) {
          n.derangements.add(derangementOfItem(i, id: newDerangementId(n.id)));
        }
```

**`lib/xp/xp_corrections.dart`**, dans `_revert` :

```dart
    case XpKind.derangement:
      n.derangements.removeWhere((d) => nameKey(d.name) == nameKey(i.name));
```

**`lib/xp/spend_screen.dart` :** la liste des types exclut aussi `XpKind.derangement` : `if (k != XpKind.ally && k != XpKind.derangement && ghoulXpError(c, k) == null)`.

Run : `flutter analyze`, puis `flutter test`, puis les tests des règles.

Expected : propre, tous les tests passent, `fail 0`.

- [ ] **Step 3 : commit**

```
git add firestore.rules rules_test/derangements.test.js lib test/morality
git commit -m "feat: dérangements — demande sans coût par l'XP, clés protégées dans le brouillon" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : formulaire commun et bloc du conte

Maquette : `C-Moralite.dc.html`, bloc Dérangements.

**Files :**
- Create : `lib/morality/derangement_form.dart`, `lib/morality/derangements_staff.dart`.
- Modify : `lib/morality/morality_screen.dart`.
- Test : `test/morality/derangements_staff_test.dart`.

**Interfaces :**
- Consumes :
  - les tâches 1 et 2 ;
  - `askReason(context, summary)` (`lib/characters/character_edit_screen.dart`) ;
  - `characterRepositoryProvider.saveEdit`.
- Produces :
  - `DerangementTile(d, {trailing})` ;
  - `DerangementForm({rb, initial, existing, onSubmit, actionLabel, showClan, askWhy, busy, onCancel})`, avec les clés `de-model`, `de-name`, `de-type`, `de-trigger`, `de-severe`, `de-clan`, `de-why` et `de-save` ;
  - `StaffDerangements({character, rb, canEdit})`, avec les clés `de-add`, `de-edit-<id>`, `de-remove-<id>`, `de-detail-<handicap>`, `de-minus`, `de-plus`, `de-traits` et `de-reset`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 3 test`, puis `flutter test test/morality/derangements_staff_test.dart`.

Expected : échec au chargement.

<!-- file: test/morality/derangements_staff_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/morality/derangements_staff.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'derangement_rules_test.dart' show fire, rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeCharacterRepository> pump(WidgetTester tester, Character c, {bool canEdit = true}) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chars = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        characterProvider(c.id).overrideWith((ref) => Stream.value(c)),
        characterRepositoryProvider.overrideWith((ref) => chars),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: StaffDerangements(character: c, rb: rb, canEdit: canEdit))),
      ),
    ));
    await tester.pumpAndSettle();
    return chars;
  }

  Future<void> reason(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), text);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('ajouter un dérangement depuis un modèle, avec motif', (tester) async {
    final chars = await pump(tester, sample());
    expect(find.text('Aucun dérangement.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-add')));
    await tester.pumpAndSettle();
    await choose(tester, 'de-model', 'Peur du feu');
    await tester.enterText(find.byKey(const Key('de-trigger')), 'Le feu, même une bougie.');
    await tester.tap(find.byKey(const Key('de-severe')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('de-save')));
    await reason(tester, 'Traumatisme en jeu');
    expect(chars.calls, ['saveEdit:Traumatisme en jeu']);
    final d = chars.lastAfter!.derangements.single;
    expect((d.name, d.type, d.trigger, d.severe, d.clan), ('Peur du feu', 'phobia', 'Le feu, même une bougie.', true, false));
  });

  testWidgets('modifier sans faux doublon, puis retirer (Review Focus 4)', (tester) async {
    final chars = await pump(tester, sample()..derangements = [fire()]);
    expect(find.text('Phobie · Sévère · 3 pts'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-edit-x-d1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('de-trigger')), 'Les flammes');
    await tester.pump();
    expect(find.text('Un dérangement porte déjà ce nom'), findsNothing);
    await tester.tap(find.byKey(const Key('de-save')));
    await reason(tester, 'Précision');
    expect(chars.lastAfter!.derangements.single.trigger, 'Les flammes');
    await tester.tap(find.byKey(const Key('de-remove-x-d1')));
    await reason(tester, 'Guéri');
    expect(chars.lastAfter!.derangements, isEmpty);
  });

  testWidgets('détailler un handicap de création', (tester) async {
    final chars = await pump(tester, sample()..flaws = [Trait('Peur du feu', 3)]);
    expect(find.text('Peur du feu · handicap 3 pts'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-detail-Peur du feu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('de-save')));
    await reason(tester, 'Détail du handicap');
    final d = chars.lastAfter!.derangements.single;
    expect((d.name, d.type, d.severe), ('Peur du feu', 'phobia', true));
  });

  testWidgets('compteur : plancher Malkavien, motif automatique, retour au plancher (Review Focus 3)', (tester) async {
    final chars = await pump(tester, sample()
      ..clan = 'Malkavien'
      ..derangementTraits = 0);
    expect(find.text('min. 1 (Malkavien)'), findsOneWidget);
    expect(find.text('●○○'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('de-minus'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('de-plus')));
    await tester.pumpAndSettle();
    expect(chars.calls, ['saveEdit:Traits de dérangement']);
    expect(chars.lastAfter!.derangementTraits, 2);
    await pump(tester, sample()
      ..clan = 'Malkavien'
      ..derangementTraits = 3);
    expect(find.text('Réaction extrême, puis retour à 0.'), findsOneWidget);
    expect(find.byKey(const Key('de-reset')), findsOneWidget);
  });

  testWidgets('lecture seule : narrateur, ou fiche en brouillon (Review Focus 5)', (tester) async {
    await pump(tester, sample()..derangements = [fire()], canEdit: false);
    expect(find.byKey(const Key('de-add')), findsNothing);
    expect(find.byKey(const Key('de-plus')), findsNothing);
    await pump(tester, sample()
      ..status = CharacterStatus.draft
      ..derangements = [fire()]);
    expect(find.byKey(const Key('de-edit-x-d1')), findsNothing);
    expect(find.byKey(const Key('de-plus')), findsNothing);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 3 impl`.

<!-- file: lib/morality/derangement_form.dart -->
```dart
import 'package:flutter/material.dart';

import '../characters/character.dart';
import '../core/theme.dart';
import '../rulebook/rulebook.dart';
import 'derangement_rules.dart';

/// Un dérangement en lecture : nom, type et points, déclencheur, mention « incurable » pour celui du clan.
class DerangementTile extends StatelessWidget {
  const DerangementTile(this.d, {super.key, this.trailing});
  final Derangement d;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.name, style: t.titleSmall),
        Text('${derangementTypes[d.type] ?? d.type} · ${derangementLine(d)}', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        if (d.trigger.isNotEmpty) Text('Déclencheur : ${d.trigger}', style: t.bodyMedium),
        if (d.clan) Text('Incurable · ne rapporte pas d’XP', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ?trailing,
      ]),
    );
  }
}

/// Formulaire d'un dérangement (conte : ajout ou modification ; joueur : demande).
class DerangementForm extends StatefulWidget {
  const DerangementForm({
    super.key,
    required this.rb,
    required this.initial,
    required this.existing,
    required this.onSubmit,
    required this.actionLabel,
    this.showClan = true,
    this.askWhy = false,
    this.busy = false,
    this.onCancel,
  });

  final Rulebook rb;
  final Derangement initial;

  /// Dérangements déjà portés (ou demandés), pour le contrôle du doublon.
  final List<Derangement> existing;
  final Future<void> Function(Derangement d, String why) onSubmit;
  final String actionLabel;
  final bool showClan;
  final bool askWhy;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  State<DerangementForm> createState() => _DerangementFormState();
}

class _DerangementFormState extends State<DerangementForm> {
  late final Derangement _d = widget.initial.copy();
  late final _name = TextEditingController(text: _d.name);
  late final _trigger = TextEditingController(text: _d.trigger);
  final _why = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _trigger.dispose();
    _why.dispose();
    super.dispose();
  }

  void _model(String? name) {
    if (name == null) return;
    final m = fromModel(widget.rb, name, id: _d.id);
    setState(() {
      _d
        ..name = m.name
        ..type = m.type;
      _name.text = m.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    _d
      ..name = _name.text.trim()
      ..trigger = _trigger.text.trim();
    final errors = [
      ...derangementChecks(_d, widget.existing),
      if (widget.askWhy && _why.text.trim().isEmpty) 'Indiquez pourquoi.',
    ];
    final models = widget.rb.offeredNames(derangementsCat);
    void touch(String _) => setState(() {});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (models.isNotEmpty)
        DropdownButtonFormField<String>(
          key: const Key('de-model'),
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Modèle (facultatif)'),
          items: [for (final m in models) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: _model,
        ),
      const SizedBox(height: 12),
      TextField(key: const Key('de-name'), controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Nom'), onChanged: touch),
      KeyedSubtree(
        key: ValueKey('de-type-${_d.type}'),
        child: DropdownButtonFormField<String>(
          key: const Key('de-type'),
          initialValue: derangementTypes.containsKey(_d.type) ? _d.type : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final e in derangementTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _d.type = v ?? _d.type),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('de-trigger'),
        controller: _trigger,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Déclencheur'),
        onChanged: touch,
      ),
      CheckboxListTile(
        key: const Key('de-severe'),
        value: _d.severe,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Sévère (3 points)'),
        onChanged: (v) => setState(() => _d.severe = v ?? false),
      ),
      if (widget.showClan)
        CheckboxListTile(
          key: const Key('de-clan'),
          value: _d.clan,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Dérangement de clan'),
          onChanged: (v) => setState(() => _d.clan = v ?? false),
        ),
      if (widget.askWhy)
        TextField(key: const Key('de-why'), controller: _why, maxLines: 2, decoration: const InputDecoration(labelText: 'Pourquoi ?'), onChanged: touch),
      for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton(
          key: const Key('de-save'),
          onPressed: widget.busy || errors.isNotEmpty ? null : () => widget.onSubmit(_d.copy(), _why.text.trim()),
          child: Text(widget.actionLabel),
        ),
        if (widget.onCancel != null) TextButton(onPressed: widget.onCancel, child: const Text('Annuler')),
      ]),
    ]);
  }
}
```

<!-- file: lib/morality/derangements_staff.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_edit_screen.dart' show askReason;
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import 'derangement_form.dart';
import 'derangement_rules.dart';

/// Bloc « Dérangements » du conte (C-Moralite) : liste, à détailler, compteur de traits en jeu.
class StaffDerangements extends ConsumerStatefulWidget {
  const StaffDerangements({super.key, required this.character, required this.rb, required this.canEdit});

  final Character character;
  final Rulebook rb;
  final bool canEdit;

  @override
  ConsumerState<StaffDerangements> createState() => _StaffDerangementsState();
}

class _StaffDerangementsState extends ConsumerState<StaffDerangements> {
  /// Dérangement ouvert dans le formulaire ; null : formulaire fermé.
  Derangement? _editing;
  int _form = 0;
  bool _busy = false;

  Character get c => widget.character;

  void _open(Derangement? d) => setState(() {
        _editing = d;
        _form++;
      });

  Future<bool> _write(Character after, String reason) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return false;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(characterRepositoryProvider).saveEdit(c, after, reason, by);
      messenger.showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      return true;
    } catch (_) {
      final latest = ref.read(characterProvider(c.id)).value;
      final moved = latest != null && latest.version != c.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ajout, modification ou retrait : modification tracée, avec motif.
  Future<void> _saveList(Character after) async {
    final changes = describeChanges(c, after);
    if (changes.isEmpty) return;
    final reason = await askReason(context, changes);
    if (reason == null || !mounted) return;
    if (await _write(after, reason) && mounted) _open(null);
  }

  Future<void> _submit(Derangement d) async {
    final after = c.clone();
    final i = after.derangements.indexWhere((x) => x.id == d.id);
    if (i < 0) {
      after.derangements.add(d);
    } else {
      after.derangements[i] = d;
    }
    await _saveList(after);
  }

  Future<void> _setTraits(int n) async {
    final after = c.clone()..derangementTraits = clampTraits(c, n);
    if (after.derangementTraits == c.derangementTraits) return;
    await _write(after, 'Traits de dérangement');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Une fiche en création ou en validation se modifie dans le parcours de création, pas ici.
    final ro = !widget.canEdit || !(c.kind == CharacterKind.pnj || c.status.settled);
    final floor = traitsFloor(c);
    final traits = clampTraits(c, c.derangementTraits);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Dérangements'),
        const SizedBox(height: 8),
        if (c.derangements.isEmpty) Text('Aucun dérangement.', style: t.bodyMedium),
        for (final d in c.derangements)
          DerangementTile(
            d,
            trailing: ro
                ? null
                : Wrap(spacing: 4, children: [
                    TextButton(key: Key('de-edit-${d.id}'), onPressed: _busy ? null : () => _open(d.copy()), child: const Text('Modifier')),
                    TextButton(
                      key: Key('de-remove-${d.id}'),
                      onPressed: _busy ? null : () => _saveList(c.clone()..derangements.removeWhere((x) => x.id == d.id)),
                      child: const Text('Retirer', style: TextStyle(color: AppColors.linkHover)),
                    ),
                  ]),
          ),
        if (!ro)
          for (final f in toDetail(c, widget.rb))
            Row(children: [
              Expanded(child: Text('${f.name} · handicap ${f.level} pts', style: t.bodyMedium)),
              TextButton(
                key: Key('de-detail-${f.name}'),
                onPressed: _busy ? null : () => _open(fromModel(widget.rb, f.name, id: newDerangementId(c.id))..severe = f.level >= 3),
                child: const Text('Détailler'),
              ),
            ]),
        if (!ro && _editing == null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('de-add'),
              onPressed: _busy ? null : () => _open(Derangement(newDerangementId(c.id), '')),
              child: const Text('+ Ajouter'),
            ),
          ),
        if (!ro && _editing != null) ...[
          const SizedBox(height: 12),
          DerangementForm(
            key: ValueKey('de-form-$_form'),
            rb: widget.rb,
            initial: _editing!,
            existing: c.derangements,
            busy: _busy,
            actionLabel: c.derangements.any((x) => x.id == _editing!.id) ? 'Enregistrer' : 'Ajouter',
            onSubmit: (d, _) => _submit(d),
            onCancel: () => _open(null),
          ),
        ],
        const SizedBox(height: 16),
        Text('Traits de dérangement en jeu', style: t.labelMedium),
        Row(children: [
          if (!ro)
            IconButton(
              key: const Key('de-minus'),
              tooltip: 'Retirer un trait',
              onPressed: _busy || traits <= floor ? null : () => _setTraits(traits - 1),
              icon: const Icon(Icons.remove),
            ),
          Text('●' * traits + '○' * (3 - traits), key: const Key('de-traits'), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
          if (!ro)
            IconButton(
              key: const Key('de-plus'),
              tooltip: 'Ajouter un trait',
              onPressed: _busy || traits >= 3 ? null : () => _setTraits(traits + 1),
              icon: const Icon(Icons.add),
            ),
          if (floor == 1) Text('min. 1 (Malkavien)', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
        if (traits >= 3) ...[
          Text('Réaction extrême, puis retour à 0.', style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
          if (!ro)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(key: const Key('de-reset'), onPressed: _busy ? null : () => _setTraits(floor), child: const Text('Revenir au plancher')),
            ),
        ],
      ]),
    );
  }
}
```

**`lib/morality/morality_screen.dart` :**
- ajouter l'import `derangements_staff.dart` ;
- dans `build`, la ligne `if (staffView) StaffMorality(...) else playerMorality(...),` devient :

```dart
          if (staffView) ...[
            StaffMorality(character: c, sins: sins, rb: rb, canEdit: canEdit),
            const SizedBox(height: 20),
            StaffDerangements(character: c, rb: rb, canEdit: canEdit),
          ] else
            playerMorality(context, c, sins, rb, basePath),
```

> Le test du compteur suppose que le plancher s'applique à l'écriture : avec 0 stocké sur un Malkavien, l'affichage est ●○○ et « + » écrit 2.

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/morality
git commit -m "feat: dérangements — bloc du conte (liste, à détailler, compteur de traits)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : bloc du joueur et demande

Maquette : `J-Moralite.dc.html`, bloc Dérangements.

**Files :**
- Create : `lib/morality/derangements_player.dart`.
- Modify :
  - `lib/morality/morality_screen.dart` ;
  - `test/morality/morality_player_test.dart`.
- Test : `test/morality/derangements_player_test.dart`.

**Interfaces :**
- Consumes :
  - les tâches 1 à 3 (`DerangementForm`, `DerangementTile`, `derangementData`, `XpKind.derangement`) ;
  - `myRequestsProvider` et `xpRepositoryProvider` (`lib/xp/xp_repository.dart`) ;
  - `XpRequest`, `XpItem`.
- Produces : `PlayerDerangements({character, rb, basePath})`, avec les clés `de-ask` et `de-pending-<nom>`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 4 test`, puis `flutter test test/morality/derangements_player_test.dart`.

Expected : échec au chargement.

<!-- file: test/morality/derangements_player_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/morality/derangements_player.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'derangement_rules_test.dart' show fire, rb;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  Future<FakeXpRepository> pump(WidgetTester tester, Character c, {List<XpRequest> requests = const []}) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        myRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        xpRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: PlayerDerangements(character: c, rb: rb, basePath: '/joueur/personnages/x'))),
      ),
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

  testWidgets('liste, compteur, rappel ; demande envoyée à 0 XP', (tester) async {
    final repo = await pump(tester, sample()
      ..derangements = [fire()]
      ..derangementTraits = 1);
    expect(find.text('Peur du feu'), findsOneWidget);
    expect(find.text('●○○'), findsOneWidget);
    expect(find.text('Handicaps de 2 points, déclencheur au choix.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('de-clan')), findsNothing, reason: 'le joueur ne déclare pas de dérangement de clan');
    await choose(tester, 'de-model', 'Mégalomanie');
    await tester.enterText(find.byKey(const Key('de-trigger')), 'Être contredit en public');
    await tester.enterText(find.byKey(const Key('de-why')), 'Suite à l’humiliation à l’Élysée.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('de-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:submit:0']);
    final r = repo.lastSaved!;
    final i = r.items.single;
    expect((i.kind, i.name, i.fromLevel, i.toLevel, i.cost), (XpKind.derangement, 'Mégalomanie', 0, 1, 0));
    expect(i.derangement, {'type': 'belief', 'trigger': 'Être contredit en public', 'severe': false, 'clan': false});
    expect(r.justification, 'Suite à l’humiliation à l’Élysée.');
  });

  testWidgets('demande ouverte : « En attente du conte » ; doublon refusé (Review Focus 2)', (tester) async {
    await pump(tester, sample()..derangements = [fire()], requests: [
      XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.derangement, 'Mégalomanie', 0, 1, 0, derangement: {'type': 'belief', 'trigger': '', 'severe': false, 'clan': false})],
      ),
    ]);
    expect(find.byKey(const Key('de-pending-Mégalomanie')), findsOneWidget);
    expect(find.text('En attente du conte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-ask')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('de-name')), 'mégalomanie');
    await tester.enterText(find.byKey(const Key('de-why')), 'Encore.');
    await tester.pump();
    expect(find.text('Un dérangement porte déjà ce nom'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('de-name')), 'Peur du feu');
    await tester.pump();
    expect(find.text('Un dérangement porte déjà ce nom'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('de-save'))).onPressed, isNull);
  });

  testWidgets('fiche inactive : pas de demande', (tester) async {
    await pump(tester, sample()..status = CharacterStatus.retired);
    expect(find.byKey(const Key('de-ask')), findsNothing);
  });
}
```

- [ ] **Step 2 : implémentation**

**`test/morality/morality_player_test.dart` :** la vue du joueur lit maintenant les demandes. Dans les `overrides` de `pump`, ajouter `myRequestsProvider.overrideWith((ref) => Stream.value(const <XpRequest>[])),`, avec les imports `package:portail_met/xp/xp_repository.dart` et `package:portail_met/xp/xp_request.dart`.

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-14-derangements.md 4 impl`.

<!-- file: lib/morality/derangements_player.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../characters/character.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'derangement_form.dart';
import 'derangement_rules.dart';

/// Bloc « Dérangements » du joueur (J-Moralite) : ses dérangements, le compteur, ses demandes, et la demande d'un dérangement.
class PlayerDerangements extends ConsumerStatefulWidget {
  const PlayerDerangements({super.key, required this.character, required this.rb, required this.basePath});

  final Character character;
  final Rulebook rb;
  final String basePath;

  @override
  ConsumerState<PlayerDerangements> createState() => _PlayerDerangementsState();
}

class _PlayerDerangementsState extends ConsumerState<PlayerDerangements> {
  bool _open = false;
  bool _busy = false;
  int _form = 0;

  Character get c => widget.character;

  Future<void> _send(Derangement d, String why) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(xpRepositoryProvider).save(
            XpRequest(
              characterId: c.id,
              characterName: c.name,
              playerUid: c.playerUid ?? '',
              playerName: c.playerName ?? '',
              items: [XpItem(XpKind.derangement, d.name, 0, 1, 0, derangement: derangementData(d..clan = false))],
              justification: why,
            ),
            submit: true,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Demande envoyée au conte.')));
      if (mounted) {
        setState(() {
          _open = false;
          _form++;
        });
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Envoi refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final requests = ref.watch(myRequestsProvider).value ?? const <XpRequest>[];
    final pending = [
      for (final r in requests)
        if (r.characterId == c.id && r.status.open)
          for (final i in r.items)
            if (i.kind == XpKind.derangement) i.name,
    ];
    final traits = clampTraits(c, c.derangementTraits);
    final canAsk = widget.basePath.startsWith('/joueur') && c.status == CharacterStatus.active;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Dérangements'),
        const SizedBox(height: 4),
        Text('Handicaps de 2 points, déclencheur au choix.', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        if (c.derangements.isEmpty && pending.isEmpty) Text('Aucun dérangement.', style: t.bodyMedium),
        for (final d in c.derangements) DerangementTile(d),
        for (final p in pending)
          Row(key: Key('de-pending-$p'), children: [
            Expanded(child: Text(p, style: t.titleSmall)),
            Text('En attente du conte', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
          ]),
        const SizedBox(height: 12),
        Row(children: [
          Text('Traits de dérangement en jeu : ', style: t.bodyMedium),
          Text('●' * traits + '○' * (3 - traits), key: const Key('de-traits'), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
        ]),
        if (canAsk && !_open)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(key: const Key('de-ask'), onPressed: () => setState(() => _open = true), child: const Text('Demander un dérangement')),
          ),
        if (canAsk && _open) ...[
          const SizedBox(height: 12),
          DerangementForm(
            key: ValueKey('de-ask-form-$_form'),
            rb: widget.rb,
            initial: Derangement('', ''),
            existing: [...c.derangements, for (final p in pending) Derangement('pending', p)],
            showClan: false,
            askWhy: true,
            busy: _busy,
            actionLabel: 'Envoyer la demande',
            onSubmit: _send,
            onCancel: () => setState(() => _open = false),
          ),
        ],
      ]),
    );
  }
}
```

**`lib/morality/morality_screen.dart` :**
- ajouter l'import `derangements_player.dart` ;
- la branche `else playerMorality(context, c, sins, rb, basePath),` devient :

```dart
          ] else ...[
            playerMorality(context, c, sins, rb, basePath),
            const SizedBox(height: 20),
            PlayerDerangements(character: c, rb: rb, basePath: basePath),
          ],
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/morality
git commit -m "feat: dérangements — bloc du joueur et demande au conte" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : revue, puis déploiement (avec accord)

- [ ] **Vérifications :**
  - tests des règles : `fail 0` ;
  - `flutter analyze` propre ;
  - `flutter test` : tous les tests passent.
- [ ] **Revue finale de la branche** par un relecteur neuf (opus). Les points Critical et Important sont corrigés, chacun avec un test qui échoue d'abord.
- [ ] **Avec l'accord de l'utilisateur :**
  - `firebase deploy --only firestore:rules --project met-mon-vampire` ;
  - `flutter build web --release` ;
  - `firebase deploy --only hosting --project met-mon-vampire` ;
  - puis fusion de `derangements` dans `main`, et `git push origin main`.
