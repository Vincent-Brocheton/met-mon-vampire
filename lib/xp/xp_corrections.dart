import '../characters/character.dart';
import 'xp_request.dart';
import 'xp_rules.dart';

enum CorrectionKind {
  costError('Correction d’une erreur de coût'),
  refund('Remboursement (règle changée, élément retiré)'),
  cancelPurchase('Annulation d’un achat'),
  forcedBuyback('Rachat forcé d’un handicap');

  const CorrectionKind(this.label);
  final String label;
}

/// La fiche après la correction, ou le message qui l'empêche. [amount] : XP rendue (+) ou reprise (−).
({Character? after, String? error}) applyCorrection(Character c, CorrectionKind k, {int amount = 0, XpItem? item, String? flaw}) {
  final n = c.clone();
  switch (k) {
    case CorrectionKind.costError:
      if (amount == 0) return (after: null, error: 'Indiquez le montant à rendre ou à reprendre.');
      n.xpSpent -= amount;
    case CorrectionKind.refund:
      if (amount <= 0) return (after: null, error: 'Indiquez le montant à rendre.');
      n.xpSpent -= amount;
    case CorrectionKind.cancelPurchase:
      if (item == null) return (after: null, error: 'Choisissez l’achat à annuler.');
      if (levelNow(c, item.kind, item.name) != item.toLevel) {
        return (after: null, error: 'Le trait a changé depuis : corrigez-le dans la fiche.');
      }
      _revert(n, item);
      n.xpSpent -= item.cost;
    case CorrectionKind.forcedBuyback:
      final f = c.flaws.where((t) => t.name == flaw).firstOrNull;
      if (f == null) return (after: null, error: 'Choisissez le handicap.');
      n.flaws.removeWhere((t) => t.name == flaw);
      n.xpSpent += 2 * f.level;
  }
  return (after: n, error: null);
}

void _revert(Character n, XpItem i) {
  switch (i.kind) {
    case XpKind.attribute:
      n.attributes[AttrCategory.values.byName(i.name)]!.value = i.fromLevel;
    case XpKind.skill || XpKind.background || XpKind.merit:
      final list = switch (i.kind) {
        XpKind.skill => n.skills,
        XpKind.background => n.backgrounds,
        _ => n.merits,
      };
      if (i.fromLevel == 0) {
        list.removeWhere((t) => t.name == i.name);
      } else {
        list.firstWhere((t) => t.name == i.name).level = i.fromLevel;
      }
    case XpKind.discipline:
      if (i.fromLevel == 0) {
        n.disciplines.removeWhere((d) => d.name == i.name);
      } else {
        n.disciplines.firstWhere((d) => d.name == i.name).level = i.fromLevel;
      }
    case XpKind.humanity:
      n.humanity = i.fromLevel;
    case XpKind.flawBuyback:
      n.flaws.add(Trait(i.name, i.fromLevel));
  }
}

/// « À rendre : + 3 XP », « À payer : − 4 XP · dette de 2 XP ».
String correctionPreview(Character before, Character after) {
  final d = before.xpSpent - after.xpSpent;
  final text = d >= 0 ? 'À rendre : + $d XP' : 'À payer : − ${-d} XP';
  return after.xpAvailable < 0 ? '$text · dette de ${-after.xpAvailable} XP' : text;
}
