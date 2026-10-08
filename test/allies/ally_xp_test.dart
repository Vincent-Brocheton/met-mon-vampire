import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rules/creation_rules.dart' show CheckLevel;
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import '../xp/xp_rules_test.dart' show err, req;
import 'ally_rules_test.dart' show castan, rb;

XpItem buy(Ally a, {int from = 0}) {
  final draft = XpItem(XpKind.ally, a.name, from, a.level, 0, ally: allyData(a));
  return XpItem(XpKind.ally, a.name, from, a.level, costOf(sample(), draft, rb: rb), ally: allyData(a));
}

List<String> errorsOf(Character c, XpItem i) =>
    [for (final k in requestChecks(c, req([i]), reservedOthers: 0, rb: rb)) if (k.level == CheckLevel.error) k.text];

void main() {
  test('nouvel allié de niveau 4 : coût d’historique cumulé, application, annulation', () {
    final c = sample();
    final item = buy(castan());
    expect((item.fromLevel, item.toLevel, item.cost), (0, 4, 20));
    expect(XpItem.fromMap(item.toMap()).ally, allyData(castan()));
    expect(item.label, 'Allié · Me Hervé Castan, notaire');
    expect(levelText(XpKind.ally, 3), '●●●');
    expect(errorsOf(c, item), isEmpty);
    final after = applyRequest(c, [item], rb: rb);
    final a = after.allies.single;
    expect((a.name, a.level, a.type, a.domain, a.influence), ('Me Hervé Castan, notaire', 4, 'Gotha', 'Finance & Industrie', 4));
    expect(a.specialties, ['Expert', 'Sécurité']);
    expect(a.id, startsWith('x-a'));
    expect(after.xpSpent, c.xpSpent + 20);
    final undo = applyCorrection(after, CorrectionKind.cancelPurchase, item: item).after!;
    expect(undo.allies, isEmpty);
  });

  test('montée de niveau : un niveau, état demandé appliqué, identifiant conservé', () {
    final c = sample()..allies = [Ally('x-a0', 'Maëlle Garnier', type: 'Gotha', domain: 'Média', specialties: ['Contact'])];
    final up = buy(c.allies.single.copy()
      ..level = 2
      ..specialties = ['Contact', 'Nocturne'], from: 1);
    expect(up.cost, 4);
    expect(levelWith(c, const [], XpKind.ally, 'maëlle garnier'), 1);
    final after = applyRequest(c, [up], rb: rb);
    expect((after.allies.single.id, after.allies.single.level), ('x-a0', 2));
    expect(after.allies.single.specialties, ['Contact', 'Nocturne']);
  });

  test('validation : achat écrit hors de l’application, allié disparu (Review Focus 1 et 2)', () {
    final c = sample();
    final bad = XpItem(XpKind.ally, 'Faux', 0, 1, 2, ally: const {'type': 'Lune', 'domain': 'Crime', 'influence': 3, 'specialties': ['Interdit']});
    expect(errorsOf(c, bad), containsAll(['Type hors liste', 'Influence : 2, 4 ou 5', 'Interdit : pas une spécialisation d’allié']));
    expect(errorsOf(c, const XpItem(XpKind.ally, 'Sans état', 0, 1, 2)), isNotEmpty);
    final gone = buy(Ally('', 'Disparu', level: 2, type: 'Gotha', domain: 'Média', specialties: ['Contact', 'Nocturne']), from: 1);
    expect(errorsOf(c, gone), contains('Allié introuvable sur la fiche'));
  });

  test('écran XP : ni type Allié, ni anciens historiques', () {
    final c = sample();
    expect(elementOptions(c, XpKind.background, rb: rb).keys, isNot(anyOf(contains('Alliés'), contains('Influence'), contains('Contacts'))));
    expect(err(c, XpKind.background, 'Alliés'), 'Les alliés se demandent depuis la page Alliés.');
    expect(elementOptions(c, XpKind.ally, rb: rb), isEmpty);
  });
}
