# Événements (sous-projet 7a) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** chaque fiche a une chronologie d'événements tenue par le conte, visible en partie par le joueur dans l'onglet « Récit ».

**Architecture :**
- **Sous-collection `characters/{id}/events/{e}`**, avec un champ `visibility` contrôlé par les règles.
- **Modèle et calculs purs** dans `lib/events/story_event.dart` et `lib/events/event_rules.dart`.
- **Dépôt** `lib/events/events_repository.dart` ; providers `eventsRepositoryProvider`, `characterEventsProvider(characterId)`.
- **Événements automatiques** écrits dans le même lot que la fiche :
  - `CharacterRepository.stageEdit`, `saveEdit` et `createSheet` reçoivent `events` ;
  - `decide` vers `active` ajoute « Fiche validée ».
- **Écrans :**
  - onglet « Événements » de l'équipe : `/conteur/fiches/:id/evenements` ;
  - onglet « Récit » : `/joueur/personnages/:id/recit` et `/conteur/fiches/:id/recit`.
- **En-tête des fiches :** `CharacterHeader` passe d'un booléen `history` à un onglet `CharacterTab`.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-12-evenements-design.md`.

**Maquettes :** canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planches `C-Evenements.dc.html`, `C-Evenements-mobile.dc.html`, `J-Recit.dc.html`, `J-Recit-mobile.dc.html`. Pour les lire : outil Artifact, `action: read`, `path: project/<planche>`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md <N> [test|impl]` ;
  - textes en français ;
  - `dart run build_runner build --delete-conflicting-outputs` après un fichier `part` (ne pas committer les autres `.g.dart` modifiés sans rapport) ;
  - analyseur propre, pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Branche :** `evenements`, déjà créée.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Valeurs fixes :**
  - visibilités `public`, `player`, `staff` ;
  - libellés côté équipe « Public », « Joueur et conte », « Conte seul » ;
  - libellés côté joueur « Public », « Vous et le conte » ;
  - titre de 80 caractères au plus, description de 2000 au plus, année de 1 à 9999 ;
  - refus d'écriture : « Enregistrement refusé : réessayez. ».
- **Écart assumé** (à reporter dans le journal) : le conte n'écrit pas d'événement sur sa propre fiche. Les règles l'interdisent, comme pour les notes privées.

## Review Focus

1. **Requête du joueur sans filtre de visibilité :** refusée par les règles. L'écran joueur utilise toujours la requête filtrée. Test : tâche 2.
2. **Date partielle :** « sept. 2026 » passe après « 20 sept. 2026 », et « 2026 » après les deux. Un jour sans mois est refusé partout (formulaire et règles). Tests : tâches 1, 2 et 4.
3. **Événement « conte seul » envoyé au joueur par erreur** (provider mal choisi) : l'onglet Récit filtre aussi avec `visibleTo`. Test : tâche 5.
4. **Fiche créée par l'étreinte avec son événement dans le même lot :** la règle des événements lit la fiche par `getAfter`. Sans cela, la fiche n'existe pas encore. Test : tâche 2.
5. **Le conte sur sa propre fiche :** écriture d'événement refusée, et le formulaire n'apparaît pas. Tests : tâches 2 et 4.

---

### Task 1 : modèle et calculs purs

**Files :**
- Create : `lib/events/story_event.dart`, `lib/events/event_rules.dart`.
- Modify : `lib/core/dates.dart`.
- Test : `test/events/event_rules_test.dart`.

**Interfaces :**
- Produces :
  - `enum EventTone { blood, title, moral, life, plot }` ;
  - `enum EventType` (champs `label`, `tone` ; `EventType.parse(String?)`) ;
  - `enum EventVisibility { public, player, staff }` (`EventVisibility.parse(String?)`) ;
  - `StoryEvent({id, type, title, description, year, month, day, visibility, auto, byName, createdAt})`, avec `fromMap(id, m)`, `toMap()`, `copy()` et `StoryEvent.blank(DateTime now)` ;
  - `newEventData(StoryEvent e, String byUid, String byName)` ;
  - `monthAbbr(int month)` dans `lib/core/dates.dart` ;
  - dans `event_rules.dart` : `formatEventDate(e)`, `compareEvents(a, b)`, `eventChecks(e)`, `visibleTo(e, {required bool staff})`, `visibilityLabel(v, {required bool staff})`, `sourceLabel(e)`, `validatedEvent(Character c, DateTime now)`, `embraceEvent(Character c, DateTime now)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 1 test`, puis `flutter test test/events`.

Expected : échec au chargement.

<!-- file: test/events/event_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/events/event_rules.dart';
import 'package:portail_met/events/story_event.dart';

import '../characters/character_test.dart' show sample;

StoryEvent ev(String title, {int year = 2026, int? month, int? day, EventVisibility v = EventVisibility.player, DateTime? created, String description = ''}) =>
    StoryEvent(id: '', title: title, description: description, year: year, month: month, day: day, visibility: v, createdAt: created);

void main() {
  test('date selon sa précision', () {
    expect(formatEventDate(ev('a', year: 1974)), '1974');
    expect(formatEventDate(ev('a', month: 9)), 'sept. 2026');
    expect(formatEventDate(ev('a', month: 9, day: 20)), '20 sept. 2026');
  });

  test('chronologie : du plus récent au plus ancien, dates partielles après (Review Focus 2)', () {
    final l = [ev('2026'), ev('sept', month: 9), ev('20 sept', month: 9, day: 20), ev('1974', year: 1974), ev('oct', month: 10)]
      ..sort(compareEvents);
    expect([for (final e in l) e.title], ['oct', '20 sept', 'sept', '2026', '1974']);
  });

  test('égalité de date : le plus récemment créé d’abord, un événement en cours d’écriture en tête', () {
    final l = [ev('ancien', created: DateTime(2026, 1, 1)), ev('récent', created: DateTime(2026, 2, 1)), ev('en cours')]..sort(compareEvents);
    expect([for (final e in l) e.title], ['en cours', 'récent', 'ancien']);
  });

  test('contrôles du formulaire', () {
    expect(eventChecks(ev('Nommée Harpie', month: 3, day: 14)), isEmpty);
    expect(eventChecks(ev(' ')), ['Titre obligatoire']);
    expect(eventChecks(ev('x' * 81)), ['Titre : 80 caractères au plus']);
    expect(eventChecks(ev('a', year: 0)), ['Année invalide']);
    expect(eventChecks(ev('a', month: 13)), ['Mois invalide']);
    expect(eventChecks(ev('a', month: 2, day: 32)), ['Jour invalide']);
    expect(eventChecks(ev('a', day: 5)), ['Jour sans mois']);
    expect(eventChecks(ev('a', description: 'x' * 2001)), ['Description : 2000 caractères au plus']);
  });

  test('visibilité et libellés', () {
    final secret = ev('a', v: EventVisibility.staff);
    expect((visibleTo(secret, staff: true), visibleTo(secret, staff: false)), (true, false));
    expect(visibleTo(ev('a', v: EventVisibility.public), staff: false), isTrue);
    expect([for (final v in EventVisibility.values) visibilityLabel(v, staff: true)], ['Public', 'Joueur et conte', 'Conte seul']);
    expect(visibilityLabel(EventVisibility.player, staff: false), 'Vous et le conte');
    expect(sourceLabel(ev('a')..byName = 'Marc'), 'Saisi par Marc');
    expect(sourceLabel(ev('a')..auto = true), 'Automatique');
  });

  test('événements automatiques : fiche validée, étreinte', () {
    final now = DateTime(2026, 10, 12);
    final v = validatedEvent(sample(), now);
    expect((v.type, v.title, v.description, v.year, v.month, v.day, v.visibility, v.auto),
        (EventType.sheet, 'Fiche validée', 'Entrée en jeu de Isaure de Valcourt.', 2026, 10, 12, EventVisibility.player, true));
    expect(embraceEvent(sample()..sire = 'Octave Marchetti', now).title, 'Étreinte par Octave Marchetti');
    final bare = embraceEvent(sample()..sire = null, now);
    expect((bare.type, bare.title, bare.auto, bare.visibility), (EventType.embrace, 'Étreinte', true, EventVisibility.player));
  });

  test('aller-retour et données écrites : exactement les clés permises par les règles', () {
    final e = ev('Chasse', month: 8, description: 'Au musée.');
    final back = StoryEvent.fromMap('e1', e.toMap());
    expect((back.id, back.type, back.title, back.description, back.year, back.month, back.day, back.visibility, back.auto),
        ('e1', EventType.other, 'Chasse', 'Au musée.', 2026, 8, null, EventVisibility.player, false));
    final d = newEventData(e, 'lea', 'Léa');
    expect(d.keys.toSet(), {'type', 'title', 'description', 'year', 'month', 'day', 'visibility', 'auto', 'byUid', 'byName', 'createdAt', 'updatedAt'});
    expect((d['type'], d['visibility'], d['day'], d['byUid']), ('other', 'player', null, 'lea'));
    expect(EventType.parse('inconnu'), EventType.other);
    expect(StoryEvent.blank(DateTime(2026, 10, 12)).year, 2026);
  });
}
```

- [ ] **Step 2 : implémentation**

**`lib/core/dates.dart` :** après la ligne `const _months = [...]`, ajouter :

```dart

/// « sept. » pour 9.
String monthAbbr(int month) => _months[month - 1];
```

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 1 impl`.

<!-- file: lib/events/story_event.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Couleur de pastille d'un type d'événement.
enum EventTone { blood, title, moral, life, plot }

/// Types d'événements (sous-projet 7a) ; le nom est la valeur stockée, contrôlée par les règles.
enum EventType {
  diablerie('Diablerie', EventTone.blood),
  titleGained('Titre obtenu', EventTone.title),
  titleLost('Titre perdu', EventTone.title),
  sectChange('Changement de secte', EventTone.plot),
  pathAdopted('Voie adoptée', EventTone.moral),
  bloodHunt('Chasse de sang', EventTone.plot),
  torpor('Torpeur', EventTone.life),
  awakening('Réveil', EventTone.life),
  finalDeath('Mort ultime', EventTone.life),
  embrace('Étreinte', EventTone.life),
  sheet('Fiche', EventTone.life),
  intrigue('Intrigue', EventTone.plot),
  renown('Renommée', EventTone.plot),
  other('Autre', EventTone.plot);

  const EventType(this.label, this.tone);
  final String label;
  final EventTone tone;

  static EventType parse(String? s) => values.where((t) => t.name == s).firstOrNull ?? other;
}

/// Qui voit l'événement. Pour l'instant, `public` est vu comme `player` (journal public : sous-projet 10).
enum EventVisibility {
  public,
  player,
  staff;

  static EventVisibility parse(String? s) => values.where((v) => v.name == s).firstOrNull ?? staff;
}

/// Événement marquant d'une fiche (`characters/{id}/events/{e}`). Date à précision variable : année, puis mois et jour facultatifs.
class StoryEvent {
  StoryEvent({
    required this.id,
    this.type = EventType.other,
    this.title = '',
    this.description = '',
    required this.year,
    this.month,
    this.day,
    this.visibility = EventVisibility.player,
    this.auto = false,
    this.byName = '',
    this.createdAt,
  });

  /// Nouvel événement saisi par le conte : année en cours, visible par le joueur.
  factory StoryEvent.blank(DateTime now) => StoryEvent(id: '', year: now.year);

  factory StoryEvent.fromMap(String id, Map<String, dynamic> m) => StoryEvent(
        id: id,
        type: EventType.parse(m['type'] as String?),
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        year: (m['year'] as num?)?.toInt() ?? 0,
        month: (m['month'] as num?)?.toInt(),
        day: (m['day'] as num?)?.toInt(),
        visibility: EventVisibility.parse(m['visibility'] as String?),
        auto: m['auto'] == true,
        byName: m['byName'] as String? ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  final String id;
  EventType type;
  String title;
  String description;
  int year;
  int? month;
  int? day;
  EventVisibility visibility;
  bool auto;
  String byName;

  /// Null tant que l'écriture n'est pas confirmée par le serveur.
  final DateTime? createdAt;

  /// Champs écrits à chaque enregistrement (mois et jour toujours présents, null si absents).
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'description': description,
        'year': year,
        'month': month,
        'day': day,
        'visibility': visibility.name,
        'auto': auto,
      };

  StoryEvent copy() => StoryEvent(
        id: id,
        type: type,
        title: title,
        description: description,
        year: year,
        month: month,
        day: day,
        visibility: visibility,
        auto: auto,
        byName: byName,
        createdAt: createdAt,
      );
}

/// Document d'un nouvel événement : exactement les clés permises par les règles.
Map<String, dynamic> newEventData(StoryEvent e, String byUid, String byName) {
  final now = FieldValue.serverTimestamp();
  return {...e.toMap(), 'byUid': byUid, 'byName': byName, 'createdAt': now, 'updatedAt': now};
}
```

<!-- file: lib/events/event_rules.dart -->
```dart
import '../characters/character.dart';
import '../core/dates.dart';
import 'story_event.dart';

/// « 1974 », « sept. 2026 » ou « 20 sept. 2026 ».
String formatEventDate(StoryEvent e) {
  if (e.month == null) return '${e.year}';
  final m = '${monthAbbr(e.month!)} ${e.year}';
  return e.day == null ? m : '${e.day} $m';
}

/// Chronologie : du plus récent au plus ancien ; une partie absente de la date compte comme la plus petite.
/// À date égale, le plus récemment créé d'abord (un événement pas encore confirmé par le serveur en tête).
int compareEvents(StoryEvent a, StoryEvent b) {
  for (final (x, y) in [(a.year, b.year), (a.month ?? 0, b.month ?? 0), (a.day ?? 0, b.day ?? 0)]) {
    if (x != y) return y.compareTo(x);
  }
  final ca = a.createdAt, cb = b.createdAt;
  if (ca == cb) return 0;
  if (ca == null) return -1;
  if (cb == null) return 1;
  return cb.compareTo(ca);
}

/// Erreurs du formulaire ; les règles Firestore appliquent les mêmes bornes.
List<String> eventChecks(StoryEvent e) => [
      if (e.title.trim().isEmpty) 'Titre obligatoire',
      if (e.title.trim().length > 80) 'Titre : 80 caractères au plus',
      if (e.year < 1 || e.year > 9999) 'Année invalide',
      if (e.month != null && (e.month! < 1 || e.month! > 12)) 'Mois invalide',
      if (e.day != null && (e.day! < 1 || e.day! > 31)) 'Jour invalide',
      if (e.day != null && e.month == null) 'Jour sans mois',
      if (e.description.length > 2000) 'Description : 2000 caractères au plus',
    ];

/// L'équipe voit tout ; le joueur voit `public` et `player`.
bool visibleTo(StoryEvent e, {required bool staff}) => staff || e.visibility != EventVisibility.staff;

String visibilityLabel(EventVisibility v, {required bool staff}) => switch (v) {
      EventVisibility.public => 'Public',
      EventVisibility.player => staff ? 'Joueur et conte' : 'Vous et le conte',
      EventVisibility.staff => 'Conte seul',
    };

String sourceLabel(StoryEvent e) => e.auto ? 'Automatique' : 'Saisi par ${e.byName}';

StoryEvent _auto(EventType type, String title, String description, DateTime now) => StoryEvent(
      id: '',
      type: type,
      title: title,
      description: description,
      year: now.year,
      month: now.month,
      day: now.day,
      visibility: EventVisibility.player,
      auto: true,
    );

/// « Fiche validée », écrit avec la validation de la création.
StoryEvent validatedEvent(Character c, DateTime now) => _auto(EventType.sheet, 'Fiche validée', 'Entrée en jeu de ${c.name}.', now);

/// « Étreinte par <sire> », écrit sur la fiche étreinte.
StoryEvent embraceEvent(Character c, DateTime now) {
  final sire = (c.sire ?? '').trim();
  return _auto(EventType.embrace, sire.isEmpty ? 'Étreinte' : 'Étreinte par $sire', '', now);
}
```

Run : `flutter test test/events`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib/core/dates.dart lib/events test/events
git commit -m "feat: événements — modèle, date à précision variable, contrôles et événements automatiques" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : règles Firestore, dépôt, providers, fake

**Files :**
- Modify : `firestore.rules`, `test/fakes.dart`.
- Create : `lib/events/events_repository.dart` et le `.g.dart` généré, `rules_test/events.test.js`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `EventsRepository` : `watchAll(characterId)`, `watchVisible(characterId)`, `save(characterId, StoryEvent e, Actor by)` (création si `e.id` est vide, sinon modification) et `delete(characterId, id)` ;
  - les providers `eventsRepositoryProvider` et `characterEventsProvider(characterId)` ;
  - `FakeEventsRepository` (`calls`, `lastSaved`, `error`), qui note `save:<characterId>:<id ou new>` et `delete:<characterId>:<id>`.

- [ ] **Step 1 : tests des règles (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 2 test`, puis les tests des règles.

Expected : les tests de `events.test.js` échouent.

<!-- file: rules_test/events.test.js -->
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

const ev = (over) => ({
  type: 'intrigue', title: 'Son sire arrive', description: '', year: 2026, month: 2, day: 3,
  visibility: 'player', auto: false, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/c1'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c2'), { name: 'Léa joue', kind: 'pj', playerUid: 'lea', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/c1/events/pub'), ev({ visibility: 'public' }));
    await setDoc(doc(db, 'characters/c1/events/pl'), ev({ visibility: 'player' }));
    await setDoc(doc(db, 'characters/c1/events/st'), ev({ visibility: 'staff' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('lecture : l’équipe voit tout, le joueur hors « conte seul », un autre joueur rien (Review Focus 1)', async () => {
  await assertSucceeds(getDocs(collection(as('julien'), 'characters/c1/events')));
  await assertSucceeds(getDoc(doc(as('zoe'), 'characters/c1/events/pub')));
  await assertSucceeds(getDoc(doc(as('zoe'), 'characters/c1/events/pl')));
  await assertFails(getDoc(doc(as('zoe'), 'characters/c1/events/st')));
  await assertSucceeds(getDocs(query(collection(as('zoe'), 'characters/c1/events'), where('visibility', 'in', ['public', 'player']))));
  await assertFails(getDocs(collection(as('zoe'), 'characters/c1/events')));
  await assertFails(getDoc(doc(as('max'), 'characters/c1/events/pl')));
});

test('écriture : le conte seulement, champs contrôlés (Review Focus 2 et 5)', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/events/n1'), ev({})));
  await assertSucceeds(setDoc(doc(lea, 'characters/c1/events/n2'), ev({ month: null, day: null, year: 1974 })));
  await assertSucceeds(updateDoc(doc(lea, 'characters/c1/events/pl'), { title: 'Autre titre', byUid: 'lea', updatedAt: new Date() }));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n3'), ev({ type: 'inconnu' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n4'), ev({ month: null, day: 4 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n5'), ev({ title: '' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n6'), ev({ secret: 1 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n7'), ev({ byUid: 'julien' })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n8'), ev({ year: 0 })));
  await assertFails(setDoc(doc(lea, 'characters/c1/events/n9'), ev({ visibility: 'tous' })));
  await assertFails(setDoc(doc(as('julien'), 'characters/c1/events/n10'), ev({ byUid: 'julien' })));
  await assertFails(setDoc(doc(as('zoe'), 'characters/c1/events/n11'), ev({ byUid: 'zoe' })));
  await assertFails(setDoc(doc(lea, 'characters/c2/events/n12'), ev({})));
  await assertFails(deleteDoc(doc(as('julien'), 'characters/c1/events/pl')));
  await assertSucceeds(deleteDoc(doc(lea, 'characters/c1/events/st')));
});

test('fiche créée par l’étreinte et son événement dans le même lot (Review Focus 4)', async () => {
  const lea = as('lea');
  const b = writeBatch(lea);
  b.set(doc(lea, 'characters/new1'), {
    name: 'Jeanne', kind: 'pnj', status: 'active', version: 1, lastHistoryId: 'h1',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  b.set(doc(lea, 'characters/new1/history/h1'), { at: serverTimestamp(), byUid: 'lea', byName: 'lea', kind: 'creation', summary: ['Fiche créée'], reason: '' });
  b.set(doc(lea, 'characters/new1/events/e1'), ev({ type: 'embrace', title: 'Étreinte par Lucie', auto: true }));
  await assertSucceeds(b.commit());
});
```

> Si la requête filtrée du joueur échoue alors que la lecture d'un document réussit, remplacer le filtre `in`, dans la règle et dans `watchVisible`, par `visibility != 'staff'` (`where('visibility', isNotEqualTo: 'staff')`). Le noter dans le rapport.

- [ ] **Step 2 : règles**

Dans `firestore.rules`, dans le bloc `match /characters/{id}`, juste après le bloc `match /private/{doc} { … }`, ajouter :

```
      // Événements de la fiche (sous-projet 7a) : l'équipe voit tout, le joueur hors « conte seul ».
      match /events/{e} {
        function eventValid() {
          let d = request.resource.data;
          return d.keys().hasOnly(['type', 'title', 'description', 'year', 'month', 'day', 'visibility', 'auto',
              'byUid', 'byName', 'createdAt', 'updatedAt'])
            && d.type in ['diablerie', 'titleGained', 'titleLost', 'sectChange', 'pathAdopted', 'bloodHunt', 'torpor',
                'awakening', 'finalDeath', 'embrace', 'sheet', 'intrigue', 'renown', 'other']
            && d.title is string && d.title.size() > 0 && d.title.size() <= 80
            && d.description is string && d.description.size() <= 2000
            && d.year is int && d.year >= 1 && d.year <= 9999
            && (d.get('month', null) == null || (d.month is int && d.month >= 1 && d.month <= 12))
            && (d.get('day', null) == null
                || (d.day is int && d.day >= 1 && d.day <= 31 && d.get('month', null) != null))
            && d.visibility in ['public', 'player', 'staff']
            && d.auto is bool
            && d.byUid == request.auth.uid;
        }
        // getAfter : la fiche peut être créée dans le même lot (étreinte). Jamais sur sa propre fiche.
        function notOwnSheet(cid) {
          return getAfter(charPath(cid)).data.get('playerUid', null) != request.auth.uid;
        }
        allow read: if isStaff()
          || (signedIn() && get(charPath(id)).data.get('playerUid', null) == request.auth.uid
              && resource.data.visibility in ['public', 'player']);
        allow create, update: if managesAccounts() && notOwnSheet(id) && eventValid();
        allow delete: if managesAccounts() && notOwnSheet(id);
      }
```

Run : les tests des règles.

Expected : `fail 0`.

- [ ] **Step 3 : dépôt, providers, fake**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 2 impl`.

<!-- file: lib/events/events_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import 'event_rules.dart';
import 'story_event.dart';

part 'events_repository.g.dart';

/// `characters/{id}/events/{e}` : événements de la fiche, écrits par le conte.
class EventsRepository {
  EventsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String characterId) =>
      _db.collection('characters').doc(characterId).collection('events');

  List<StoryEvent> _list(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) StoryEvent.fromMap(d.id, d.data())]..sort(compareEvents);

  /// Équipe : tous les événements.
  Stream<List<StoryEvent>> watchAll(String characterId) => _col(characterId).snapshots().map(_list);

  /// Joueur : la requête doit filtrer la visibilité, sinon les règles la refusent.
  Stream<List<StoryEvent>> watchVisible(String characterId) => _col(characterId)
      .where('visibility', whereIn: [EventVisibility.public.name, EventVisibility.player.name])
      .snapshots()
      .map(_list);

  /// Crée ([e] sans identifiant) ou modifie l'événement. Pas de version : la dernière écriture l'emporte.
  Future<void> save(String characterId, StoryEvent e, Actor by) {
    if (e.id.isEmpty) return _col(characterId).doc().set(newEventData(e, by.uid, by.name));
    return _col(characterId).doc(e.id).update({
      ...e.toMap(),
      'byUid': by.uid,
      'byName': by.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String characterId, String id) => _col(characterId).doc(id).delete();
}

@Riverpod(keepAlive: true)
EventsRepository eventsRepository(Ref ref) => EventsRepository(ref.watch(firestoreProvider));

/// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.
@riverpod
Stream<List<StoryEvent>> characterEvents(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final repo = ref.watch(eventsRepositoryProvider);
  return me.role.isStaff ? repo.watchAll(characterId) : repo.watchVisible(characterId);
}
```

**`test/fakes.dart` :**
- ajouter les imports `package:portail_met/events/events_repository.dart` et `package:portail_met/events/story_event.dart`, à leur place dans l'ordre alphabétique des imports `portail_met` ;
- ajouter à la fin :

```dart
class FakeEventsRepository implements EventsRepository {
  final calls = <String>[];
  StoryEvent? lastSaved;
  Object? error;

  @override
  Future<void> save(String characterId, StoryEvent e, Actor by) async {
    calls.add('save:$characterId:${e.id.isEmpty ? 'new' : e.id}');
    if (error != null) throw error!;
    lastSaved = e;
  }

  @override
  Future<void> delete(String characterId, String id) async {
    calls.add('delete:$characterId:$id');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test`, puis les tests des règles.

Expected : propre, tous les tests passent, et les tests des règles donnent `fail 0`.

- [ ] **Step 4 : commit**

```
git add firestore.rules rules_test/events.test.js lib/events test/fakes.dart
git commit -m "feat: événements — règles Firestore, dépôt et providers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : événements automatiques (validation, étreinte)

**Files :**
- Modify :
  - `lib/characters/character_repository.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `lib/servants/transform_actions.dart` ;
  - `test/fakes.dart` ;
  - `test/characters/character_edit_test.dart` ;
  - `test/servants/transform_actions_test.dart`.

**Interfaces :**
- Consumes : la tâche 1 (`StoryEvent`, `newEventData`, `validatedEvent`, `embraceEvent`).
- Produces :
  - `CharacterRepository.stageEdit(…, {List<StoryEvent> events = const []})`, avec le même paramètre pour `_commit`, `saveEdit` et `createSheet` ;
  - `FakeCharacterRepository.lastEvents` (dernier `saveEdit`) et `lastCreatedEvents` (dernier `createSheet`).

- [ ] **Step 1 : tests (échec attendu)**

**`test/characters/character_edit_test.dart`**, test « C3 : étreindre une goule, clé ghoul supprimée (Review Focus 1) » :
- ajouter l'import `package:portail_met/events/story_event.dart` ;
- à la fin du test, ajouter :

```dart
    final e = repo.lastEvents.single;
    expect((e.type, e.title, e.auto, e.visibility), (EventType.embrace, 'Étreinte par ${repo.lastAfter!.sire}', true, EventVisibility.player));
```

**`test/servants/transform_actions_test.dart`**, test « mortel étreint : nouvelle fiche, puis suppression du mortel » :
- ajouter l'import `package:portail_met/events/story_event.dart` ;
- à la fin du test, ajouter :

```dart
    final e = chars.lastCreatedEvents.single;
    expect((e.type, e.title, e.auto), (EventType.embrace, 'Étreinte par Isaure de Valcourt', true));
```

Run : `flutter test test/characters/character_edit_test.dart test/servants/transform_actions_test.dart`.

Expected : échec à la compilation, car `lastEvents` et `lastCreatedEvents` n'existent pas.

- [ ] **Step 2 : implémentation**

**`test/fakes.dart`**, dans `FakeCharacterRepository` :
- ajouter les champs `List<StoryEvent> lastEvents = const [];` et `List<StoryEvent> lastCreatedEvents = const [];` ;
- `saveEdit` reçoit `{String? kind, Map<String, Object?> extra = const {}, List<StoryEvent> events = const []}`, et note `lastEvents = events;` à côté de `lastExtra = extra;` ;
- `createSheet` reçoit `{String? id, List<StoryEvent> events = const []}`, et note `lastCreatedEvents = events;` à côté de `lastCreatedId = id;`.

**`lib/characters/character_repository.dart` :**
- ajouter les imports `../events/event_rules.dart` et `../events/story_event.dart` ;
- `stageEdit` reçoit le paramètre nommé `List<StoryEvent> events = const [],` après `extra`. À la fin du corps, après `c.legacyServants = false;`, ajouter :

```dart
    for (final e in events) {
      batch.set(ref.collection('events').doc(), newEventData(e, by.uid, by.name));
    }
```

- `_commit` reçoit le même paramètre `List<StoryEvent> events = const [],` et le passe à `stageEdit(…, events: events)` ;
- `saveEdit` : la signature devient `{String? kind, Map<String, Object?> extra = const {}, List<StoryEvent> events = const []}`, et l'appel à `_commit` reçoit `events: events,` ;
- `decide` : l'appel à `_commit` reçoit `events: to == CharacterStatus.active ? [validatedEvent(c, DateTime.now())] : const [],` ;
- `createSheet` :
  - la signature devient `createSheet(Character c, Actor by, String summary, {String? id, List<StoryEvent> events = const []})` ;
  - le lot devient :

```dart
    final batch = _db.batch()
      ..set(ref, {...sheet.toMap(), 'createdAt': now, 'updatedAt': now})
      ..set(h, _entry(by, 'creation', [summary], ''));
    for (final e in events) {
      batch.set(ref.collection('events').doc(), newEventData(e, by.uid, by.name));
    }
    await batch.commit();
```

**`lib/characters/character_edit_screen.dart`**, dans `_embraceGhoul` :
- ajouter l'import `../events/event_rules.dart` ;
- l'appel devient :

```dart
      await ref.read(characterRepositoryProvider).saveEdit(latest, r.after!, choice.reason, by,
          kind: 'embrace', extra: {'ghoul': FieldValue.delete()}, events: [embraceEvent(r.after!, DateTime.now())]);
```

**`lib/servants/transform_actions.dart`**, dans `embraceFollower` :
- ajouter l'import `../events/event_rules.dart` ;
- l'appel devient :

```dart
  await chars.createSheet(sheet, by, 'Fiche créée par l’étreinte de ${row.name}', id: row.id, events: [embraceEvent(sheet, DateTime.now())]);
```

Run : `flutter analyze`, puis `flutter test`, puis les tests des règles.

Expected : propre, tous les tests passent, `fail 0`.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: événements — « Fiche validée » et « Étreinte » écrits avec la fiche" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : onglets de la fiche et écran « Événements » du conte

Maquettes : `C-Evenements.dc.html` (Web), `C-Evenements-mobile.dc.html`.

**Files :**
- Create : `lib/events/event_timeline.dart`, `lib/events/events_screen.dart`.
- Modify :
  - `lib/characters/character_screen.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `lib/router.dart`.
- Test : `test/events/events_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2.
- Produces :
  - `enum CharacterTab { sheet, events, history, story }`, et `CharacterHeader(c, {basePath, tab = CharacterTab.sheet})` ;
  - `EventTimeline({events, staff, onTap, selectedId})`, avec les lignes `ev-row-<id>` ;
  - `CharacterEventsScreen(characterId)`, avec les clés :
    - filtres : `ev-filter-all`, `ev-filter-public`, `ev-filter-player`, `ev-filter-staff`, `ev-type-filter` ;
    - `ev-add` (mobile) ;
    - formulaire : `ev-type`, `ev-year`, `ev-month`, `ev-day`, `ev-title`, `ev-desc`, `ev-vis-<visibilité>`, `ev-save`, `ev-delete`, `ev-delete-confirm`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 4 test`, puis `flutter test test/events/events_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/events/events_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/events_screen.dart';
import 'package:portail_met/events/story_event.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  StoryEvent ev(String id, String title, {EventVisibility v = EventVisibility.player, EventType type = EventType.intrigue, int year = 2026, int? month}) =>
      StoryEvent(id: id, type: type, title: title, year: year, month: month, visibility: v, byName: 'Marc');

  final events = [
    ev('e2', 'Nommée Harpie', v: EventVisibility.public, type: EventType.titleGained, month: 3),
    ev('e1', 'Son sire arrive', v: EventVisibility.staff, month: 2),
    ev('e3', 'Étreinte à Lyon', type: EventType.embrace, year: 1998),
  ];

  Future<FakeEventsRepository> pump(WidgetTester tester, {AppUser user = lea, Character? c, Size size = const Size(1440, 1800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeEventsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        characterProvider('x').overrideWith((ref) => Stream.value(c ?? sample())),
        characterEventsProvider('x').overrideWith((ref) => Stream.value(events)),
        eventsRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterEventsScreen(characterId: 'x'))),
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

  testWidgets('ajouter un événement daté au mois, public', (tester) async {
    final repo = await pump(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('ev-save'))).onPressed, isNull, reason: 'titre obligatoire');
    expect(find.text('Titre obligatoire'), findsOneWidget);
    await choose(tester, 'ev-type', 'Chasse de sang');
    await tester.enterText(find.byKey(const Key('ev-year')), '2026');
    await choose(tester, 'ev-month', 'août');
    await tester.enterText(find.byKey(const Key('ev-title')), 'Chasse de sang prononcée');
    await tester.enterText(find.byKey(const Key('ev-desc')), 'Au musée des Beaux-Arts.');
    await tester.tap(find.byKey(const Key('ev-vis-public')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:x:new']);
    final e = repo.lastSaved!;
    expect((e.type, e.year, e.month, e.day, e.title, e.description, e.visibility, e.auto),
        (EventType.bloodHunt, 2026, 8, null, 'Chasse de sang prononcée', 'Au musée des Beaux-Arts.', EventVisibility.public, false));
  });

  testWidgets('modifier, puis supprimer après confirmation', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('ev-row-e2')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nommée Harpie'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ev-title')), 'Nommée Harpie par le Prince');
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:x:e2']);
    expect(repo.lastSaved!.title, 'Nommée Harpie par le Prince');
    await tester.tap(find.byKey(const Key('ev-row-e2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ev-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ev-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:x:e2');
  });

  testWidgets('jour sans mois impossible : retirer le mois vide le jour (Review Focus 2)', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'ev-month', 'mars');
    await choose(tester, 'ev-day', '14');
    await choose(tester, 'ev-month', '—');
    await tester.enterText(find.byKey(const Key('ev-title')), 'Nommée');
    await tester.pump();
    expect(find.text('Jour sans mois'), findsNothing);
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.month, repo.lastSaved!.day), (null, null));
  });

  testWidgets('filtres : conte seul, puis par type', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('ev-filter-staff')));
    await tester.pumpAndSettle();
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.text('Nommée Harpie'), findsNothing);
    await tester.tap(find.byKey(const Key('ev-filter-all')));
    await tester.pumpAndSettle();
    await choose(tester, 'ev-type-filter', 'Étreinte');
    expect(find.text('Étreinte à Lyon'), findsOneWidget);
    expect(find.text('Son sire arrive'), findsNothing);
  });

  testWidgets('refus d’écriture : message', (tester) async {
    final repo = await pump(tester);
    repo.error = Exception('refus');
    await tester.enterText(find.byKey(const Key('ev-title')), 'Torpeur');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
  });

  testWidgets('narrateur, ou conte sur sa propre fiche : lecture seule (Review Focus 5)', (tester) async {
    await pump(tester, user: julien);
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.byKey(const Key('ev-save')), findsNothing);
    await pump(tester, c: Character(id: 'x', name: 'Léa joue', kind: CharacterKind.pj, playerUid: 'lea', status: CharacterStatus.active));
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.byKey(const Key('ev-save')), findsNothing);
  });

  testWidgets('mobile : la liste, puis le formulaire en pleine page', (tester) async {
    await pump(tester, size: const Size(390, 1600));
    expect(find.byKey(const Key('ev-save')), findsNothing);
    await tester.tap(find.byKey(const Key('ev-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ev-save')), findsOneWidget);
    expect(find.text('← Retour'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : implémentation**

**`lib/characters/character_screen.dart`**, classe `CharacterHeader` :
- avant la classe, ajouter :

```dart
/// Onglet ouvert dans l'en-tête de la fiche.
enum CharacterTab { sheet, events, history, story }
```

- le constructeur devient `const CharacterHeader(this.c, {super.key, required this.basePath, this.tab = CharacterTab.sheet});` ;
- le champ `final bool history;` devient `final CharacterTab tab;` ;
- dans `build`, la fonction locale `tab(String label, String? path, bool selected)` est renommée `item`, avec son corps inchangé ;
- les enfants du `Row` des onglets deviennent :

```dart
            item('Fiche', basePath, tab == CharacterTab.sheet),
            Tooltip(message: 'À venir', child: item('Moralité & liens', null, false)),
            if (basePath.startsWith('/conteur')) item('Événements', '$basePath/evenements', tab == CharacterTab.events),
            item('Historique', '$basePath/historique', tab == CharacterTab.history),
            item('Récit', '$basePath/recit', tab == CharacterTab.story),
```

- dans `CharacterScreen.build`, l'appel devient `CharacterHeader(c, basePath: basePath, tab: history ? CharacterTab.history : CharacterTab.sheet)`.

**`lib/characters/character_edit_screen.dart` :** dans les deux appels `CharacterHeader(…, history: false)`, retirer `, history: false`.

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 4 impl`.

<!-- file: lib/events/event_timeline.dart -->
```dart
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'event_rules.dart';
import 'story_event.dart';

Color toneColor(EventTone t) => switch (t) {
      EventTone.blood => AppColors.accentIcon,
      EventTone.title => AppColors.goldLight,
      EventTone.moral => AppColors.narrator,
      EventTone.life => AppColors.success,
      EventTone.plot => AppColors.textSecondary,
    };

/// Étiquette de visibilité (maquettes C-Evenements et J-Recit).
class VisibilityChip extends StatelessWidget {
  const VisibilityChip(this.v, {super.key, required this.staff});
  final EventVisibility v;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (v) {
      EventVisibility.public => (AppColors.activeBg, AppColors.success),
      EventVisibility.player => (const Color(0xFF2A2240), AppColors.narrator),
      EventVisibility.staff => (AppColors.deadBg, AppColors.linkHover),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(visibilityLabel(v, staff: staff), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// Chronologie d'une fiche, dans l'ordre reçu.
class EventTimeline extends StatelessWidget {
  const EventTimeline({super.key, required this.events, required this.staff, this.onTap, this.selectedId});

  final List<StoryEvent> events;
  final bool staff;
  final void Function(StoryEvent e)? onTap;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (events.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Text('Aucun événement.', style: t.bodyMedium));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, e) in events.indexed)
        InkWell(
          key: Key('ev-row-${e.id}'),
          onTap: onTap == null ? null : () => onTap!(e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: e.id.isNotEmpty && e.id == selectedId ? AppColors.navActive : null,
              border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: toneColor(e.type.tone), shape: BoxShape.circle)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(formatEventDate(e), style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    Text(e.type.label.toUpperCase(), style: t.labelSmall),
                    VisibilityChip(e.visibility, staff: staff),
                  ]),
                  const SizedBox(height: 4),
                  Text(e.title, style: t.titleMedium),
                  if (e.description.isNotEmpty) Text(e.description, style: t.bodyMedium),
                  const SizedBox(height: 4),
                  Text(sourceLabel(e), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}
```

<!-- file: lib/events/events_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show CharacterHeader, CharacterTab;
import '../core/dates.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'event_rules.dart';
import 'event_timeline.dart';
import 'events_repository.dart';
import 'story_event.dart';

/// Onglet « Événements » de la fiche, côté équipe (C-Evenements). Le conte ajoute, modifie et supprime.
class CharacterEventsScreen extends ConsumerStatefulWidget {
  const CharacterEventsScreen({super.key, required this.characterId});
  final String characterId;

  @override
  ConsumerState<CharacterEventsScreen> createState() => _CharacterEventsScreenState();
}

class _CharacterEventsScreenState extends ConsumerState<CharacterEventsScreen> {
  EventVisibility? _vis;
  EventType? _type;

  /// Événement ouvert dans le formulaire (identifiant vide : nouveau), ou null.
  StoryEvent? _open;

  /// Incrémenté à chaque formulaire ouvert ou fermé : les champs repartent de zéro.
  int _form = 0;

  void _edit(StoryEvent? e) => setState(() {
        _open = e?.copy() ?? StoryEvent.blank(DateTime.now());
        _form++;
      });

  void _close() => setState(() {
        _open = null;
        _form++;
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    return asyncView(ref.watch(characterProvider(widget.characterId)), (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      final canEdit = me != null && me.role.managesAccounts && c.playerUid != me.uid;
      return asyncView(
        ref.watch(characterEventsProvider(widget.characterId)),
        (events) => _body(context, c, events, canEdit),
        onRetry: () => ref.invalidate(characterEventsProvider(widget.characterId)),
      );
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }

  Widget _body(BuildContext context, Character c, List<StoryEvent> events, bool canEdit) {
    final wide = isWide(context);
    final shown = [
      for (final e in events)
        if ((_vis == null || e.visibility == _vis) && (_type == null || e.type == _type)) e,
    ];
    Widget chip(EventVisibility? v, String label) => ChoiceChip(
          key: Key('ev-filter-${v?.name ?? 'all'}'),
          label: Text(label),
          selected: _vis == v,
          onSelected: (_) => setState(() => _vis = v),
        );
    final filters = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      chip(null, 'Tous'),
      for (final v in EventVisibility.values) chip(v, visibilityLabel(v, staff: true)),
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<EventType?>(
          key: const Key('ev-type-filter'),
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            const DropdownMenuItem<EventType?>(value: null, child: Text('Tous les types')),
            for (final t in EventType.values) DropdownMenuItem<EventType?>(value: t, child: Text(t.label)),
          ],
          onChanged: (v) => setState(() => _type = v),
        ),
      ),
      if (canEdit && !wide) FilledButton(key: const Key('ev-add'), onPressed: () => _edit(null), child: const Text('+ Ajouter')),
    ]);
    final timeline = Panel(
      padding: EdgeInsets.zero,
      child: EventTimeline(events: shown, staff: true, selectedId: _open?.id, onTap: canEdit ? _edit : null),
    );
    // En Web, le formulaire d'ajout reste ouvert à droite ; en mobile, il s'ouvre en pleine page.
    final editing = _open ?? (canEdit && wide ? StoryEvent.blank(DateTime.now()) : null);
    final form = editing == null
        ? null
        : Panel(child: EventForm(key: ValueKey('ev-form-$_form'), characterId: c.id, initial: editing, onDone: _close));
    final header = CharacterHeader(c, basePath: '/conteur/fiches/${c.id}', tab: CharacterTab.events);

    if (!wide) {
      if (form != null) {
        return PageBody(children: [
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _close, child: const Text('← Retour'))),
          form,
        ]);
      }
      return PageBody(children: [header, const SizedBox(height: 22), filters, const SizedBox(height: 16), timeline]);
    }
    return PageBody(children: [
      header,
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [filters, const SizedBox(height: 16), timeline])),
        if (form != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: form)],
      ]),
    ]);
  }
}

/// Formulaire d'un événement : ajout ([initial] sans identifiant) ou modification, avec suppression.
class EventForm extends ConsumerStatefulWidget {
  const EventForm({super.key, required this.characterId, required this.initial, required this.onDone});
  final String characterId;
  final StoryEvent initial;
  final VoidCallback onDone;

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  late final StoryEvent _e = widget.initial.copy();
  late final _year = TextEditingController(text: '${_e.year}');
  late final _title = TextEditingController(text: _e.title);
  late final _desc = TextEditingController(text: _e.description);
  bool _busy = false;

  bool get _isNew => _e.id.isEmpty;

  @override
  void dispose() {
    _year.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _read() => _e
    ..year = int.tryParse(_year.text.trim()) ?? 0
    ..title = _title.text.trim()
    ..description = _desc.text.trim();

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    _read();
    if (by == null || eventChecks(_e).isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepositoryProvider).save(widget.characterId, _e, by);
      messenger.showSnackBar(SnackBar(content: Text(_isNew ? 'Événement ajouté.' : 'Événement enregistré.')));
      widget.onDone();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l’événement ?'),
        content: Text('« ${_e.title} » sera retiré de la chronologie.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(key: const Key('ev-delete-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepositoryProvider).delete(widget.characterId, _e.id);
      messenger.showSnackBar(const SnackBar(content: Text('Événement supprimé.')));
      widget.onDone();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    _read();
    final errors = eventChecks(_e);
    void touch(String _) => setState(() {});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_isNew ? 'Ajouter un événement' : 'Modifier l’événement'),
      const SizedBox(height: 12),
      DropdownButtonFormField<EventType>(
        key: const Key('ev-type'),
        initialValue: _e.type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Type'),
        items: [for (final ty in EventType.values) DropdownMenuItem(value: ty, child: Text(ty.label))],
        onChanged: (v) => setState(() => _e.type = v ?? _e.type),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            key: const Key('ev-year'),
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Année'),
            onChanged: touch,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: const Key('ev-month'),
            initialValue: _e.month,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mois'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('—')),
              for (var m = 1; m <= 12; m++) DropdownMenuItem<int?>(value: m, child: Text(monthAbbr(m))),
            ],
            onChanged: (v) => setState(() {
              _e.month = v;
              if (v == null) _e.day = null;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          // Recréé quand le mois change : sans mois, le jour est vidé et fermé.
          child: KeyedSubtree(
            key: ValueKey('ev-day-${_e.month}'),
            child: DropdownButtonFormField<int?>(
              key: const Key('ev-day'),
              initialValue: _e.day,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Jour'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                for (var d = 1; d <= 31; d++) DropdownMenuItem<int?>(value: d, child: Text('$d')),
              ],
              onChanged: _e.month == null ? null : (v) => setState(() => _e.day = v),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextField(
        key: const Key('ev-title'),
        controller: _title,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Titre'),
        onChanged: touch,
      ),
      TextField(
        key: const Key('ev-desc'),
        controller: _desc,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Ce qui s’est passé'),
        onChanged: touch,
      ),
      const SizedBox(height: 12),
      Text('Qui le voit', style: t.labelMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in EventVisibility.values)
          ChoiceChip(
            key: Key('ev-vis-${v.name}'),
            label: Text(visibilityLabel(v, staff: true)),
            selected: _e.visibility == v,
            onSelected: (_) => setState(() => _e.visibility = v),
          ),
      ]),
      const SizedBox(height: 8),
      for (final err in errors) Text(err, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton(
          key: const Key('ev-save'),
          onPressed: _busy || errors.isNotEmpty ? null : _save,
          child: Text(_isNew ? 'Ajouter l’événement' : 'Enregistrer'),
        ),
        if (!_isNew) ...[
          TextButton(
            key: const Key('ev-delete'),
            onPressed: _busy ? null : _delete,
            child: const Text('Supprimer', style: TextStyle(color: AppColors.linkHover)),
          ),
          TextButton(onPressed: widget.onDone, child: const Text('Annuler')),
        ],
      ]),
    ]);
  }
}
```

**`lib/router.dart` :**
- ajouter l'import `events/events_screen.dart` (dans l'ordre alphabétique) ;
- après la route `/conteur/fiches/:id/historique`, ajouter :

```dart
          GoRoute(
            path: '/conteur/fiches/:id/evenements',
            builder: (_, s) => CharacterEventsScreen(characterId: s.pathParameters['id']!),
          ),
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/events
git commit -m "feat: événements — onglet du conte (chronologie, filtres, ajout, modification, suppression)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : onglet « Récit »

Maquettes : `J-Recit.dc.html` (Web), `J-Recit-mobile.dc.html`.

**Files :**
- Create : `lib/events/story_screen.dart`.
- Modify : `lib/router.dart`.
- Test : `test/events/story_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1, 2 et 4 (`EventTimeline`, `CharacterHeader`, `CharacterTab.story`, `characterEventsProvider`).
- Produces : `CharacterStoryScreen(characterId, basePath)`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 5 test`, puis `flutter test test/events/story_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/events/story_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/events/story_screen.dart';

import '../characters/character_test.dart' show sample;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  // Le provider renvoie volontairement un événement « conte seul » : l'écran doit le filtrer (Review Focus 3).
  final events = [
    StoryEvent(id: 'e1', title: 'Son sire arrive', year: 2026, month: 2, visibility: EventVisibility.staff),
    StoryEvent(id: 'e2', type: EventType.titleGained, title: 'Nommée Harpie', year: 2026, month: 3, visibility: EventVisibility.public),
    StoryEvent(id: 'e3', type: EventType.embrace, title: 'Étreinte au soir de sa dernière représentation', year: 1974),
  ];

  Future<void> pump(WidgetTester tester, AppUser user, Character c, {Size size = const Size(1440, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        characterProvider('x').overrideWith((ref) => Stream.value(c)),
        characterEventsProvider('x').overrideWith((ref) => Stream.value(events)),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: const Scaffold(body: CharacterStoryScreen(characterId: 'x', basePath: '/joueur/personnages/x')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Character isaure() => sample()
    ..concept = 'Cantatrice lyrique devenue faiseuse de réputations.'
    ..story = 'Soprano admirée de l’opéra municipal.';

  testWidgets('joueur : récit et événements ouverts, jamais « conte seul » (Review Focus 3)', (tester) async {
    await pump(tester, camille, isaure());
    expect(find.text('Cantatrice lyrique devenue faiseuse de réputations.'), findsOneWidget);
    expect(find.text('Soprano admirée de l’opéra municipal.'), findsOneWidget);
    expect(find.text('Nommée Harpie'), findsOneWidget);
    expect(find.text('Étreinte au soir de sa dernière représentation'), findsOneWidget);
    expect(find.text('Son sire arrive'), findsNothing);
    expect(find.text('Vous et le conte'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
  });

  testWidgets('équipe : tous les événements', (tester) async {
    await pump(tester, lea, isaure());
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.text('Conte seul'), findsOneWidget);
    expect(find.text('Joueur et conte'), findsOneWidget);
  });

  testWidgets('sans récit ; mobile en une colonne', (tester) async {
    await pump(tester, camille, sample()..story = null, size: const Size(390, 1600));
    expect(find.text('Aucun récit.'), findsOneWidget);
    expect(find.text('Nommée Harpie'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-12-evenements.md 5 impl`.

<!-- file: lib/events/story_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show CharacterHeader, CharacterTab;
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'event_rules.dart';
import 'event_timeline.dart';
import 'events_repository.dart';

/// Onglet « Récit » (J-Recit) : le récit de la fiche et ses événements marquants, en lecture.
/// Le joueur ne voit que les événements qui lui sont ouverts ; l'équipe les voit tous.
class CharacterStoryScreen extends ConsumerWidget {
  const CharacterStoryScreen({super.key, required this.characterId, required this.basePath});

  final String characterId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final staff = ref.watch(currentUserProvider).value?.role.isStaff ?? false;
    final value = ref.watch(characterProvider(characterId));
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    return asyncView(value, (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      final concept = (c.concept ?? '').trim();
      final text = (c.story ?? '').trim();
      final story = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Concept'),
          const SizedBox(height: 8),
          Text(concept.isEmpty ? '—' : concept, style: t.titleMedium),
          const SizedBox(height: 20),
          const SectionTitle('Récit'),
          const SizedBox(height: 8),
          Text(text.isEmpty ? 'Aucun récit.' : text, style: t.bodyLarge?.copyWith(height: 1.6)),
        ]),
      );
      final events = Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Row(children: [
              const Expanded(child: SectionTitle('Événements marquants')),
              Text('Tenus par le conte', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          asyncView(
            ref.watch(characterEventsProvider(c.id)),
            (l) => EventTimeline(events: [for (final e in l) if (visibleTo(e, staff: staff)) e], staff: staff),
            onRetry: () => ref.invalidate(characterEventsProvider(c.id)),
          ),
        ]),
      );
      final header = CharacterHeader(c, basePath: basePath, tab: CharacterTab.story);
      if (!isWide(context)) {
        return PageBody(children: [header, const SizedBox(height: 22), story, const SizedBox(height: 20), events]);
      }
      return PageBody(children: [
        header,
        const SizedBox(height: 22),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: story),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: events),
        ]),
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(characterId)));
  }
}
```

**`lib/router.dart` :**
- ajouter l'import `events/story_screen.dart` ;
- après la route `/joueur/personnages/:id/historique`, ajouter :

```dart
          GoRoute(
            path: '/joueur/personnages/:id/recit',
            builder: (_, s) => CharacterStoryScreen(
              characterId: s.pathParameters['id']!,
              basePath: '/joueur/personnages/${s.pathParameters['id']}',
            ),
          ),
```

- après la route `/conteur/fiches/:id/evenements`, ajouter :

```dart
          GoRoute(
            path: '/conteur/fiches/:id/recit',
            builder: (_, s) => CharacterStoryScreen(
              characterId: s.pathParameters['id']!,
              basePath: '/conteur/fiches/${s.pathParameters['id']}',
            ),
          ),
```

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 3 : commit**

```
git add lib test/events
git commit -m "feat: événements — onglet Récit (récit de la fiche et événements visibles)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
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
  - puis fusion de `evenements` dans `main`, et `git push origin main`.
