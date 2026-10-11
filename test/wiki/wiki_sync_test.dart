import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/wiki/wiki_repository.dart';

import '../fakes.dart';
import 'wiki_rules_test.dart' show julienUser, leaUser, sheet, zoeUser;

Future<List<String>> run(AppUser me, List<AppUser> users, List<Character> sheets) async {
  final repo = FakeWikiRepository();
  final c = ProviderContainer(overrides: [
    currentUserProvider.overrideWith((ref) => Stream.value(me)),
    allUsersProvider.overrideWith((ref) => Stream.value(users)),
    allCharactersProvider.overrideWith((ref) => Stream.value(sheets)),
    wikiRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  final sub = c.listen(wikiAudienceSyncProvider, (_, _) {});
  addTearDown(sub.close);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return repo.calls;
}

void main() {
  const zoeBare = AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur);

  test('le conte écrit les accès qui changent (Review Focus 3)', () async {
    expect(await run(leaUser, [leaUser, zoeBare], [sheet('isaure')]), ['audiences:zoe=clan:toreador,sect:camarilla']);
    expect(await run(leaUser, [leaUser, zoeUser], [sheet('isaure', status: CharacterStatus.dead)]), ['audiences:zoe=']);
  });

  test('rien à écrire, ou narrateur : aucune écriture', () async {
    expect(await run(leaUser, [leaUser, zoeUser], [sheet('isaure')]), isEmpty);
    expect(await run(julienUser, [julienUser, zoeBare], [sheet('isaure')]), isEmpty);
  });
}
