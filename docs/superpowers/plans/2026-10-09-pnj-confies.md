# PNJ confiés (sous-projet 6e) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** le conte confie un PNJ à un joueur pour une période. Le joueur lit une copie de la fiche (complète ou résumée) et les consignes, et tient ses notes d'interprétation.

**Architecture :**
- **Données :**
  - `npcLoans/{id}` : en-tête lisible par son joueur (PNJ, joueur, dates, mode, consignes, notes) ;
  - `npcLoans/{id}/sheet/copy` : copie de la fiche, lisible seulement pendant la période et sans révocation.
- **Calculs purs** dans `lib/npcs/loan_rules.dart`.
- **Écrans :**
  - conte `/conteur/pnj` ;
  - joueur `/joueur/pnj` et `/joueur/pnj/:id` ;
  - section « Prêts » de C3 pour un PNJ.

**Tech Stack :** inchangée (Flutter, Riverpod generator, cloud_firestore, go_router).

**Spec :** `docs/superpowers/specs/2026-10-09-pnj-confies-design.md`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md <N> [test|impl]` ;
  - textes en français ;
  - `dart run build_runner build --delete-conflicting-outputs` après un fichier `part` ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche :** `pnj-confies`, déjà créée.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Écarts assumés avec la spec** (à reporter dans le journal) :
  - **Copie de la fiche dans le sous-document `sheet/copy` :** une règle qui dépend des dates ne permet pas au joueur de lister ses prêts par requête. L'en-tête reste lisible par son joueur ; la copie n'est lisible que pendant la période.
  - **Notes du joueur :** bouton « Enregistrer » plutôt qu'un enregistrement automatique.
  - **Dates :** saisies en JJ/MM/AAAA. Le début est à 0 h, la fin à 23 h 59 min 59 s.

## Review Focus

1. **Joueur après la fin ou après révocation :** il ne lit plus la copie de la fiche. Il ne peut plus écrire ses notes. Test : tâche 2.
2. **Autre joueur :** il ne lit ni l'en-tête ni la copie. Test : tâche 2.
3. **Le conte modifie le prêt pendant que le joueur écrit ses notes :** les notes du joueur ne sont pas écrasées, car le conte n'écrit jamais `playerNotes`. Test : tâche 2.
4. **Fiche résumée :** la copie ne contient ni récit, ni atouts, ni handicaps, ni historiques. Test : tâche 1.
5. **Fin avant le début :** refusé à l'écran et par les règles. Tests : tâches 1, 2 et 3.

---

### Task 1 : modèle et calculs

**Files :** Create `lib/npcs/npc_loan.dart`, `lib/npcs/loan_rules.dart`. Test : `test/npcs/loan_rules_test.dart`.

**Interfaces :**
- Produces :
  - `LoanMode { full('Fiche complète'), summary('Fiche résumée') }` ;
  - `NpcLoan` (`fromMap`, `toMap`, `copy`) ;
  - `LoanState { upcoming, active, ended, revoked }` ;
  - `loanState(l, now)`, `daysLeft(l, now)` ;
  - `sheetCopy(c, mode)` ;
  - `parseDay(text)`, `startOfDay(d)`, `endOfDay(d)` ;
  - `loanWarnings(l, {loans, npc, now})`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 1 test`, puis `flutter test test/npcs`.

Expected : échec au chargement.

<!-- file: test/npcs/loan_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/npcs/loan_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';

import '../characters/character_test.dart' show sample;

/// PNJ prêté à Camille du 28 sept. au 17 oct. 2026.
NpcLoan octave({String id = 'l1'}) => NpcLoan(
      id: id,
      characterId: 'x',
      characterName: 'Isaure de Valcourt',
      playerUid: 'u1',
      playerName: 'Camille R.',
      from: DateTime(2026, 9, 28),
      until: endOfDay(DateTime(2026, 10, 17)),
      personality: 'Courtois, patient.',
      goals: 'Obtenir le soutien de la Primogène.',
      limits: 'Pas de Domination sur un PJ.',
      version: 1,
      sheetAt: DateTime(2026, 9, 28, 20),
    );

void main() {
  test('dates : saisie JJ/MM/AAAA, fin de journée', () {
    expect(parseDay('17/10/2026'), DateTime(2026, 10, 17));
    expect(parseDay(' 1/2/2026 '), DateTime(2026, 2, 1));
    expect(parseDay('31/02/2026'), isNull);
    expect(parseDay('demain'), isNull);
    expect(endOfDay(DateTime(2026, 10, 17, 8)), DateTime(2026, 10, 17, 23, 59, 59));
    expect(startOfDay(DateTime(2026, 10, 17, 8)), DateTime(2026, 10, 17));
  });

  test('état du prêt et jours restants', () {
    final l = octave();
    expect(loanState(l, DateTime(2026, 9, 27)), LoanState.upcoming);
    expect(loanState(l, DateTime(2026, 10, 17, 23)), LoanState.active);
    expect(loanState(l, DateTime(2026, 10, 18)), LoanState.ended);
    expect(loanState(l.copy()..revokedAt = DateTime(2026, 10, 1), DateTime(2026, 10, 2)), LoanState.revoked);
    expect(daysLeft(l, DateTime(2026, 9, 28, 21)), 19);
    expect(daysLeft(l, DateTime(2026, 10, 17, 1)), 0);
  });

  test('copie résumée : identité, attributs, 7 meilleures compétences, disciplines, sang (Review Focus 4)', () {
    final c = sample()
      ..title = 'Harpie'
      ..story = 'Secret'
      ..merits = [Trait('Chanceux', 2)]
      ..skills = [for (var i = 1; i <= 9; i++) Trait('C$i', i % 5 + 1)]
      ..blood = 12
      ..willpower = 6;
    final s = sheetCopy(c, LoanMode.summary);
    for (final k in ['story', 'merits', 'flaws', 'backgrounds']) {
      expect(s.containsKey(k), isFalse, reason: k);
    }
    expect((s['name'], s['title'], s['blood'], s['willpower']), ('Isaure de Valcourt', 'Harpie', 12, 6));
    expect((s['skills'] as List).length, 7);
    final back = Character.fromMap('x', s);
    expect(back.attributes[AttrCategory.social]!.value, c.attributes[AttrCategory.social]!.value);
    expect(back.disciplines.single.name, 'Auspex');
    expect(sheetCopy(c, LoanMode.full)['story'], 'Secret');
  });

  test('aller-retour et avertissements (Review Focus 5)', () {
    final l = octave();
    expect(NpcLoan.fromMap('l1', l.toMap()).toMap(), l.toMap());
    final now = DateTime(2026, 10, 1);
    final npc = sample()..updatedAt = DateTime(2026, 9, 30);
    final other = octave(id: 'l2')
      ..playerUid = 'u2'
      ..playerName = 'Julien P.';
    expect(loanWarnings(l, loans: [l, other], npc: npc, now: now), [
      'Déjà confié à Julien P. jusqu’au ${formatDayForTest(other.until)}',
      'Copie du ${formatDayForTest(l.sheetAt!)} : mettre à jour',
    ]);
    npc.status = CharacterStatus.dead;
    expect(loanWarnings(l.copy()..sheetAt = null, loans: const [], npc: npc, now: now), ['Le PNJ est une fiche retirée ou morte']);
    final backwards = l.copy()..until = DateTime(2026, 9, 1);
    expect(loanWarnings(backwards, loans: const [], npc: null, now: now), ['La fin précède le début']);
  });
}

String formatDayForTest(DateTime d) => formatLoanDay(d);
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 1 impl`.

<!-- file: lib/npcs/npc_loan.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanMode {
  full('Fiche complète'),
  summary('Fiche résumée');

  const LoanMode(this.label);
  final String label;
}

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

/// Prêt d'un PNJ à un joueur (`npcLoans/{id}`) ; la copie de la fiche est à part (`sheet/copy`).
class NpcLoan {
  NpcLoan({
    this.id = '',
    this.characterId = '',
    this.characterName = '',
    this.playerUid = '',
    this.playerName = '',
    required this.from,
    required this.until,
    this.mode = LoanMode.full,
    this.allowNotes = true,
    this.personality = '',
    this.goals = '',
    this.limits = '',
    this.sheetAt,
    this.revokedAt,
    this.playerNotes = '',
    this.notesAt,
    this.version = 0,
    this.updatedByName,
  });

  factory NpcLoan.fromMap(String id, Map<String, dynamic> m) => NpcLoan(
        id: id,
        characterId: m['characterId'] as String? ?? '',
        characterName: m['characterName'] as String? ?? '',
        playerUid: m['playerUid'] as String? ?? '',
        playerName: m['playerName'] as String? ?? '',
        from: _date(m['from']) ?? DateTime(2000),
        until: _date(m['until']) ?? DateTime(2000),
        mode: LoanMode.values.asNameMap()[m['mode']] ?? LoanMode.full,
        allowNotes: m['allowNotes'] != false,
        personality: m['personality'] as String? ?? '',
        goals: m['goals'] as String? ?? '',
        limits: m['limits'] as String? ?? '',
        sheetAt: _date(m['sheetAt']),
        revokedAt: _date(m['revokedAt']),
        playerNotes: m['playerNotes'] as String? ?? '',
        notesAt: _date(m['notesAt']),
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String characterId;
  String characterName;
  String playerUid;
  String playerName;
  DateTime from;
  DateTime until;
  LoanMode mode;
  bool allowNotes;
  String personality;
  String goals;
  String limits;
  DateTime? sheetAt;
  DateTime? revokedAt;
  String playerNotes;
  DateTime? notesAt;
  final int version;
  final String? updatedByName;

  /// Champs écrits par le conte (jamais `playerNotes` ni `notesAt`, écrits par le joueur).
  Map<String, dynamic> toMap() => {
        'characterId': characterId,
        'characterName': characterName,
        'playerUid': playerUid,
        'playerName': playerName,
        'from': _ts(from),
        'until': _ts(until),
        'mode': mode.name,
        'allowNotes': allowNotes,
        'personality': personality,
        'goals': goals,
        'limits': limits,
        'sheetAt': _ts(sheetAt),
        'revokedAt': _ts(revokedAt),
      };

  NpcLoan copy() => NpcLoan.fromMap(id, {
        ...toMap(),
        'playerNotes': playerNotes,
        'notesAt': _ts(notesAt),
        'version': version,
        'updatedByName': updatedByName,
      });
}
```

<!-- file: lib/npcs/loan_rules.dart -->
```dart
import '../characters/character.dart';
import '../core/dates.dart';
import 'npc_loan.dart';

enum LoanState { upcoming, active, ended, revoked }

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dernière seconde du jour : la fin d'un prêt est incluse.
DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

/// Date d'un prêt affichée (« 17 oct. 2026 » selon `formatDay`).
String formatLoanDay(DateTime d) => formatDay(d);

/// « 17/10/2026 » ; null si la date n'existe pas.
DateTime? parseDay(String text) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text.trim());
  if (m == null) return null;
  final (d, mo, y) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final date = DateTime(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

LoanState loanState(NpcLoan l, DateTime now) {
  if (l.revokedAt != null) return LoanState.revoked;
  if (now.isBefore(l.from)) return LoanState.upcoming;
  if (now.isAfter(l.until)) return LoanState.ended;
  return LoanState.active;
}

/// Jours entiers jusqu'à la fin (0 le dernier jour), en jours de calendrier (indépendant de l'heure d'été).
int daysLeft(NpcLoan l, DateTime now) {
  final a = DateTime.utc(now.year, now.month, now.day);
  final b = DateTime.utc(l.until.year, l.until.month, l.until.day);
  return b.difference(a).inDays;
}

/// Copie de la fiche montrée au joueur. Résumée : identité, attributs, 7 meilleures compétences, disciplines, sang.
Map<String, dynamic> sheetCopy(Character c, LoanMode mode) {
  final all = c.toMap();
  if (mode == LoanMode.full) return all;
  final skills = [...c.skills]..sort((a, b) => b.level.compareTo(a.level));
  return {
    for (final k in ['name', 'kind', 'status', 'clan', 'lineage', 'sect', 'title', 'generation', 'attributes', 'disciplines', 'blood', 'bloodPerTurn', 'willpower'])
      k: all[k],
    'skills': [for (final t in skills.take(7)) t.toMap()],
  };
}

/// Avertissements (le conte peut quand même enregistrer, sauf « La fin précède le début »).
List<String> loanWarnings(NpcLoan l, {List<NpcLoan> loans = const [], Character? npc, required DateTime now}) {
  final out = <String>[];
  if (!l.until.isAfter(l.from)) out.add('La fin précède le début');
  for (final o in loans) {
    if (o.id == l.id || o.characterId != l.characterId) continue;
    final s = loanState(o, now);
    final open = s == LoanState.active || s == LoanState.upcoming;
    if (open && o.from.isBefore(l.until) && l.from.isBefore(o.until)) out.add('Déjà confié à ${o.playerName} jusqu’au ${formatDay(o.until)}');
  }
  if (npc != null) {
    final at = l.sheetAt;
    if (at != null && npc.updatedAt != null && npc.updatedAt!.isAfter(at)) out.add('Copie du ${formatDay(at)} : mettre à jour');
    if (npc.status == CharacterStatus.retired || npc.status == CharacterStatus.dead) out.add('Le PNJ est une fiche retirée ou morte');
  }
  return out;
}
```

Run : `flutter test test/npcs`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib/npcs test/npcs
git commit -m "feat: PNJ confiés — modèle et calculs (dates, état, copie complète ou résumée, avertissements)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : règles Firestore, dépôt, providers, fake

**Files :**
- Modify : `firestore.rules`, `test/fakes.dart`.
- Create : `lib/npcs/npc_loans_repository.dart`, `rules_test/npc_loans.test.js`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `NpcLoansRepository` : `watchAll`, `watchForPlayer(uid)`, `watchForCharacter(id)`, `watchSheet(loanId)` qui renvoie la copie ou null, `save(before, loan, by, {sheet})` qui renvoie l'id, et `saveNotes(id, text)` ;
  - les providers `npcLoansRepositoryProvider`, `allNpcLoansProvider`, `myNpcLoansProvider`, `characterNpcLoansProvider(id)` et `npcLoanSheetProvider(loanId)` ;
  - `FakeNpcLoansRepository` (`calls`, `lastSaved`, `lastBefore`, `lastSheet`, `lastNotes`, `error`) ;
  - l'override `noNpcLoans`.

- [ ] **Step 1 : tests des règles (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 2 test`, puis les tests des règles.

Expected : les tests de `npc_loans.test.js` échouent ; les autres passent.

<!-- file: rules_test/npc_loans.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, collection, query, where, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const day = 24 * 3600 * 1000;
const loan = (over) => ({
  characterId: 'n1', characterName: 'Octave', playerUid: 'zoe', playerName: 'Zoé',
  from: Timestamp.fromMillis(Date.now() - day), until: Timestamp.fromMillis(Date.now() + 10 * day),
  mode: 'full', allowNotes: true, personality: '', goals: '', limits: '', sheetAt: null, revokedAt: null,
  playerNotes: '', notesAt: null, version: 1, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'npcLoans/now'), loan({}));
    await setDoc(doc(db, 'npcLoans/now/sheet/copy'), { sheet: { name: 'Octave' } });
    await setDoc(doc(db, 'npcLoans/past'), loan({ until: Timestamp.fromMillis(Date.now() - day / 2) }));
    await setDoc(doc(db, 'npcLoans/past/sheet/copy'), { sheet: { name: 'Octave' } });
    await setDoc(doc(db, 'npcLoans/revoked'), loan({ revokedAt: Timestamp.fromMillis(Date.now() - 1000) }));
    await setDoc(doc(db, 'npcLoans/revoked/sheet/copy'), { sheet: { name: 'Octave' } });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('le joueur liste ses prêts et lit la copie pendant la période seulement (Review Focus 1 et 2)', async () => {
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'npcLoans'), where('playerUid', '==', 'zoe'))));
  await assertFails(getDocs(collection(as('zoe'), 'npcLoans')));
  await assertSucceeds(getDoc(doc(as('zoe'), 'npcLoans/now/sheet/copy')));
  await assertFails(getDoc(doc(as('zoe'), 'npcLoans/past/sheet/copy')));
  await assertFails(getDoc(doc(as('zoe'), 'npcLoans/revoked/sheet/copy')));
  await assertFails(getDoc(doc(as('max'), 'npcLoans/now')));
  await assertFails(getDoc(doc(as('max'), 'npcLoans/now/sheet/copy')));
  await assertSucceeds(getDoc(doc(as('julien'), 'npcLoans/now/sheet/copy')));
});

test('notes du joueur : seulement elles, pendant la période, si autorisées (Review Focus 1 et 3)', async () => {
  const notes = (id, extra = {}) => updateDoc(doc(as('zoe'), `npcLoans/${id}`), { playerNotes: 'Promis une faveur', notesAt: serverTimestamp(), ...extra });
  await assertSucceeds(notes('now'));
  await assertFails(notes('now', { limits: 'aucune' }));
  await assertFails(notes('now', { notesAt: Timestamp.fromMillis(Date.now() - day) }));
  await assertFails(notes('past'));
  await assertFails(notes('revoked'));
  await assertFails(updateDoc(doc(as('max'), 'npcLoans/now'), { playerNotes: 'x', notesAt: serverTimestamp() }));
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'npcLoans/now'), { allowNotes: false }));
  await assertFails(notes('now'));
});

test('le conte écrit avec la version ; fin avant début refusée (Review Focus 5)', async () => {
  const lea = as('lea');
  await assertSucceeds(updateDoc(doc(lea, 'npcLoans/now'), { limits: 'aucune', version: 2 }));
  await assertFails(updateDoc(doc(lea, 'npcLoans/now'), { limits: 'x', version: 2 }));
  await assertFails(setDoc(doc(as('julien'), 'npcLoans/n2'), loan({})));
  await assertFails(setDoc(doc(lea, 'npcLoans/n2'), loan({ until: Timestamp.fromMillis(Date.now() - 2 * day) })));
  await assertSucceeds(setDoc(doc(lea, 'npcLoans/n2'), loan({})));
  await assertSucceeds(setDoc(doc(lea, 'npcLoans/n2/sheet/copy'), { sheet: {} }));
  await assertFails(setDoc(doc(as('zoe'), 'npcLoans/n2/sheet/copy'), { sheet: {} }));
});
```

Si les autres fichiers de `rules_test` construisent l'environnement autrement (fonction partagée, création des utilisateurs), suivre leur forme ; le contenu des tests reste celui-ci.

- [ ] **Step 2 : règles**

Dans `firestore.rules`, juste avant `match /invitations/{email} {`, ajouter le bloc suivant. Les noms de fonctions `isStaff()`, `managesAccounts()` et `signedIn()` sont ceux du fichier ; s'ils diffèrent, utiliser les fonctions existantes équivalentes.

```
    // PNJ confiés (sous-projet 6e) : en-tête lisible par son joueur ; copie de la fiche pendant la période seulement.
    function loanOpen(l) {
      return l.get('revokedAt', null) == null && l.from <= request.time && request.time <= l.until;
    }

    match /npcLoans/{id} {
      allow read: if isStaff() || (signedIn() && resource.data.playerUid == request.auth.uid);
      allow create: if managesAccounts() && request.resource.data.version == 1
        && request.resource.data.until > request.resource.data.from;
      allow update: if (managesAccounts() && request.resource.data.version == resource.data.version + 1
          && request.resource.data.until > request.resource.data.from)
        || (signedIn() && resource.data.playerUid == request.auth.uid && resource.data.allowNotes == true && loanOpen(resource.data)
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['playerNotes', 'notesAt'])
          && request.resource.data.notesAt == request.time);
      allow delete: if managesAccounts();

      match /sheet/{doc} {
        allow read: if isStaff() || (signedIn()
          && get(/databases/$(database)/documents/npcLoans/$(id)).data.playerUid == request.auth.uid
          && loanOpen(get(/databases/$(database)/documents/npcLoans/$(id)).data));
        allow write: if managesAccounts();
      }
    }

```

Run : les tests des règles.

Expected : `fail 0`.

- [ ] **Step 3 : dépôt, providers, fake**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 2 impl`.

<!-- file: lib/npcs/npc_loans_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import 'npc_loan.dart';

part 'npc_loans_repository.g.dart';

/// `npcLoans/{id}` et la copie de la fiche `npcLoans/{id}/sheet/copy`.
class NpcLoansRepository {
  NpcLoansRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('npcLoans');

  List<NpcLoan> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) NpcLoan.fromMap(d.id, d.data())]..sort((a, b) => b.until.compareTo(a.until));

  /// Équipe : tous les prêts, ceux qui finissent le plus tard d'abord.
  Stream<List<NpcLoan>> watchAll() => _col.snapshots().map(_sorted);

  /// Joueur : ses prêts (requête permise par les règles).
  Stream<List<NpcLoan>> watchForPlayer(String uid) => _col.where('playerUid', isEqualTo: uid).snapshots().map(_sorted);

  /// Équipe : les prêts d'un PNJ.
  Stream<List<NpcLoan>> watchForCharacter(String characterId) =>
      _col.where('characterId', isEqualTo: characterId).snapshots().map(_sorted);

  /// Copie de la fiche ; null si elle manque.
  Stream<Map<String, dynamic>?> watchSheet(String loanId) => _col.doc(loanId).collection('sheet').doc('copy').snapshots().map((d) {
        final s = d.data()?['sheet'];
        return s is Map ? Map<String, dynamic>.from(s) : null;
      });

  /// Crée ([before] en version 0) ou modifie le prêt ; [sheet] remplace la copie de la fiche. Renvoie l'id.
  /// Le conte n'écrit jamais les notes du joueur : une mise à jour ne les écrase pas.
  Future<String> save(NpcLoan before, NpcLoan l, Actor by, {Map<String, dynamic>? sheet}) async {
    final creating = before.version == 0;
    final ref = l.id.isEmpty ? _col.doc() : _col.doc(l.id);
    final now = FieldValue.serverTimestamp();
    final data = {
      ...l.toMap(),
      if (sheet != null) 'sheetAt': now,
      'version': creating ? 1 : before.version + 1,
      'updatedAt': now,
      'updatedByName': by.name,
    };
    final batch = _db.batch();
    if (creating) {
      batch.set(ref, {...data, 'playerNotes': '', 'notesAt': null, 'createdAt': now});
    } else {
      batch.update(ref, data);
    }
    if (sheet != null) batch.set(ref.collection('sheet').doc('copy'), {'sheet': sheet});
    await batch.commit();
    return ref.id;
  }

  /// Notes du joueur (seules clés qu'il peut écrire).
  Future<void> saveNotes(String id, String text) =>
      _col.doc(id).update({'playerNotes': text.trim(), 'notesAt': FieldValue.serverTimestamp()});
}

@Riverpod(keepAlive: true)
NpcLoansRepository npcLoansRepository(Ref ref) => NpcLoansRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<NpcLoan>> allNpcLoans(Ref ref) => ref.watch(npcLoansRepositoryProvider).watchAll();

@riverpod
Stream<List<NpcLoan>> myNpcLoans(Ref ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
  if (uid == null) return const Stream.empty();
  return ref.watch(npcLoansRepositoryProvider).watchForPlayer(uid);
}

@riverpod
Stream<List<NpcLoan>> characterNpcLoans(Ref ref, String characterId) =>
    ref.watch(npcLoansRepositoryProvider).watchForCharacter(characterId);

@riverpod
Stream<Map<String, dynamic>?> npcLoanSheet(Ref ref, String loanId) => ref.watch(npcLoansRepositoryProvider).watchSheet(loanId);
```

Dans `test/fakes.dart` :
- ajouter les imports `package:portail_met/npcs/npc_loan.dart` et `package:portail_met/npcs/npc_loans_repository.dart`, dans l'ordre alphabétique ;
- ajouter à la fin :

```dart
class FakeNpcLoansRepository implements NpcLoansRepository {
  final calls = <String>[];
  NpcLoan? lastSaved;
  NpcLoan? lastBefore;
  Map<String, dynamic>? lastSheet;
  String? lastNotes;
  Object? error;

  @override
  Future<String> save(NpcLoan before, NpcLoan l, Actor by, {Map<String, dynamic>? sheet}) async {
    calls.add('save:${l.characterName}:${l.playerName}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = l;
    lastSheet = sheet;
    return l.id.isEmpty ? 'new-loan' : l.id;
  }

  @override
  Future<void> saveNotes(String id, String text) async {
    calls.add('notes:$id');
    if (error != null) throw error!;
    lastNotes = text;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucun prêt pour la fiche 'x'.
final noNpcLoans = characterNpcLoansProvider('x').overrideWith((ref) => Stream.value(const <NpcLoan>[]));
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add firestore.rules rules_test/npc_loans.test.js lib/npcs test/fakes.dart
git commit -m "feat: PNJ confiés — règles Firestore, dépôt et providers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : écran du conte

**Files :**
- Create : `lib/npcs/npc_loans_screen.dart`.
- Modify : `lib/router.dart`.
- Test : `test/npcs/npc_loans_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2, `allCharactersProvider`, `allUsersProvider`, `currentUserProvider`, `actorOf`, `confirm`.
- Produces : `NpcLoansScreen` (`/conteur/pnj`), avec les clés :
  - formulaire : `loan-npc`, `loan-player`, `loan-from`, `loan-until`, `loan-mode`, `loan-allow-notes`, `loan-personality`, `loan-goals`, `loan-limits`, `loan-save` ;
  - actions de la liste : `loan-extend-<id>` (fenêtre avec `extend-until` et `extend-ok`), `loan-revoke-<id>`, `loan-refresh-<id>`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 3 test`, puis `flutter test test/npcs/npc_loans_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/npcs/npc_loans_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/npcs/loan_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';
import 'package:portail_met/npcs/npc_loans_screen.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'loan_rules_test.dart' show octave;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  Character npc() => sample()
    ..kind = CharacterKind.pnj
    ..status = CharacterStatus.active
    ..playerUid = null;

  Future<FakeNpcLoansRepository> pump(WidgetTester tester, {List<NpcLoan> loans = const []}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeNpcLoansRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea, camille])),
        allCharactersProvider.overrideWith((ref) => Stream.value([npc()])),
        allNpcLoansProvider.overrideWith((ref) => Stream.value(loans)),
        npcLoansRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: NpcLoansScreen())),
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

  testWidgets('confier un PNJ : copie résumée, consignes, dates incluses', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'loan-npc', 'Isaure de Valcourt');
    await choose(tester, 'loan-player', 'Camille R.');
    await tester.enterText(find.byKey(const Key('loan-from')), '28/09/2026');
    await tester.enterText(find.byKey(const Key('loan-until')), '17/10/2026');
    await tester.tap(find.text('Fiche résumée'));
    await tester.enterText(find.byKey(const Key('loan-personality')), 'Courtois.');
    await tester.pump();
    expect(find.text('Confier à Camille R.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loan-save')));
    await tester.pumpAndSettle();
    final l = repo.lastSaved!;
    expect((l.characterId, l.playerUid, l.mode, l.personality), ('x', 'u1', LoanMode.summary, 'Courtois.'));
    expect(l.from, DateTime(2026, 9, 28));
    expect(l.until, DateTime(2026, 10, 17, 23, 59, 59));
    expect(repo.lastBefore!.version, 0);
    expect(repo.lastSheet!.containsKey('story'), isFalse);
  });

  testWidgets('fin avant le début : refusé (Review Focus 5)', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'loan-npc', 'Isaure de Valcourt');
    await choose(tester, 'loan-player', 'Camille R.');
    await tester.enterText(find.byKey(const Key('loan-from')), '28/09/2026');
    await tester.enterText(find.byKey(const Key('loan-until')), '01/09/2026');
    await tester.tap(find.byKey(const Key('loan-save')));
    await tester.pumpAndSettle();
    expect(find.text('La fin précède le début'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('liste : prolonger, révoquer, mettre à jour la copie', (tester) async {
    final repo = await pump(tester, loans: [
      octave()
        ..from = startOfDay(DateTime.now())
        ..until = endOfDay(DateTime.now().add(const Duration(days: 3))),
    ]);
    expect(find.textContaining('1 en cours'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loan-extend-l1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('extend-until')), '31/12/2030');
    await tester.tap(find.byKey(const Key('extend-ok')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.until, DateTime(2030, 12, 31, 23, 59, 59));
    expect(repo.lastSheet, isNull);
    await tester.tap(find.byKey(const Key('loan-refresh-l1')));
    await tester.pumpAndSettle();
    expect(repo.lastSheet, isNotNull);
    await tester.tap(find.byKey(const Key('loan-revoke-l1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Révoquer').last);
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.revokedAt, isNotNull);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 3 impl`.

<!-- file: lib/npcs/npc_loans_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'loan_rules.dart';
import 'npc_loan.dart';
import 'npc_loans_repository.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// « Confier un PNJ » (C-PNJ) : formulaire et liste des prêts.
class NpcLoansScreen extends ConsumerStatefulWidget {
  const NpcLoansScreen({super.key});

  @override
  ConsumerState<NpcLoansScreen> createState() => _NpcLoansScreenState();
}

class _NpcLoansScreenState extends ConsumerState<NpcLoansScreen> {
  String? _npcId;
  String? _playerUid;
  final _from = TextEditingController(text: _day(DateTime.now()));
  final _until = TextEditingController();
  LoanMode _mode = LoanMode.full;
  bool _allowNotes = true;
  final _personality = TextEditingController();
  final _goals = TextEditingController();
  final _limits = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_from, _until, _personality, _goals, _limits]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _write(NpcLoan before, NpcLoan l, {Map<String, dynamic>? sheet, String done = 'Prêt enregistré.'}) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return false;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(npcLoansRepositoryProvider).save(before, l, by, sheet: sheet);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      return true;
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.code == 'permission-denied' && before.version > 0 ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
      return false;
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create(List<Character> npcs, List<AppUser> players) async {
    final npc = npcs.where((c) => c.id == _npcId).firstOrNull;
    final player = players.where((u) => u.uid == _playerUid).firstOrNull;
    final from = parseDay(_from.text);
    final until = parseDay(_until.text);
    String? error;
    if (npc == null || player == null) {
      error = 'Choisissez le PNJ et le joueur.';
    } else if (from == null || until == null) {
      error = 'Dates attendues au format JJ/MM/AAAA.';
    } else if (until.isBefore(from)) {
      error = 'La fin précède le début';
    }
    setState(() => _error = error);
    if (error != null) return;
    final l = NpcLoan(
      characterId: npc!.id,
      characterName: npc.name,
      playerUid: player!.uid,
      playerName: player.displayName,
      from: startOfDay(from!),
      until: endOfDay(until!),
      mode: _mode,
      allowNotes: _allowNotes,
      personality: _personality.text.trim(),
      goals: _goals.text.trim(),
      limits: _limits.text.trim(),
    );
    final ok = await _write(NpcLoan(from: l.from, until: l.until), l, sheet: sheetCopy(npc, _mode), done: 'PNJ confié à ${player.displayName}.');
    if (ok && mounted) {
      setState(() {
        _npcId = null;
        _playerUid = null;
        _until.clear();
        for (final c in [_personality, _goals, _limits]) {
          c.clear();
        }
      });
    }
  }

  Future<void> _extend(NpcLoan l) async {
    final field = TextEditingController(text: _day(l.until));
    final day = await showDialog<DateTime>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Prolonger le prêt de ${l.characterName}'),
        content: TextField(key: const Key('extend-until'), controller: field, decoration: const InputDecoration(labelText: 'Jusqu’au (JJ/MM/AAAA)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(key: const Key('extend-ok'), onPressed: () => Navigator.pop(d, parseDay(field.text)), child: const Text('Prolonger')),
        ],
      ),
    );
    field.dispose();
    if (day == null || !mounted) return;
    if (day.isBefore(startOfDay(l.from))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fin précède le début')));
      return;
    }
    await _write(l, l.copy()..until = endOfDay(day), done: 'Prêt prolongé.');
  }

  Future<void> _revoke(NpcLoan l) async {
    if (!await confirm(context, title: 'Révoquer le prêt ?', body: '${l.playerName} ne verra plus la fiche de ${l.characterName}.', action: 'Révoquer')) {
      return;
    }
    await _write(l, l.copy()..revokedAt = DateTime.now(), done: 'Prêt révoqué.');
  }

  Future<void> _refresh(NpcLoan l, Character? npc) async {
    if (npc == null) return;
    await _write(l, l.copy(), sheet: sheetCopy(npc, l.mode), done: 'Copie mise à jour.');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les PNJ sont confiés par le conte.');
    }
    return asyncView(
      ref.watch(allNpcLoansProvider),
      (loans) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, !me.role.managesAccounts, loans, chars, ref.watch(allUsersProvider).value ?? const []),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allNpcLoansProvider),
    );
  }

  Widget _body(BuildContext context, bool readOnly, List<NpcLoan> loans, List<Character> chars, List<AppUser> users) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final npcs = [for (final c in chars) if (c.kind == CharacterKind.pnj && c.status != CharacterStatus.draft) c];
    final players = [for (final u in users) if (u.role != Role.pending && u.role != Role.disabled) u];
    final active = loans.where((l) => loanState(l, now) == LoanState.active).length;
    final playerName = players.where((u) => u.uid == _playerUid).firstOrNull?.displayName;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    final form = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        gap(DropdownButtonFormField<String>(
          key: const Key('loan-npc'),
          initialValue: npcs.any((c) => c.id == _npcId) ? _npcId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'PNJ'),
          items: [for (final c in npcs) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (id) => setState(() => _npcId = id),
        )),
        gap(DropdownButtonFormField<String>(
          key: const Key('loan-player'),
          initialValue: players.any((u) => u.uid == _playerUid) ? _playerUid : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Joueur'),
          items: [for (final u in players) DropdownMenuItem(value: u.uid, child: Text(u.displayName))],
          onChanged: (uid) => setState(() => _playerUid = uid),
        )),
        gap(Row(children: [
          Expanded(child: TextField(key: const Key('loan-from'), controller: _from, decoration: const InputDecoration(labelText: 'Accès à partir du'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(key: const Key('loan-until'), controller: _until, decoration: const InputDecoration(labelText: 'Jusqu’au (inclus)'))),
        ])),
        gap(SegmentedButton<LoanMode>(
          key: const Key('loan-mode'),
          segments: [for (final m in LoanMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        )),
        CheckboxListTile(
          key: const Key('loan-allow-notes'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Autoriser les notes d’interprétation du joueur'),
          value: _allowNotes,
          onChanged: (v) => setState(() => _allowNotes = v == true),
        ),
        for (final (key, label, c) in [
          ('loan-personality', 'Personnalité', _personality),
          ('loan-goals', 'Objectifs', _goals),
          ('loan-limits', 'Limites', _limits),
        ])
          gap(TextField(key: Key(key), controller: c, maxLines: 2, decoration: InputDecoration(labelText: label))),
        if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const Key('loan-save'),
            onPressed: _busy ? null : () => _create(npcs, players),
            child: Text(playerName == null ? 'Confier' : 'Confier à $playerName'),
          ),
        ),
      ]),
    );

    final list = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [const Expanded(child: SectionTitle('PNJ confiés')), Text('$active en cours', style: t.bodySmall)]),
        ),
        if (loans.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: Text('Aucun prêt.', style: t.bodySmall)),
        for (final l in loans) _row(context, readOnly, l, loans, chars, now),
      ]),
    );

    final title = PageTitle('Confier un PNJ',
        subtitle: 'Le joueur voit la fiche en lecture seule pendant la période choisie. Les notes privées du conte ne sont jamais partagées.');
    if (!isWide(context)) {
      return PageBody(children: [title, const SizedBox(height: 20), if (!readOnly) ...[form, const SizedBox(height: 20)], list]);
    }
    return PageBody(children: [
      title,
      const SizedBox(height: 24),
      if (readOnly)
        list
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: form),
          const SizedBox(width: 24),
          SizedBox(width: 520, child: list),
        ]),
    ]);
  }

  Widget _row(BuildContext context, bool readOnly, NpcLoan l, List<NpcLoan> loans, List<Character> chars, DateTime now) {
    final t = Theme.of(context).textTheme;
    final state = loanState(l, now);
    final open = state == LoanState.active || state == LoanState.upcoming;
    final npc = chars.where((c) => c.id == l.characterId).firstOrNull;
    final warnings = open ? loanWarnings(l, loans: loans, npc: npc, now: now) : const <String>[];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.characterName, style: t.titleSmall?.copyWith(color: open ? null : AppColors.textMuted)),
        Text(
          '${l.playerName} · ${state == LoanState.upcoming ? 'à partir du ${formatDay(l.from)}' : 'jusqu’au ${formatDay(l.until)}'} · ${l.mode.label}',
          style: t.bodySmall,
        ),
        if (!open) Text('Terminé${state == LoanState.revoked ? ' (révoqué)' : ''}', style: t.bodySmall),
        if (open && !readOnly)
          Wrap(spacing: 4, children: [
            TextButton(key: Key('loan-extend-${l.id}'), onPressed: _busy ? null : () => _extend(l), child: const Text('Prolonger')),
            TextButton(key: Key('loan-refresh-${l.id}'), onPressed: _busy || npc == null ? null : () => _refresh(l, npc), child: const Text('Mettre à jour la copie')),
            TextButton(key: Key('loan-revoke-${l.id}'), onPressed: _busy ? null : () => _revoke(l), child: const Text('Révoquer')),
          ]),
        for (final w in warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        if (l.personality.isNotEmpty || l.goals.isNotEmpty || l.limits.isNotEmpty)
          Text('Consignes : ${[l.personality, l.goals, l.limits].where((s) => s.isNotEmpty).join(' · ')}', style: t.bodySmall),
        if (l.playerNotes.isNotEmpty) Text('Notes du joueur : ${l.playerNotes}', style: t.bodySmall),
      ]),
    );
  }
}
```

Si `FirebaseException` n'est pas visible par les imports ci-dessus, ajouter `import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;`.

**`lib/router.dart` :**
- ajouter l'import `npcs/npc_loans_screen.dart`, à sa place alphabétique ;
- `page('/conteur/pnj', soon('PNJ confiés')),` devient `page('/conteur/pnj', const NpcLoansScreen()),`.

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/npcs
git commit -m "feat: PNJ confiés — écran du conte (confier, prolonger, révoquer, mettre à jour la copie)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : écrans du joueur et section « Prêts » de C3

**Files :**
- Create : `lib/npcs/my_npc_loans_screen.dart`.
- Modify :
  - `lib/router.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `test/characters/character_edit_test.dart` ;
  - `test/characters/edit_fixes_test.dart`.
- Test : `test/npcs/my_npc_loans_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2, `CharacterSheetView`, `InfoRow`, `identityLine`, `dots`.
- Produces :
  - `MyNpcLoansScreen` (`/joueur/pnj`) et `NpcLoanScreen(loanId)` (`/joueur/pnj/:id`), avec les clés `loan-player-notes` et `loan-notes-save` ;
  - `NpcLoansSection(characterId)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 4 test`, puis `flutter test test/npcs/my_npc_loans_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/npcs/my_npc_loans_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/npcs/loan_rules.dart';
import 'package:portail_met/npcs/my_npc_loans_screen.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'loan_rules_test.dart' show octave;

void main() {
  NpcLoan current({LoanMode mode = LoanMode.full, String id = 'l1'}) => octave(id: id)
    ..from = startOfDay(DateTime.now().subtract(const Duration(days: 1)))
    ..until = endOfDay(DateTime.now().add(const Duration(days: 19)))
    ..mode = mode;

  Future<FakeNpcLoansRepository> pump(WidgetTester tester, {required List<NpcLoan> loans, Map<String, dynamic>? sheet}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeNpcLoansRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        myNpcLoansProvider.overrideWith((ref) => Stream.value(loans)),
        for (final l in loans) npcLoanSheetProvider(l.id).overrideWith((ref) => Stream.value(sheet)),
        npcLoansRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: MyNpcLoansScreen())),
          GoRoute(path: '/joueur/pnj/:id', builder: (_, s) => Scaffold(body: NpcLoanScreen(loanId: s.pathParameters['id']!))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('un seul prêt : ouvert directement, bandeau, consignes, fiche complète, notes', (tester) async {
    final repo = await pump(tester, loans: [current()], sheet: sheetCopy(sample(), LoanMode.full));
    expect(find.textContaining('lecture seule, accès jusqu’au'), findsOneWidget);
    expect(find.text('Encore 19 jours'), findsOneWidget);
    expect(find.text('Courtois, patient.'), findsOneWidget);
    expect(find.textContaining('Auspex'), findsWidgets);
    await tester.enterText(find.byKey(const Key('loan-player-notes')), 'Promis une faveur.');
    await tester.tap(find.byKey(const Key('loan-notes-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['notes:l1']);
    expect(repo.lastNotes, 'Promis une faveur.');
  });

  testWidgets('fiche résumée : pas de récit ; notes interdites (Review Focus 4)', (tester) async {
    await pump(tester, loans: [current(mode: LoanMode.summary)..allowNotes = false], sheet: sheetCopy(sample()..story = 'Secret', LoanMode.summary));
    expect(find.text('Secret'), findsNothing);
    expect(find.text('Auspex'), findsOneWidget);
    expect(find.byKey(const Key('loan-player-notes')), findsNothing);
  });

  testWidgets('plusieurs prêts : liste des prêts en cours seulement', (tester) async {
    await pump(tester, loans: [current(), current(id: 'l2')..characterName = 'Jonas Ferrand', octave(id: 'old')..until = DateTime(2020)]);
    expect(find.text('Jonas Ferrand'), findsOneWidget);
    expect(find.text('Isaure de Valcourt'), findsOneWidget);
    expect(find.textContaining('lecture seule'), findsNothing);
  });

  testWidgets('aucun prêt en cours : état vide', (tester) async {
    await pump(tester, loans: [octave()..until = DateTime(2020)]);
    expect(find.text('Aucun PNJ confié'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-09-pnj-confies.md 4 impl`.

<!-- file: lib/npcs/my_npc_loans_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../characters/character.dart';
import '../characters/describe_changes.dart' show dots;
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'loan_rules.dart';
import 'npc_loan.dart';
import 'npc_loans_repository.dart';

/// « PNJ confiés » du joueur : ses prêts en cours ; un seul s'ouvre directement.
class MyNpcLoansScreen extends ConsumerWidget {
  const MyNpcLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(myNpcLoansProvider), (loans) {
      final now = DateTime.now();
      final open = [for (final l in loans) if (loanState(l, now) == LoanState.active) l];
      if (open.isEmpty) {
        return const EmptyState(kind: EmptyKind.empty, title: 'Aucun PNJ confié', message: 'Le conte ne vous a confié aucun PNJ en ce moment.');
      }
      if (open.length == 1) return NpcLoanScreen(loanId: open.single.id);
      return PageBody(children: [
        const PageTitle('PNJ confiés'),
        const SizedBox(height: 20),
        for (final l in open)
          Card(
            child: ListTile(
              title: Text(l.characterName, style: t.titleMedium),
              subtitle: Text('Jusqu’au ${formatDay(l.until)} · ${l.mode.label}'),
              onTap: () => context.go('/joueur/pnj/${l.id}'),
            ),
          ),
      ]);
    }, onRetry: () => ref.invalidate(myNpcLoansProvider));
  }
}

/// Un PNJ confié (J-PNJ) : bandeau, consignes, fiche selon le mode, notes d'interprétation.
class NpcLoanScreen extends ConsumerStatefulWidget {
  const NpcLoanScreen({super.key, required this.loanId});
  final String loanId;

  @override
  ConsumerState<NpcLoanScreen> createState() => _NpcLoanScreenState();
}

class _NpcLoanScreenState extends ConsumerState<NpcLoanScreen> {
  final _notes = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(npcLoansRepositoryProvider).saveNotes(widget.loanId, _notes.text);
      messenger.showSnackBar(const SnackBar(content: Text('Notes enregistrées.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : le prêt est peut-être terminé.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(myNpcLoansProvider), (loans) {
      final l = loans.where((x) => x.id == widget.loanId).firstOrNull;
      final now = DateTime.now();
      if (l == null || loanState(l, now) != LoanState.active) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Prêt terminé', message: 'Ce PNJ ne vous est plus confié.');
      }
      if (!_loaded) {
        _notes.text = l.playerNotes;
        _loaded = true;
      }
      final left = daysLeft(l, now);
      return PageBody(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.navActive, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
              child: Text(
                'PNJ confié par ${l.updatedByName ?? 'le conte'} — lecture seule, accès jusqu’au ${formatDay(l.until)} 23h59. '
                'Les notes privées du conte ne sont pas visibles.',
                style: t.bodyMedium?.copyWith(color: AppColors.goldLight),
              ),
            ),
            const SizedBox(width: 12),
            Text(left == 0 ? 'Dernier jour' : 'Encore $left jour${left > 1 ? 's' : ''}', style: t.bodySmall),
          ]),
        ),
        const SizedBox(height: 20),
        PageTitle(l.characterName, subtitle: l.mode.label),
        const SizedBox(height: 20),
        if (l.personality.isNotEmpty || l.goals.isNotEmpty || l.limits.isNotEmpty) ...[
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Consignes du conte'),
              const SizedBox(height: 10),
              for (final (label, text) in [('Personnalité', l.personality), ('Objectifs', l.goals), ('Limites', l.limits)])
                if (text.isNotEmpty) ...[
                  Text(label, style: t.bodySmall),
                  Text(text, style: t.bodyMedium),
                  const SizedBox(height: 8),
                ],
            ]),
          ),
          const SizedBox(height: 20),
        ],
        asyncView(ref.watch(npcLoanSheetProvider(l.id)), (sheet) {
          if (sheet == null) return Text('La fiche n’est pas encore disponible.', style: t.bodySmall);
          final c = Character.fromMap(l.characterId, sheet);
          return l.mode == LoanMode.full ? CharacterSheetView(c) : _Summary(c);
        }, onRetry: () => ref.invalidate(npcLoanSheetProvider(l.id))),
        if (l.allowNotes) ...[
          const SizedBox(height: 20),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Mes notes d’interprétation'),
              if (l.notesAt != null) Text('Partagées avec le conte · enregistré le ${formatDay(l.notesAt)}', style: t.bodySmall),
              const SizedBox(height: 10),
              TextField(
                key: const Key('loan-player-notes'),
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Ce que le PNJ a dit, promis ou appris pendant la partie…'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const Key('loan-notes-save'), onPressed: _busy ? null : _saveNotes, child: const Text('Enregistrer')),
              ),
            ]),
          ),
        ],
      ]);
    }, onRetry: () => ref.invalidate(myNpcLoansProvider));
  }
}

/// Fiche résumée : identité, attributs, Sang et Volonté, compétences principales, disciplines.
class _Summary extends StatelessWidget {
  const _Summary(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(identityLine(c), style: t.bodyMedium),
        const SizedBox(height: 12),
        for (final cat in AttrCategory.values)
          InfoRow(cat.label, '${c.attributes[cat]!.value}${c.attributes[cat]!.focus == null ? '' : ' · ${c.attributes[cat]!.focus}'}'),
        InfoRow('Sang · Volonté', '${c.blood} (${c.bloodPerTurn} par tour) · ${c.willpower}'),
        if ((c.title ?? '').isNotEmpty) InfoRow('Titre', c.title!),
        const SizedBox(height: 12),
        const SectionTitle('Compétences principales'),
        for (final s in c.skills) InfoRow(s.name, dots(s.level)),
        const SizedBox(height: 12),
        const SectionTitle('Disciplines'),
        for (final d in c.disciplines) InfoRow(d.name, dots(d.level)),
      ]),
    );
  }
}

/// Section « Prêts » d'une fiche de PNJ (C3) : joueurs, périodes, notes.
class NpcLoansSection extends ConsumerWidget {
  const NpcLoansSection({super.key, required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final loans = ref.watch(characterNpcLoansProvider(characterId)).value ?? const <NpcLoan>[];
    final now = DateTime.now();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Prêts'),
        const SizedBox(height: 8),
        if (loans.isEmpty) Text('Jamais confié.', style: t.bodySmall),
        for (final l in loans) ...[
          Text(
            '${l.playerName} · du ${formatDay(l.from)} au ${formatDay(l.until)} · ${switch (loanState(l, now)) {
              LoanState.active => 'en cours',
              LoanState.upcoming => 'à venir',
              LoanState.ended => 'terminé',
              LoanState.revoked => 'révoqué',
            }}',
            style: t.bodyMedium,
          ),
          if (l.playerNotes.isNotEmpty) Text('Notes : ${l.playerNotes}', style: t.bodySmall),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}
```

Adapter au besoin aux signatures réelles : `AttrCategory.label` (ou le libellé existant de la catégorie), `InfoRow(label, value)`.

**`lib/router.dart` :**
- ajouter l'import `npcs/my_npc_loans_screen.dart` ;
- `page('/joueur/pnj', soon('PNJ confiés')),` devient deux routes : `/joueur/pnj` vers `const MyNpcLoansScreen()`, et `/joueur/pnj/:id` vers `NpcLoanScreen(loanId: …)`.
- Pour `/joueur/pnj/:id`, suivre la forme d'une route à paramètre déjà présente dans le fichier (même coquille).

**`lib/characters/character_edit_screen.dart` :**
- ajouter l'import `../npcs/my_npc_loans_screen.dart` ;
- après la ligne `ServantsSection(character: latest, linkOf: (_) => '/conteur/goules'),` (ou à la fin des panneaux du bas, après la section des serviteurs), ajouter :

```dart
              if (latest.kind == CharacterKind.pnj) ...[
                const SizedBox(height: 20),
                NpcLoansSection(characterId: latest.id),
              ],
```

**Tests existants :** dans les `overrides` de `test/characters/character_edit_test.dart` et `test/characters/edit_fixes_test.dart`, ajouter `noNpcLoans,` après `noServantFiles,`. Ajouter aussi, dans `character_edit_test.dart`, le test suivant :

```dart
  testWidgets('fiche de PNJ : section « Prêts »', (tester) async {
    // Même mise en place que les autres tests de ce fichier, avec une fiche `..kind = CharacterKind.pnj`.
    expect(find.text('PRÊTS'), findsOneWidget);
    expect(find.text('Jamais confié.'), findsOneWidget);
  });
```

Le corps reprend la fonction de mise en place du fichier (`pump…`) avec la fiche PNJ. `SectionTitle` affiche en majuscules.

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: PNJ confiés — écrans du joueur et section « Prêts » de C3" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
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
  - puis fusion de `pnj-confies` dans `main`.
