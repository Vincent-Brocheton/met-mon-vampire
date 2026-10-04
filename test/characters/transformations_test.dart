import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/transformations.dart';
import 'package:portail_met/rules/creation_rules.dart';

import 'character_test.dart' show sample;
import 'ghoul_test.dart' show mila;

void main() {
  test('goule étreinte : clan, génération, disciplines 2/1/1, Génération, Sang ; ghoul retirée (Review Focus 1)', () {
    final g = mila()
      ..status = CharacterStatus.active
      ..disciplines = [Discipline('Auspex', 3, inClan: true), Discipline('Présence', 2, inClan: true)]
      ..xpInitial = 30
      ..xpSpent = 10;
    final r = embraceGhoul(g, sire: sample(), genNumber: 11, first: 'Présence');
    final a = r.after!;
    expect(r.error, isNull);
    expect(a.ghoul, isNull);
    expect((a.clan, a.sire, a.genRank, a.genNumber, a.blood, a.bloodPerTurn), ('Toreador', 'Isaure de Valcourt', GenRank.neonate, 11, 10, 1));
    expect([for (final d in a.disciplines) (d.name, d.level, d.inClan)], [('Auspex', 1, true), ('Célérité', 1, true), ('Présence', 2, true)]);
    expect([for (final b in a.backgrounds) if (b.name == generationName) b.level], [1]);
    expect((a.xpSpent, debtOf(a)), (10, 0));
    expect(g.ghoul, isNotNull, reason: 'la fiche d’origine ne change pas');
  });

  test('étreinte refusée : génération hors du tableau, sire sans clan (Review Focus 3)', () {
    final g = mila()..status = CharacterStatus.active;
    expect(embraceGhoul(g, sire: sample(), genNumber: 14).error, 'Génération 14e absente du tableau des générations');
    expect(embraceGhoul(g, sire: sample()..clan = null, genNumber: 11).error, 'Le sire n’a pas de clan');
    expect(embraceGhoul(sample(), sire: sample(), genNumber: 11).error, 'Ce n’est pas une goule');
    expect(rankOfNumber(9), GenRank.ancilla);
    expect(rankLevel(GenRank.pretender), 3);
  });

  test('PNJ étreint et amorce de PJ étreinte (Review Focus 4)', () {
    final npc = embracedNpc('Jeanne', sire: sample(), genNumber: 11).after!;
    expect((npc.kind, npc.status, npc.clan, npc.genNumber, npc.willpower, npc.humanity), (CharacterKind.pnj, CharacterStatus.active, 'Toreador', 11, 6, 5));
    expect(npc.disciplines.map((d) => d.level), [2, 1, 1]);
    final pj = embracedDraft('Paul', playerUid: 'u2', playerName: 'Inès T.', sire: sample(), genNumber: 11).after!;
    expect((pj.kind, pj.status, pj.clan, pj.embrace!.sireName, pj.embrace!.genNumber), (CharacterKind.pj, CharacterStatus.draft, 'Toreador', 'Isaure de Valcourt', 11));
    expect(Character.fromMap('n', pj.toMap()).embrace!.clan, 'Toreador');
    expect(sample().toMap().containsKey('embrace'), isFalse);
    List<(CheckLevel, String)> at(int step) => [for (final k in creationChecks(pj)) if (k.step == step) (k.level, k.text)];
    expect(at(3), contains((CheckLevel.ok, 'Étreint par Isaure de Valcourt · clan Toreador')));
    expect(at(6), contains((CheckLevel.error, 'Génération imposée par l’étreinte : 11e')));
    pj.clan = 'Brujah';
    expect(at(3), contains((CheckLevel.error, 'Clan imposé par l’étreinte : Toreador')));
  });

  test('serviteur acheté par le domitor : coût d’historique, dette, sans doublon à la reprise (Review Focus 2)', () {
    final d = sample()
      ..xpInitial = 10
      ..xpEarned = 0
      ..xpSpent = 8;
    expect(servantCost(d, 2), 6, reason: 'Ancilla : 1×2 + 2×2');
    final after = withServant(d, 'm1', 'Jeanne', ServantKind.human, 2);
    expect((after.servants.single.id, after.servants.single.rank, after.xpSpent, debtOf(after)), ('m1', 2, 14, 4));
    final again = withServant(after, 'm1', 'Jeanne', ServantKind.human, 2);
    expect((again.servants.length, again.xpSpent), (1, 14));
  });
}
