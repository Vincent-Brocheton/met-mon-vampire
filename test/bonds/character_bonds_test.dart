import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';

import 'bond_rules_test.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  test('conte : la fiche en chargement n’ouvre pas la branche joueur', () async {
    final sheet = StreamController<Character?>();
    addTearDown(sheet.close);
    var playerReads = 0;
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(lea)),
      characterProvider('luc').overrideWith((ref) => sheet.stream),
      allBondsProvider.overrideWith((ref) => Stream.value([octLuc(), lucLem(), agaBas()])),
      sufferedBondsProvider('luc', 'lea').overrideWith((ref) {
        playerReads++;
        return Stream.value(const <Bond>[]);
      }),
      exertedBondsProvider('luc', 'lea').overrideWith((ref) {
        playerReads++;
        return Stream.value(const <Bond>[]);
      }),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(characterBondsProvider('luc'), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(playerReads, 0, reason: 'fiche pas encore lue');
    expect(sub.read().hasValue, isFalse);
    sheet.add(lucie());
    final bonds = await container.read(characterBondsProvider('luc').future);
    expect([for (final b in bonds) b.id]..sort(), ['luc_lem', 'oct_luc']);
    expect(playerReads, 0);
  });
}
