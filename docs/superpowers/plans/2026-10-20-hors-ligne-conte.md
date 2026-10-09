# Partie hors ligne côté conte (sous-projet 8d) : plan d’implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** pendant une partie, le conte travaille sans réseau. Il consulte les fiches figées et saisit péchés, événements et gorgées. Une file montre ce qui attend le réseau, et les doublons de péchés sont signalés pour être tranchés. Les données de l’appareil s’effacent après la partie ou à la demande.

**Architecture :**
- **Calculs purs :**
  - `conflicts` dans `lib/morality/morality_rules.dart` (doublons de péchés) ;
  - `lib/offline/sync_queue.dart` (lignes de la file, textes) ;
  - `lib/offline/wipe.dart` (politique d’effacement, réglages de l’appareil).
- **Garde hors ligne :** `lib/offline/offline.dart` fournit `offlineProvider`, `OfflineError` et `refusalText`. Les dépôts `CharacterRepository` et `GamesRepository` refusent hors ligne toute écriture de fiche faite par l’équipe.
- **Dépôt de l’écran :** `lib/offline/offline_game_repository.dart`, qui suit péchés et événements avec leurs métadonnées, prépare l’appareil et synchronise.
- **Effacement :** `DeviceSession.wipe` / `wipeIfDue`, déclenchés depuis `router.dart`.
- **Écran :** `lib/offline/offline_game_screen.dart`, route `/conteur/gel/hors-ligne`, bouton sur l’écran du gel.

**Tech Stack :** Flutter, Riverpod 3 (génération), Cloud Firestore (cache persistant, métadonnées des instantanés), `shared_preferences`. Aucune dépendance nouvelle.

**Spec :** `docs/superpowers/specs/2026-10-20-hors-ligne-conte-design.md`.

**Maquette :** canvas https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planche `C-HorsLigne.dc.html` (outil Artifact, `action: read`, `path: project/C-HorsLigne.dc.html`).

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md <N> [test|impl]`. L’outil n’écrit que des fichiers complets : les modifications de fichiers existants sont décrites et se font à la main ;
  - textes en français, avec l’apostrophe typographique ’ dans les textes affichés ;
  - analyseur propre ; pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` exactement ;
  - ne jamais commiter `bash.exe.stackdump`, `rules_test/bash.exe.stackdump`, `CLAUDE.md` ni `firestore-debug.log`.
- **Branche :** `hors-ligne-conte`, déjà créée ; la spec y est commitée.
- **Code généré :** `dart run build_runner build --delete-conflicting-outputs` après un nouveau `@riverpod`. Si des `.g.dart` sans rapport changent (empreintes seulement), les commiter avec la tâche.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Règles Firestore :** tests depuis `rules_test/` avec `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Textes fixes :**
  - « Pas de réseau : les modifications de la fiche attendent le réseau. » ;
  - « Aucune partie en cours » ;
  - « Partie préparée sur cet appareil. » ;
  - « Préparation impossible : vérifiez le réseau et réessayez. » ;
  - « Tout est envoyé. » ;
  - « Pas de réseau : les saisies partiront dès son retour. » ;
  - « Aucune saisie depuis le gel. » ;
  - « Ce que vous ouvrez sur cet appareil reste aussi dans son cache. » ;
  - « Les appareils des joueurs ne reçoivent que leurs propres fiches, sans notes ni événements secrets. » ;
  - « Cette partie n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau. » ;
  - « Effacer les données de cet appareil ? Vous restez connecté. » ;
  - « Consulter les fiches figées et le référentiel » ;
  - « Saisir péchés, événements et gorgées » ;
  - « Pas de modification de la fiche, de validation de demande ni d’XP : elles attendent le réseau » ;
  - « 7 jours après la partie », « Au dégel », « Jamais » ;
  - « Péché niveau 2 · remords réussi », « remords échoué », « sans remords », « Événement · <titre> » ;
  - « En attente », « Envoyé », « Conflit » ;
  - « <A> et <B> ont saisi chacun un péché de niveau 2 le 3 oct. S’agit-il du même péché ? » ;
  - « Même péché : garder celui de <A> », « Deux péchés distincts », « +1 trait de Bête » ;
  - « Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 21h02 ».
- **Leçons des lots précédents :**
  - un `ref.read` d’un provider pas encore écouté renvoie null : l’écouter tôt (ici, dans `router.dart`) ;
  - rangées de boutons en `Wrap` (390 px) ;
  - tout écran qui lit un nouveau provider oblige ses tests à le surcharger ;
  - `SectionTitle` affiche son texte en capitales : les tests cherchent « CONFLIT · ISAURE DE VALCOURT » ;
  - hors ligne, le futur d’une écriture Firestore ne se termine qu’au retour du réseau : ne jamais bloquer l’écran en l’attendant.

## Review Focus

1. **Conflit tranché hors ligne :** l’écriture reste en file. L’écran ne doit pas rester bloqué en attendant son futur, et les autres boutons restent utilisables. Test : tâche 6.
2. **Membre de l’équipe sur sa propre fiche, hors ligne :** il agit en joueur. La garde ne doit pas bloquer son envoi de fiche ni ses demandes. Test : tâche 3.
3. **Effacement programmé avec des saisies en attente :** il est retardé, et aucune saisie n’est perdue. Test : tâche 4.
4. **Événement ancien modifié hors ligne :** il apparaît dans la file « En attente », même s’il a été créé avant le gel. Test : tâche 5.
5. **« Synchroniser maintenant » sans réseau :** le bouton ne tourne pas indéfiniment ; un message dit que les saisies partiront plus tard. Test : tâche 6.

---

### Task 1 : péchés, auteur et conflits

**Files :**
- Modify : `lib/morality/sin.dart` (réécrit en entier ci-dessous).
- Modify : `lib/morality/morality_rules.dart` (ajout en fin de fichier).
- Modify : `lib/morality/sins_repository.dart` (méthode `markDistinct`).
- Modify : `test/fakes.dart` (`FakeSinsRepository.markDistinct`).
- Test : `test/morality/sin_conflicts_test.dart`.

**Interfaces :**
- Consumes : `dayOf` (`sin.dart`).
- Produces :
  - `Sin` reçoit `byUid` (String, `''` par défaut), `createdAt` (DateTime?, final) et `distinct` (bool) ;
  - `List<(Sin, Sin)> conflicts(List<Sin> sins)` ;
  - `SinsRepository.markDistinct(String characterId, List<Sin> sins, Actor by)` → `Future<void>` ;
  - `FakeSinsRepository.calls` reçoit `'distinct:<characterId>:<id>,<id>'`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 1 test`, puis `flutter test test/morality/sin_conflicts_test.dart`. Échec attendu : `byUid`, `createdAt`, `distinct` et `conflicts` n’existent pas.

<!-- file: test/morality/sin_conflicts_test.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/morality/morality_rules.dart';
import 'package:portail_met/morality/sin.dart';

Sin s(String id, String by, {int level = 2, DateTime? day, DateTime? at, bool locked = false, bool distinct = false}) => Sin(
      id: id,
      date: day ?? DateTime(2026, 10, 3),
      level: level,
      byUid: by,
      byName: by,
      createdAt: at,
      lossApplied: locked,
      distinct: distinct,
    );

void main() {
  test('même jour, même niveau, deux auteurs : un conflit, le plus ancien d’abord', () {
    final c = conflicts([s('a', 'marc', at: DateTime(2026, 10, 3, 22, 47)), s('b', 'lea', at: DateTime(2026, 10, 3, 22, 44))]);
    expect(c, hasLength(1));
    expect(c.single.$1.id, 'b');
    expect(c.single.$2.id, 'a');
  });

  test('même auteur, autre niveau, autre jour : pas de conflit', () {
    expect(conflicts([s('a', 'lea'), s('b', 'lea')]), isEmpty);
    expect(conflicts([s('a', 'lea'), s('b', 'marc', level: 3)]), isEmpty);
    expect(conflicts([s('a', 'lea'), s('b', 'marc', day: DateTime(2026, 10, 4))]), isEmpty);
  });

  test('péché verrouillé, marqué distinct ou sans auteur : pas de conflit', () {
    expect(conflicts([s('a', 'lea', locked: true), s('b', 'marc')]), isEmpty);
    expect(conflicts([s('a', 'lea', distinct: true), s('b', 'marc')]), isEmpty);
    expect(conflicts([s('a', ''), s('b', 'marc')]), isEmpty);
  });

  test('trois péchés : une seule paire, chaque péché une fois', () {
    final c = conflicts([
      s('a', 'lea', at: DateTime(2026, 10, 3, 22)),
      s('b', 'marc', at: DateTime(2026, 10, 3, 22, 5)),
      s('c', 'marc', at: DateTime(2026, 10, 3, 22, 10)),
    ]);
    expect(c, hasLength(1));
    expect(c.single.$1.id, 'a');
    expect(c.single.$2.id, 'b');
  });

  test('péché en attente (sans heure du serveur) : apparié après les péchés envoyés', () {
    final c = conflicts([s('p', 'marc'), s('a', 'lea', at: DateTime(2026, 10, 3, 22))]);
    expect(c.single.$1.id, 'a');
    expect(c.single.$2.id, 'p');
  });

  test('toMap : « distinct » écrit seulement s’il est vrai', () {
    expect(s('a', 'lea').toMap().containsKey('distinct'), isFalse);
    expect((s('a', 'lea')..distinct = true).toMap()['distinct'], isTrue);
  });

  test('fromMap : auteur, création et « distinct » ; copy les garde', () {
    final sin = Sin.fromMap('a', {
      'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'level': 2,
      'byUid': 'lea',
      'byName': 'Léa G.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 3, 22, 44)),
      'distinct': true,
    });
    expect(sin.byUid, 'lea');
    expect(sin.createdAt, DateTime(2026, 10, 3, 22, 44));
    expect(sin.distinct, isTrue);
    final copy = sin.copy();
    expect(copy.byUid, 'lea');
    expect(copy.createdAt, DateTime(2026, 10, 3, 22, 44));
    expect(copy.distinct, isTrue);
    expect(Sin.fromMap('b', const {}).distinct, isFalse);
  });
}
```

- [ ] **Step 2 : modèle et calcul**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 1 impl` (réécrit `lib/morality/sin.dart`).

<!-- file: lib/morality/sin.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Test de remords d'un péché.
enum Remorse {
  success('Réussi (−1)', 'Réussi (−1 trait)'),
  failed('Échoué', 'Échoué'),
  none('Non tenté', 'Non tenté');

  const Remorse(this.label, this.choice);

  /// Libellé du tableau.
  final String label;

  /// Libellé du choix dans le formulaire.
  final String choice;

  static Remorse parse(String? s) => values.where((r) => r.name == s).firstOrNull ?? none;
}

/// La soirée d'une date : le jour, à minuit.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Péché d'une soirée (`characters/{id}/sins/{s}`), saisi par le conte (sous-projet 7b).
class Sin {
  Sin({
    required this.id,
    required this.date,
    this.level = 1,
    this.what = '',
    this.remorse = Remorse.none,
    this.lossApplied = false,
    this.byName = '',
    this.byUid = '',
    this.createdAt,
    this.distinct = false,
  });

  factory Sin.fromMap(String id, Map<String, dynamic> m) => Sin(
        id: id,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime(1900),
        level: (m['level'] as num?)?.toInt() ?? 1,
        what: m['what'] as String? ?? '',
        remorse: Remorse.parse(m['remorse'] as String?),
        lossApplied: m['lossApplied'] == true,
        byName: m['byName'] as String? ?? '',
        byUid: m['byUid'] as String? ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        distinct: m['distinct'] == true,
      );

  final String id;
  DateTime date;
  int level;
  String what;
  Remorse remorse;

  /// Vrai une fois la perte de la soirée appliquée : le péché ne se modifie plus.
  bool lossApplied;
  String byName;

  /// Auteur de la dernière écriture.
  String byUid;

  /// Null tant que la création n'est pas confirmée par le serveur.
  final DateTime? createdAt;

  /// Tranché « distinct » d'un péché voisin (sous-projet 8d) : il ne fait plus conflit.
  bool distinct;

  /// `distinct` n'est écrit que s'il est vrai : les anciens documents ne changent pas.
  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(dayOf(date)),
        'level': level,
        'what': what,
        'remorse': remorse.name,
        'lossApplied': lossApplied,
        if (distinct) 'distinct': true,
      };

  Sin copy() => Sin(
        id: id,
        date: date,
        level: level,
        what: what,
        remorse: remorse,
        lossApplied: lossApplied,
        byName: byName,
        byUid: byUid,
        createdAt: createdAt,
        distinct: distinct,
      );
}

/// Document d'un nouveau péché : exactement les clés permises par les règles.
Map<String, dynamic> newSinData(Sin s, String byUid, String byName) {
  final now = FieldValue.serverTimestamp();
  return {...s.toMap(), 'byUid': byUid, 'byName': byName, 'createdAt': now, 'updatedAt': now};
}
```

Ajouter à la fin de `lib/morality/morality_rules.dart` :

```dart
/// Péchés saisis deux fois (sous-projet 8d) : même jour, même niveau, deux auteurs, ni verrouillés ni tranchés « distincts ».
/// Chaque péché entre dans une paire au plus, dans l'ordre de création ; les péchés en attente (sans heure) viennent en dernier.
List<(Sin, Sin)> conflicts(List<Sin> sins) {
  final open = sins.where((s) => !s.lossApplied && !s.distinct && s.byUid.isNotEmpty).toList()
    ..sort((a, b) {
      final t = (a.createdAt ?? DateTime(9999)).compareTo(b.createdAt ?? DateTime(9999));
      return t != 0 ? t : a.id.compareTo(b.id);
    });
  final used = <Sin>{};
  final pairs = <(Sin, Sin)>[];
  for (var i = 0; i < open.length; i++) {
    final a = open[i];
    if (used.contains(a)) continue;
    for (var j = i + 1; j < open.length; j++) {
      final b = open[j];
      if (used.contains(b) || b.byUid == a.byUid || b.level != a.level || dayOf(b.date) != dayOf(a.date)) continue;
      used
        ..add(a)
        ..add(b);
      pairs.add((a, b));
      break;
    }
  }
  return pairs;
}
```

Dans `lib/morality/sins_repository.dart`, ajouter après `delete` :

```dart
  /// « Deux péchés distincts » (sous-projet 8d) : les deux sortent du conflit, en un lot.
  Future<void> markDistinct(String characterId, List<Sin> sins, Actor by) {
    final batch = _db.batch();
    for (final s in sins) {
      batch.update(_col(characterId).doc(s.id), {
        'distinct': true,
        'byUid': by.uid,
        'byName': by.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }
```

Dans `test/fakes.dart`, classe `FakeSinsRepository`, ajouter après `delete` :

```dart
  @override
  Future<void> markDistinct(String characterId, List<Sin> sins, Actor by) async {
    calls.add('distinct:$characterId:${[for (final s in sins) s.id].join(',')}');
    if (error != null) throw error!;
  }
```

- [ ] **Step 3 : tests verts**

Run : `flutter test test/morality/` puis `flutter analyze`. Tout passe et l’analyseur est propre.

- [ ] **Step 4 : commit**

```bash
git add lib/morality/sin.dart lib/morality/morality_rules.dart lib/morality/sins_repository.dart test/fakes.dart test/morality/sin_conflicts_test.dart
git commit -m "feat: hors ligne conte — conflits de péchés, auteur et « distinct »

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2 : règles Firestore, « distinct » et partie préparée oubliée

**Files :**
- Modify : `firestore.rules` (`sinValid`, bloc `users/{uid}/devices/{d}`).
- Test : `rules_test/offline_staff.test.js`.

**Interfaces :**
- Produces :
  - un péché accepte la clé `distinct` (booléen) ;
  - un appareil peut remettre `gameId` et `preparedAt` à nul. La tâche 4 s’en sert (`DevicesRepository.clearPrepared`).

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 2 test`, puis lancer les tests de règles (voir Global Constraints). Échec attendu : `distinct` refusé, `preparedAt: null` refusé.

<!-- file: rules_test/offline_staff.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const sin = (over) => ({
  date: new Date('2026-10-03T00:00:00'), level: 2, what: 'Témoin rendu fou', remorse: 'success', lossApplied: false,
  byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c1/sins/a'), sin({ byUid: 'marc', byName: 'Marc' }));
    await setDoc(doc(db, 'characters/c1/sins/b'), sin({}));
    await setDoc(doc(db, 'characters/c1/sins/locked'), sin({ lossApplied: true }));
    await setDoc(doc(db, 'users/lea/devices/d1'), {
      name: 'Navigateur · Windows', web: true, lastSeen: new Date('2026-10-03T17:00:00'), gameId: 'g2', preparedAt: new Date('2026-10-03T17:30:00'), revokedAt: null,
    });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const mark = () => ({ distinct: true, byUid: 'lea', byName: 'lea', updatedAt: new Date() });

test('« distinct » : accepté à la création et en lot sur deux péchés', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/sins/n1'), sin({ distinct: true })));
  const b = writeBatch(lea);
  b.update(doc(lea, 'characters/c1/sins/a'), mark());
  b.update(doc(lea, 'characters/c1/sins/b'), mark());
  await assertSucceeds(b.commit());
});

test('« distinct » : booléen seulement ; ni joueur, ni narrateur, ni péché verrouillé', async () => {
  await assertFails(setDoc(doc(as('lea'), 'characters/c1/sins/n2'), sin({ distinct: 'oui' })));
  await assertFails(updateDoc(doc(as('zoe'), 'characters/c1/sins/a'), { ...mark(), byUid: 'zoe' }));
  await assertFails(updateDoc(doc(as('julien'), 'characters/c1/sins/a'), { ...mark(), byUid: 'julien' }));
  await assertFails(updateDoc(doc(as('lea'), 'characters/c1/sins/locked'), mark()));
});

test('appareil : la partie préparée peut être oubliée, pas antidatée', async () => {
  const lea = as('lea');
  await assertSucceeds(updateDoc(doc(lea, 'users/lea/devices/d1'), { gameId: null, preparedAt: null }));
  await assertFails(updateDoc(doc(lea, 'users/lea/devices/d1'), { gameId: 'g2', preparedAt: new Date('2020-01-01T00:00:00') }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/lea/devices/d1'), { gameId: null, preparedAt: null }));
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules`, bloc `match /sins/{s}`, fonction `sinValid` :
- ajouter `'distinct'` à la liste de `hasOnly` (après `'lossApplied'`) ;
- ajouter la ligne `&& d.get('distinct', false) is bool` après `&& d.lossApplied is bool`.

Dans le bloc `match /users/{uid}/devices/{d}`, remplacer :

```
        && sameOrNow('lastSeen') && sameOrNow('preparedAt') && sameOrNow('revokedAt')
```

par :

```
        && sameOrNow('lastSeen') && sameOrNow('revokedAt')
        // Partie préparée oubliée avant l'effacement des données de l'appareil (sous-projet 8d).
        && (sameOrNow('preparedAt') || request.resource.data.get('preparedAt', null) == null)
```

- [ ] **Step 3 : tests verts**

Lancer toute la suite des règles, pour que `sins.test.js` et `offline.test.js` restent verts.

- [ ] **Step 4 : commit**

```bash
git add firestore.rules rules_test/offline_staff.test.js
git commit -m "feat: hors ligne conte — règles, péchés distincts et partie préparée oubliée

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3 : garde hors ligne des écritures de fiche

**Files :**
- Create : `lib/offline/offline.dart` (+ `offline.g.dart` généré).
- Modify :
  - `lib/characters/character_repository.dart` ;
  - `lib/games/games_repository.dart` ;
  - `lib/xp/xp_repository.dart` (`_eachSheet`).
- Modify (messages) :
  - `lib/characters/character_edit_screen.dart` ;
  - `lib/morality/morality_staff.dart`, `lib/morality/derangements_staff.dart` ;
  - `lib/titles/title_blocks.dart`, `lib/titles/title_holders.dart` ;
  - `lib/allies/allies_admin_screen.dart` ;
  - `lib/games/freeze_screen.dart` ;
  - `lib/xp/request_review.dart`, `lib/xp/corrections_screen.dart` ;
  - `lib/creation/validation_screen.dart`.
- Test : `test/offline/offline_guard_test.dart`.

**Interfaces :**
- Produces :
  - `offlineEditText` (String) ;
  - `class OfflineError implements Exception` (`const OfflineError()`) ;
  - `String refusalText(Object e, String fallback)` ;
  - `offlineProvider` (`Stream<bool>`, keepAlive) ;
  - `CharacterRepository(FirebaseFirestore db, {bool Function()? offline})` ;
  - `GamesRepository(FirebaseFirestore db, {bool Function()? offline})`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 3 test`, puis `flutter test test/offline/offline_guard_test.dart`. Échec attendu : `offline.dart` n’existe pas.

<!-- file: test/offline/offline_guard_test.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/offline/offline.dart';

import '../characters/character_test.dart' show sample;
import '../games/game_rules_test.dart' show frozenGame;

/// Firestore absent : toute écriture qui passe la garde le touche et lève StateError.
class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Firestore touché');
}

void main() {
  const lea = Actor('lea', 'Léa G.');

  test('hors ligne : une modification de fiche par l’équipe est refusée sans rien écrire', () {
    final repo = CharacterRepository(_NoDb(), offline: () => true);
    expect(() => repo.setBonus(sample(), 2, lea), throwsA(isA<OfflineError>()));
    expect(() => repo.saveEdit(sample(), sample()..humanity = 4, 'Motif', lea), throwsA(isA<OfflineError>()));
  });

  test('hors ligne : le joueur sur sa propre fiche passe la garde (Review Focus 2)', () {
    final repo = CharacterRepository(_NoDb(), offline: () => true);
    // sample() appartient à u1 : la garde laisse passer, Firestore (absent ici) est touché.
    expect(() => repo.submit(sample(), const Actor('u1', 'Camille R.')), throwsStateError);
  });

  test('en ligne : la garde laisse passer', () {
    final repo = CharacterRepository(_NoDb(), offline: () => false);
    expect(() => repo.setBonus(sample(), 2, lea), throwsStateError);
    expect(() => CharacterRepository(_NoDb()).setBonus(sample(), 2, lea), throwsStateError);
  });

  test('gel : figer, lever, corriger refusés hors ligne', () {
    final repo = GamesRepository(_NoDb(), offline: () => true);
    final g = frozenGame();
    expect(() => repo.freeze(g.date, g.until, [sample()], lea), throwsA(isA<OfflineError>()));
    expect(() => repo.lift(g, lea), throwsA(isA<OfflineError>()));
    expect(() => repo.correct(g, sample(), 'Erreur', lea), throwsA(isA<OfflineError>()));
    expect(() => GamesRepository(_NoDb(), offline: () => false).lift(g, lea), throwsStateError);
  });

  test('texte du refus : celui du hors ligne, sinon celui de l’écran', () {
    expect(refusalText(const OfflineError(), 'Enregistrement refusé : réessayez.'), offlineEditText);
    expect(refusalText(Exception('refus'), 'Enregistrement refusé : réessayez.'), 'Enregistrement refusé : réessayez.');
    expect(const OfflineError().toString(), 'Pas de réseau : les modifications de la fiche attendent le réseau.');
  });
}
```

- [ ] **Step 2 : garde**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 3 impl`, puis `dart run build_runner build --delete-conflicting-outputs`.

<!-- file: lib/offline/offline.dart -->
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';

part 'offline.g.dart';

const offlineEditText = 'Pas de réseau : les modifications de la fiche attendent le réseau.';

/// Écriture de fiche tentée hors ligne par l'équipe (sous-projet 8d) : refusée tout de suite, rien ne part en file.
/// Sinon, elle pourrait être rejetée au retour du réseau si la fiche a changé entre-temps (version).
class OfflineError implements Exception {
  const OfflineError();

  @override
  String toString() => offlineEditText;
}

/// Texte d'un enregistrement refusé : celui du hors ligne, ou celui de l'écran.
String refusalText(Object e, String fallback) => e is OfflineError ? offlineEditText : fallback;

/// Vrai quand les parties viennent du cache de l'appareil : pas de réseau. Faux tant que rien n'est arrivé, et sans compte.
@Riverpod(keepAlive: true)
Stream<bool> offline(Ref ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  if (uid == null) return Stream.value(false);
  return ref.watch(firestoreProvider).collection('games').snapshots(includeMetadataChanges: true).map((q) => q.metadata.isFromCache);
}
```

Dans `lib/characters/character_repository.dart` :
- importer `'../offline/offline.dart'` ;
- ajouter au-dessus de la classe :

```dart
bool _online() => false;
```

- remplacer le constructeur et ajouter le champ et la garde :

```dart
class CharacterRepository {
  CharacterRepository(this._db, {bool Function()? offline}) : _offline = offline ?? _online;

  final FirebaseFirestore _db;

  /// Vrai sans réseau (sous-projet 8d).
  final bool Function() _offline;

  /// Hors ligne, l'équipe ne modifie pas la fiche d'un autre ; le joueur, lui, garde la file de Firestore.
  void _guard(Character c, Actor by) {
    if (_offline() && by.uid != c.playerUid) throw const OfflineError();
  }
```

- en première ligne du corps de `stageEdit`, et en première ligne de `_commit` avant `_db.batch()`, ajouter `_guard(c, by);`. `_commit` étant écrit avec `=>`, le convertir en bloc `{ _guard(c, by); final batch = ...; ...; return batch.commit(); }` ;
- dans le provider :

```dart
@Riverpod(keepAlive: true)
CharacterRepository characterRepository(Ref ref) =>
    CharacterRepository(ref.watch(firestoreProvider), offline: () => ref.read(offlineProvider).value ?? false);
```

Dans `lib/games/games_repository.dart` :
- importer `'../offline/offline.dart'` ;
- ajouter au-dessus de la classe :

```dart
bool _online() => false;
```

- remplacer le constructeur :

```dart
  GamesRepository(this._db, {bool Function()? offline}) : _offline = offline ?? _online;

  final FirebaseFirestore _db;

  /// Vrai sans réseau : le gel et ses corrections attendent le réseau (sous-projet 8d).
  final bool Function() _offline;

  void _guard() {
    if (_offline()) throw const OfflineError();
  }
```

- en première ligne de `freeze`, `lift` et `correct`, ajouter `_guard();`. `lift` et `correct` sont écrits avec `=>` : les convertir en blocs `{ _guard(); return ...; }` ;
- dans le provider :

```dart
@Riverpod(keepAlive: true)
GamesRepository gamesRepository(Ref ref) =>
    GamesRepository(ref.watch(firestoreProvider), offline: () => ref.read(offlineProvider).value ?? false);
```

Dans `lib/xp/xp_repository.dart`, méthode `_eachSheet`, déplacer `stage(batch, item);` dans le `try`, avant `await batch.commit();`. Une fiche refusée par la garde rejoint ainsi la liste des noms refusés, comme une fiche modifiée entre-temps.

- [ ] **Step 3 : messages des écrans**

Dans chacun des blocs ci-dessous :
- remplacer `catch (_)` par `catch (e)` ;
- passer le texte affiché par `refusalText(e, <texte actuel>)` ;
- importer `'../offline/offline.dart'` (chemin relatif au fichier).

Le texte actuel ne change pas pour les autres erreurs.

| Fichier | Bloc |
|---|---|
| `lib/characters/character_edit_screen.dart` | étreinte (« Modifié entre-temps : rechargez la page. »), `_save` (« Enregistrement refusé : la fiche a peut-être été modifiée entre-temps… »), bonus (« Enregistrement refusé : réessayez. ») |
| `lib/morality/morality_staff.dart` | `_write` |
| `lib/morality/derangements_staff.dart` | enregistrement |
| `lib/titles/title_blocks.dart` | `_save`, après `assign` |
| `lib/titles/title_holders.dart` | `_assign` |
| `lib/allies/allies_admin_screen.dart` | conversion des anciens historiques (`saveEdit`) |
| `lib/games/freeze_screen.dart` | `_freeze`, `_lift`, `_correct` |
| `lib/xp/request_review.dart` | décision |
| `lib/xp/corrections_screen.dart` | correction |
| `lib/creation/validation_screen.dart` | décision |

Exemple pour `morality_staff.dart` :

```dart
    } catch (e) {
      final latest = ref.read(characterProvider(c.id)).value;
      final moved = latest != null && latest.version != c.version;
      messenger.showSnackBar(SnackBar(content: Text(refusalText(e, moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.'))));
      return false;
```

Pour `freeze_screen.dart`, bloc `_freeze` :

```dart
    } catch (e) {
      if (!mounted) return;
      // Un autre membre du conte a pu figer entre-temps : les règles refusent un second gel.
      final other = runningGame(ref.read(gamesProvider).value ?? const <Game>[], widget.now());
      setState(() => _error = refusalText(e, other != null ? 'Un gel est déjà en cours.' : 'Enregistrement refusé : réessayez.'));
```

Si un `Text` devient non constant, retirer le `const` du `SnackBar` ou du `Text`.

- [ ] **Step 4 : tests verts**

Run : `flutter test test/offline/offline_guard_test.dart`, puis `flutter test`, puis `flutter analyze`. La suite entière passe : les écrans testés utilisent des dépôts factices et ne passent donc pas par la garde.

- [ ] **Step 5 : commit**

```bash
git add lib/offline/offline.dart lib/offline/offline.g.dart lib/characters/ lib/games/ lib/xp/ lib/morality/ lib/titles/ lib/allies/ lib/creation/ test/offline/offline_guard_test.dart
git commit -m "feat: hors ligne conte — garde des écritures de fiche, message « Pas de réseau »

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4 : effacement des données de l’appareil

**Files :**
- Create : `lib/offline/wipe.dart`.
- Modify :
  - `lib/offline/device_session.dart` (réécrit en entier ci-dessous) ;
  - `lib/offline/devices_repository.dart` (`clearPrepared`) ;
  - `lib/router.dart` (écoute de l’appareil, de `offlineProvider`) ;
  - `test/fakes.dart` (`FakeDevicesRepository.clearPrepared`).
- Test : `test/offline/wipe_test.dart`.

**Interfaces :**
- Consumes : `Game`, `Device`, `offlineProvider` (tâche 3), la règle `preparedAt` nul (tâche 2).
- Produces :
  - `enum WipePolicy { week, lift, never }`, avec `label` et `parse` ;
  - `DateTime? gameEnd(Game g, DateTime now)` ;
  - `bool shouldWipe(WipePolicy p, Game? g, DateTime now)` ;
  - `class OfflinePrefs { rulebook, bonds, notes, policy; copyWith; static Future<OfflinePrefs> load(); Future<void> save(); }`, avec les clés `prepare.rulebook`, `prepare.bonds`, `prepare.notes`, `wipePolicy` ;
  - `DeviceSession({…, clearPrepared, policy})` ;
  - `DeviceSession.wipe(String? uid, String? deviceId, String location)` ;
  - `DeviceSession.wipeIfDue(String? uid, Device? d, List<Game> games, DateTime now, String location)` ;
  - `DevicesRepository.clearPrepared(String uid, String id)`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 4 test`, puis `flutter test test/offline/wipe_test.dart`. Échec attendu : `wipe.dart` n’existe pas.

<!-- file: test/offline/wipe_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/device_session.dart';
import 'package:portail_met/offline/wipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/game_rules_test.dart' show frozenGame;

DeviceSession session(List<String> calls, {WipePolicy policy = WipePolicy.week, bool pending = false}) => DeviceSession(
      removeDevice: (_, _) async {},
      pendingWrites: () async => pending,
      wipeCache: () async => calls.add('wipe'),
      forgetDevice: () async => calls.add('forget'),
      signOutAccount: () async => calls.add('signOut'),
      restart: (location) async => calls.add('restart:$location'),
      clearPrepared: (uid, id) async => calls.add('clear:$uid/$id'),
      policy: () async => policy,
      removeTimeout: const Duration(milliseconds: 20),
    );

void main() {
  // Partie du 3 oct., levée prévue le 4 à 6h.
  final running = frozenGame();
  final lifted = frozenGame(liftedAt: DateTime(2026, 10, 4, 1));
  const device = Device(id: 'd1', name: 'Navigateur · Windows', gameId: 'g2');

  test('politique : libellés et lecture, « 7 jours » par défaut', () {
    expect([for (final p in WipePolicy.values) p.label], ['7 jours après la partie', 'Au dégel', 'Jamais']);
    expect(WipePolicy.parse('lift'), WipePolicy.lift);
    expect(WipePolicy.parse(null), WipePolicy.week);
    expect(WipePolicy.parse('autre'), WipePolicy.week);
  });

  test('fin du gel : levée, ou levée prévue passée ; rien tant qu’il court', () {
    expect(gameEnd(running, DateTime(2026, 10, 3, 22)), isNull);
    expect(gameEnd(running, DateTime(2026, 10, 4, 7)), DateTime(2026, 10, 4, 6));
    expect(gameEnd(lifted, DateTime(2026, 10, 4, 2)), DateTime(2026, 10, 4, 1));
  });

  test('faut-il effacer ?', () {
    expect(shouldWipe(WipePolicy.lift, running, DateTime(2026, 10, 3, 22)), isFalse);
    expect(shouldWipe(WipePolicy.lift, running, DateTime(2026, 10, 4, 7)), isTrue);
    expect(shouldWipe(WipePolicy.week, running, DateTime(2026, 10, 11, 5)), isFalse);
    expect(shouldWipe(WipePolicy.week, running, DateTime(2026, 10, 11, 6)), isTrue);
    expect(shouldWipe(WipePolicy.week, lifted, DateTime(2026, 10, 11, 1)), isTrue);
    expect(shouldWipe(WipePolicy.never, lifted, DateTime(2027)), isFalse);
    expect(shouldWipe(WipePolicy.lift, null, DateTime(2027)), isFalse);
  });

  test('réglages de l’appareil : défauts, puis gardés', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await OfflinePrefs.load();
    expect(p.rulebook, isTrue);
    expect(p.bonds, isTrue);
    expect(p.notes, isFalse);
    expect(p.policy, WipePolicy.week);
    await p.copyWith(rulebook: false, notes: true, policy: WipePolicy.never).save();
    final again = await OfflinePrefs.load();
    expect(again.rulebook, isFalse);
    expect(again.bonds, isTrue);
    expect(again.notes, isTrue);
    expect(again.policy, WipePolicy.never);
    expect((await SharedPreferences.getInstance()).getString('wipePolicy'), 'never');
  });

  test('« Effacer maintenant » : partie oubliée, cache vidé, l’app repart ; le compte reste connecté', () async {
    final calls = <String>[];
    await session(calls).wipe('u1', 'd1', '/conteur/gel/hors-ligne');
    expect(calls, ['clear:u1/d1', 'wipe', 'restart:/conteur/gel/hors-ligne']);
  });

  test('effacement programmé : une semaine après la levée', () async {
    final calls = <String>[];
    await session(calls).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 12), '/');
    expect(calls, ['clear:u1/d1', 'wipe', 'restart:/']);
  });

  test('effacement programmé : trop tôt, jamais, partie inconnue, rien de préparé', () async {
    final calls = <String>[];
    await session(calls).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 8), '/');
    await session(calls, policy: WipePolicy.never).wipeIfDue('u1', device, [lifted], DateTime(2027), '/');
    await session(calls).wipeIfDue('u1', device, const [], DateTime(2027), '/');
    await session(calls).wipeIfDue('u1', const Device(id: 'd1', name: 'x'), [lifted], DateTime(2027), '/');
    await session(calls).wipeIfDue('u1', null, [lifted], DateTime(2027), '/');
    expect(calls, isEmpty);
  });

  test('effacement programmé : retardé tant que des saisies attendent le réseau (Review Focus 3)', () async {
    final calls = <String>[];
    await session(calls, pending: true).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 12), '/');
    expect(calls, isEmpty);
  });

  test('« Au dégel » : dès la levée', () async {
    final calls = <String>[];
    await session(calls, policy: WipePolicy.lift).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 4, 2), '/');
    expect(calls, contains('wipe'));
  });

  test('partie préparée impossible à oublier, cache impossible à vider : l’app repart quand même', () async {
    final calls = <String>[];
    final s = DeviceSession(
      removeDevice: (_, _) async {},
      pendingWrites: () async => false,
      wipeCache: () async => throw Exception('échec'),
      forgetDevice: () async {},
      signOutAccount: () async {},
      restart: (location) async => calls.add('restart:$location'),
      clearPrepared: (_, _) async => throw Exception('refus'),
    );
    await s.wipe('u1', 'd1', '/');
    expect(calls, ['restart:/']);
  });
}
```

- [ ] **Step 2 : politique, réglages et session**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 4 impl` (crée `wipe.dart`, réécrit `device_session.dart`), puis `dart run build_runner build --delete-conflicting-outputs`.

<!-- file: lib/offline/wipe.dart -->
```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../games/game.dart';

/// Quand effacer les données de l'appareil après la partie préparée (sous-projet 8d).
enum WipePolicy {
  week('7 jours après la partie'),
  lift('Au dégel'),
  never('Jamais');

  const WipePolicy(this.label);
  final String label;

  static WipePolicy parse(String? s) => values.where((w) => w.name == s).firstOrNull ?? week;
}

/// Fin du gel : sa levée, ou la levée prévue une fois passée ; null tant qu'il court.
DateTime? gameEnd(Game g, DateTime now) => g.liftedAt ?? (now.isBefore(g.until) ? null : g.until);

/// L'effacement programmé est dû : partie connue, finie, délai de la politique passé.
bool shouldWipe(WipePolicy p, Game? g, DateTime now) {
  if (g == null || p == WipePolicy.never) return false;
  final end = gameEnd(g, now);
  if (end == null) return false;
  return p == WipePolicy.lift || !now.isBefore(end.add(const Duration(days: 7)));
}

const wipePolicyKey = 'wipePolicy';
const _rulebookKey = 'prepare.rulebook';
const _bondsKey = 'prepare.bonds';
const _notesKey = 'prepare.notes';

/// Réglages propres à cet appareil (`shared_preferences`) : ce que « Préparer la partie » lit, et la politique d'effacement.
class OfflinePrefs {
  const OfflinePrefs({this.rulebook = true, this.bonds = true, this.notes = false, this.policy = WipePolicy.week});

  final bool rulebook;

  /// Liens de sang et événements, y compris les secrets.
  final bool bonds;

  /// Notes du conte (`private/notes`).
  final bool notes;
  final WipePolicy policy;

  OfflinePrefs copyWith({bool? rulebook, bool? bonds, bool? notes, WipePolicy? policy}) => OfflinePrefs(
        rulebook: rulebook ?? this.rulebook,
        bonds: bonds ?? this.bonds,
        notes: notes ?? this.notes,
        policy: policy ?? this.policy,
      );

  static Future<OfflinePrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return OfflinePrefs(
      rulebook: p.getBool(_rulebookKey) ?? true,
      bonds: p.getBool(_bondsKey) ?? true,
      notes: p.getBool(_notesKey) ?? false,
      policy: WipePolicy.parse(p.getString(wipePolicyKey)),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_rulebookKey, rulebook);
    await p.setBool(_bondsKey, bonds);
    await p.setBool(_notesKey, notes);
    await p.setString(wipePolicyKey, policy.name);
  }
}
```

<!-- file: lib/offline/device_session.dart -->
```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import '../games/game.dart';
import '../router.dart';
import 'device.dart';
import 'devices_repository.dart';
import 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';
import 'wipe.dart';

part 'device_session.g.dart';

Future<void> _keepPrepared(String uid, String deviceId) async {}

Future<WipePolicy> _weekPolicy() async => WipePolicy.week;

/// Déconnexion de cet appareil (« Se déconnecter », ou demandée depuis un autre appareil) :
/// document retiré, cache Firestore vidé, identifiant oublié, compte déconnecté, app relancée.
/// Effacement des données de l'appareil (sous-projet 8d) : partie préparée oubliée, cache vidé, app relancée, compte gardé.
class DeviceSession {
  DeviceSession({
    required this.removeDevice,
    required this.pendingWrites,
    required this.wipeCache,
    required this.forgetDevice,
    required this.signOutAccount,
    required this.restart,
    this.clearPrepared = _keepPrepared,
    this.policy = _weekPolicy,
    this.removeTimeout = const Duration(seconds: 3),
  });

  final Future<void> Function(String uid, String deviceId) removeDevice;

  /// Vrai si des écritures attendent encore le réseau : elles seraient perdues.
  final Future<bool> Function() pendingWrites;

  /// `terminate` puis `clearPersistence`.
  final Future<void> Function() wipeCache;

  /// La prochaine connexion sur cet appareil crée un nouveau document.
  final Future<void> Function() forgetDevice;
  final Future<void> Function() signOutAccount;

  /// Repart sur [location] avec une instance Firestore neuve.
  final Future<void> Function(String location) restart;

  /// `gameId` et `preparedAt` à nul : la copie hors ligne n'est plus annoncée dans « Mon compte ».
  final Future<void> Function(String uid, String deviceId) clearPrepared;

  /// Politique d'effacement choisie sur cet appareil.
  final Future<WipePolicy> Function() policy;
  final Duration removeTimeout;

  bool _busy = false;

  Future<void> signOut(String? uid, String? deviceId, {bool revoked = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      if (uid != null && deviceId != null) {
        try {
          // Hors ligne, la suppression resterait en file et partirait avec le cache : on n'attend pas le réseau.
          await removeDevice(uid, deviceId).timeout(removeTimeout);
        } catch (e) {
          debugPrint('Déconnexion : suppression du document de l’appareil échouée ($e)');
          // Le document reste : la ligne s'affiche « Déconnexion en attente » et reste listée.
        }
      }
      try {
        await wipeCache();
      } catch (e) {
        debugPrint('Déconnexion : effacement du cache Firestore échoué ($e)');
        // La déconnexion et le redémarrage doivent toujours avoir lieu.
      }
      await forgetDevice();
      await signOutAccount();
      await restart(revoked ? '/connexion?retire=1' : '/connexion');
    } finally {
      _busy = false;
    }
  }

  /// « Effacer maintenant », effacement programmé : le compte reste connecté.
  Future<void> wipe(String? uid, String? deviceId, String location) async {
    if (_busy) return;
    _busy = true;
    try {
      if (uid != null && deviceId != null) {
        try {
          await clearPrepared(uid, deviceId).timeout(removeTimeout);
        } catch (e) {
          // Le prochain démarrage en ligne refera l'effacement, puis oubliera la partie.
          debugPrint('Effacement : partie préparée non oubliée ($e)');
        }
      }
      try {
        await wipeCache();
      } catch (e) {
        debugPrint('Effacement : cache Firestore non vidé ($e)');
      }
      // L'instance arrêtée par `terminate` ne resservirait pas : on repart dans tous les cas.
      await restart(location);
    } finally {
      _busy = false;
    }
  }

  /// Effacement programmé : la partie préparée est finie depuis le délai choisi, et rien n'attend le réseau.
  Future<void> wipeIfDue(String? uid, Device? d, List<Game> games, DateTime now, String location) async {
    final gameId = d?.gameId;
    if (_busy || d == null || gameId == null) return;
    final g = games.where((g) => g.id == gameId).firstOrNull;
    if (!shouldWipe(await policy(), g, now)) return;
    if (await pendingWrites()) return;
    await wipe(uid, d.id, location);
  }
}

@Riverpod(keepAlive: true)
DeviceSession deviceSession(Ref ref) {
  final db = ref.watch(firestoreProvider);
  final devices = ref.watch(devicesRepositoryProvider);
  final auth = ref.watch(authRepositoryProvider);
  return DeviceSession(
    removeDevice: devices.remove,
    pendingWrites: () => db.waitForPendingWrites().then((_) => false).timeout(const Duration(seconds: 2), onTimeout: () => true),
    wipeCache: () async {
      await db.terminate();
      await db.clearPersistence();
    },
    forgetDevice: () async {
      await (await SharedPreferences.getInstance()).remove(deviceIdKey);
    },
    signOutAccount: auth.signOut,
    restart: (location) async {
      // Web : l'instance Firestore arrêtée ne resservirait pas, on recharge la page.
      if (kIsWeb) return reloadAt(location);
      // Android : une instance neuve remplace l'ancienne ; on relance les providers qui la lisent.
      final router = ref.read(routerProvider);
      ref.invalidate(deviceIdProvider);
      ref.invalidate(firestoreProvider);
      router.go(location);
    },
    clearPrepared: devices.clearPrepared,
    policy: () async => (await OfflinePrefs.load()).policy,
  );
}
```

Dans `lib/offline/devices_repository.dart`, ajouter après `prepared` :

```dart
  /// Partie préparée oubliée, avant l'effacement des données de l'appareil (sous-projet 8d).
  Future<void> clearPrepared(String uid, String id) => _col(uid).doc(id).update({'gameId': null, 'preparedAt': null});
```

Dans `test/fakes.dart`, classe `FakeDevicesRepository`, ajouter :

```dart
  @override
  Future<void> clearPrepared(String uid, String id) => _record('clearPrepared:$uid/$id');
```

Dans `lib/router.dart` :
- importer `'games/games_repository.dart'` et `'offline/offline.dart'` (s’ils n’y sont pas) ;
- remplacer l’écoute de `thisDeviceProvider` par :

```dart
  // Appareil déconnecté depuis un autre appareil (8c) : il vide son cache et se déconnecte lui-même.
  // Effacement programmé (8d) : la partie préparée sur l'appareil est finie depuis le délai choisi.
  ref.listen(thisDeviceProvider, (_, next) {
    final d = next.value;
    if (d == null) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (d.revokedAt != null) {
      ref.read(deviceSessionProvider).signOut(uid, d.id, revoked: true);
      return;
    }
    if (d.gameId == null) return;
    ref
        .read(gamesRepositoryProvider)
        .watchAll()
        .first
        .then((games) => ref.read(deviceSessionProvider).wipeIfDue(uid, d, games, DateTime.now(), '/'))
        .catchError((Object e) => debugPrint('Effacement programmé impossible ($e)'));
  });
  // État hors ligne (8d), lu par la garde des dépôts : écouté dès le démarrage pour être connu à la première écriture.
  ref.listen(offlineProvider, (_, _) {});
```

Si `debugPrint` n’est pas déjà disponible dans `router.dart` (il l’est par `package:flutter/material.dart`), importer `package:flutter/foundation.dart`.

- [ ] **Step 3 : tests verts**

Run : `flutter test test/offline/`, puis `flutter analyze`. `device_session_test.dart` (8c) reste vert, puisque les nouveaux paramètres ont des valeurs par défaut.

- [ ] **Step 4 : commit**

```bash
git add lib/offline/wipe.dart lib/offline/device_session.dart lib/offline/device_session.g.dart lib/offline/devices_repository.dart lib/router.dart lib/router.g.dart test/fakes.dart test/offline/wipe_test.dart
git commit -m "feat: hors ligne conte — effacement des données de l’appareil, programmé ou immédiat

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5 : file de synchronisation, calculs et dépôt

**Files :**
- Create :
  - `lib/offline/sync_queue.dart` ;
  - `lib/offline/offline_game_repository.dart` (+ `.g.dart` généré).
- Modify : `test/fakes.dart` (`FakeOfflineGameRepository`).
- Test : `test/offline/sync_queue_test.dart`.

**Interfaces :**
- Consumes : `Sin` (tâche 1), `OfflinePrefs` (tâche 4), `StoryEvent`, `Game`, `Character`, `hourText`, `shortDay` (`game_rules.dart`), `formatDay` (`core/dates.dart`), `pendingLossText` (`device.dart`).
- Produces :
  - `typedef Tracked<T> = ({T doc, bool pending})` ;
  - `enum QueueState { pending, sent, conflict }` avec `label` ;
  - `QueueLine({at, byName, label, sheetName, path, state})` ;
  - `remorseText`, `sinLabel`, `eventLabel`, `sinceFreeze(DateTime?, Game)` ;
  - `queueLines(Game, Map<String, Character>, Map<String, List<Tracked<Sin>>>, Map<String, List<Tracked<StoryEvent>>>, Set<String> conflictIds)` ;
  - `pendingCount(List<QueueLine>)` ;
  - textes : `lineHour`, `conflictLabel`, `headerLine`, `conflictText`, `conflictHead`, `traitsText`, `keepText`, `sheetCountText`, `wipeConfirmText` ;
  - constantes : `noGameText`, `preparedText`, `prepareFailedText`, `allSentText`, `syncLaterText`, `emptyQueueText`, `cacheNote`, `playersNote`, `notPreparedGameText`, `resolveRefusedText`, `canDo`, `cannotDo` ;
  - `OfflineGameRepository` : `watchSins`, `watchEvents`, `prepare(Game, OfflinePrefs)`, `sync()` ;
  - providers `offlineGameRepositoryProvider`, `trackedSinsProvider(characterId)`, `trackedEventsProvider(characterId)` ;
  - `FakeOfflineGameRepository` (`calls` : `'prepare:<gameId>:<rulebook>/<bonds>/<notes>'`, `'sync'` ; `error`).

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 5 test`, puis `flutter test test/offline/sync_queue_test.dart`. Échec attendu : `sync_queue.dart` n’existe pas.

<!-- file: test/offline/sync_queue_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/offline/sync_queue.dart';

import '../characters/character_test.dart' show sample;
import '../games/game_rules_test.dart' show frozenGame;

void main() {
  // Partie du samedi 3 oct., figée le 29 sept. à 20h.
  final g = frozenGame(sheetIds: const ['x']);
  final sheets = {'x': sample()};
  Sin sin(String id, {DateTime? at, int level = 2, Remorse remorse = Remorse.success, DateTime? day}) =>
      Sin(id: id, date: day ?? DateTime(2026, 10, 3), level: level, remorse: remorse, byUid: 'lea', byName: 'Léa G.', createdAt: at);
  StoryEvent ev(String title, DateTime? at) => StoryEvent(id: title, title: title, year: 2026, byName: 'Marc', createdAt: at);

  test('libellés des lignes', () {
    expect(sinLabel(sin('a')), 'Péché niveau 2 · remords réussi');
    expect(sinLabel(sin('a', remorse: Remorse.failed)), 'Péché niveau 2 · remords échoué');
    expect(sinLabel(sin('a', remorse: Remorse.none)), 'Péché niveau 2 · sans remords');
    expect(eventLabel(ev('Titre obtenu : Gardien de l’Élysée', null)), 'Événement · Titre obtenu : Gardien de l’Élysée');
  });

  test('depuis le gel : en attente, ou créé après le gel', () {
    expect(sinceFreeze(null, g), isTrue);
    expect(sinceFreeze(DateTime(2026, 9, 29, 19), g), isFalse);
    expect(sinceFreeze(DateTime(2026, 9, 29, 20), g), isTrue);
  });

  test('file : péchés du jour, événements depuis le gel, en attente d’abord, puis du plus récent au plus ancien (Review Focus 4)', () {
    final lines = queueLines(
      g,
      sheets,
      {
        'x': [
          (doc: sin('s1', at: DateTime(2026, 10, 3, 22, 41)), pending: false),
          (doc: sin('s2'), pending: true),
          (doc: sin('old', at: DateTime(2026, 9, 20, 22), day: DateTime(2026, 9, 20)), pending: false),
        ],
      },
      {
        'x': [
          (doc: ev('Récent', DateTime(2026, 10, 3, 22, 12)), pending: false),
          (doc: ev('Ancien', DateTime(2026, 9, 1)), pending: false),
          (doc: ev('Ancien modifié', DateTime(2026, 9, 1)), pending: true),
        ],
      },
      const {},
    );
    expect([for (final l in lines) l.label], [
      'Péché niveau 2 · remords réussi',
      'Événement · Ancien modifié',
      'Péché niveau 2 · remords réussi',
      'Événement · Récent',
    ]);
    expect([for (final l in lines) l.state], [QueueState.pending, QueueState.pending, QueueState.sent, QueueState.sent]);
    expect([for (final l in lines) l.path], [
      '/conteur/fiches/x/moralite',
      '/conteur/fiches/x/evenements',
      '/conteur/fiches/x/moralite',
      '/conteur/fiches/x/evenements',
    ]);
    expect(lines.first.sheetName, 'Isaure de Valcourt');
    expect(lines.first.byName, 'Léa G.');
    expect(lines[2].at, DateTime(2026, 10, 3, 22, 41));
    expect(pendingCount(lines), 2);
  });

  test('file : péché en conflit, fiche inconnue', () {
    final lines = queueLines(g, const {}, {
      'x': [(doc: sin('s1', at: DateTime(2026, 10, 3, 22)), pending: false)],
    }, const {}, {'s1'});
    expect(lines.single.state, QueueState.conflict);
    expect(lines.single.sheetName, '—');
    expect(pendingCount(lines), 0);
    expect([for (final s in QueueState.values) s.label], ['En attente', 'Envoyé', 'Conflit']);
  });

  test('textes', () {
    expect(lineHour(null), '—');
    expect(lineHour(DateTime(2026, 10, 3, 22, 47)), '22h47');
    expect(conflictLabel(1), 'conflit');
    expect(conflictLabel(2), 'conflits');
    expect(traitsText(1), '+1 trait de Bête');
    expect(traitsText(2), '+2 traits de Bête');
    expect(sheetCountText(1), '1 fiche');
    expect(sheetCountText(42), '42 fiches');
    final a = Sin(id: 'a', date: DateTime(2026, 10, 3), level: 2, byUid: 'lea', byName: 'Léa G.', createdAt: DateTime(2026, 10, 3, 22, 44));
    final b = Sin(id: 'b', date: DateTime(2026, 10, 3), level: 2, byUid: 'marc', byName: 'Marc');
    expect(conflictText(a, b), 'Léa G. et Marc ont saisi chacun un péché de niveau 2 le 3 oct. S’agit-il du même péché ?');
    expect(conflictHead(a), 'Léa G. · 22h44');
    expect(conflictHead(b), 'Marc · en attente');
    expect(keepText(a), 'Même péché : garder celui de Léa G.');
    expect(wipeConfirmText(pending: false), 'Effacer les données de cet appareil ? Vous restez connecté.');
    expect(wipeConfirmText(pending: true),
        'Effacer les données de cet appareil ? Vous restez connecté. Des saisies n’ont pas encore été envoyées : elles seront perdues.');
  });

  test('ligne d’en-tête', () {
    expect(headerLine(g, null, null), 'Partie du samedi 3 oct.');
    expect(headerLine(g, DateTime(2026, 10, 3, 17, 30), DateTime(2026, 10, 3, 21, 2)),
        'Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 21h02');
  });
}
```

- [ ] **Step 2 : calculs et dépôt**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 5 impl`, puis `dart run build_runner build --delete-conflicting-outputs`.

<!-- file: lib/offline/sync_queue.dart -->
```dart
import '../characters/character.dart';
import '../core/dates.dart' show formatDay;
import '../events/story_event.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show hourText, shortDay;
import '../morality/sin.dart';
import 'device.dart' show pendingLossText;

/// Un document suivi avec son état d'envoi (`hasPendingWrites`).
typedef Tracked<T> = ({T doc, bool pending});

enum QueueState {
  pending('En attente'),
  sent('Envoyé'),
  conflict('Conflit');

  const QueueState(this.label);
  final String label;
}

/// Ligne de la file de synchronisation (C-HorsLigne, sous-projet 8d).
class QueueLine {
  const QueueLine({required this.at, required this.byName, required this.label, required this.sheetName, required this.path, required this.state});

  /// Heure du serveur à la création ; null tant qu'elle n'est pas confirmée.
  final DateTime? at;
  final String byName;
  final String label;
  final String sheetName;

  /// Onglet de la fiche où la saisie se fait.
  final String path;
  final QueueState state;
}

const noGameText = 'Aucune partie en cours';
const preparedText = 'Partie préparée sur cet appareil.';
const prepareFailedText = 'Préparation impossible : vérifiez le réseau et réessayez.';
const allSentText = 'Tout est envoyé.';
const syncLaterText = 'Pas de réseau : les saisies partiront dès son retour.';
const emptyQueueText = 'Aucune saisie depuis le gel.';
const cacheNote = 'Ce que vous ouvrez sur cet appareil reste aussi dans son cache.';
const playersNote = 'Les appareils des joueurs ne reçoivent que leurs propres fiches, sans notes ni événements secrets.';
const notPreparedGameText = 'Cette partie n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau.';
const resolveRefusedText = 'Enregistrement refusé : réessayez.';
const canDo = ['Consulter les fiches figées et le référentiel', 'Saisir péchés, événements et gorgées'];
const cannotDo = 'Pas de modification de la fiche, de validation de demande ni d’XP : elles attendent le réseau';

String remorseText(Remorse r) => switch (r) {
      Remorse.success => 'remords réussi',
      Remorse.failed => 'remords échoué',
      Remorse.none => 'sans remords',
    };

String sinLabel(Sin s) => 'Péché niveau ${s.level} · ${remorseText(s.remorse)}';

/// Une gorgée écrit aussi un événement « Lien de sang » : la file la montre par lui.
String eventLabel(StoryEvent e) => 'Événement · ${e.title}';

/// Saisie de la partie : en attente (pas encore d'heure), ou créée depuis le gel.
bool sinceFreeze(DateTime? at, Game g) => at == null || !at.isBefore(g.frozenAt);

/// Péchés du jour de la partie et événements créés depuis le gel (ou modifiés hors ligne), pour les fiches figées.
/// En attente d'abord, puis du plus récent au plus ancien.
List<QueueLine> queueLines(
  Game g,
  Map<String, Character> sheets,
  Map<String, List<Tracked<Sin>>> sins,
  Map<String, List<Tracked<StoryEvent>>> events,
  Set<String> conflictIds,
) {
  final day = dayOf(g.date);
  final lines = <QueueLine>[
    for (final id in g.sheetIds) ...[
      for (final s in sins[id] ?? const <Tracked<Sin>>[])
        if (dayOf(s.doc.date) == day)
          QueueLine(
            at: s.doc.createdAt,
            byName: s.doc.byName,
            label: sinLabel(s.doc),
            sheetName: sheets[id]?.name ?? '—',
            path: '/conteur/fiches/$id/moralite',
            state: conflictIds.contains(s.doc.id)
                ? QueueState.conflict
                : s.pending
                    ? QueueState.pending
                    : QueueState.sent,
          ),
      for (final e in events[id] ?? const <Tracked<StoryEvent>>[])
        if (e.pending || sinceFreeze(e.doc.createdAt, g))
          QueueLine(
            at: e.doc.createdAt,
            byName: e.doc.byName,
            label: eventLabel(e.doc),
            sheetName: sheets[id]?.name ?? '—',
            path: '/conteur/fiches/$id/evenements',
            state: e.pending ? QueueState.pending : QueueState.sent,
          ),
    ],
  ];
  int rank(QueueLine l) => l.state == QueueState.pending ? 0 : 1;
  // Sans heure : la plus récente (2^52 tient dans un entier JavaScript).
  int time(QueueLine l) => l.at?.millisecondsSinceEpoch ?? (1 << 52);
  lines.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : time(b).compareTo(time(a));
  });
  return lines;
}

int pendingCount(List<QueueLine> lines) => lines.where((l) => l.state == QueueState.pending).length;

String lineHour(DateTime? at) => at == null ? '—' : hourText(at);

/// Libellé du compteur des conflits.
String conflictLabel(int n) => n > 1 ? 'conflits' : 'conflit';

/// « Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 21h02 ».
String headerLine(Game g, DateTime? preparedAt, DateTime? lastSync) => [
      'Partie du ${shortDay(g.date)}',
      if (preparedAt != null) 'préparée sur cet appareil le ${formatDay(preparedAt)} à ${hourText(preparedAt)}',
      if (lastSync != null) 'dernière synchronisation à ${hourText(lastSync)}',
    ].join(' · ');

String conflictText(Sin a, Sin b) =>
    '${a.byName} et ${b.byName} ont saisi chacun un péché de niveau ${a.level} le ${formatDay(a.date)}. S’agit-il du même péché ?';

String conflictHead(Sin s) => s.createdAt == null ? '${s.byName} · en attente' : '${s.byName} · ${hourText(s.createdAt!)}';

String traitsText(int n) => '+$n ${n > 1 ? 'traits' : 'trait'} de Bête';

String keepText(Sin s) => 'Même péché : garder celui de ${s.byName}';

String sheetCountText(int n) => n > 1 ? '$n fiches' : '$n fiche';

String wipeConfirmText({required bool pending}) =>
    'Effacer les données de cet appareil ? Vous restez connecté.${pending ? ' $pendingLossText' : ''}';
```

<!-- file: lib/offline/offline_game_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../events/story_event.dart';
import '../games/game.dart';
import '../morality/sin.dart';
import 'sync_queue.dart';
import 'wipe.dart';

part 'offline_game_repository.g.dart';

/// Lectures de « Partie hors ligne » (sous-projet 8d) : saisies suivies avec leur état d'envoi, préparation, synchronisation.
class OfflineGameRepository {
  OfflineGameRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _sub(String characterId, String name) =>
      _db.collection('characters').doc(characterId).collection(name);

  /// Avec les changements de métadonnées : une saisie passe de « En attente » à « Envoyé » sans changer de contenu.
  Stream<List<Tracked<Sin>>> watchSins(String characterId) => _sub(characterId, 'sins').snapshots(includeMetadataChanges: true).map((q) => [
        for (final d in q.docs) (doc: Sin.fromMap(d.id, d.data()), pending: d.metadata.hasPendingWrites),
      ]);

  /// Équipe : tous les événements de la fiche.
  Stream<List<Tracked<StoryEvent>>> watchEvents(String characterId) =>
      _sub(characterId, 'events').snapshots(includeMetadataChanges: true).map((q) => [
            for (final d in q.docs) (doc: StoryEvent.fromMap(d.id, d.data()), pending: d.metadata.hasPendingWrites),
          ]);

  /// Lit une fois ce dont la partie a besoin : le cache persistant le garde pour la suite.
  /// Les notes du conte ne sont lisibles que par le conte, hors de sa propre fiche : un refus est ignoré.
  Future<void> prepare(Game g, OfflinePrefs p) async {
    final chars = _db.collection('characters');
    Future<void> quiet(Future<Object?> f) => f.then((_) {}, onError: (Object _) {});
    await Future.wait<Object?>([
      _db.collection('games').get(),
      chars.get(),
      if (p.rulebook) _db.collection('rules').get(),
      if (p.bonds) _db.collection('bonds').get(),
      for (final id in g.sheetIds) ...[
        chars.doc(id).collection('frozen').doc(g.id).get(),
        _sub(id, 'sins').get(),
        if (p.bonds) _sub(id, 'events').get(),
        if (p.notes) quiet(_sub(id, 'private').doc('notes').get()),
      ],
    ]);
  }

  /// « Synchroniser maintenant » : réseau rétabli s'il était coupé, puis attente de l'envoi des saisies.
  Future<void> sync() async {
    await _db.enableNetwork();
    await _db.waitForPendingWrites();
  }
}

@Riverpod(keepAlive: true)
OfflineGameRepository offlineGameRepository(Ref ref) => OfflineGameRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Tracked<Sin>>> trackedSins(Ref ref, String characterId) => ref.watch(offlineGameRepositoryProvider).watchSins(characterId);

@riverpod
Stream<List<Tracked<StoryEvent>>> trackedEvents(Ref ref, String characterId) =>
    ref.watch(offlineGameRepositoryProvider).watchEvents(characterId);
```

Dans `test/fakes.dart` :
- importer `package:portail_met/offline/offline_game_repository.dart` et `package:portail_met/offline/wipe.dart` ;
- ajouter :

```dart
class FakeOfflineGameRepository implements OfflineGameRepository {
  final calls = <String>[];
  Object? error;

  @override
  Future<void> prepare(Game g, OfflinePrefs p) async {
    calls.add('prepare:${g.id}:${p.rulebook}/${p.bonds}/${p.notes}');
    if (error != null) throw error!;
  }

  @override
  Future<void> sync() async {
    calls.add('sync');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 3 : tests verts**

Run : `flutter test test/offline/sync_queue_test.dart`, puis `flutter analyze`. Si le générateur refuse le type record `Tracked<T>` en retour de provider, remplacer `Tracked<Sin>` par `({Sin doc, bool pending})` dans les deux providers seulement, puis relancer `build_runner`.

- [ ] **Step 4 : commit**

```bash
git add lib/offline/sync_queue.dart lib/offline/offline_game_repository.dart lib/offline/offline_game_repository.g.dart test/fakes.dart test/offline/sync_queue_test.dart
git commit -m "feat: hors ligne conte — file de synchronisation, préparation de l’appareil

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6 : écran « Partie hors ligne », route et bouton du gel

**Files :**
- Create : `lib/offline/offline_game_screen.dart`.
- Modify :
  - `lib/router.dart` (route) ;
  - `lib/games/freeze_screen.dart` (bouton) ;
  - `test/games/freeze_screen_test.dart` (deux tests).
- Test : `test/offline/offline_game_screen_test.dart`.

**Interfaces :**
- Consumes :
  - tâche 1 : `conflicts`, `sinTraits`, `markDistinct` ;
  - tâche 3 : `offlineProvider` ;
  - tâche 4 : `OfflinePrefs`, `WipePolicy`, `DeviceSession.wipe`, `pendingWrites` ;
  - tâche 5 : tout `sync_queue.dart`, `trackedSinsProvider`, `trackedEventsProvider`, `offlineGameRepositoryProvider` ;
  - existants : `thisDeviceProvider`, `devicesRepositoryProvider.prepared`, `gamesProvider`, `runningGame`, `allCharactersProvider`, `sinsRepositoryProvider`, `confirm`, `webTabText` (`night.dart`).
- Produces : `OfflineGameScreen({DateTime Function() now})`, route `/conteur/gel/hors-ligne`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 6 test`, puis `flutter test test/offline/offline_game_screen_test.dart`. Échec attendu : `offline_game_screen.dart` n’existe pas.

<!-- file: test/offline/offline_game_screen_test.dart -->
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/device_session.dart';
import 'package:portail_met/offline/devices_repository.dart';
import 'package:portail_met/offline/offline.dart';
import 'package:portail_met/offline/offline_game_repository.dart';
import 'package:portail_met/offline/offline_game_screen.dart';
import 'package:portail_met/offline/sync_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;

/// Hors ligne, la suppression reste en file : son futur ne se termine pas.
class _HangingSins extends FakeSinsRepository {
  @override
  Future<void> delete(String characterId, String id) {
    calls.add('delete:$characterId:$id');
    return Completer<void>().future;
  }
}

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);
  final now = DateTime(2026, 10, 3, 23);
  final g2 = frozenGame(sheetIds: const ['x', 'y']);
  Character bastien() => Character.fromMap('y', {...sample().toMap(), 'name': 'Bastien Roche', 'playerUid': 'u2'});
  Sin sin(String id, String uid, String name, {int level = 2, DateTime? at}) => Sin(
        id: id,
        date: DateTime(2026, 10, 3),
        level: level,
        what: 'Témoin rendu fou',
        remorse: Remorse.success,
        byUid: uid,
        byName: name,
        createdAt: at,
      );
  // Isaure : Marc et Léa ont saisi le même péché ; un troisième péché attend le réseau.
  final sinsX = <Tracked<Sin>>[
    (doc: sin('m1', 'marc', 'Marc', at: DateTime(2026, 10, 3, 22, 47)), pending: false),
    (doc: sin('l1', 'lea', 'Léa G.', at: DateTime(2026, 10, 3, 22, 44)), pending: false),
    (doc: sin('p1', 'lea', 'Léa G.', level: 1), pending: true),
  ];
  // Bastien : un événement de la soirée, un autre bien plus ancien.
  final eventsY = <Tracked<StoryEvent>>[
    (doc: StoryEvent(id: 'e1', title: 'Titre obtenu : Gardien', year: 2026, byName: 'Marc', createdAt: DateTime(2026, 10, 3, 22, 12)), pending: false),
    (doc: StoryEvent(id: 'e0', title: 'Étreinte', year: 1890, byName: 'Marc', createdAt: DateTime(2026, 9, 1)), pending: false),
  ];
  final prepared = Device(id: 'd1', name: 'Navigateur · Windows', web: true, gameId: 'g2', preparedAt: DateTime(2026, 10, 3, 17, 30));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<({FakeOfflineGameRepository repo, FakeSinsRepository sins, FakeDevicesRepository devices, List<String> session})> pump(
    WidgetTester tester, {
    AppUser me = lea,
    List<Game>? games,
    bool offline = false,
    Device? device,
    FakeSinsRepository? sins,
    FakeOfflineGameRepository? repo,
    Size size = const Size(1440, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = repo ?? FakeOfflineGameRepository();
    final sinsRepo = sins ?? FakeSinsRepository();
    final devices = FakeDevicesRepository();
    final session = <String>[];
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(me)),
        gamesProvider.overrideWith((ref) => Stream.value(games ?? [g2])),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample(), bastien()])),
        offlineProvider.overrideWith((ref) => Stream.value(offline)),
        thisDeviceProvider.overrideWith((ref) => Stream.value(device ?? prepared)),
        trackedSinsProvider('x').overrideWith((ref) => Stream.value(sinsX)),
        trackedSinsProvider('y').overrideWith((ref) => Stream.value(const <Tracked<Sin>>[])),
        trackedEventsProvider('x').overrideWith((ref) => Stream.value(const <Tracked<StoryEvent>>[])),
        trackedEventsProvider('y').overrideWith((ref) => Stream.value(eventsY)),
        offlineGameRepositoryProvider.overrideWith((ref) => r),
        sinsRepositoryProvider.overrideWith((ref) => sinsRepo),
        devicesRepositoryProvider.overrideWith((ref) => devices),
        deviceSessionProvider.overrideWith((ref) => DeviceSession(
              removeDevice: (_, _) async {},
              pendingWrites: () async => false,
              wipeCache: () async => session.add('wipe'),
              forgetDevice: () async => session.add('forget'),
              signOutAccount: () async => session.add('signOut'),
              restart: (location) async => session.add('restart:$location'),
              clearPrepared: (uid, id) async => session.add('clear:$uid/$id'),
            )),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: OfflineGameScreen(now: () => now))),
    ));
    await tester.pumpAndSettle();
    return (repo: r, sins: sinsRepo, devices: devices, session: session);
  }

  String kpi(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('en ligne : en-tête, compteurs, conflit et file', (tester) async {
    await pump(tester);
    expect(find.text('Partie hors ligne'), findsOneWidget);
    expect(find.text('Hors ligne'), findsNothing);
    expect(find.text('Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30'), findsOneWidget);
    expect(kpi(tester, 'kpi-sheets'), '2');
    expect(kpi(tester, 'kpi-pending'), '1');
    expect(kpi(tester, 'kpi-conflicts'), '1');
    expect(find.text('conflit'), findsOneWidget);
    expect(find.text('CONFLIT · ISAURE DE VALCOURT'), findsOneWidget);
    expect(find.text('Léa G. et Marc ont saisi chacun un péché de niveau 2 le 3 oct. S’agit-il du même péché ?'), findsOneWidget);
    expect(find.text('Léa G. · 22h44'), findsOneWidget);
    expect(find.text('Marc · 22h47'), findsOneWidget);
    expect(find.text('+1 trait de Bête'), findsNWidgets(2));
    expect(find.text('Péché niveau 1 · remords réussi'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Événement · Titre obtenu : Gardien'), findsOneWidget);
    expect(find.text('Envoyé'), findsOneWidget);
    expect(find.text('Événement · Étreinte'), findsNothing);
    expect(find.text('Conflit'), findsNWidgets(2));
    expect(find.text(cannotDo), findsOneWidget);
    expect(find.text(playersNote), findsOneWidget);
  });

  testWidgets('conflit : garder l’un, garder l’autre, ou deux péchés distincts', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Même péché : garder celui de Léa G.'));
    await tester.pump();
    await tester.tap(find.text('Même péché : garder celui de Marc'));
    await tester.pump();
    await tester.tap(find.text('Deux péchés distincts'));
    await tester.pump();
    expect(r.sins.calls, ['delete:x:m1', 'delete:x:l1', 'distinct:x:l1,m1']);
  });

  testWidgets('conflit tranché hors ligne : l’écran ne reste pas bloqué (Review Focus 1)', (tester) async {
    final r = await pump(tester, offline: true, sins: _HangingSins());
    await tester.tap(find.text('Même péché : garder celui de Léa G.'));
    await tester.pump();
    await tester.tap(find.text('Deux péchés distincts'));
    await tester.pump();
    expect(r.sins.calls, ['delete:x:m1', 'distinct:x:l1,m1']);
  });

  testWidgets('conflit refusé : message sous le bloc', (tester) async {
    await pump(tester, sins: FakeSinsRepository()..error = Exception('refus'));
    await tester.tap(find.text('Deux péchés distincts'));
    await tester.pumpAndSettle();
    expect(find.text(resolveRefusedText), findsOneWidget);
  });

  testWidgets('narrateur : il prépare son appareil, il ne tranche pas', (tester) async {
    await pump(tester, me: julien);
    expect(find.text('CONFLIT · ISAURE DE VALCOURT'), findsOneWidget);
    expect(find.text('Deux péchés distincts'), findsNothing);
    expect(find.text('Préparer la partie'), findsOneWidget);
  });

  testWidgets('hors ligne : badge, préparation impossible', (tester) async {
    await pump(tester, offline: true);
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Préparer la partie')).onPressed, isNull);
    expect(find.text(notPreparedGameText), findsNothing);
  });

  testWidgets('hors ligne sans préparation : bandeau', (tester) async {
    await pump(tester, offline: true, device: const Device(id: 'd1', name: 'Navigateur · Windows', web: true));
    expect(find.text(notPreparedGameText), findsOneWidget);
    expect(find.text('Partie du samedi 3 oct.'), findsOneWidget);
  });

  testWidgets('aucune partie en cours', (tester) async {
    await pump(tester, games: const []);
    expect(find.text(noGameText), findsOneWidget);
  });

  testWidgets('préparer : lectures selon les cases, appareil noté, cases gardées', (tester) async {
    final r = await pump(tester);
    expect(find.text('2 fiches'), findsOneWidget);
    await tester.tap(find.text('Référentiel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Préparer la partie'));
    await tester.pumpAndSettle();
    expect(r.repo.calls, ['prepare:g2:false/true/false']);
    expect(r.devices.calls, ['prepared:lea/d1/g2']);
    expect(find.text(preparedText), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('prepare.rulebook'), isFalse);
  });

  testWidgets('préparation refusée : message', (tester) async {
    await pump(tester, repo: FakeOfflineGameRepository()..error = Exception('refus'));
    await tester.tap(find.text('Préparer la partie'));
    await tester.pumpAndSettle();
    expect(find.text(prepareFailedText), findsOneWidget);
  });

  testWidgets('synchroniser : envoi attendu, heure de la synchronisation', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Synchroniser maintenant'));
    await tester.pumpAndSettle();
    expect(r.repo.calls, ['sync']);
    expect(find.text(allSentText), findsOneWidget);
    expect(find.text('Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 23h'), findsOneWidget);
  });

  testWidgets('synchroniser sans réseau : message, le bouton revient (Review Focus 5)', (tester) async {
    await pump(tester, repo: FakeOfflineGameRepository()..error = TimeoutException('réseau'));
    await tester.tap(find.text('Synchroniser maintenant'));
    await tester.pumpAndSettle();
    expect(find.text(syncLaterText), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Synchroniser maintenant')).onPressed, isNotNull);
  });

  testWidgets('politique d’effacement : gardée sur l’appareil', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('wipe-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jamais').last);
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('wipePolicy'), 'never');
  });

  testWidgets('effacer maintenant : confirmation, puis effacement de l’appareil', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Effacer maintenant de cet appareil'));
    await tester.pumpAndSettle();
    expect(find.text('Effacer les données de cet appareil ? Vous restez connecté.'), findsOneWidget);
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();
    expect(r.session, ['clear:lea/d1', 'wipe', 'restart:/conteur/gel/hors-ligne']);
  });

  testWidgets('390 px : une colonne, sans débordement', (tester) async {
    await pump(tester, size: const Size(390, 4200));
    expect(tester.takeException(), isNull);
    expect(find.text('Deux péchés distincts'), findsOneWidget);
    expect(find.text('Péché niveau 1 · remords réussi'), findsOneWidget);
  });
}
```

Ajouter à la fin de `main()` dans `test/games/freeze_screen_test.dart` :

```dart
  testWidgets('gel en cours : bouton « Partie hors ligne » (sous-projet 8d)', (tester) async {
    await pump(tester, games: [g1, g2]);
    expect(find.text('Partie hors ligne'), findsOneWidget);
  });

  testWidgets('sans gel : pas de bouton « Partie hors ligne » (sous-projet 8d)', (tester) async {
    await pump(tester, games: [g1]);
    expect(find.text('Partie hors ligne'), findsNothing);
  });
```

- [ ] **Step 2 : écran**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-20-hors-ligne-conte.md 6 impl`.

<!-- file: lib/offline/offline_game_screen.dart -->
```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../events/story_event.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../morality/morality_rules.dart';
import '../morality/sin.dart';
import '../morality/sins_repository.dart';
import 'device_session.dart';
import 'devices_repository.dart';
import 'night.dart' show webTabText;
import 'offline.dart';
import 'offline_game_repository.dart';
import 'sync_queue.dart';
import 'wipe.dart';

const _route = '/conteur/gel/hors-ligne';

/// « Partie hors ligne » (C-HorsLigne, sous-projet 8d) : préparer l'appareil, suivre la file, trancher les conflits de péchés.
class OfflineGameScreen extends ConsumerStatefulWidget {
  const OfflineGameScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<OfflineGameScreen> createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends ConsumerState<OfflineGameScreen> {
  OfflinePrefs? _prefs;
  bool _busy = false;
  String? _message;
  String? _conflictError;

  /// Heure où la file est revenue à zéro en ligne, gardée en mémoire.
  DateTime? _lastSync;
  bool _hadPending = false;

  @override
  void initState() {
    super.initState();
    OfflinePrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  void _setPrefs(OfflinePrefs p) {
    setState(() => _prefs = p);
    p.save();
  }

  Future<void> _prepare(Game g, String uid, String? deviceId) async {
    final p = _prefs;
    if (p == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(offlineGameRepositoryProvider).prepare(g, p);
      if (deviceId != null) await ref.read(devicesRepositoryProvider).prepared(uid, deviceId, g.id);
      if (mounted) setState(() => _message = preparedText);
    } catch (_) {
      if (mounted) setState(() => _message = prepareFailedText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Sans réseau, l'attente ne finirait qu'à son retour : on rend la main.
      await ref.read(offlineGameRepositoryProvider).sync().timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _lastSync = widget.now();
          _message = allSentText;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = syncLaterText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipeNow(String uid, String? deviceId) async {
    final session = ref.read(deviceSessionProvider);
    final pending = await session.pendingWrites();
    if (!mounted) return;
    final ok = await confirm(context, title: 'Effacer cet appareil', body: wipeConfirmText(pending: pending), action: 'Effacer');
    if (!ok) return;
    await session.wipe(uid, deviceId, _route);
  }

  /// Hors ligne, l'écriture reste en file et son futur ne finit qu'au retour du réseau : on ne l'attend pas.
  void _resolve(Future<void> Function(Actor by) write) {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    setState(() => _conflictError = null);
    write(by).catchError((Object _) {
      if (mounted) setState(() => _conflictError = resolveRefusedText);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'La partie hors ligne est l’affaire du conte.');
    }
    return asyncView(ref.watch(gamesProvider), (games) {
      final g = runningGame(games, widget.now());
      if (g == null) {
        return EmptyState(
          kind: EmptyKind.empty,
          title: noGameText,
          message: 'Le bouton « Partie hors ligne » apparaît sur l’écran du gel pendant une partie.',
          actionLabel: 'Gel des fiches',
          onAction: () => context.go('/conteur/gel'),
        );
      }
      return _page(context, me, g);
    }, onRetry: () => ref.invalidate(gamesProvider));
  }

  Widget _page(BuildContext context, AppUser me, Game g) {
    final t = Theme.of(context).textTheme;
    final wide = isWide(context);
    final offline = ref.watch(offlineProvider).value ?? false;
    final device = ref.watch(thisDeviceProvider).value;
    final sheets = {for (final c in ref.watch(allCharactersProvider).value ?? const <Character>[]) c.id: c};
    final sins = {for (final id in g.sheetIds) id: ref.watch(trackedSinsProvider(id)).value ?? const <Tracked<Sin>>[]};
    final events = {for (final id in g.sheetIds) id: ref.watch(trackedEventsProvider(id)).value ?? const <Tracked<StoryEvent>>[]};
    final day = dayOf(g.date);
    final pairs = [
      for (final id in g.sheetIds)
        for (final p in conflicts([for (final s in sins[id]!) if (dayOf(s.doc.date) == day) s.doc])) (id: id, a: p.$1, b: p.$2),
    ];
    final inConflict = {for (final p in pairs) ...[p.a.id, p.b.id]};
    final lines = queueLines(g, sheets, sins, events, inConflict);
    final pending = pendingCount(lines);
    if (pending > 0) _hadPending = true;
    if (!offline && pending == 0 && _hadPending) {
      _hadPending = false;
      _lastSync = widget.now();
    }
    final preparedAt = device?.gameId == g.id ? device?.preparedAt : null;
    final p = _prefs;

    Widget kpi(String value, String label, String key) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, key: Key(key), style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(label, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        );

    Widget conflictBlock(String id, Sin a, Sin b) {
      Widget card(Sin s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.background, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(conflictHead(s), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(s.what.isEmpty ? '—' : s.what, style: t.bodyLarge),
              const SizedBox(height: 4),
              Text(traitsText(sinTraits(s)), style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
          );
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Conflit · ${sheets[id]?.name ?? '—'}'),
          const SizedBox(height: 12),
          Text(conflictText(a, b), style: t.bodyLarge?.copyWith(color: AppColors.textSoft)),
          const SizedBox(height: 12),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: card(a)), const SizedBox(width: 12), Expanded(child: card(b))])
          else ...[
            card(a),
            const SizedBox(height: 12),
            card(b),
          ],
          if (me.role.managesAccounts) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(onPressed: () => _resolve((_) => ref.read(sinsRepositoryProvider).delete(id, b.id)), child: Text(keepText(a))),
              OutlinedButton(onPressed: () => _resolve((_) => ref.read(sinsRepositoryProvider).delete(id, a.id)), child: Text(keepText(b))),
              OutlinedButton(
                onPressed: () => _resolve((by) => ref.read(sinsRepositoryProvider).markDistinct(id, [a, b], by)),
                child: const Text('Deux péchés distincts'),
              ),
            ]),
          ],
          if (_conflictError != null) ...[
            const SizedBox(height: 8),
            Text(_conflictError!, style: const TextStyle(color: AppColors.linkHover)),
          ],
        ]),
      );
    }

    Widget chip(QueueState s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: switch (s) {
              QueueState.pending => AppColors.reviewBg,
              QueueState.sent => AppColors.activeBg,
              QueueState.conflict => AppColors.deadBg,
            },
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            s.label,
            style: TextStyle(
              color: switch (s) {
                QueueState.pending => AppColors.goldLight,
                QueueState.sent => AppColors.success,
                QueueState.conflict => AppColors.linkHover,
              },
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    Widget lineTile(QueueLine l) {
      final hour = Text(lineHour(l.at), style: t.bodyMedium?.copyWith(color: AppColors.textMuted));
      final what = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.label, style: t.bodyMedium),
        Text(l.sheetName, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]);
      return InkWell(
        onTap: () => context.go(l.path),
        child: Container(
          color: l.state == QueueState.conflict ? AppColors.deadBg.withValues(alpha: 0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: wide
              ? Row(children: [
                  SizedBox(width: 70, child: hour),
                  SizedBox(width: 130, child: Text(l.byName, style: t.bodyMedium)),
                  Expanded(child: what),
                  chip(l.state),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    hour,
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.byName, style: t.bodyMedium)),
                    chip(l.state),
                  ]),
                  const SizedBox(height: 4),
                  what,
                ]),
        ),
      );
    }

    final queue = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 14), child: SectionTitle('File de synchronisation')),
        const Divider(height: 1, color: AppColors.border),
        if (lines.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(emptyQueueText, style: t.bodyMedium))
        else
          for (final l in lines) ...[lineTile(l), const Divider(height: 1, color: AppColors.border)],
      ]),
    );

    Widget box(String label, String detail, bool value, OfflinePrefs Function(bool) next) => CheckboxListTile(
          value: value,
          onChanged: p == null ? null : (v) => _setPrefs(next(v ?? false)),
          title: Text(label),
          subtitle: Text(detail),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        );

    final devicePanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Sur cet appareil'),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: true,
          onChanged: null,
          title: const Text('Fiches figées'),
          subtitle: Text(sheetCountText(g.sheetIds.length)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        box('Référentiel', 'Atouts, disciplines, titres', p?.rulebook ?? true, (v) => p!.copyWith(rulebook: v)),
        box('Liens de sang et événements', 'Y compris les secrets', p?.bonds ?? true, (v) => p!.copyWith(bonds: v)),
        box('Notes du conte', 'Lecture seule', p?.notes ?? false, (v) => p!.copyWith(notes: v)),
        const SizedBox(height: 6),
        Text(cacheNote, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: offline || _busy || p == null ? null : () => _prepare(g, me.uid, device?.id),
            child: const Text('Préparer la partie'),
          ),
        ),
      ]),
    );

    final canDoPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Hors ligne, on peut'),
        const SizedBox(height: 8),
        for (final x in canDo) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x, style: t.bodyLarge)),
        Text(cannotDo, style: t.bodyLarge?.copyWith(color: AppColors.textSecondary)),
      ]),
    );

    final securityPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Sécurité'),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('wipe-policy'),
          child: DropdownButtonFormField<WipePolicy>(
            // Les réglages arrivent après le premier affichage : le menu repart avec eux.
            key: ValueKey(p?.policy),
            initialValue: p?.policy ?? WipePolicy.week,
            decoration: const InputDecoration(labelText: 'Effacer les données de l’appareil'),
            items: [for (final w in WipePolicy.values) DropdownMenuItem(value: w, child: Text(w.label))],
            onChanged: p == null ? null : (w) => _setPrefs(p.copyWith(policy: w)),
          ),
        ),
        const SizedBox(height: 12),
        Text(playersNote, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: () => _wipeNow(me.uid, device?.id), child: const Text('Effacer maintenant de cet appareil')),
        ),
      ]),
    );

    final main = [
      for (final c in pairs) ...[conflictBlock(c.id, c.a, c.b), const SizedBox(height: 20)],
      queue,
    ];
    final side = [devicePanel, const SizedBox(height: 20), canDoPanel, const SizedBox(height: 20), securityPanel];

    return PageBody(children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(onPressed: () => context.go('/conteur/gel'), child: const Text('Gel des fiches')),
        Text('/ Hors ligne', style: t.bodySmall),
      ]),
      Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Partie hors ligne', style: wide ? t.displaySmall : t.headlineMedium),
        if (offline) const _OfflineBadge(),
      ]),
      const SizedBox(height: 6),
      Text(headerLine(g, preparedAt, _lastSync), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton(onPressed: _busy ? null : _sync, child: const Text('Synchroniser maintenant')),
        if (_message != null) Text(_message!, style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
      ]),
      const SizedBox(height: 16),
      if (offline && preparedAt == null) ...[const _Notice(notPreparedGameText), const SizedBox(height: 12)],
      if (kIsWeb) ...[const _Notice(webTabText), const SizedBox(height: 12)],
      Row(children: [
        kpi('${g.sheetIds.length}', 'fiches figées', 'kpi-sheets'),
        const SizedBox(width: 14),
        kpi('$pending', 'saisies en attente', 'kpi-pending'),
        const SizedBox(width: 14),
        kpi('${pairs.length}', conflictLabel(pairs.length), 'kpi-conflicts'),
      ]),
      const SizedBox(height: 20),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main)),
          const SizedBox(width: 24),
          SizedBox(width: 420, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side)),
        ])
      else ...[
        ...main,
        const SizedBox(height: 20),
        ...side,
      ],
    ]);
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.reviewBg, borderRadius: BorderRadius.circular(999)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off, size: 16, color: AppColors.goldLight),
          SizedBox(width: 6),
          Text('Hors ligne', style: TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.reviewBg, border: Border.all(color: AppColors.gold), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(color: AppColors.textSoft, fontSize: 15)),
      );
}
```

Remarques pour l’implémenteur :
- Si `DropdownButtonFormField.initialValue` n’existe pas dans la version de Flutter installée, utiliser `value`.
- Retirer les imports que l’analyseur signale inutilisés (selon les symboles réellement utilisés, par exemple `game.dart` ou `games_repository.dart`).

Dans `lib/router.dart` :
- importer `'offline/offline_game_screen.dart'` ;
- ajouter juste après `page('/conteur/gel', const FreezeScreen()),` :

```dart
          page('/conteur/gel/hors-ligne', const OfflineGameScreen()),
```

Dans `lib/games/freeze_screen.dart`, méthode `_page`, remplacer l’`action` du `PageTitle` par :

```dart
        action: running == null
            ? null
            : Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton(onPressed: () => context.go('/conteur/gel/hors-ligne'), child: const Text('Partie hors ligne')),
                if (me.role.managesAccounts) OutlinedButton(onPressed: _busy ? null : () => _lift(running), child: const Text('Lever le gel')),
              ]),
```

- [ ] **Step 3 : tests verts**

Run : `flutter test test/offline/ test/games/`, puis `flutter test`, puis `flutter analyze`.

- [ ] **Step 4 : commit**

```bash
git add lib/offline/offline_game_screen.dart lib/router.dart lib/games/freeze_screen.dart test/offline/offline_game_screen_test.dart test/games/freeze_screen_test.dart
git commit -m "feat: hors ligne conte — écran « Partie hors ligne », route et bouton du gel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7 : vérification finale

**Files :** aucun nouveau fichier.

- [ ] **Step 1 : suites complètes**

Lancer les commandes suivantes :
- `flutter analyze` (propre) ;
- `flutter test` (tout vert) ;
- les tests de règles (tout vert).

Noter les résultats exacts.

- [ ] **Step 2 : vérification à la main** (avec l’utilisateur ; émulateurs ou projet réel selon son choix)

1. Deux navigateurs connectés en conteur, pendant un gel : ouvrir « Partie hors ligne » sur chacun et « Préparer la partie ».
2. Couper le réseau (outils de développement → hors ligne) sur les deux. Saisir le même péché, de même niveau, sur la même fiche, sur chacun. La file montre « En attente ».
3. Tenter une perte d’Humanité ou un titre hors ligne : le message « Pas de réseau : les modifications de la fiche attendent le réseau. » s’affiche.
4. Rétablir le réseau : les lignes passent à « Envoyé », puis le bloc « Conflit » apparaît. Le trancher.
5. « Effacer maintenant » : l’app repart sur l’écran, le compte reste connecté, et « Mon compte » ne montre plus « Copie hors ligne ».

- [ ] **Step 3 : fin de branche**

Utiliser superpowers:finishing-a-development-branch. La fusion dans `main`, le déploiement des règles (`firebase deploy --only firestore:rules`) et l’hébergement se font seulement avec l’accord explicite de l’utilisateur.
