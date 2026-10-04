import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/transformations.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servant_rules.dart';
import 'package:portail_met/servants/transform_actions.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'servant_rules_test.dart' show isaure, rexFile;

void main() {
  const by = Actor('lea', 'Léa G.');
  ServantFile jeanne() => ServantFile(id: 'm1', kind: 'mortal', name: 'Jeanne', attachment: 'Voisine', version: 1);

  test('mortel devient serviteur : domitor débité, puis fiche convertie ; reprise sans doublon (Review Focus 2)', () async {
    final chars = FakeCharacterRepository();
    final servants = FakeServantsRepository();
    final d = sample();
    expect(await mortalToServant(chars, servants, mortal: jeanne(), domitor: d, kind: ServantKind.human, rank: 2, reason: 'Recrutée', by: by), isNull);
    expect(chars.calls, ['saveEdit:Recrutée']);
    expect(chars.lastKind, 'xp');
    expect((chars.lastAfter!.servants.single.id, chars.lastAfter!.xpSpent), ('m1', d.xpSpent + servantCost(d, 2)));
    final f = servants.lastSaved!;
    expect((f.kind, f.domitorId, f.domitorName, f.name), ('human', 'x', 'Isaure de Valcourt', 'Jeanne'));
    expect(f.holderPlayers, ['u1']);

    servants.error = Exception('refus');
    final retry = chars.lastAfter!;
    final message = await mortalToServant(chars, servants, mortal: jeanne(), domitor: retry, kind: ServantKind.human, rank: 2, reason: 'Recrutée', by: by);
    expect(message, contains('relancez'));
    expect(chars.calls, ['saveEdit:Recrutée'], reason: 'revue : déjà serviteur, pas de nouvelle écriture du domitor');
  });

  test('mortel étreint : nouvelle fiche, puis suppression du mortel', () async {
    final chars = FakeCharacterRepository();
    final servants = FakeServantsRepository();
    final sheet = embracedNpc('Jeanne', sire: sample(), genNumber: 11).after!;
    expect(await embraceFollower(chars, servants, row: ServantRow(file: jeanne()), sheet: sheet, reason: 'Étreinte', by: by), isNull);
    expect(chars.calls, ['createSheet:Jeanne']);
    expect(servants.calls, ['delete:m1']);
  });

  test('serviteur étreint : retiré du domitor, fiche détaillée libérée (Review Focus 5)', () async {
    final chars = FakeCharacterRepository();
    final servants = FakeServantsRepository();
    final d = isaure();
    final row = ServantRow(entry: d.servants.first, domitor: d, file: rexFile());
    final sheet = embracedNpc('Rex', sire: sample(), genNumber: 11).after!;
    expect(await embraceFollower(chars, servants, row: row, sheet: sheet, reason: 'Étreint', by: by), isNull);
    expect(chars.calls, ['createSheet:Rex', 'saveEdit:Étreint']);
    expect(chars.lastAfter!.servants.map((s) => s.id), ['x-s2']);
    expect(servants.calls, ['release:x-s1']);
  });

  test('étreinte : fiche créée sous l’identifiant d’origine ; domitor en création refusé sans écriture (revue)', () async {
    final chars = FakeCharacterRepository();
    final servants = FakeServantsRepository();
    final sheet = embracedNpc('Jeanne', sire: sample(), genNumber: 11).after!;
    await embraceFollower(chars, servants, row: ServantRow(file: jeanne()), sheet: sheet, reason: 'Étreinte', by: by);
    expect(chars.lastCreatedId, 'm1');
    final draft = isaure()..status = CharacterStatus.draft;
    final message = await embraceFollower(chars, servants,
        row: ServantRow(entry: draft.servants.first, domitor: draft, file: rexFile()), sheet: sheet, reason: 'Étreint', by: by);
    expect(message, contains('en création'));
    expect(chars.calls, ['createSheet:Jeanne'], reason: 'aucune écriture pour le second');
  });

  test('mortel devient goule jouée : amorce de goule, puis suppression ; échec partiel signalé', () async {
    final chars = FakeCharacterRepository();
    final servants = FakeServantsRepository();
    const ines = AppUser(uid: 'u2', displayName: 'Inès T.', email: 'i@ex.fr', role: Role.joueur);
    expect(await mortalToGhoul(chars, servants, mortal: jeanne(), player: ines, domitor: sample(), by: by), isNull);
    expect(chars.calls, ['create:pj:Jeanne']);
    expect(chars.lastGhoul!.domitorName, 'Isaure de Valcourt');
    expect(servants.calls, ['delete:m1']);
    servants.error = Exception('refus');
    expect(await mortalToGhoul(chars, servants, mortal: jeanne(), player: ines, domitor: sample(), by: by), contains('supprimez-la'));
  });
}
