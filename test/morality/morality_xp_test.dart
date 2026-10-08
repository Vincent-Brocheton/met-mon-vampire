import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import '../xp/xp_rules_test.dart' show err;
import 'morality_rules_test.dart' show rb;

void main() {
  test('voie : plafond de la voie, nom de la voie dans l’achat', () {
    final night = sample()
      ..path = 'Voie de la Nuit'
      ..humanity = 4;
    expect(err(night, XpKind.humanity, 'Voie de la Nuit', rb: rb), 'Plafond atteint (4).');
    expect(err(night..humanity = 3, XpKind.humanity, 'Voie de la Nuit', rb: rb), isNull);
    expect(elementOptions(night, XpKind.humanity, rb: rb), {'Voie de la Nuit': 'Voie de la Nuit'});
    expect(costTable(night, rb: rb), contains(('Voie de la Nuit', '10 XP le point, 4 au plus')));
    const item = XpItem(XpKind.humanity, 'Voie de la Nuit', 3, 4, 10);
    expect(ruleText(night, item, rb: rb), '10 XP le point, 4 au plus');
    expect(item.label, 'Voie de la Nuit');
    expect(applyRequest(night, [item], rb: rb).humanity, 4);
  });

  test('changement de voie : l’achat d’Humanité déjà demandé reste chaîné', () {
    final night = sample()
      ..path = 'Voie de la Nuit'
      ..humanity = 3;
    const old = XpItem(XpKind.humanity, 'Humanité', 3, 4, 10);
    expect(err(night, XpKind.humanity, 'Voie de la Nuit', items: [old], rb: rb), 'Plafond atteint (4).');
    expect(draftItem(night, [old], XpKind.humanity, 'Voie de la Nuit', rb: rb).fromLevel, 4);
    expect(applyRequest(night, [old], rb: rb).humanity, 4);
    expect(err(night, XpKind.humanity, 'Voie de la Nuit', rb: rb), isNull);
    // Deux achats 3→4 sous deux noms : le second est refusé à l'envoi.
    const dup = XpItem(XpKind.humanity, 'Voie de la Nuit', 3, 4, 10);
    expect(sendProblems(night, [old, dup], usable: 100, rb: rb), isNotEmpty);
    final items = [old, dup];
    expect(removeItem(items, 0), isNotNull);
  });

  test('Humanité : inchangé (6 au plus, nom « Humanité »)', () {
    expect(err(sample()..humanity = 6, XpKind.humanity, 'Humanité'), 'Plafond atteint (6).');
    expect(elementOptions(sample(), XpKind.humanity), {'Humanité': 'Humanité'});
    expect(const XpItem(XpKind.humanity, 'Humanité', 5, 6, 10).label, 'Humanité');
  });
}
