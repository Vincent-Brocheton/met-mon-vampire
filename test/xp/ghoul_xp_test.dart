import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/ghoul_test.dart' show mila;
import 'xp_rules_test.dart' show err, req;

void main() {
  test('goule : coûts Neonate ; disciplines, techniques et pouvoirs d’anciens refusés (Review Focus 3)', () {
    final c = mila()
      ..status = CharacterStatus.active
      ..xpEarned = 30;
    expect(err(c, XpKind.discipline, 'Auspex'), 'Les disciplines d’une goule ne s’achètent pas avec l’XP.');
    expect(err(c, XpKind.technique, 'Regard ardent'), 'Une goule n’apprend ni technique ni pouvoir d’ancien.');
    expect(err(c, XpKind.elderPower, 'Clairvoyance'), 'Une goule n’apprend ni technique ni pouvoir d’ancien.');
    expect(elementOptions(c, XpKind.discipline), isEmpty);
    expect(draftItem(c, const [], XpKind.skill, 'Médecine').cost, 1);
    expect(
      costTable(c),
      containsAll([('Discipline en clan', 'Jamais en XP'), ('Discipline hors clan', 'Jamais en XP'), ('Technique', 'Jamais en XP'), ('Pouvoir d’ancien', 'Jamais en XP')]),
    );
    final checks = requestChecks(c, req([const XpItem(XpKind.discipline, 'Auspex', 0, 1, 3)]), reservedOthers: 0);
    expect(checks.map((k) => k.text), contains('Les disciplines d’une goule ne s’achètent pas avec l’XP.'));
  });
}
