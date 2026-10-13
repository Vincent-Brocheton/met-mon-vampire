# Notifications (sous-projet 10a) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** une page « Notifications » et un point rouge sur la cloche, à partir des données que l'application tient déjà ; « Tout marquer comme lu » enregistre la date de dernière visite.

**Architecture :**
- **Calcul pur** dans `lib/notifications/notification_rules.dart` : une fonction par source, `feed` (60 jours, tri), `unreadCount`.
- **Providers** dans `lib/notifications/notifications_repository.dart` : `notificationsProvider` assemble les sources depuis les providers existants (conte ou joueur), `unreadNotificationsProvider` compte les non lues ; `NotificationsRepository.markAllRead` écrit `users/{uid}.notifSeenAt` (heure du serveur).
- **Écrans :** `NotificationsScreen` pour `/joueur/notifications` et `/conteur/notifications` ; point rouge sur la cloche de `AppShell`.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-13-notifications-design.md`.

**Maquettes :** `C-Notifications`, `J-Notifications` (sans le panneau « Recevoir aussi par e-mail »).

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md <N> [test|impl]` ;
  - textes en français, apostrophe typographique ’, espace avant « : » ;
  - analyseur propre, pas de `dart format` ; fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - ne jamais commiter `bash.exe.stackdump`, `rules_test/bash.exe.stackdump`, `CLAUDE.md` ni `rules_test/firestore-debug.log`.
- **Branche :** `notifications`, déjà créée depuis `main` (la spec y est commitée).
- **Code généré :** `dart run build_runner build --delete-conflicting-outputs` après un nouveau `@riverpod` ; commiter les `.g.dart` qui changent.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Dart :** un record contenant des listes se compare par identité ; `select` demande l'import `package:flutter_riverpod/flutter_riverpod.dart`.
- **Textes fixes :**
  - « Notifications », « {n} non lue. La cloche en haut de l’écran les signale. » / « {n} non lues. … », « Aucune notification non lue. », « Tout marquer comme lu », « Rien de nouveau pour l’instant. », « Enregistrement refusé : réessayez. » ;
  - conte : « Demande d’accès : {nom} » (détail « « {message} » » ou « Nouveau compte en attente. »), « 1 demande à traiter » / « {n} demandes à traiter » (« Dépenses d’XP et demandes en attente. »), « {fiche} : fiche soumise à validation » (« Joueur : {nom} » ou « Fiche en attente de validation. »), « {auteur} a publié une page du wiki » (« « {titre} », version {n}. ») ;
  - joueur : « Une demande a été validée » (« {fiche} · la fiche est à jour. »), « Une demande a été refusée » (« Le conte a laissé un motif. Votre XP réservée vous est rendue. »), « XP reçue : +{n} » ({fiche}), « Fiches figées pour la partie du {date} » (« Jusqu’au {date} à {hh:mm}, vos demandes restent en attente. »), « Un PNJ vous a été confié » ({PNJ}), « Nouvelle page du wiki » / « Page du wiki mise à jour » (« « {titre} » »).
- **Leçons des lots précédents :** rangées de boutons en `Wrap` (390 px) ; un écran qui ajoute un provider oblige chaque test qui le monte à le remplacer (`unreadNotificationsProvider` dans `test/app_shell_test.dart`).

## Review Focus

1. **Narrateur :** pas de ligne « Demande d’accès » (il ne lit pas les comptes, la requête serait refusée). Test : tâche 2.
2. **Source en erreur ou en chargement :** le fil s'affiche quand même avec les autres sources. Test : tâche 2.
3. **« Tout marquer comme lu » refusé (hors ligne) :** message, fil inchangé. Test : tâche 3.
4. **`notifSeenAt` :** seul le titulaire l'écrit, à l'heure du serveur, sans autre champ. Test : tâche 2 (règles).
5. **Prêt de PNJ révoqué, partie dont le gel est levé ou terminé :** pas de notification. Test : tâche 1.

---

### Task 1 : calcul du fil (pur), date de dernière visite, auteur des pages du wiki

**Files :**
- Create : `lib/notifications/notification_rules.dart`.
- Modify : `lib/auth/session.dart` (`AppUser.notifSeenAt`), `lib/wiki/wiki_page.dart` (`WikiPage.updatedByUid`).
- Test : `test/notifications/notification_rules_test.dart`.

**Interfaces :**
- Produces :
  - `NotifKind { access, requests, review, wiki, decided, xp, freeze, npc }` ;
  - `AppNotification({kind, title, detail, at, link})` ;
  - `accessRequests(List<AppUser>)`, `pendingSummary(List<XpRequest>)`, `reviewQueue(List<Character>)`, `wikiByOthers(List<WikiPage>, String uid)`, `decidedRequests(List<XpRequest>)`, `xpReceived(Character, List<HistoryEntry>)`, `freeze(List<Game>, DateTime now)`, `npcLoans(List<NpcLoan>)`, `wikiForPlayer(List<WikiPage>)` → `List<AppNotification>` ;
  - `feedDays` (60), `feed(List<AppNotification>, {required DateTime now})`, `isUnread(AppNotification, DateTime? seenAt)`, `unreadCount(List<AppNotification>, DateTime? seenAt)` ;
  - `AppUser.notifSeenAt` (`DateTime?`), `WikiPage.updatedByUid` (`String?`).

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md 1 test`, puis `flutter test test/notifications`.

Expected : échec au chargement.

<!-- file: test/notifications/notification_rules_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/notifications/notification_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/xp/xp_request.dart';

final now = DateTime(2026, 10, 13, 12);

XpRequest req(RequestStatus s, {DateTime? submitted, DateTime? decided, String name = 'Isaure'}) =>
    XpRequest(characterId: 'c1', characterName: name, playerUid: 'zoe', playerName: 'Zoé', status: s, submittedAt: submitted, decidedAt: decided);

WikiPage wp(String id, {String? by, int version = 1, DateTime? at}) =>
    WikiPage(id: id, title: 'Page $id', version: version, updatedAt: at ?? DateTime(2026, 10, 1), updatedByName: by == null ? null : 'Léa', updatedByUid: by);

HistoryEntry hist(String id, int earned, DateTime at) => HistoryEntry(id: id, at: at, byName: 'Léa', kind: 'xp', summary: const [], reason: '', xpEarned: earned);

void main() {
  test('demandes d’accès : nom, message entre guillemets, sinon texte par défaut', () {
    final n = accessRequests([
      AppUser(uid: 'p', displayName: 'Paul V.', email: 'p@ex.fr', role: Role.pending, accessMessage: ' Je reprends. ', createdAt: DateTime(2026, 9, 28)),
      AppUser(uid: 'z', displayName: 'Zoé A.', email: 'z@ex.fr', role: Role.pending, createdAt: DateTime(2026, 9, 27)),
      const AppUser(uid: 'x', displayName: 'Sans date', email: 'x@ex.fr', role: Role.pending),
    ]);
    expect([for (final x in n) x.title], ['Demande d’accès : Paul V.', 'Demande d’accès : Zoé A.']);
    expect([for (final x in n) x.detail], ['« Je reprends. »', 'Nouveau compte en attente.']);
    expect(n.first.link, '/conteur/comptes');
  });

  test('demandes à traiter : une seule ligne, singulier ou pluriel, datée de la plus récente', () {
    expect(pendingSummary(const []), isEmpty);
    final one = pendingSummary([req(RequestStatus.pending, submitted: DateTime(2026, 10, 2))]);
    expect((one.single.title, one.single.at), ('1 demande à traiter', DateTime(2026, 10, 2)));
    final two = pendingSummary([req(RequestStatus.pending, submitted: DateTime(2026, 10, 2)), req(RequestStatus.pending, submitted: DateTime(2026, 10, 5))]);
    expect((two.single.title, two.single.at, two.single.link), ('2 demandes à traiter', DateTime(2026, 10, 5), '/conteur/demandes'));
  });

  test('fiches soumises ; wiki publié par un autre conteur seulement', () {
    final c = Character(id: 'n', name: 'Nikolaï Vesk', kind: CharacterKind.pj, playerName: 'Thomas B.', status: CharacterStatus.review)
      ..submittedAt = DateTime(2026, 9, 23);
    final r = reviewQueue([c, Character(id: 'o', name: 'Sans date', kind: CharacterKind.pj)]);
    expect((r.single.title, r.single.detail), ('Nikolaï Vesk : fiche soumise à validation', 'Joueur : Thomas B.'));
    final w = wikiByOthers([wp('a', by: 'lea', version: 4), wp('b', by: 'marc'), wp('c')], 'marc');
    expect((w.single.title, w.single.detail, w.single.link), ('Léa a publié une page du wiki', '« Page a », version 4.', '/conteur/wiki/edition/a/historique'));
  });

  test('joueur : demandes tranchées, XP reçue, gel en cours, PNJ confiés, wiki (Review Focus 5)', () {
    final d = decidedRequests([
      req(RequestStatus.accepted, decided: DateTime(2026, 9, 18)),
      req(RequestStatus.rejected, decided: DateTime(2026, 9, 16)),
      req(RequestStatus.pending, submitted: DateTime(2026, 9, 1)),
    ]);
    expect([for (final x in d) x.title], ['Une demande a été validée', 'Une demande a été refusée']);
    expect(d.first.detail, 'Isaure · la fiche est à jour.');
    final c = Character(id: 'c1', name: 'Isaure', kind: CharacterKind.pj);
    final x = xpReceived(c, [hist('h1', 3, DateTime(2026, 10, 1)), hist('h2', 0, DateTime(2026, 10, 2)), hist('h3', -2, DateTime(2026, 10, 3))]);
    expect((x.single.title, x.single.detail, x.single.link), ('XP reçue : +3', 'Isaure', '/joueur/personnages/c1/historique'));
    final games = [
      Game(id: 'g1', date: DateTime(2026, 10, 3), frozenAt: DateTime(2026, 9, 29, 20), until: DateTime(2026, 10, 14, 6)),
      Game(id: 'g0', date: DateTime(2026, 9, 1), frozenAt: DateTime(2026, 8, 30), until: DateTime(2026, 9, 2)),
      Game(id: 'g2', date: DateTime(2026, 10, 10), frozenAt: DateTime(2026, 10, 9), until: DateTime(2026, 10, 20), liftedAt: DateTime(2026, 10, 11)),
    ];
    final f = freeze(games, now);
    expect((f.single.title, f.single.detail, f.single.at),
        ('Fiches figées pour la partie du 3 oct.', 'Jusqu’au 14 oct. à 06:00, vos demandes restent en attente.', DateTime(2026, 9, 29, 20)));
    final l = npcLoans([
      NpcLoan(id: 'l1', characterName: 'Sœur Agathe', from: DateTime(2026, 9, 15), until: DateTime(2026, 12, 1)),
      NpcLoan(id: 'l2', from: DateTime(2026, 9, 1), until: DateTime(2026, 9, 2), revokedAt: DateTime(2026, 9, 2)),
    ]);
    expect((l.single.title, l.single.detail, l.single.link), ('Un PNJ vous a été confié', 'Sœur Agathe', '/joueur/pnj/l1'));
    final w = wikiForPlayer([wp('a'), wp('b', version: 3)]);
    expect([for (final x in w) x.title], ['Nouvelle page du wiki', 'Page du wiki mise à jour']);
    expect((w.first.detail, w.first.link), ('« Page a »', '/joueur/wiki/page/a'));
  });

  test('fil : 60 jours, du plus récent au plus ancien ; non lues après la dernière visite', () {
    AppNotification n(DateTime at) => AppNotification(kind: NotifKind.xp, title: '$at', detail: '', at: at, link: '/');
    final f = feed([n(DateTime(2026, 10, 1)), n(DateTime(2026, 7, 1)), n(DateTime(2026, 10, 10))], now: now);
    expect([for (final x in f) x.at], [DateTime(2026, 10, 10), DateTime(2026, 10, 1)]);
    expect(unreadCount(f, null), 2);
    expect(unreadCount(f, DateTime(2026, 10, 5)), 1);
    expect((isUnread(f.first, DateTime(2026, 10, 5)), isUnread(f.last, DateTime(2026, 10, 5))), (true, false));
  });

  test('compte : pas de date de visite par défaut ; page : auteur de la publication', () {
    expect(const AppUser(uid: 'u', displayName: 'U', email: 'u@ex.fr', role: Role.joueur).notifSeenAt, isNull);
    expect(WikiPage.fromMap('x', {'updatedByUid': 'lea'}).updatedByUid, 'lea');
  });
}
```

- [ ] **Step 2 : implémentation**

Dans `lib/auth/session.dart` :
- constructeur : après `this.wikiAudiences = const [],`, ajouter `this.notifSeenAt,` ;
- `fromDoc` : après la ligne `wikiAudiences: [...]`, ajouter `notifSeenAt: (m['notifSeenAt'] as Timestamp?)?.toDate(),` ;
- après `final List<String> wikiAudiences;`, ajouter :

```dart

  /// Dernière visite des notifications (« Tout marquer comme lu », heure du serveur ; sous-projet 10a).
  final DateTime? notifSeenAt;
```

Dans `lib/wiki/wiki_page.dart` (classe `WikiPage`) :
- constructeur : remplacer `    this.updatedByName,\n  });` (la première occurrence, dans `WikiPage`) par `    this.updatedByName,\n    this.updatedByUid,\n  });` ;
- `fromMap` : après `updatedByName: m['updatedByName'] as String?,`, ajouter `updatedByUid: m['updatedByUid'] as String?,` ;
- après `final String? updatedByName;`, ajouter `final String? updatedByUid;`.

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md 1 impl`.

<!-- file: lib/notifications/notification_rules.dart -->
```dart
import '../auth/session.dart';
import '../characters/character.dart';
import '../core/dates.dart';
import '../games/game.dart';
import '../npcs/npc_loan.dart';
import '../wiki/wiki_page.dart';
import '../xp/xp_request.dart';

enum NotifKind { access, requests, review, wiki, decided, xp, freeze, npc }

/// Notification calculée : rien n'est stocké, chaque ligne vient d'une donnée que l'application tient déjà.
class AppNotification {
  const AppNotification({required this.kind, required this.title, required this.detail, required this.at, required this.link});
  final NotifKind kind;
  final String title;
  final String detail;
  final DateTime at;
  final String link;
}

/// Durée du fil, en jours.
const feedDays = 60;

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---- Conte ----

List<AppNotification> accessRequests(List<AppUser> pending) => [
      for (final u in pending)
        if (u.createdAt case final at?)
          AppNotification(
            kind: NotifKind.access,
            title: 'Demande d’accès : ${u.displayName}',
            detail: (u.accessMessage ?? '').trim().isEmpty ? 'Nouveau compte en attente.' : '« ${u.accessMessage!.trim()} »',
            at: at,
            link: '/conteur/comptes',
          ),
    ];

/// Une seule ligne pour toutes les demandes en attente, datée de la plus récente.
List<AppNotification> pendingSummary(List<XpRequest> pending) {
  final dates = [for (final r in pending) if (r.date case final d?) d];
  if (dates.isEmpty) return const [];
  final n = pending.length;
  return [
    AppNotification(
      kind: NotifKind.requests,
      title: n == 1 ? '1 demande à traiter' : '$n demandes à traiter',
      detail: 'Dépenses d’XP et demandes en attente.',
      at: dates.reduce((a, b) => a.isAfter(b) ? a : b),
      link: '/conteur/demandes',
    ),
  ];
}

List<AppNotification> reviewQueue(List<Character> sheets) => [
      for (final c in sheets)
        if (c.submittedAt case final at?)
          AppNotification(
            kind: NotifKind.review,
            title: '${c.name} : fiche soumise à validation',
            detail: (c.playerName ?? '').isEmpty ? 'Fiche en attente de validation.' : 'Joueur : ${c.playerName}',
            at: at,
            link: '/conteur/demandes',
          ),
    ];

/// Pages publiées par un autre membre du conte que le lecteur [uid].
List<AppNotification> wikiByOthers(List<WikiPage> pages, String uid) => [
      for (final p in pages)
        if (p.updatedAt case final at? when p.updatedByUid != null && p.updatedByUid != uid)
          AppNotification(
            kind: NotifKind.wiki,
            title: '${p.updatedByName ?? 'Un conteur'} a publié une page du wiki',
            detail: '« ${p.title} », version ${p.version}.',
            at: at,
            link: '/conteur/wiki/edition/${p.id}/historique',
          ),
    ];

// ---- Joueur ----

List<AppNotification> decidedRequests(List<XpRequest> mine) => [
      for (final r in mine)
        if (r.decidedAt case final at? when r.status == RequestStatus.accepted || r.status == RequestStatus.rejected)
          r.status == RequestStatus.accepted
              ? AppNotification(
                  kind: NotifKind.decided, title: 'Une demande a été validée', detail: '${r.characterName} · la fiche est à jour.', at: at, link: '/joueur/demandes')
              : AppNotification(
                  kind: NotifKind.decided,
                  title: 'Une demande a été refusée',
                  detail: 'Le conte a laissé un motif. Votre XP réservée vous est rendue.',
                  at: at,
                  link: '/joueur/demandes',
                ),
    ];

/// Entrées d'historique de la fiche qui ajoutent de l'XP gagnée (gain mensuel, attribution).
List<AppNotification> xpReceived(Character c, List<HistoryEntry> history) => [
      for (final e in history)
        if (e.at case final at? when e.xpEarned > 0)
          AppNotification(kind: NotifKind.xp, title: 'XP reçue : +${e.xpEarned}', detail: c.name, at: at, link: '/joueur/personnages/${c.id}/historique'),
    ];

/// Parties dont le gel est en cours : ni levé, ni dépassé.
List<AppNotification> freeze(List<Game> games, DateTime now) => [
      for (final g in games)
        if (g.liftedAt == null && now.isBefore(g.until))
          AppNotification(
            kind: NotifKind.freeze,
            title: 'Fiches figées pour la partie du ${formatDay(g.date)}',
            detail: 'Jusqu’au ${formatDay(g.until)} à ${_hm(g.until)}, vos demandes restent en attente.',
            at: g.frozenAt,
            link: '/joueur/personnages',
          ),
    ];

List<AppNotification> npcLoans(List<NpcLoan> loans) => [
      for (final l in loans)
        if (l.revokedAt == null)
          AppNotification(kind: NotifKind.npc, title: 'Un PNJ vous a été confié', detail: l.characterName, at: l.from, link: '/joueur/pnj/${l.id}'),
    ];

/// Pages lisibles par le joueur (la requête du wiki les filtre déjà).
List<AppNotification> wikiForPlayer(List<WikiPage> pages) => [
      for (final p in pages)
        if (p.updatedAt case final at?)
          AppNotification(
            kind: NotifKind.wiki,
            title: p.version <= 1 ? 'Nouvelle page du wiki' : 'Page du wiki mise à jour',
            detail: '« ${p.title} »',
            at: at,
            link: '/joueur/wiki/page/${p.id}',
          ),
    ];

// ---- Fil ----

/// Les [feedDays] derniers jours, du plus récent au plus ancien.
List<AppNotification> feed(List<AppNotification> items, {required DateTime now}) {
  final cutoff = now.subtract(const Duration(days: feedDays));
  return [for (final i in items) if (i.at.isAfter(cutoff)) i]..sort((a, b) => b.at.compareTo(a.at));
}

/// Non lue : plus récente que la dernière visite (toutes, sans visite).
bool isUnread(AppNotification n, DateTime? seenAt) => seenAt == null || n.at.isAfter(seenAt);

int unreadCount(List<AppNotification> items, DateTime? seenAt) => items.where((n) => isUnread(n, seenAt)).length;
```

Run : `flutter test test/notifications test/wiki`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib/auth/session.dart lib/wiki/wiki_page.dart lib/notifications test/notifications
git commit -m "feat: notifications — calcul du fil, date de dernière visite" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : règle de `notifSeenAt`, dépôt et providers

**Files :**
- Create :
  - `lib/notifications/notifications_repository.dart` (et son `.g.dart` généré) ;
  - `rules_test/notifications.test.js` ;
  - `test/notifications/notifications_provider_test.dart`.
- Modify : `firestore.rules`, `test/fakes.dart`.

**Interfaces :**
- Consumes : tâche 1 ; providers existants `pendingUsersProvider`, `pendingRequestsProvider`, `reviewQueueProvider`, `wikiPagesProvider`, `myRequestsProvider`, `myCharactersProvider`, `characterHistoryProvider(id)`, `gamesProvider`, `myNpcLoansProvider`.
- Produces :
  - `NotificationsRepository.markAllRead(String uid)` ;
  - `notificationsRepositoryProvider`, `notificationsProvider` (`List<AppNotification>`), `unreadNotificationsProvider` (`int`) ;
  - `FakeNotificationsRepository` : `calls` (`'read:<uid>'`), `error`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md 2 test`, puis les tests des règles.

Expected : les tests de `notifications.test.js` échouent ; les autres passent.

<!-- file: rules_test/notifications.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

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
    const users = { lea: 'conteur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

test('notifSeenAt : écrit par le titulaire seul, à l’heure du serveur, sans autre champ (Review Focus 4)', async () => {
  await assertSucceeds(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(as('lea'), 'users/lea'), { notifSeenAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: Timestamp.fromDate(new Date(2020, 0, 1)) }));
  await assertFails(updateDoc(doc(as('lea'), 'users/zoe'), { notifSeenAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: serverTimestamp(), role: 'conteur' }));
  await assertFails(updateDoc(doc(as('zoe'), 'users/zoe'), { notifSeenAt: serverTimestamp(), displayName: 'Zoé' }));
});
```

<!-- file: test/notifications/notifications_provider_test.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/notifications/notifications_repository.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_repository.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import 'notification_rules_test.dart' show hist, req;

final yesterday = DateTime.now().subtract(const Duration(days: 1));

Future<(List<String>, int)> read(ProviderContainer c) async {
  addTearDown(c.dispose);
  final a = c.listen(notificationsProvider, (_, _) {});
  final b = c.listen(unreadNotificationsProvider, (_, _) {});
  addTearDown(a.close);
  addTearDown(b.close);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return ([for (final n in c.read(notificationsProvider)) n.title], c.read(unreadNotificationsProvider));
}

ProviderContainer staff(AppUser me) => ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(me)),
      pendingUsersProvider.overrideWith(
          (ref) => Stream.value([AppUser(uid: 'p', displayName: 'Paul V.', email: 'p@ex.fr', role: Role.pending, createdAt: yesterday)])),
      pendingRequestsProvider.overrideWith((ref) => Stream.value([req(RequestStatus.pending, submitted: yesterday)])),
      reviewQueueProvider.overrideWith((ref) => Stream<List<Character>>.error('refusé')),
      wikiPagesProvider.overrideWith((ref) => Stream.value(<WikiPage>[])),
    ]);

void main() {
  test('conte : demandes d’accès, demandes à traiter ; une source en erreur est absente (Review Focus 1, 2)', () async {
    final (titles, unread) = await read(staff(const AppUser(uid: 'lea', displayName: 'Léa', email: 'l@ex.fr', role: Role.conteur)));
    expect(titles, unorderedEquals(['Demande d’accès : Paul V.', '1 demande à traiter']));
    expect(unread, 2);
  });

  test('narrateur : pas de demande d’accès ; tout lu jusqu’à maintenant', () async {
    final me = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur, notifSeenAt: DateTime.now());
    final (titles, unread) = await read(staff(me));
    expect(titles, ['1 demande à traiter']);
    expect(unread, 0);
  });

  test('joueur : demandes tranchées et XP reçue de ses fiches', () async {
    final c = Character(id: 'c1', name: 'Isaure', kind: CharacterKind.pj, playerUid: 'zoe', status: CharacterStatus.active);
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(const AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur))),
      myRequestsProvider.overrideWith((ref) => Stream.value([req(RequestStatus.accepted, decided: yesterday)])),
      myCharactersProvider.overrideWith((ref) => Stream.value([c])),
      characterHistoryProvider('c1').overrideWith((ref) => Stream.value([hist('h1', 2, yesterday)])),
      gamesProvider.overrideWith((ref) => Stream.value(<Game>[])),
      myNpcLoansProvider.overrideWith((ref) => Stream.value(<NpcLoan>[])),
      wikiPagesProvider.overrideWith((ref) => Stream.value(<WikiPage>[])),
    ]);
    final (titles, unread) = await read(container);
    expect(titles, unorderedEquals(['Une demande a été validée', 'XP reçue : +2']));
    expect(unread, 2);
  });
}
```

- [ ] **Step 2 : règle**

Dans `firestore.rules`, dans la fonction `selfUpdate(uid)`, remplacer :

```
        || acceptsInvitation()
```

par :

```
        || acceptsInvitation()
        // Notifications (sous-projet 10a) : dernière visite, à l'heure du serveur.
        || (changedOnly(['notifSeenAt']) && request.resource.data.notifSeenAt == request.time)
```

Run : les tests des règles.

Expected : `fail 0`.

- [ ] **Step 3 : dépôt, providers, fake**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md 2 impl`, puis `dart run build_runner build --delete-conflicting-outputs`.

<!-- file: lib/notifications/notifications_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../chronicle/chronicle_repository.dart';
import '../games/games_repository.dart';
import '../npcs/npc_loans_repository.dart';
import '../wiki/wiki_repository.dart';
import '../xp/xp_repository.dart';
import 'notification_rules.dart';

part 'notifications_repository.g.dart';

/// Seule écriture des notifications : la date de dernière visite (`users/{uid}.notifSeenAt`, heure du serveur).
class NotificationsRepository {
  NotificationsRepository(this._db);

  final FirebaseFirestore _db;

  Future<void> markAllRead(String uid) => _db.collection('users').doc(uid).update({'notifSeenAt': FieldValue.serverTimestamp()});
}

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) => NotificationsRepository(ref.watch(firestoreProvider));

/// Une source qui charge ou qui échoue ne donne rien : elle n'empêche pas les autres.
List<T> _v<T>(AsyncValue<List<T>> a) => a.value ?? const [];

/// Fil du lecteur, calculé à partir des données que l'application lit déjà (conte ou joueur selon le rôle).
@riverpod
List<AppNotification> notifications(Ref ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final now = DateTime.now();
  if (me.role.isStaff) {
    return feed([
      // Le narrateur ne lit pas les comptes.
      if (me.role.managesAccounts) ...accessRequests(_v(ref.watch(pendingUsersProvider))),
      ...pendingSummary(_v(ref.watch(pendingRequestsProvider))),
      ...reviewQueue(_v(ref.watch(reviewQueueProvider))),
      ...wikiByOthers(_v(ref.watch(wikiPagesProvider)), me.uid),
    ], now: now);
  }
  return feed([
    ...decidedRequests(_v(ref.watch(myRequestsProvider))),
    for (final c in _v(ref.watch(myCharactersProvider))) ...xpReceived(c, _v(ref.watch(characterHistoryProvider(c.id)))),
    ...freeze(_v(ref.watch(gamesProvider)), now),
    ...npcLoans(_v(ref.watch(myNpcLoansProvider))),
    ...wikiForPlayer(_v(ref.watch(wikiPagesProvider))),
  ], now: now);
}

/// Nombre de notifications non lues (point rouge de la cloche).
@riverpod
int unreadNotifications(Ref ref) =>
    unreadCount(ref.watch(notificationsProvider), ref.watch(currentUserProvider.select((u) => u.value?.notifSeenAt)));
```

Ajouter à `test/fakes.dart` :
- l'import `import 'package:portail_met/notifications/notifications_repository.dart';` (après `import 'package:portail_met/npcs/npc_loans_repository.dart';`) ;
- à la fin du fichier :

```dart

class FakeNotificationsRepository implements NotificationsRepository {
  final calls = <String>[];
  Object? error;

  @override
  Future<void> markAllRead(String uid) async {
    calls.add('read:$uid');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Run : `flutter test test/notifications`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 4 : commit**

```
git add firestore.rules rules_test/notifications.test.js lib/notifications test/notifications test/fakes.dart
git commit -m "feat: notifications — date de dernière visite, fil du conte et du joueur" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : page « Notifications », routes, point rouge de la cloche

**Files :**
- Create : `lib/notifications/notifications_screen.dart`.
- Modify : `lib/router.dart`, `lib/shell/app_shell.dart`, `test/app_shell_test.dart`.
- Test : `test/notifications/notifications_screen_test.dart`.

**Interfaces :**
- Consumes : tâches 1 et 2.
- Produces : `NotificationsScreen()` ; clés `nt-read`, `nt-<index>`, `nt-bell` (pastille de la cloche).

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md 3 test`, puis appliquer au test de la coquille :

```
python - <<'EOF'
import pathlib
p = pathlib.Path('test/app_shell_test.dart'); s = p.read_text(encoding='utf-8')
reps = [
  ("import 'package:portail_met/core/theme.dart';\n", "import 'package:portail_met/core/theme.dart';\nimport 'package:portail_met/notifications/notifications_repository.dart';\n"),
  ("  Future<void> pumpShell(WidgetTester tester, Size size) async {", "  Future<void> pumpShell(WidgetTester tester, Size size, {int unread = 0}) async {"),
  ("        pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),\n", "        pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),\n        unreadNotificationsProvider.overrideWith((ref) => unread),\n"),
]
for a, b in reps:
    assert s.count(a) == 1, a
    s = s.replace(a, b)
s = s.rstrip('\n')
assert s.endswith('}')
s = s[:-1] + """
  testWidgets('cloche : point rouge s’il y a des notifications non lues (Web et mobile)', (tester) async {
    await pumpShell(tester, const Size(1440, 900));
    expect(tester.widget<Badge>(find.byKey(const Key('nt-bell'))).isLabelVisible, isFalse);
    await pumpShell(tester, const Size(1440, 900), unread: 2);
    expect(tester.widget<Badge>(find.byKey(const Key('nt-bell'))).isLabelVisible, isTrue);
    await pumpShell(tester, const Size(390, 800), unread: 1);
    expect(tester.widget<Badge>(find.byKey(const Key('nt-bell'))).isLabelVisible, isTrue);
  });
}
"""
p.write_text(s, encoding='utf-8', newline='\n')
EOF
```

Run : `flutter test test/notifications/notifications_screen_test.dart test/app_shell_test.dart`.

Expected : échec (écran absent, pastille absente).

<!-- file: test/notifications/notifications_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/notifications/notification_rules.dart';
import 'package:portail_met/notifications/notifications_repository.dart';
import 'package:portail_met/notifications/notifications_screen.dart';

import '../fakes.dart';

final zoe = AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur, notifSeenAt: DateTime(2026, 10, 5));

final items = [
  AppNotification(kind: NotifKind.decided, title: 'Une demande a été validée', detail: 'Isaure · la fiche est à jour.', at: DateTime(2026, 10, 10), link: '/joueur/demandes'),
  AppNotification(kind: NotifKind.xp, title: 'XP reçue : +3', detail: 'Isaure', at: DateTime(2026, 10, 1), link: '/joueur/personnages/c1/historique'),
];

Future<void> pumpNotif(WidgetTester tester, {List<AppNotification>? list, FakeNotificationsRepository? repo, AppUser? user, double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user ?? zoe)),
      notificationsProvider.overrideWith((ref) => list ?? items),
      notificationsRepositoryProvider.overrideWithValue(repo ?? FakeNotificationsRepository()),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: '/n', routes: [
        GoRoute(path: '/n', builder: (_, _) => const Scaffold(body: NotificationsScreen())),
        GoRoute(path: '/joueur/demandes', builder: (_, _) => const Text('mes demandes')),
      ]),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('liste : non lues signalées, tout marquer comme lu, ouverture du lien', (tester) async {
    final repo = FakeNotificationsRepository();
    await pumpNotif(tester, repo: repo);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('1 non lue. La cloche en haut de l’écran les signale.'), findsOneWidget);
    expect(find.text('XP reçue : +3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nt-read')));
    await tester.pump();
    expect(repo.calls, ['read:zoe']);
    await tester.tap(find.byKey(const Key('nt-0')));
    await tester.pumpAndSettle();
    expect(find.text('mes demandes'), findsOneWidget);
  });

  testWidgets('rien de nouveau ; tout lu : bouton désactivé', (tester) async {
    await pumpNotif(tester, list: const []);
    expect(find.text('Rien de nouveau pour l’instant.'), findsOneWidget);
    expect(find.text('Aucune notification non lue.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('nt-read'))).onPressed, isNull);
    await pumpNotif(tester, user: const AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur));
    expect(find.text('2 non lues. La cloche en haut de l’écran les signale.'), findsOneWidget);
  });

  testWidgets('enregistrement refusé : message (Review Focus 3) ; 390 px', (tester) async {
    final repo = FakeNotificationsRepository()..error = Exception('hors ligne');
    await pumpNotif(tester, repo: repo);
    await tester.tap(find.byKey(const Key('nt-read')));
    await tester.pump();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.text('1 non lue. La cloche en haut de l’écran les signale.'), findsOneWidget);
    await pumpNotif(tester, width: 390);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-23-notifications.md 3 impl`.

<!-- file: lib/notifications/notifications_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'notification_rules.dart';
import 'notifications_repository.dart';

/// Notifications (C-Notifications, J-Notifications) : le fil des 60 derniers jours, les non lues signalées.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _busy = false;

  Future<void> _markRead(String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead(uid);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    final items = ref.watch(notificationsProvider);
    final seen = me?.notifSeenAt;
    final unread = unreadCount(items, seen);
    return PageBody(children: [
      PageTitle(
        'Notifications',
        subtitle: unread == 0 ? 'Aucune notification non lue.' : '$unread non lue${unread > 1 ? 's' : ''}. La cloche en haut de l’écran les signale.',
        action: OutlinedButton(
          key: const Key('nt-read'),
          onPressed: unread == 0 || _busy || me == null ? null : () => _markRead(me.uid),
          child: const Text('Tout marquer comme lu'),
        ),
      ),
      const SizedBox(height: 20),
      if (items.isEmpty)
        Text('Rien de nouveau pour l’instant.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
      else
        Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, n) in items.indexed)
              if (isUnread(n, seen) case final fresh)
                InkWell(
                  key: Key('nt-$i'),
                  onTap: () => context.go(n.link),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: fresh ? const Color(0xFF211719) : null,
                      border: const Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: fresh ? AppColors.accentIcon : Colors.transparent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: t.bodyLarge?.copyWith(fontWeight: fresh ? FontWeight.w600 : FontWeight.w400)),
                          if (n.detail.isNotEmpty) Text(n.detail, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(formatDay(n.at), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ]),
                  ),
                ),
          ]),
        ),
    ]);
  }
}
```

Dans `lib/router.dart` :
- ajouter l'import `import 'notifications/notifications_screen.dart';` juste avant `import 'npcs/my_npc_loans_screen.dart';` ;
- remplacer `          page('/joueur/notifications', soon('Notifications')),` par `          page('/joueur/notifications', const NotificationsScreen()),` ;
- remplacer `          page('/conteur/notifications', soon('Notifications')),` par `          page('/conteur/notifications', const NotificationsScreen()),` ;
- si `soon(` n'apparaît plus ailleurs dans le fichier, supprimer la ligne `  Widget soon(String feature) => EmptyState.comingSoon(feature);`, puis l'import `import 'core/empty_state.dart';` s'il n'est plus utilisé (l'analyseur le signale).

Dans `lib/shell/app_shell.dart` :
- ajouter l'import `import '../notifications/notifications_repository.dart';` (dans l'ordre des imports relatifs) ;
- dans `AppShell.build`, après `final pending = …;`, ajouter `final unread = ref.watch(unreadNotificationsProvider);`, et passer `unread: unread,` au constructeur de `_ShellData` (après `pending: pending,`) ;
- dans `_ShellData` : constructeur `required this.unread` (après `required this.pending`), champ `final int unread;` ;
- après la classe `_ShellData`, ajouter :

```dart

/// Icône d'une destination ; la cloche porte un point rouge s'il y a des notifications non lues (sous-projet 10a).
Widget _iconOf(Destination d, _ShellData data, {Color? color}) {
  final icon = Icon(d.icon, color: color);
  if (!d.path.endsWith('/notifications')) return icon;
  return Badge(key: const Key('nt-bell'), isLabelVisible: data.unread > 0, smallSize: 9, backgroundColor: AppColors.accentIcon, child: icon);
}
```

- dans `_WideShell`, remplacer `icon: Icon(d.icon, color: data.isSelected(d) ? AppColors.text : AppColors.textSecondary),` par `icon: _iconOf(d, data, color: data.isSelected(d) ? AppColors.text : AppColors.textSecondary),` ;
- dans `_NarrowShell`, remplacer `icon: Icon(d.icon)),` (dans les `actions` de l'`AppBar`) par `icon: _iconOf(d, data)),`.

Run : `flutter test test/notifications test/app_shell_test.dart`, puis `flutter analyze`.

Expected : tout passe, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib/notifications lib/router.dart lib/shell/app_shell.dart test/notifications test/app_shell_test.dart
git commit -m "feat: notifications — page, routes, point rouge de la cloche" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : revue, puis déploiement (avec accord)

- [ ] **Step 1 :** revue finale de la branche contre la spec et la Review Focus (sous-agent le plus capable).
- [ ] **Step 2 :** suite complète : `flutter analyze`, `flutter test`, tests des règles.
- [ ] **Step 3 :** avec l'accord de l'utilisateur seulement :
  - `firebase deploy --only firestore:rules` ;
  - `flutter build web` puis `firebase deploy --only hosting` ;
  - pull request de `notifications` vers `main`, fusion, puis suppression de la branche locale.
