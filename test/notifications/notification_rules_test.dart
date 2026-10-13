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
  reviewFixes();

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
      Game(id: 'g1', date: DateTime(2026, 10, 3), frozenAt: DateTime(2026, 9, 29, 20), until: DateTime(2026, 10, 14, 6), sheetIds: const ['c1']),
      Game(id: 'g0', date: DateTime(2026, 9, 1), frozenAt: DateTime(2026, 8, 30), until: DateTime(2026, 9, 2)),
      Game(id: 'g2', date: DateTime(2026, 10, 10), frozenAt: DateTime(2026, 10, 9), until: DateTime(2026, 10, 20), liftedAt: DateTime(2026, 10, 11)),
    ];
    final f = freeze(games, now, ['c1']);
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

void reviewFixes() {
  test('revue : PNJ daté de la création du prêt, pas du début de la période', () {
    final l = npcLoans([NpcLoan(id: 'l1', characterName: 'Agathe', from: DateTime(2026, 11, 1), until: DateTime(2026, 12, 1), createdAt: DateTime(2026, 10, 12, 15))]);
    expect(l.single.at, DateTime(2026, 10, 12, 15));
  });

  test('revue : fiches figées seulement pour le joueur dont une fiche est dans la partie', () {
    final g = Game(id: 'g1', date: DateTime(2026, 10, 3), frozenAt: DateTime(2026, 9, 29), until: DateTime(2026, 10, 14), sheetIds: const ['c1']);
    expect(freeze([g], now, ['c2']), isEmpty);
    expect(freeze([g], now, ['c2', 'c1']), hasLength(1));
  });
}
