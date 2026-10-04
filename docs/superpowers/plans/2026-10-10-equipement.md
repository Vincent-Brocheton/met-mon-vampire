# Équipement (sous-projet 6f) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** le joueur demande un objet construit avec le système de génération d'équipement. Le conte le valide ou le refuse avec un motif, puis le gère : il le donne, le modifie, le confisque, le détruit ou le supprime.

**Architecture :**
- **Données :** collection `items/{id}` avec note secrète et historique, sur le modèle des lieux (`stageTraced`, `deleteTraced`, `TraceHistory`).
- **Calculs purs** dans `lib/items/item_rules.dart` : règles de base par catégorie, qualités proposées, contrôles, résumé des changements.
- **Écrans :**
  - conte `/conteur/objets` ;
  - joueur `/joueur/personnages/:id/equipement` ;
  - section « Équipement » sur J2 et C3.

**Tech Stack :** inchangée (Flutter, Riverpod generator, cloud_firestore, go_router).

**Spec :** `docs/superpowers/specs/2026-10-10-equipement-design.md`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md <N> [test|impl]` ;
  - textes en français ;
  - `dart run build_runner build --delete-conflicting-outputs` après un fichier `part` ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche :** `equipement`, déjà créée.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Référentiel :**
  - qualités : catégorie `equipment` du référentiel, avec `data.categories` (liste parmi `melee`, `ranged`, `armor`, `gear`), `data.incompatible` (noms), `data.outsideLimit` (booléen) et l'état de l'élément ;
  - règles de base par catégorie : `rb.settings['equipment']['rules']`, lignes `{category, damage, hands, qualitiesNormal, qualitiesCheap}`.
- **Écarts et précisions assumés** (à reporter dans le journal) :
  - **Suppression d'une demande par le joueur :** une demande refusée a déjà un historique écrit par le conte. Le joueur ne peut pas le supprimer, donc ces entrées restent orphelines et ne sont lisibles que par l'équipe. Aucun écran ne les montre.
  - **Erreurs ajoutées aux contrôles de la spec :** « X en double » et « X compte dans la limite : à choisir parmi les qualités de la gamme » (une qualité ordinaire posée comme hors limite).
  - **J2 :** la section « Équipement » (liste et lien) joue le rôle du lien prévu par la spec, comme la section « Lieux ».

## Review Focus

1. **Un joueur demande un objet pour le personnage d'un autre joueur, ou en son nom :** refusé par les règles. Test : tâche 2.
2. **Un joueur contourne l'application :** il écrit l'état « En jeu », une qualité hors limite, plus de 2 qualités ou une clé inconnue. Tout est refusé. Test : tâche 2.
3. **Un joueur supprime un objet en jeu ou confisqué :** refusé. Seules ses demandes en attente ou refusées peuvent l'être. Test : tâche 2.
4. **Une qualité devenue interdite dans le référentiel :** le panneau du conte affiche l'erreur et bloque l'enregistrement. Test : tâche 3.
5. **Le joueur du porteur change :** au prochain enregistrement, le conte recopie le joueur de la fiche dans `playerUid`. Test : tâche 3.

---

### Task 1 : modèle et contrôles

**Files :** Create `lib/items/item.dart`, `lib/items/item_rules.dart`. Test : `test/items/item_rules_test.dart`.

**Interfaces :**
- Produces :
  - `ItemCategory { melee, ranged, armor, gear }`, `ItemGrade { normal, cheap }` et `ItemState { requested, active, refused, confiscated, destroyed }`, chacun avec un `label` ;
  - `Item` (`fromMap`, `toMap`, `copy`) ;
  - `equipmentCat`, `CategoryRules` (avec `max(grade)`), `categoryRules(rb, c)`, `rulesText(rb, c)` ;
  - `qualityOptions(rb, c)`, `extraOptions(rb, c)`, `setQuality(list, i, name)` ;
  - `itemChecks(item, rb, {byPlayer})` qui renvoie `({List<String> errors, List<String> warnings})` ;
  - `itemQualitiesText(item)`, `holderText(item)`, `itemChanges(before, after)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 1 test`, puis `flutter test test/items`.

Expected : échec au chargement.

<!-- file: test/items/item_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/item_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

const _all = ['melee', 'ranged', 'armor', 'gear'];

final rb = Rulebook({
  'equipment': [
    RuleEntry(name: 'Précise', data: {'categories': ['melee', 'ranged']}),
    RuleEntry(name: 'Dissimulable', data: {'categories': _all, 'incompatible': ['Brutale']}),
    RuleEntry(name: 'Brutale', data: {'categories': ['melee']}),
    RuleEntry(name: 'Perforante', state: RuleState.approval, data: {'categories': ['ranged']}),
    RuleEntry(name: 'Fer froid', state: RuleState.forbidden, data: {'categories': ['melee']}),
    RuleEntry(name: 'Chef-d’œuvre', data: {'categories': _all, 'outsideLimit': true}),
    RuleEntry(name: 'Sécurisé', data: {'categories': ['gear']}),
  ],
}, const CreationValues(), {
  'equipment': {
    'rules': [
      {'category': 'melee', 'damage': '1 normal', 'hands': 1, 'qualitiesNormal': 2, 'qualitiesCheap': 1},
    ],
  },
});

/// Canne-épée d'Isaure : courante, deux qualités, en jeu.
Item cane() => Item(
      id: 'i1',
      name: 'Canne-épée',
      category: ItemCategory.melee,
      qualities: ['Dissimulable', 'Précise'],
      characterId: 'x',
      characterName: 'Isaure de Valcourt',
      playerUid: 'u1',
      description: 'Lame de 60 cm.',
      version: 1,
    );

List<String> errors(Item i, {bool byPlayer = false}) => itemChecks(i, rb, byPlayer: byPlayer).errors;

void main() {
  test('règles de base : réglage de la catégorie, sinon 2 et 1', () {
    final melee = categoryRules(rb, ItemCategory.melee);
    expect((melee.damage, melee.hands, melee.max(ItemGrade.normal), melee.max(ItemGrade.cheap)), ('1 normal', 1, 2, 1));
    final gear = categoryRules(rb, ItemCategory.gear);
    expect((gear.damage, gear.hands, gear.normal, gear.cheap), ('', null, 2, 1));
    expect(rulesText(rb, ItemCategory.melee), 'Arme de mêlée : dégâts 1 normal · 1 main');
    expect(rulesText(rb, ItemCategory.gear), '');
  });

  test('qualités proposées : de la catégorie, sans interdites ; hors limite à part', () {
    expect(qualityOptions(rb, ItemCategory.melee), ['Précise', 'Dissimulable', 'Brutale']);
    expect(qualityOptions(rb, ItemCategory.ranged), ['Précise', 'Dissimulable', 'Perforante']);
    expect(extraOptions(rb, ItemCategory.melee), ['Chef-d’œuvre']);
    expect(setQuality(['A', 'B'], 0, null), ['B']);
    expect(setQuality(['A'], 1, 'C'), ['A', 'C']);
    expect(setQuality(['A', 'B'], 1, 'C'), ['A', 'C']);
  });

  test('objet valide : aucune erreur', () {
    final c = itemChecks(cane(), rb);
    expect(c.errors, isEmpty);
    expect(c.warnings, isEmpty);
  });

  test('nombre de qualités selon la gamme ; nom obligatoire', () {
    expect(errors(cane()..qualities = ['Dissimulable', 'Précise', 'Chef-d’œuvre']), contains('2 qualités au plus pour un objet courant'));
    expect(errors(cane()..grade = ItemGrade.cheap), contains('1 qualité au plus pour un objet bon marché'));
    expect(errors(cane()..name = '  '), contains('Nom obligatoire'));
  });

  test('catégorie, interdite, accord du conte, en double', () {
    expect(errors(cane()..category = ItemCategory.gear), ['Précise : pas une qualité de cette catégorie']);
    expect(errors(cane()..qualities = ['Volante']), ['Volante : pas une qualité de cette catégorie']);
    expect(errors(cane()..qualities = ['Fer froid']), ['Fer froid est interdite']);
    expect(errors(cane()..qualities = ['Précise', 'précise']), ['précise en double']);
    final ranged = itemChecks(cane()
      ..category = ItemCategory.ranged
      ..qualities = ['Perforante'], rb);
    expect(ranged.errors, isEmpty);
    expect(ranged.warnings, ['Perforante demande l’accord du conte']);
  });

  test('incompatibles ; hors limite : place, demande du joueur', () {
    expect(errors(cane()..qualities = ['Dissimulable', 'Brutale']), ['Dissimulable et Brutale sont incompatibles']);
    expect(errors(cane()..qualities = ['Chef-d’œuvre']), ['Chef-d’œuvre ne compte pas dans la limite : à poser comme qualité hors limite']);
    expect(errors(cane()..extraQuality = 'Brutale'), [
      'Brutale compte dans la limite : à choisir parmi les qualités de la gamme',
      'Dissimulable et Brutale sont incompatibles',
    ]);
    final masterwork = cane()..extraQuality = 'Chef-d’œuvre';
    expect(errors(masterwork), isEmpty);
    expect(errors(masterwork, byPlayer: true), ['Les qualités hors limite sont posées par le conte']);
  });

  test('aller-retour, textes et changements tracés', () {
    final i = cane()..extraQuality = 'Chef-d’œuvre';
    expect(Item.fromMap('i1', i.toMap()).toMap(), i.toMap());
    expect(itemQualitiesText(i), 'Dissimulable · Précise · Chef-d’œuvre (hors limite)');
    expect(itemQualitiesText(Item()), '—');
    expect(holderText(Item()), 'Personne (réserve du conte)');
    final after = cane()
      ..state = ItemState.confiscated
      ..characterId = ''
      ..characterName = ''
      ..qualities = ['Précise'];
    expect(itemChanges(cane(), after), [
      'Qualités : Dissimulable · Précise → Précise',
      'Porté par : Isaure de Valcourt → Personne (réserve du conte)',
      'État : En jeu → Confisqué',
    ]);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 1 impl`.

<!-- file: lib/items/item.dart -->
```dart
enum ItemCategory {
  melee('Arme de mêlée'),
  ranged('Arme à distance'),
  armor('Protection'),
  gear('Matériel divers');

  const ItemCategory(this.label);
  final String label;
}

enum ItemGrade {
  normal('Courant'),
  cheap('Bon marché');

  const ItemGrade(this.label);
  final String label;
}

enum ItemState {
  requested('Demande à valider'),
  active('En jeu'),
  refused('Refusée'),
  confiscated('Confisqué'),
  destroyed('Détruit');

  const ItemState(this.label);
  final String label;
}

/// Objet d'un personnage (`items/{id}`). Mutable : l'édition travaille sur une [copy].
class Item {
  Item({
    this.id = '',
    this.name = '',
    this.category = ItemCategory.melee,
    this.grade = ItemGrade.normal,
    List<String>? qualities,
    this.extraQuality,
    this.characterId = '',
    this.characterName = '',
    this.playerUid = '',
    this.state = ItemState.active,
    this.description = '',
    this.origin = '',
    this.refusal = '',
    this.version = 0,
    this.updatedByName,
  }) : qualities = qualities ?? [];

  factory Item.fromMap(String id, Map<String, dynamic> m) => Item(
        id: id,
        name: m['name'] as String? ?? '',
        category: ItemCategory.values.asNameMap()[m['category']] ?? ItemCategory.gear,
        grade: ItemGrade.values.asNameMap()[m['grade']] ?? ItemGrade.normal,
        qualities: [for (final q in (m['qualities'] as List?) ?? const []) '$q'],
        extraQuality: m['extraQuality'] as String?,
        characterId: m['characterId'] as String? ?? '',
        characterName: m['characterName'] as String? ?? '',
        playerUid: m['playerUid'] as String? ?? '',
        state: ItemState.values.asNameMap()[m['state']] ?? ItemState.active,
        description: m['description'] as String? ?? '',
        origin: m['origin'] as String? ?? '',
        refusal: m['refusal'] as String? ?? '',
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String name;
  ItemCategory category;
  ItemGrade grade;
  List<String> qualities;
  String? extraQuality;
  String characterId;
  String characterName;
  String playerUid;
  ItemState state;
  String description;
  String origin;
  String refusal;
  final int version;
  final String? updatedByName;

  /// Clés écrites (le suivi — version, historique, dates — est ajouté par le dépôt).
  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category.name,
        'grade': grade.name,
        'qualities': qualities,
        'extraQuality': extraQuality,
        'characterId': characterId,
        'characterName': characterName,
        'playerUid': playerUid,
        'state': state.name,
        'description': description,
        'origin': origin,
        'refusal': refusal,
      };

  Item copy() => Item.fromMap(id, {...toMap(), 'qualities': [...qualities], 'version': version, 'updatedByName': updatedByName});
}
```

<!-- file: lib/items/item_rules.dart -->
```dart
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import 'item.dart';

/// Catégorie du référentiel qui porte les qualités d'objets.
const equipmentCat = 'equipment';

/// Règles de base d'une catégorie (paramètres du référentiel) ; 2 et 1 qualités par défaut.
class CategoryRules {
  const CategoryRules({this.damage = '', this.hands, this.normal = 2, this.cheap = 1});
  final String damage;
  final int? hands;
  final int normal;
  final int cheap;

  int max(ItemGrade g) => g == ItemGrade.normal ? normal : cheap;
}

int? _n(Object? v) => v is num && v >= 0 ? v.toInt() : null;

CategoryRules categoryRules(Rulebook rb, ItemCategory c) {
  final rows = rb.settings[equipmentCat]?['rules'];
  final row = rows is List ? rows.whereType<Map>().where((r) => r['category'] == c.name).firstOrNull : null;
  if (row == null) return const CategoryRules();
  return CategoryRules(
    damage: '${row['damage'] ?? ''}'.trim(),
    hands: _n(row['hands']),
    normal: _n(row['qualitiesNormal']) ?? 2,
    cheap: _n(row['qualitiesCheap']) ?? 1,
  );
}

/// « Arme de mêlée : dégâts 1 normal · 1 main » ; vide sans règle de base.
String rulesText(Rulebook rb, ItemCategory c) {
  final r = categoryRules(rb, c);
  final parts = [
    if (r.damage.isNotEmpty) 'dégâts ${r.damage}',
    if (r.hands case final h?) '$h main${h > 1 ? 's' : ''}',
  ];
  return parts.isEmpty ? '' : '${c.label} : ${parts.join(' · ')}';
}

bool _inCategory(RuleEntry e, ItemCategory c) => ((e.data['categories'] as List?) ?? const []).contains(c.name);
bool _outside(RuleEntry e) => e.data['outsideLimit'] == true;

/// Qualités de la gamme pour [c] : disponibles ou sur accord du conte, hors limite exclues.
List<String> qualityOptions(Rulebook rb, ItemCategory c) =>
    [for (final e in rb.all(equipmentCat)) if (e.state.offered && _inCategory(e, c) && !_outside(e)) e.name];

/// Qualités hors limite pour [c] (posées par le conte).
List<String> extraOptions(Rulebook rb, ItemCategory c) =>
    [for (final e in rb.all(equipmentCat)) if (e.state.offered && _inCategory(e, c) && _outside(e)) e.name];

/// Qualité [i] remplacée par [name] ; null la retire ; au-delà de la liste, ajoutée.
List<String> setQuality(List<String> qualities, int i, String? name) {
  final l = [...qualities];
  if (i < l.length) {
    if (name == null) {
      l.removeAt(i);
    } else {
      l[i] = name;
    }
  } else if (name != null) {
    l.add(name);
  }
  return l;
}

bool _incompatible(Rulebook rb, String a, String b) {
  List<String> of(String x) => [for (final n in (rb.find(equipmentCat, x)?.data['incompatible'] as List?) ?? const []) nameKey('$n')];
  return of(a).contains(nameKey(b)) || of(b).contains(nameKey(a));
}

/// Contrôles d'un objet : les erreurs bloquent l'enregistrement, les avertissements sont signalés au conte.
({List<String> errors, List<String> warnings}) itemChecks(Item i, Rulebook rb, {bool byPlayer = false}) {
  final errors = <String>[];
  final warnings = <String>[];
  if (i.name.trim().isEmpty) errors.add('Nom obligatoire');
  final max = categoryRules(rb, i.category).max(i.grade);
  if (i.qualities.length > max) {
    errors.add('$max qualité${max > 1 ? 's' : ''} au plus pour un objet ${i.grade == ItemGrade.normal ? 'courant' : 'bon marché'}');
  }
  final extra = i.extraQuality;
  if (byPlayer && extra != null) errors.add('Les qualités hors limite sont posées par le conte');
  final all = [...i.qualities, ?extra];
  final seen = <String>{};
  for (final (k, q) in all.indexed) {
    if (!seen.add(nameKey(q))) {
      errors.add('$q en double');
      continue;
    }
    final e = rb.find(equipmentCat, q);
    if (e == null || !_inCategory(e, i.category)) {
      errors.add('$q : pas une qualité de cette catégorie');
      continue;
    }
    if (!e.state.offered) {
      errors.add('$q est interdite');
      continue;
    }
    if (e.state == RuleState.approval) warnings.add('$q demande l’accord du conte');
    final isExtra = extra != null && k == all.length - 1;
    if (!isExtra && _outside(e)) errors.add('$q ne compte pas dans la limite : à poser comme qualité hors limite');
    if (isExtra && !_outside(e)) errors.add('$q compte dans la limite : à choisir parmi les qualités de la gamme');
  }
  for (var a = 0; a < all.length; a++) {
    for (var b = a + 1; b < all.length; b++) {
      if (nameKey(all[a]) != nameKey(all[b]) && _incompatible(rb, all[a], all[b])) errors.add('${all[a]} et ${all[b]} sont incompatibles');
    }
  }
  return (errors: errors, warnings: warnings);
}

/// « Dissimulable · Précise · Chef-d’œuvre (hors limite) » ; « — » sans qualité.
String itemQualitiesText(Item i) {
  final all = [...i.qualities, if (i.extraQuality case final x?) '$x (hors limite)'];
  return all.isEmpty ? '—' : all.join(' · ');
}

String holderText(Item i) => i.characterId.isEmpty ? 'Personne (réserve du conte)' : i.characterName;

/// Résumé des changements pour l'historique.
List<String> itemChanges(Item a, Item b) => [
      if (a.name != b.name) 'Nom : ${a.name} → ${b.name}',
      if (a.category != b.category) 'Catégorie : ${a.category.label} → ${b.category.label}',
      if (a.grade != b.grade) 'Gamme : ${a.grade.label} → ${b.grade.label}',
      if (itemQualitiesText(a) != itemQualitiesText(b)) 'Qualités : ${itemQualitiesText(a)} → ${itemQualitiesText(b)}',
      if (a.characterId != b.characterId) 'Porté par : ${holderText(a)} → ${holderText(b)}',
      if (a.state != b.state) 'État : ${a.state.label} → ${b.state.label}',
      if (a.description != b.description) 'Description modifiée',
      if (a.refusal != b.refusal && b.refusal.isNotEmpty) 'Motif du refus : ${b.refusal}',
    ];
```

Run : `flutter test test/items`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib/items test/items
git commit -m "feat: équipement — modèle et contrôles des qualités" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : règles Firestore, dépôt, providers, fake

**Files :**
- Modify : `firestore.rules`, `test/fakes.dart`.
- Create : `lib/items/items_repository.dart`, `rules_test/items.test.js`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `ItemsRepository` : `watchAll`, `watchForCharacter(id)`, `watchForPlayer(uid)`, `watchNote(id)`, `watchHistory(id)`, `save(before, item, by, {note, noteBefore, reason})` qui renvoie l'id, `request(item, by)` qui renvoie l'id, `delete(id)` (conte) et `deleteRequest(id)` (joueur) ;
  - les providers `itemsRepositoryProvider`, `allItemsProvider`, `characterItemsProvider(characterId)`, `itemNoteProvider(id)` et `itemHistoryProvider(id)` ;
  - `FakeItemsRepository` (`calls`, `lastSaved`, `lastBefore`, `lastRequest`, `lastNote`, `lastReason`, `error`) ;
  - l'override `noItems` (fiche 'x').

- [ ] **Step 1 : tests des règles (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 2 test`, puis les tests des règles.

Expected : les tests de `items.test.js` échouent ; les autres passent.

<!-- file: rules_test/items.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, query, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const item = (over) => ({
  name: 'Canne-épée', category: 'melee', grade: 'normal', qualities: ['Dissimulable'], extraQuality: null,
  characterId: 'c1', characterName: 'Isaure', playerUid: 'zoe', state: 'active', description: '', origin: '', refusal: '',
  version: 1, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Isaure', playerUid: 'zoe', kind: 'pj', status: 'active' });
    await setDoc(doc(db, 'characters/c2'), { name: 'Rafael', playerUid: 'max', kind: 'pj', status: 'active' });
    await setDoc(doc(db, 'items/i1'), item({ lastHistoryId: 'h1' }));
    await setDoc(doc(db, 'items/i1/private/note'), { text: 'Secret' });
    await setDoc(doc(db, 'items/i1/history/h1'), { at: new Date(), byUid: 'lea', byName: 'lea', summary: ['Objet créé'], reason: '' });
    await setDoc(doc(db, 'items/r1'), item({ state: 'requested' }));
    await setDoc(doc(db, 'items/f1'), item({ state: 'refused', refusal: 'Trop cher.' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/// Objet et son entrée d'historique dans un même lot.
function saved(uid, id, data, { history = true } = {}) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `items/${id}`), { ...data, lastHistoryId: 'hx' });
  if (history) b.set(doc(db, `items/${id}/history/hx`), { at: serverTimestamp(), byUid: uid, byName: uid, summary: [], reason: '' });
  return b.commit();
}

const request = (over) => item({ state: 'requested', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), updatedByName: 'zoe', ...over });

test('lecture : le joueur de l’objet et l’équipe ; note et historique à l’équipe', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'items/i1')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'items'), where('playerUid', '==', 'zoe'))));
  await assertFails(getDoc(doc(as('max'), 'items/i1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'items/i1')));
  await assertFails(getDoc(doc(as('zoe'), 'items/i1/private/note')));
  await assertFails(getDoc(doc(as('zoe'), 'items/i1/history/h1')));
  await assertSucceeds(getDoc(doc(as('julien'), 'items/i1/history/h1')));
});

test('demande du joueur : pour son personnage, en son nom (Review Focus 1)', async () => {
  await assertSucceeds(setDoc(doc(as('zoe'), 'items/n1'), request({})));
  await assertFails(setDoc(doc(as('zoe'), 'items/n2'), request({ characterId: 'c2' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n3'), request({ playerUid: 'max' })));
  await assertFails(setDoc(doc(as('max'), 'items/n4'), request({ playerUid: 'max' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n5'), request({ characterId: 'absent' })));
});

test('demande du joueur : rien au-delà d’une demande (Review Focus 2)', async () => {
  await assertFails(setDoc(doc(as('zoe'), 'items/n1'), request({ state: 'active' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n2'), request({ extraQuality: 'Chef-d’œuvre' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n3'), request({ qualities: ['A', 'B', 'C'] })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n4'), request({ refusal: 'x' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n5'), request({ secret: true })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n6'), request({ name: '' })));
  await assertFails(setDoc(doc(as('zoe'), 'items/n7'), request({ version: 2 })));
  await assertFails(updateDoc(doc(as('zoe'), 'items/r1'), { name: 'Autre' }));
});

test('suppression par le joueur : demandes en attente ou refusées seulement (Review Focus 3)', async () => {
  await assertFails(deleteDoc(doc(as('max'), 'items/r1')));
  await assertSucceeds(deleteDoc(doc(as('zoe'), 'items/r1')));
  await assertSucceeds(deleteDoc(doc(as('zoe'), 'items/f1')));
  await assertFails(deleteDoc(doc(as('zoe'), 'items/i1')));
});

test('le conte écrit avec version et historique ; le narrateur lit seulement', async () => {
  await assertSucceeds(saved('lea', 'n1', item({})));
  await assertFails(saved('lea', 'n2', item({}), { history: false }));
  await assertFails(saved('julien', 'n3', item({})));
  await assertFails(saved('lea', 'n4', item({ name: 'x'.repeat(81) })));
  await assertFails(saved('lea', 'n5', item({ state: 'perdu' })));
  await assertSucceeds(saved('lea', 'i1', item({ state: 'confiscated', version: 2 })));
  await assertFails(saved('lea', 'r1', item({ state: 'active', version: 1 })));
  await assertSucceeds(saved('lea', 'r1', item({ state: 'active', version: 2 })));
  await assertFails(deleteDoc(doc(as('julien'), 'items/i1')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'items/i1')));
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules`, juste avant le commentaire `// Serviteurs et mortels (sous-projet 6b)`, ajouter :

```
    // Équipement (sous-projet 6f) : lu par l'équipe et le joueur du porteur ; demandé par le joueur, géré par le conte.
    function itemValid() {
      let d = request.resource.data;
      return d.keys().hasOnly(['name', 'category', 'grade', 'qualities', 'extraQuality', 'characterId', 'characterName', 'playerUid',
          'state', 'description', 'origin', 'refusal', 'version', 'lastHistoryId', 'createdAt', 'updatedAt', 'updatedByName'])
        && d.name is string && d.name.size() > 0 && d.name.size() <= 80
        && d.category in ['melee', 'ranged', 'armor', 'gear'] && d.grade in ['normal', 'cheap']
        && d.qualities is list && d.qualities.size() <= 5
        && d.state in ['requested', 'active', 'refused', 'confiscated', 'destroyed']
        && d.characterId is string && d.playerUid is string
        && d.description is string && d.description.size() <= 2000
        && d.origin is string && d.origin.size() <= 2000
        && d.refusal is string && d.refusal.size() <= 2000;
    }
    function itemHistoryOk(id) {
      let h = getAfter(/databases/$(database)/documents/items/$(id)/history/$(request.resource.data.lastHistoryId)).data;
      return h.byUid == request.auth.uid && h.at == request.time;
    }
    function itemRequestOk() {
      let d = request.resource.data;
      return signedIn() && d.state == 'requested' && d.version == 1 && d.playerUid == request.auth.uid
        && d.get('extraQuality', null) == null && d.refusal == '' && !d.keys().hasAny(['lastHistoryId'])
        && d.qualities.size() <= 2
        && get(/databases/$(database)/documents/characters/$(d.characterId)).data.playerUid == request.auth.uid;
    }

    match /items/{id} {
      allow read: if isStaff() || (signedIn() && resource.data.playerUid == request.auth.uid);
      allow create: if itemValid()
        && ((managesAccounts() && request.resource.data.version == 1 && itemHistoryOk(id)) || itemRequestOk());
      allow update: if managesAccounts() && itemValid()
        && request.resource.data.version == resource.data.version + 1 && itemHistoryOk(id);
      allow delete: if managesAccounts()
        || (signedIn() && resource.data.playerUid == request.auth.uid && resource.data.state in ['requested', 'refused']);

      match /private/{doc} {
        allow read: if isStaff();
        allow write: if managesAccounts();
      }

      match /history/{h} {
        allow read: if isStaff();
        allow create: if managesAccounts()
          && request.resource.data.byUid == request.auth.uid
          && request.resource.data.at == request.time
          && getAfter(/databases/$(database)/documents/items/$(id)).data.lastHistoryId == h;
        allow delete: if managesAccounts();
      }
    }

```

Run : les tests des règles.

Expected : `fail 0`.

- [ ] **Step 3 : dépôt, providers, fake**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 2 impl`.

<!-- file: lib/items/items_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/trace.dart';
import 'item.dart';
import 'item_rules.dart';

part 'items_repository.g.dart';

/// `items/{id}`, `items/{id}/private/note`, `items/{id}/history/{h}`.
class ItemsRepository {
  ItemsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('items');

  List<Item> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) Item.fromMap(d.id, d.data())]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Équipe : tous les objets.
  Stream<List<Item>> watchAll() => _col.snapshots().map(_sorted);

  /// Équipe : les objets d'un personnage.
  Stream<List<Item>> watchForCharacter(String characterId) => _col.where('characterId', isEqualTo: characterId).snapshots().map(_sorted);

  /// Joueur : les objets de ses personnages (requête permise par les règles).
  Stream<List<Item>> watchForPlayer(String uid) => _col.where('playerUid', isEqualTo: uid).snapshots().map(_sorted);

  Stream<String> watchNote(String id) =>
      _col.doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Stream<List<TraceEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) TraceEntry.fromMap(d.data())]);

  /// Conte : crée (id vide) ou modifie [i] dans un lot : objet (version + 1), historique, note secrète. Renvoie l'id.
  Future<String> save(Item before, Item i, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    final creating = i.id.isEmpty;
    final ref = creating ? _col.doc() : _col.doc(i.id);
    final noteChanged = note != null && note.trim() != noteBefore.trim();
    final batch = _db.batch();
    stageTraced(
      batch,
      ref,
      i.toMap(),
      creating: creating,
      fromVersion: before.version,
      byUid: by.uid,
      byName: by.name,
      summary: creating ? ['Objet créé'] : [...itemChanges(before, i), if (noteChanged) 'Note secrète modifiée'],
      reason: reason,
      note: noteChanged ? note : null,
    );
    await batch.commit();
    return ref.id;
  }

  /// Joueur : demande d'objet (état « Demande à valider », sans qualité hors limite). Renvoie l'id.
  Future<String> request(Item i, Actor by) async {
    final ref = _col.doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      ...i.toMap(),
      'state': ItemState.requested.name,
      'extraQuality': null,
      'refusal': '',
      'version': 1,
      'createdAt': now,
      'updatedAt': now,
      'updatedByName': by.name,
    });
    return ref.id;
  }

  /// Conte : supprime l'objet, sa note et son historique.
  Future<void> delete(String id) => deleteTraced(_db, _col.doc(id));

  /// Joueur : supprime sa demande (en attente ou refusée).
  Future<void> deleteRequest(String id) => _col.doc(id).delete();
}

@Riverpod(keepAlive: true)
ItemsRepository itemsRepository(Ref ref) => ItemsRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Item>> allItems(Ref ref) => ref.watch(itemsRepositoryProvider).watchAll();

/// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.
@riverpod
Stream<List<Item>> characterItems(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final repo = ref.watch(itemsRepositoryProvider);
  if (me.role.isStaff) return repo.watchForCharacter(characterId);
  return repo.watchForPlayer(me.uid).map((l) => [for (final i in l) if (i.characterId == characterId) i]);
}

@riverpod
Stream<String> itemNote(Ref ref, String id) => ref.watch(itemsRepositoryProvider).watchNote(id);

@riverpod
Stream<List<TraceEntry>> itemHistory(Ref ref, String id) => ref.watch(itemsRepositoryProvider).watchHistory(id);
```

Dans `test/fakes.dart` :
- ajouter les imports `package:portail_met/items/item.dart` et `package:portail_met/items/items_repository.dart`, à leur place alphabétique (après `core/trace.dart`) ;
- ajouter à la fin :

```dart
class FakeItemsRepository implements ItemsRepository {
  final calls = <String>[];
  Item? lastSaved;
  Item? lastBefore;
  Item? lastRequest;
  String? lastNote;
  String? lastReason;
  Object? error;

  @override
  Stream<String> watchNote(String id) => Stream.value('');

  @override
  Stream<List<TraceEntry>> watchHistory(String id) => Stream.value(const []);

  @override
  Future<String> save(Item before, Item i, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    calls.add('save:${i.name}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = i;
    lastNote = note;
    lastReason = reason;
    return i.id.isEmpty ? 'new-item' : i.id;
  }

  @override
  Future<String> request(Item i, Actor by) async {
    calls.add('request:${i.name}');
    if (error != null) throw error!;
    lastRequest = i;
    return 'new-request';
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (error != null) throw error!;
  }

  @override
  Future<void> deleteRequest(String id) async {
    calls.add('deleteRequest:$id');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucun objet pour la fiche 'x'.
final noItems = characterItemsProvider('x').overrideWith((ref) => Stream.value(const <Item>[]));
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add firestore.rules rules_test/items.test.js lib/items test/fakes.dart
git commit -m "feat: équipement — règles Firestore, dépôt et providers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : écran du conte « Objets en jeu »

**Files :**
- Create : `lib/items/items_screen.dart`.
- Modify : `lib/router.dart`, `lib/characters/characters_list_screen.dart`.
- Test : `test/items/items_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2, `allCharactersProvider`, `currentUserProvider`, `rulebookProvider`, `actorOf`, `confirm`, `TraceHistory`.
- Produces :
  - `ItemsScreen` (`/conteur/objets`) ;
  - `itemStateColor(state)` ;
  - les clés :
    - liste : `it-new`, `it-cat-filter`, `it-state-filter`, `it-search`, `it-row-<id>` ;
    - panneau : `it-name`, `it-category`, `it-grade`, `it-q<i>`, `it-extra`, `it-holder`, `it-state`, `it-description`, `it-note`, `it-reason`, `it-save`, `it-validate`, `it-refuse` (fenêtre avec `refusal` et `refusal-ok`), `it-delete`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 3 test`, puis `flutter test test/items/items_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/items/items_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/items/items_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'item_rules_test.dart' show cane, rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Item phone() => Item(
        id: 'r1',
        name: 'Téléphone sécurisé',
        category: ItemCategory.gear,
        qualities: ['Sécurisé'],
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        state: ItemState.requested,
        origin: 'Acheté avec ses Ressources.',
        version: 1,
      );

  Future<FakeItemsRepository> pump(WidgetTester tester, {AppUser user = lea, List<Item>? items}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeItemsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        itemsRepositoryProvider.overrideWith((ref) => repo),
        allItemsProvider.overrideWith((ref) => Stream.value(items ?? [cane(), phone()])),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ItemsScreen())),
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

  testWidgets('créer un objet et le donner : joueur recopié, version 0', (tester) async {
    final repo = await pump(tester, items: const []);
    await tester.tap(find.byKey(const Key('it-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('it-name')), 'Dague');
    await tester.pump();
    expect(find.text('Arme de mêlée : dégâts 1 normal · 1 main'), findsOneWidget);
    await choose(tester, 'it-q0', 'Précise');
    await choose(tester, 'it-holder', 'Isaure de Valcourt');
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    final i = repo.lastSaved!;
    expect((i.name, i.characterId, i.characterName, i.playerUid, i.state), ('Dague', 'x', 'Isaure de Valcourt', 'u1', ItemState.active));
    expect(i.qualities, ['Précise']);
    expect(repo.lastBefore!.version, 0);
  });

  testWidgets('erreurs : enregistrement bloqué', (tester) async {
    final repo = await pump(tester, items: const []);
    await tester.tap(find.byKey(const Key('it-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(find.text('Nom obligatoire'), findsOneWidget);
    expect(find.text('Corrigez les erreurs avant d’enregistrer.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('qualité devenue interdite : erreur, enregistrement bloqué (Review Focus 4)', (tester) async {
    final repo = await pump(tester, items: [cane()..qualities = ['Fer froid']]);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    expect(find.text('Fer froid est interdite'), findsOneWidget);
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('joueur du porteur changé : recopié à l’enregistrement (Review Focus 5)', (tester) async {
    final repo = await pump(tester, items: [cane()..playerUid = 'ancien']);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.playerUid, 'u1');
  });

  testWidgets('demande : valider', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('it-row-r1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Acheté avec ses Ressources.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('it-validate')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.state, ItemState.active);
    expect(repo.lastReason, 'Demande validée');
  });

  testWidgets('demande : refuser avec motif', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('it-row-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-refuse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refusal-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Indiquez un motif.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const Key('it-refuse')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refusal')), 'Trop cher.');
    await tester.tap(find.byKey(const Key('refusal-ok')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.state, repo.lastSaved!.refusal, repo.lastReason), (ItemState.refused, 'Trop cher.', 'Demande refusée'));
  });

  testWidgets('confisquer puis supprimer', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await choose(tester, 'it-state', 'Confisqué');
    await tester.enterText(find.byKey(const Key('it-reason')), 'Fouille à l’Élysée');
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.state, repo.lastReason), (ItemState.confiscated, 'Fouille à l’Élysée'));
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:i1');
  });

  testWidgets('filtre des demandes', (tester) async {
    await pump(tester);
    await choose(tester, 'it-state-filter', 'Demandes à valider');
    expect(find.byKey(const Key('it-row-r1')), findsOneWidget);
    expect(find.byKey(const Key('it-row-i1')), findsNothing);
  });

  testWidgets('narrateur en lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('it-new')), findsNothing);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 3 impl`.

<!-- file: lib/items/items_screen.dart -->
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/trace.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'item.dart';
import 'item_rules.dart';
import 'items_repository.dart';

Color itemStateColor(ItemState s) => switch (s) {
      ItemState.active => AppColors.success,
      ItemState.requested => AppColors.goldLight,
      _ => AppColors.linkHover,
    };

/// « Objets en jeu » (C-Objets) : l'équipement de tous les personnages, demandes à valider comprises.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  /// Objet ouvert : id, '' pour un nouveau, null pour aucun.
  String? _selectedId;
  int _version = 0;
  ItemCategory? _category;
  String _state = 'all';
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
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les objets sont gérés par le conte.');
    }
    return asyncView(
      ref.watch(allItemsProvider),
      (items) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, me, rb, items, chars),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allItemsProvider),
    );
  }

  Widget _body(BuildContext context, AppUser me, Rulebook rb, List<Item> items, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final readOnly = !me.role.managesAccounts;
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final i in items)
        if ((_category == null || i.category == _category) &&
            switch (_state) {
              'requested' => i.state == ItemState.requested,
              'active' => i.state == ItemState.active,
              'refused' => i.state == ItemState.refused,
              'gone' => i.state == ItemState.confiscated || i.state == ItemState.destroyed,
              _ => true,
            } &&
            (q.isEmpty || i.name.toLowerCase().contains(q) || i.characterName.toLowerCase().contains(q)))
          i,
    ];
    final selected = _selectedId == null ? null : (_selectedId!.isEmpty ? Item() : items.where((i) => i.id == _selectedId).firstOrNull);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        'Objets en jeu',
        subtitle: 'L’équipement de tous les personnages. Un joueur demande un objet depuis sa fiche ; il n’entre en jeu qu’après validation.',
        action: readOnly ? null : FilledButton(key: const Key('it-new'), onPressed: () => _open(''), child: const Text('+ Nouvel objet')),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        DropdownButton<ItemCategory?>(
          key: const Key('it-cat-filter'),
          value: _category,
          items: [
            const DropdownMenuItem<ItemCategory?>(value: null, child: Text('Toutes les catégories')),
            for (final c in ItemCategory.values) DropdownMenuItem<ItemCategory?>(value: c, child: Text(c.label)),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        DropdownButton<String>(
          key: const Key('it-state-filter'),
          value: _state,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous les états')),
            DropdownMenuItem(value: 'requested', child: Text('Demandes à valider')),
            DropdownMenuItem(value: 'active', child: Text('En jeu')),
            DropdownMenuItem(value: 'refused', child: Text('Refusées')),
            DropdownMenuItem(value: 'gone', child: Text('Confisqués ou détruits')),
          ],
          onChanged: (v) => setState(() => _state = v ?? 'all'),
        ),
        TextButton(onPressed: () => context.go('/conteur/referentiel/equipment'), child: const Text('Qualités d’équipement')),
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('it-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Objet, personnage…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun objet.', style: t.bodyMedium)),
          for (final i in shown)
            InkWell(
              key: Key('it-row-${i.id}'),
              onTap: () => _open(i.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: i.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 200, child: Text(i.name, style: t.titleSmall)),
                  SizedBox(width: 140, child: Text(i.category.label, style: t.bodySmall)),
                  SizedBox(width: 240, child: Text(itemQualitiesText(i), style: t.bodySmall)),
                  SizedBox(width: 180, child: Text(holderText(i), style: t.bodySmall)),
                  Text(i.state.label, style: t.bodySmall?.copyWith(color: itemStateColor(i.state), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
    ]);

    Widget? editor;
    if (selected != null) {
      editor = Panel(
        child: _ItemEditor(
          key: ValueKey('${selected.id}/$_version'),
          item: selected,
          items: items,
          chars: chars,
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

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.items,
    required this.chars,
    required this.rb,
    required this.readOnly,
    required this.onSaved,
    required this.onDeleted,
  });

  final Item item;
  final List<Item> items;
  final List<Character> chars;
  final Rulebook rb;
  final bool readOnly;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  /// Version ouverte : base de l'enregistrement (le flux peut apporter une version plus récente entre-temps).
  late final Item _base;
  late final Item _d = widget.item.copy();
  late final _name = TextEditingController(text: _d.name);
  late final _description = TextEditingController(text: _d.description);
  final _note = TextEditingController();
  final _reason = TextEditingController();
  String _noteBefore = '';
  bool _noteLoaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _base = widget.item;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save({String? reason}) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    _d
      ..name = _name.text.trim()
      ..description = _description.text.trim();
    // Le porteur donne l'accès : son joueur est recopié à chaque enregistrement.
    final holder = widget.chars.where((c) => c.id == _d.characterId).firstOrNull;
    if (_d.characterId.isEmpty) {
      _d
        ..characterName = ''
        ..playerUid = '';
    } else if (holder != null) {
      _d
        ..characterName = holder.name
        ..playerUid = holder.playerUid ?? '';
    }
    if (itemChecks(_d, widget.rb).errors.isNotEmpty) {
      setState(() => _error = 'Corrigez les erreurs avant d’enregistrer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref
          .read(itemsRepositoryProvider)
          .save(_base, _d, by, note: _note.text, noteBefore: _noteBefore, reason: reason ?? _reason.text);
      messenger.showSnackBar(const SnackBar(content: Text('Objet enregistré.')));
      widget.onSaved(id);
    } catch (_) {
      final latest = widget.items.where((i) => i.id == _base.id).firstOrNull;
      final moved = _base.id.isNotEmpty && latest != null && latest.version != _base.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    _d
      ..state = ItemState.active
      ..refusal = '';
    await _save(reason: 'Demande validée');
  }

  Future<void> _refuse() async {
    final field = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Refuser « ${_d.name} » ?'),
        content: TextField(key: const Key('refusal'), controller: field, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif, visible par le joueur')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(key: const Key('refusal-ok'), onPressed: () => Navigator.pop(d, field.text.trim()), child: const Text('Refuser')),
        ],
      ),
    );
    if (text == null || !mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez un motif.')));
      return;
    }
    _d
      ..state = ItemState.refused
      ..refusal = text;
    await _save(reason: 'Demande refusée');
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirm(context, title: 'Supprimer « ${_d.name} » ?', body: 'Cette suppression est définitive.', action: 'Supprimer')) return;
    setState(() => _busy = true);
    try {
      await ref.read(itemsRepositoryProvider).delete(_d.id);
      widget.onDeleted();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Suppression refusée : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = widget.rb;
    final ro = widget.readOnly;
    if (_d.id.isNotEmpty && !_noteLoaded) {
      final note = ref.watch(itemNoteProvider(_d.id));
      // Sans la note, enregistrer l'effacerait : pas de formulaire tant qu'elle n'est pas lue.
      if (note.hasError) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Note secrète illisible.'),
          TextButton(onPressed: () => ref.invalidate(itemNoteProvider(_d.id)), child: const Text('Réessayer')),
        ]);
      }
      if (!note.hasValue) return const Center(child: CircularProgressIndicator());
      _noteBefore = note.value!;
      _note.text = _noteBefore;
      _noteLoaded = true;
    }
    final checks = itemChecks(_d.copy()..name = _name.text, rb);
    final slots = math.max(categoryRules(rb, _d.category).max(_d.grade), _d.qualities.length);
    final options = qualityOptions(rb, _d.category);
    final extras = extraOptions(rb, _d.category);
    final holders = [for (final c in widget.chars) if (c.status == CharacterStatus.active || c.id == _d.characterId) c];
    final help = rulesText(rb, _d.category);
    final pending = _base.id.isNotEmpty && _base.state == ItemState.requested;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    Widget choice(String key, String label, String? value, List<String> names, ValueChanged<String?> onChanged) => KeyedSubtree(
          key: ValueKey('$key/$value/${_d.category.name}'),
          child: DropdownButtonFormField<String?>(
            key: Key(key),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
              for (final n in [...names, if (value != null && !names.contains(value)) value]) DropdownMenuItem<String?>(value: n, child: Text(n)),
            ],
            onChanged: ro ? null : onChanged,
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_d.id.isEmpty ? 'Nouvel objet' : 'Modifier l’objet'),
      const SizedBox(height: 12),
      gap(TextField(
        key: const Key('it-name'),
        controller: _name,
        enabled: !ro,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nom'),
        onChanged: (_) => setState(() {}),
      )),
      gap(Row(children: [
        Expanded(
          child: DropdownButtonFormField<ItemCategory>(
            key: const Key('it-category'),
            isExpanded: true,
            initialValue: _d.category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [for (final c in ItemCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: ro ? null : (v) => setState(() => _d.category = v ?? _d.category),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<ItemGrade>(
            key: const Key('it-grade'),
            isExpanded: true,
            initialValue: _d.grade,
            decoration: const InputDecoration(labelText: 'Gamme'),
            items: [for (final g in ItemGrade.values) DropdownMenuItem(value: g, child: Text(g.label))],
            onChanged: ro ? null : (v) => setState(() => _d.grade = v ?? _d.grade),
          ),
        ),
      ])),
      for (var i = 0; i < slots; i++)
        gap(choice('it-q$i', 'Qualité ${i + 1}', i < _d.qualities.length ? _d.qualities[i] : null, options,
            (n) => setState(() => _d.qualities = setQuality(_d.qualities, i, n)))),
      gap(choice('it-extra', 'Qualité hors limite', _d.extraQuality, extras, (n) => setState(() => _d.extraQuality = n))),
      gap(KeyedSubtree(
        key: ValueKey('holder/${_d.characterId}'),
        child: DropdownButtonFormField<String>(
          key: const Key('it-holder'),
          isExpanded: true,
          initialValue: _d.characterId.isEmpty || holders.any((c) => c.id == _d.characterId) ? _d.characterId : null,
          decoration: const InputDecoration(labelText: 'Porté par'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Personne (réserve du conte)')),
            for (final c in holders) DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: ro ? null : (id) => setState(() => _d.characterId = id ?? ''),
        ),
      )),
      gap(KeyedSubtree(
        key: ValueKey('state/${_d.state.name}'),
        child: DropdownButtonFormField<ItemState>(
          key: const Key('it-state'),
          isExpanded: true,
          initialValue: _d.state,
          decoration: const InputDecoration(labelText: 'État'),
          items: [for (final s in ItemState.values) DropdownMenuItem(value: s, child: Text(s.label))],
          onChanged: ro ? null : (v) => setState(() => _d.state = v ?? _d.state),
        ),
      )),
      if (_d.origin.isNotEmpty) gap(Text('Comment l’obtient-il ? ${_d.origin}', style: t.bodyMedium)),
      if (_d.state == ItemState.refused && _d.refusal.isNotEmpty) gap(Text('Motif du refus : ${_d.refusal}', style: t.bodyMedium)),
      gap(TextField(
        key: const Key('it-description'),
        controller: _description,
        enabled: !ro,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Description'),
      )),
      gap(TextField(
        key: const Key('it-note'),
        controller: _note,
        enabled: !ro,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Note secrète du conte'),
      )),
      if (help.isNotEmpty)
        gap(Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.navActive, borderRadius: BorderRadius.circular(6)),
          child: Text(help, style: t.bodyMedium),
        )),
      for (final e in checks.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      for (final w in checks.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      if (!ro) ...[
        const SizedBox(height: 8),
        gap(TextField(key: const Key('it-reason'), controller: _reason, decoration: const InputDecoration(labelText: 'Motif (facultatif)'))),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(key: const Key('it-save'), onPressed: _busy ? null : () => _save(), child: const Text('Enregistrer')),
          if (pending) ...[
            FilledButton(key: const Key('it-validate'), onPressed: _busy ? null : _validate, child: const Text('Valider')),
            OutlinedButton(key: const Key('it-refuse'), onPressed: _busy ? null : _refuse, child: const Text('Refuser…')),
          ],
          if (_d.id.isNotEmpty) TextButton(key: const Key('it-delete'), onPressed: _busy ? null : _delete, child: const Text('Supprimer')),
        ]),
      ],
      if (_d.id.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionTitle('Historique'),
        const SizedBox(height: 8),
        asyncView(ref.watch(itemHistoryProvider(_d.id)), TraceHistory.new),
      ],
    ]);
  }
}
```

**`lib/router.dart` :**
- ajouter l'import `items/items_screen.dart`, à sa place alphabétique ;
- après `page('/conteur/goules', const ServantsScreen()),`, ajouter `page('/conteur/objets', const ItemsScreen()),`.

**`lib/characters/characters_list_screen.dart` :** après le bouton « Goules et mortels », ajouter :

```dart
            OutlinedButton(onPressed: () => context.go('/conteur/objets'), child: const Text('Objets en jeu')),
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/items
git commit -m "feat: équipement — écran du conte « Objets en jeu » (créer, valider, refuser, confisquer, supprimer)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : écran du joueur et sections J2 et C3

**Files :**
- Create : `lib/items/character_items_screen.dart`.
- Modify :
  - `lib/router.dart` ;
  - `lib/characters/character_screen.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `test/characters/character_edit_test.dart` ;
  - `test/characters/character_screen_test.dart` ;
  - `test/characters/edit_fixes_test.dart`.
- Test : `test/items/character_items_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 à 3 (`itemStateColor`).
- Produces :
  - `CharacterItemsScreen(characterId)` (`/joueur/personnages/:id/equipement`), avec les clés `rq-name`, `rq-category`, `rq-grade`, `rq-q<i>`, `rq-origin`, `rq-send` et `rq-delete-<id>` ;
  - `ItemsSection(characterId, link)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 4 test`, puis `flutter test test/items/character_items_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/items/character_items_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/items/character_items_screen.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'item_rules_test.dart' show cane, rb;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  Item refused() => Item(
        id: 'f1',
        name: 'Fusil',
        category: ItemCategory.ranged,
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        state: ItemState.refused,
        refusal: 'Trop voyant.',
        version: 2,
      );

  Future<FakeItemsRepository> pump(WidgetTester tester, {List<Item>? items}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeItemsRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        rulebookProvider.overrideWith((ref) => rb),
        itemsRepositoryProvider.overrideWith((ref) => repo),
        characterItemsProvider('x').overrideWith((ref) => Stream.value(items ?? [cane(), refused()])),
        characterProvider('x').overrideWith((ref) => Stream.value(sample())),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterItemsScreen(characterId: 'x'))),
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

  testWidgets('demander un objet : envoyé pour le personnage, au nom du joueur', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byKey(const Key('rq-name')), 'Téléphone sécurisé');
    await choose(tester, 'rq-category', 'Matériel divers');
    await choose(tester, 'rq-q0', 'Sécurisé');
    await tester.enterText(find.byKey(const Key('rq-origin')), 'Acheté avec ses Ressources.');
    await tester.tap(find.byKey(const Key('rq-send')));
    await tester.pumpAndSettle();
    final r = repo.lastRequest!;
    expect((r.name, r.category, r.characterId, r.characterName, r.playerUid, r.origin, r.extraQuality),
        ('Téléphone sécurisé', ItemCategory.gear, 'x', 'Isaure de Valcourt', 'u1', 'Acheté avec ses Ressources.', null));
    expect(r.qualities, ['Sécurisé']);
  });

  testWidgets('demande invalide : pas d’envoi ; ni interdite ni hors limite proposées', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('rq-send')));
    await tester.pumpAndSettle();
    expect(find.text('Nom obligatoire'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.byKey(const Key('rq-extra')), findsNothing);
    await choose(tester, 'rq-category', 'Arme de mêlée');
    await tester.tap(find.byKey(const Key('rq-q0')));
    await tester.pumpAndSettle();
    expect(find.text('Brutale'), findsWidgets);
    expect(find.text('Fer froid'), findsNothing);
    expect(find.text('Chef-d’œuvre'), findsNothing);
  });

  testWidgets('liste : motif du refus, suppression d’une demande refusée seulement', (tester) async {
    final repo = await pump(tester);
    expect(find.text('Motif : Trop voyant.'), findsOneWidget);
    expect(find.byKey(const Key('rq-delete-i1')), findsNothing);
    await tester.tap(find.byKey(const Key('rq-delete-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls, ['deleteRequest:f1']);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-10-equipement.md 4 impl`.

<!-- file: lib/items/character_items_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'item.dart';
import 'item_rules.dart';
import 'items_repository.dart';
import 'items_screen.dart' show itemStateColor;

/// « Équipement » d'un personnage (J-Equipement) : ses objets et la demande d'un nouvel objet.
class CharacterItemsScreen extends ConsumerStatefulWidget {
  const CharacterItemsScreen({super.key, required this.characterId});
  final String characterId;

  @override
  ConsumerState<CharacterItemsScreen> createState() => _CharacterItemsScreenState();
}

class _CharacterItemsScreenState extends ConsumerState<CharacterItemsScreen> {
  final _name = TextEditingController();
  final _origin = TextEditingController();
  Item _draft = Item(state: ItemState.requested, category: ItemCategory.gear);
  bool _tried = false;
  bool _busy = false;

  /// Incrémenté à chaque envoi réussi : les listes déroulantes repartent à vide.
  int _form = 0;

  @override
  void dispose() {
    _name.dispose();
    _origin.dispose();
    super.dispose();
  }

  Item _request(Character c, String uid) => _draft.copy()
    ..name = _name.text.trim()
    ..origin = _origin.text.trim()
    ..characterId = c.id
    ..characterName = c.name
    ..playerUid = uid
    ..state = ItemState.requested;

  Future<void> _send(Character c, Rulebook rb) async {
    final me = ref.read(currentUserProvider).value;
    final by = actorOf(me);
    if (me == null || by == null) return;
    final r = _request(c, me.uid);
    if (itemChecks(r, rb, byPlayer: true).errors.isNotEmpty) {
      setState(() => _tried = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(itemsRepositoryProvider).request(r, by);
      messenger.showSnackBar(const SnackBar(content: Text('Demande envoyée au conte.')));
      if (mounted) {
        setState(() {
          _name.clear();
          _origin.clear();
          _draft = Item(state: ItemState.requested, category: ItemCategory.gear);
          _tried = false;
          _form++;
        });
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Envoi refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Item i) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirm(context, title: 'Supprimer la demande ?', body: '« ${i.name} » sera supprimé.', action: 'Supprimer')) return;
    try {
      await ref.read(itemsRepositoryProvider).deleteRequest(i.id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Suppression refusée : réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = ref.watch(rulebookProvider) ?? const Rulebook();
    final c = ref.watch(characterProvider(widget.characterId)).value;
    return asyncView(ref.watch(characterItemsProvider(widget.characterId)), (items) {
      final list = Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun objet.', style: t.bodyMedium)),
          for (final i in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 200, child: Text(i.name, style: t.titleSmall)),
                  SizedBox(width: 140, child: Text(i.category.label, style: t.bodySmall)),
                  SizedBox(width: 220, child: Text(itemQualitiesText(i), style: t.bodySmall)),
                  SizedBox(width: 90, child: Text(i.grade.label, style: t.bodySmall)),
                  Text(i.state.label, style: t.bodySmall?.copyWith(color: itemStateColor(i.state), fontWeight: FontWeight.w600)),
                  if (i.state == ItemState.requested || i.state == ItemState.refused)
                    TextButton(key: Key('rq-delete-${i.id}'), onPressed: () => _delete(i), child: const Text('Supprimer')),
                ]),
                if (i.state == ItemState.refused && i.refusal.isNotEmpty) Text('Motif : ${i.refusal}', style: t.bodySmall),
              ]),
            ),
        ]),
      );
      final form = c == null || c.status != CharacterStatus.active ? null : _requestForm(context, c, rb);
      final title = PageTitle('Équipement',
          subtitle: c == null ? null : 'Ce que ${c.name} possède. Un nouvel objet est validé par le conte avant d’entrer en jeu.');
      if (!isWide(context)) {
        return PageBody(children: [title, const SizedBox(height: 20), list, if (form != null) ...[const SizedBox(height: 20), form]]);
      }
      return PageBody(children: [
        title,
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: list),
          if (form != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: form)],
        ]),
      ]);
    }, onRetry: () => ref.invalidate(characterItemsProvider(widget.characterId)));
  }

  Widget _requestForm(BuildContext context, Character c, Rulebook rb) {
    final t = Theme.of(context).textTheme;
    final checks = itemChecks(_request(c, ''), rb, byPlayer: true);
    final showErrors = _tried || _name.text.trim().isNotEmpty;
    final slots = categoryRules(rb, _draft.category).max(_draft.grade);
    final options = qualityOptions(rb, _draft.category);
    final help = rulesText(rb, _draft.category);
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Demander un objet'),
        const SizedBox(height: 12),
        gap(TextField(
          key: const Key('rq-name'),
          controller: _name,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Nom'),
          onChanged: (_) => setState(() {}),
        )),
        gap(Row(children: [
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('rq-category/$_form'),
              child: DropdownButtonFormField<ItemCategory>(
                key: const Key('rq-category'),
                isExpanded: true,
                initialValue: _draft.category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [for (final cat in ItemCategory.values) DropdownMenuItem(value: cat, child: Text(cat.label))],
                onChanged: (v) => setState(() => _draft
                  ..category = v ?? _draft.category
                  ..qualities = []),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('rq-grade/$_form'),
              child: DropdownButtonFormField<ItemGrade>(
                key: const Key('rq-grade'),
                isExpanded: true,
                initialValue: _draft.grade,
                decoration: const InputDecoration(labelText: 'Gamme'),
                items: [
                  for (final g in ItemGrade.values)
                    DropdownMenuItem(value: g, child: Text('${g.label} · ${categoryRules(rb, _draft.category).max(g)} qualité(s)')),
                ],
                onChanged: (v) => setState(() => _draft.grade = v ?? _draft.grade),
              ),
            ),
          ),
        ])),
        for (var i = 0; i < slots; i++)
          gap(KeyedSubtree(
            key: ValueKey('rq-q$i/$_form/${_draft.category.name}/${_draft.qualities.join('|')}'),
            child: DropdownButtonFormField<String?>(
              key: Key('rq-q$i'),
              isExpanded: true,
              initialValue: i < _draft.qualities.length ? _draft.qualities[i] : null,
              decoration: InputDecoration(labelText: 'Qualité ${i + 1}'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
                for (final n in options) DropdownMenuItem<String?>(value: n, child: Text(n)),
              ],
              onChanged: (n) => setState(() => _draft.qualities = setQuality(_draft.qualities, i, n)),
            ),
          )),
        gap(TextField(
          key: const Key('rq-origin'),
          controller: _origin,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Comment l’obtient-il ?'),
        )),
        if (help.isNotEmpty) gap(Text(help, style: t.bodySmall)),
        if (showErrors)
          for (final e in checks.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        for (final w in checks.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        const SizedBox(height: 8),
        FilledButton(key: const Key('rq-send'), onPressed: _busy ? null : () => _send(c, rb), child: const Text('Envoyer la demande')),
      ]),
    );
  }
}

/// Section « Équipement » d'une fiche (J2, C3) : objets du personnage et lien.
class ItemsSection extends ConsumerWidget {
  const ItemsSection({super.key, required this.characterId, required this.link});
  final String characterId;
  final String link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(characterItemsProvider(characterId));
    final items = async.value ?? const <Item>[];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Équipement'),
        const SizedBox(height: 8),
        if (async.hasError)
          Text('Équipement indisponible.', style: t.bodySmall)
        else if (!async.hasValue)
          const LinearProgressIndicator()
        else if (items.isEmpty)
          Text('Aucun objet.', style: t.bodySmall),
        for (final i in items) Text('${i.name} · ${itemQualitiesText(i)} · ${i.state.label}', style: t.bodyMedium),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go(link), child: const Text('Voir l’équipement'))),
      ]),
    );
  }
}
```

**`lib/router.dart` :**
- ajouter l'import `items/character_items_screen.dart` ;
- après la route `/joueur/personnages/:id/lieux`, ajouter :

```dart
          GoRoute(
            path: '/joueur/personnages/:id/equipement',
            builder: (_, s) => CharacterItemsScreen(characterId: s.pathParameters['id']!),
          ),
```

**`lib/characters/character_screen.dart` :**
- ajouter l'import `../items/character_items_screen.dart` ;
- après la ligne `PlacesSection(...)` de la vue fiche, ajouter :

```dart
          const SizedBox(height: 20),
          ItemsSection(characterId: id, link: basePath.startsWith('/joueur') ? '$basePath/equipement' : '/conteur/objets'),
```

**`lib/characters/character_edit_screen.dart` :**
- ajouter l'import `../items/character_items_screen.dart` ;
- après `PlacesSection(characterId: latest.id, link: '/conteur/lieux'),`, ajouter :

```dart
              const SizedBox(height: 20),
              ItemsSection(characterId: latest.id, link: '/conteur/objets'),
```

**Tests existants :**
- dans les `overrides` de `test/characters/character_edit_test.dart`, `test/characters/character_screen_test.dart` et `test/characters/edit_fixes_test.dart`, ajouter `noItems,` après `noServantFiles,` ;
- dans `test/characters/character_edit_test.dart`, ajouter :

```dart
  testWidgets('C3 : section « Équipement »', (tester) async {
    await pump(tester, sample());
    await tester.pumpAndSettle();
    expect(find.text('ÉQUIPEMENT'), findsOneWidget);
    expect(find.text('Aucun objet.'), findsOneWidget);
  });
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: équipement — écran du joueur (demander un objet) et sections J2 et C3" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
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
  - puis fusion de `equipement` dans `main`.
