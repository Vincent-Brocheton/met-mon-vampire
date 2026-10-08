import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/morality/derangement_rules.dart';
import 'package:portail_met/rules/creation_rules.dart' show CheckLevel;
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import '../xp/xp_rules_test.dart' show req;
import 'derangement_rules_test.dart' show fire, rb;

XpItem ask(Derangement d) => XpItem(XpKind.derangement, d.name, 0, 1, 0, derangement: derangementData(d));

List<String> errorsOf(Character c, XpItem i) =>
    [for (final k in requestChecks(c, req([i]), reservedOthers: 0, rb: rb)) if (k.level == CheckLevel.error) k.text];

void main() {
  test('demande à 0 XP : aller-retour, application, annulation', () {
    final c = sample();
    final item = ask(fire());
    expect(costOf(c, item, rb: rb), 0);
    expect(XpItem.fromMap(item.toMap()).derangement, derangementData(fire()));
    expect(item.label, 'Dérangement · Peur du feu');
    expect(errorsOf(c, item), isEmpty);
    final after = applyRequest(c, [item], rb: rb);
    final d = after.derangements.single;
    expect((d.name, d.type, d.trigger, d.severe, d.clan, after.xpSpent), ('Peur du feu', 'phobia', 'Le feu, même une bougie.', true, false, c.xpSpent));
    expect(d.id, startsWith('x-d'));
    expect(applyCorrection(after, CorrectionKind.cancelPurchase, item: item).after!.derangements, isEmpty);
  });

  test('validation : doublon et données invalides refusés (Review Focus 2)', () {
    final c = sample()..derangements = [fire()];
    expect(errorsOf(c, ask(Derangement('', 'peur du feu', type: 'phobia'))), contains('Un dérangement porte déjà ce nom'));
    expect(errorsOf(sample(), ask(Derangement('', 'Rite', type: 'lune'))), contains('Type inconnu'));
    expect(errorsOf(sample(), const XpItem(XpKind.derangement, 'Sans détail', 0, 1, 0)), isNotEmpty);
  });

  test('écran XP : pas de type « Dérangement »', () {
    expect(elementOptions(sample(), XpKind.derangement, rb: rb), isEmpty);
  });
}
