import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import 'xp_rules_test.dart' show err, req;

void main() {
  test('nouveau serviteur, montée dans la même demande, coût d’historique, application, annulation (Review Focus 2)', () {
    final c = sample();
    final items = <XpItem>[];
    expect(elementOptions(c, XpKind.servant), {newHumanServant: 'Nouvelle goule humaine', newAnimalServant: 'Nouvelle goule animale'});
    expect(noteSpec(XpKind.servant, newAnimalServant), ('Nom du serviteur', true));
    expect(noteSpec(XpKind.servant, 'Rex'), isNull);
    expect(err(c, XpKind.servant, newAnimalServant, note: ' '), 'Précisez le nom du serviteur.');
    final rex = draftItem(c, items, XpKind.servant, newAnimalServant, note: 'Rex');
    expect((rex.name, rex.fromLevel, rex.toLevel, rex.cost, rex.note), ('Rex', 0, 1, 2, 'Goule animale'));
    items.add(rex);
    final up = draftItem(c, items, XpKind.servant, 'Rex');
    expect((up.fromLevel, up.toLevel, up.cost, up.note), (1, 2, 4, null));
    items.add(up);
    final mila = draftItem(c, items, XpKind.servant, newHumanServant, note: 'Mila');
    items.add(mila);
    final after = applyRequest(c, items);
    expect([for (final s in after.servants) (s.name, s.kind, s.rank)], [('Rex', ServantKind.animal, 2), ('Mila', ServantKind.human, 1)]);
    expect(after.servants.first.id, isNot(after.servants.last.id));
    expect(after.xpSpent, c.xpSpent + 8);
    expect(elementOptions(after, XpKind.servant)['Rex'], 'Rex (Goule animale)');
    expect(err(after, XpKind.servant, newHumanServant, note: 'rex'), 'Un serviteur porte déjà ce nom.');
    final undo = applyCorrection(after, CorrectionKind.cancelPurchase, item: up).after!;
    expect(undo.servants.first.rank, 1);
    final gone = applyCorrection(undo, CorrectionKind.cancelPurchase, item: rex).after!;
    expect(gone.servants.map((s) => s.name), ['Mila']);
  });

  test('noms : 80 caractères au plus, casse ignorée dans la demande et à l’annulation (revue)', () {
    final c = sample();
    expect(err(c, XpKind.servant, newHumanServant, note: 'A' * 81), 'Nom du serviteur : 80 caractères au plus.');
    final items = [draftItem(c, const [], XpKind.servant, newAnimalServant, note: 'Rex')];
    expect(itemError(c, items, draftItem(c, items, XpKind.servant, newHumanServant, note: 'rex'), usable: 100), 'Un serviteur porte déjà ce nom.');
    final after = applyRequest(c, items);
    after.servants.single.name = 'REX';
    final gone = applyCorrection(after, CorrectionKind.cancelPurchase, item: items.single).after!;
    expect(gone.servants, isEmpty);
    final up = const XpItem(XpKind.servant, 'Rex', 1, 2, 4);
    final raised = applyRequest(after, [up]);
    raised.servants.single.name = 'rex';
    expect(applyCorrection(raised, CorrectionKind.cancelPurchase, item: up).after!.servants.single.rank, 1);
  });

  test('plafond 5, historique Serviteurs écarté, libellés, contrôle à la validation', () {
    final c = sample()..servants = [Servant('x-s1', 'Mila', ServantKind.human, 5)];
    expect(err(c, XpKind.servant, 'Mila'), 'Plafond atteint (5).');
    expect(elementOptions(c, XpKind.background).containsKey(servantsBackground), isFalse);
    expect(err(c, XpKind.background, servantsBackground), 'Les serviteurs s’achètent avec le type « Serviteur ».');
    expect(levelText(XpKind.servant, 2), '●●');
    expect(const XpItem(XpKind.servant, 'Mila', 1, 2, 4).label, 'Serviteur · Mila');
    expect(costTable(c), contains(('Serviteur', 'Nouveau niveau × 2')));
    final checks = requestChecks(c, req([const XpItem(XpKind.servant, 'Mila', 3, 4, 8)]), reservedOthers: 0);
    expect(checks.map((k) => k.text), contains(startsWith('La fiche a changé')));
  });
}
