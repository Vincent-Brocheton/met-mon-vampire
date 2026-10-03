import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;

void main() {
  test('erreur de coût et remboursement', () {
    final c = sample();
    final fix = applyCorrection(c, CorrectionKind.costError, amount: 3);
    expect(fix.after!.xpSpent, 43);
    expect(correctionPreview(c, fix.after!), 'À rendre : + 3 XP');
    expect(applyCorrection(c, CorrectionKind.costError, amount: -2).after!.xpSpent, 48);
    expect(applyCorrection(c, CorrectionKind.costError).error, 'Indiquez le montant à rendre ou à reprendre.');
    expect(applyCorrection(c, CorrectionKind.refund, amount: -2).error, 'Indiquez le montant à rendre.');
    expect(applyCorrection(c, CorrectionKind.refund, amount: 2).after!.xpSpent, 44);
  });

  test('annulation d’un achat : trait rétabli, coût rendu', () {
    final c = sample();
    final skill = applyCorrection(c, CorrectionKind.cancelPurchase, item: const XpItem(XpKind.skill, 'Représentation', 3, 4, 8)).after!;
    expect((skill.skills.single.level, skill.xpSpent), (3, 38));
    final merit = applyCorrection(c, CorrectionKind.cancelPurchase, item: const XpItem(XpKind.merit, 'Visage angélique', 0, 1, 1)).after!;
    expect(merit.merits, isEmpty);
    final buyback = applyCorrection(c, CorrectionKind.cancelPurchase, item: const XpItem(XpKind.flawBuyback, 'Traqué', 4, 0, 8)).after!;
    expect(buyback.flaws.map((f) => (f.name, f.level)), contains(('Traqué', 4)));
    expect(buyback.xpSpent, 38);
    expect(applyCorrection(c, CorrectionKind.cancelPurchase, item: const XpItem(XpKind.skill, 'Représentation', 4, 5, 10)).error,
        'Le trait a changé depuis : corrigez-le dans la fiche.');
    expect(applyCorrection(c, CorrectionKind.cancelPurchase).error, 'Choisissez l’achat à annuler.');
  });

  test('rachat forcé : dette affichée (Review Focus 4)', () {
    final c = sample();
    final after = applyCorrection(c, CorrectionKind.forcedBuyback, flaw: 'Curiosité').after!;
    expect(after.flaws, isEmpty);
    expect(after.xpSpent, 50);
    expect(correctionPreview(c, after), 'À payer : − 4 XP');
    final poor = sample()..xpSpent = 63;
    final debt = applyCorrection(poor, CorrectionKind.forcedBuyback, flaw: 'Curiosité').after!;
    expect(correctionPreview(poor, debt), 'À payer : − 4 XP · dette de 1 XP');
    expect(applyCorrection(c, CorrectionKind.forcedBuyback, flaw: 'Inconnu').error, 'Choisissez le handicap.');
  });
}
