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
