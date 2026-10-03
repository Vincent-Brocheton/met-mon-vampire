import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rules/creation_rules.dart' show CheckLevel;
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;

XpItem add(Character c, List<XpItem> items, XpKind k, String name, {String? note}) {
  final i = draftItem(c, items, k, name, note: note);
  final e = itemError(c, items, i, usable: 100);
  if (e != null) throw StateError(e);
  items.add(i);
  return i;
}

String? err(Character c, XpKind k, String name, {String? note, int usable = 100, List<XpItem>? items}) {
  final list = items ?? <XpItem>[];
  return itemError(c, list, draftItem(c, list, k, name, note: note), usable: usable);
}

XpRequest req(List<XpItem> items) =>
    XpRequest(characterId: 'x', characterName: 'Isaure', playerUid: 'u1', playerName: 'Camille', items: items);

void main() {
  test('coûts Ancilla, puis Neonate', () {
    final c = sample();
    (int, int, int) of(XpKind k, String n, {String? note}) {
      final i = draftItem(c, const [], k, n, note: note);
      return (i.fromLevel, i.toLevel, i.cost);
    }

    expect(of(XpKind.skill, 'Linguistique'), (0, 1, 2));
    expect(of(XpKind.background, 'Ressources', note: 'héritage'), (3, 4, 8));
    expect(of(XpKind.discipline, 'Auspex'), (3, 4, 12));
    expect(of(XpKind.discipline, 'Présence'), (0, 1, 3));
    expect(of(XpKind.discipline, 'Domination'), (0, 1, 4));
    expect(of(XpKind.merit, 'Chanceux'), (0, 2, 2));
    expect(of(XpKind.humanity, 'Humanité'), (0, 1, 10));
    expect(of(XpKind.flawBuyback, 'Curiosité'), (2, 0, 4));
    expect(of(XpKind.attribute, 'mental'), (0, 1, 3));
    c.genRank = GenRank.neonate;
    expect(of(XpKind.skill, 'Linguistique'), (0, 1, 1));
    expect(of(XpKind.background, 'Ressources', note: 'héritage'), (3, 4, 4));
  });

  test('plafonds, précisions, Génération, atout déjà pris', () {
    final c = sample();
    expect(err(c, XpKind.skill, 'Représentation'), 'Précisez le domaine.');
    expect(err(c, XpKind.skill, 'Représentation', note: 'opéra'), isNull);
    final items = <XpItem>[];
    add(c, items, XpKind.skill, 'Représentation', note: 'opéra');
    expect(err(c, XpKind.skill, 'Représentation', note: 'jazz', items: items), 'Plafond atteint (5).');
    expect(err(c, XpKind.background, 'Ressources'), 'Précisez le détail du nouveau point.');
    expect(err(c, XpKind.background, 'Génération', note: 'x'), 'La Génération ne s’achète qu’à la création.');
    expect(err(c, XpKind.merit, 'Visage angélique'), 'Atout déjà pris.');
    final twice = <XpItem>[];
    add(c, twice, XpKind.flawBuyback, 'Curiosité');
    expect(err(c, XpKind.flawBuyback, 'Curiosité', items: twice), 'Handicap déjà racheté.');
  });

  test('atouts : 7 points au plus, rareté du clan comprise', () {
    final c = sample();
    final items = <XpItem>[];
    add(c, items, XpKind.merit, 'Volonté de fer');
    add(c, items, XpKind.merit, 'Esprit labyrinthique');
    expect(meritPoints(c, items), 7);
    expect(err(c, XpKind.merit, 'Chanceux', items: items), 'Atouts : 7 points au plus, rareté de clan comprise.');
  });

  test('XP utilisable et réservée', () {
    final c = sample();
    expect(err(c, XpKind.humanity, 'Humanité', usable: 8), 'XP libre insuffisante : 10 requis, 8 restant après les achats déjà ajoutés.');
    XpRequest r(String id, String cid, RequestStatus s, int cost) => XpRequest(
          id: id,
          characterId: cid,
          characterName: '',
          playerUid: 'u1',
          playerName: '',
          status: s,
          items: [XpItem(XpKind.attribute, 'mental', 0, 1, cost)],
        );
    final all = [
      r('a', 'x', RequestStatus.pending, 12),
      r('b', 'x', RequestStatus.draft, 5),
      r('c', 'x', RequestStatus.changes, 3),
      r('d', 'y', RequestStatus.pending, 7),
      r('e', 'x', RequestStatus.cancelled, 4),
    ];
    expect(reservedBy(all, 'x'), 15);
    expect(reservedBy(all, 'x', exceptId: 'c'), 12);
  });

  test('empilement et retrait par le haut', () {
    final c = sample();
    final items = <XpItem>[];
    add(c, items, XpKind.skill, 'Linguistique');
    final second = add(c, items, XpKind.skill, 'Linguistique');
    expect((second.fromLevel, second.toLevel, second.cost), (1, 2, 4));
    expect(removeItem(items, 0), 'Retirez d’abord le niveau supérieur.');
    expect(removeItem(items, 1), isNull);
    expect(items.length, 1);
  });

  test('contrôles à la validation : écart, coût recalculé, dette, mentor (Review Focus 1 et 5)', () {
    final auspex = req([const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)]);
    expect(requestChecks(sample(), auspex, reservedOthers: 0).single.level, CheckLevel.ok);
    final changed = sample()..disciplines.first.level = 4;
    final c1 = requestChecks(changed, auspex, reservedOthers: 0);
    expect(c1.where((k) => k.level == CheckLevel.error).map((k) => k.text),
        contains('La fiche a changé : Auspex est à ●●●● (demande faite depuis ●●●)'));
    final cheap = req([const XpItem(XpKind.skill, 'Linguistique', 0, 1, 1)]);
    expect(requestChecks(sample(), cheap, reservedOthers: 0).map((k) => k.text),
        contains('Coût recalculé : 2 XP au lieu de 1 (Compétence · Linguistique)'));
    expect(requestChecks(sample(), auspex, reservedOthers: 15).map((k) => k.text), contains('Dette après validation : 7 XP'));
    final vicissitude = req([const XpItem(XpKind.discipline, 'Vicissitude', 0, 1, 4)]);
    expect(requestChecks(sample(), vicissitude, reservedOthers: 0).any((k) => k.text.startsWith('Mentor nécessaire')), isTrue);
  });

  test('achats truqués : forme vérifiée à la validation (revue finale)', () {
    String? invalid(XpItem i) =>
        requestChecks(sample(), req([i]), reservedOthers: 0).where((k) => k.level == CheckLevel.error).map((k) => k.text).firstOrNull;
    expect(invalid(const XpItem(XpKind.skill, 'Linguistique', 0, 5, 5)), 'Achat invalide : Compétence · Linguistique (— → ●●●●●)');
    expect(invalid(const XpItem(XpKind.attribute, 'mental', 0, 10, 3)), startsWith('Achat invalide'));
    expect(invalid(const XpItem(XpKind.merit, 'Chanceux', 0, 1, 1)), startsWith('Achat invalide'));
    expect(invalid(const XpItem(XpKind.flawBuyback, 'Curiosité', 2, 1, 4)), startsWith('Achat invalide'));
    expect(invalid(const XpItem(XpKind.attribute, 'occulte', 0, 1, 3)), startsWith('Achat invalide'));
    expect(const XpItem(XpKind.attribute, 'occulte', 0, 1, 3).displayName, 'occulte');
  });

  test('avant l’envoi : XP insuffisante ou fiche changée (revue finale)', () {
    final c = sample();
    expect(sendProblems(c, [const XpItem(XpKind.humanity, 'Humanité', 0, 1, 10)], usable: 8),
        ['XP libre insuffisante : 10 requis, 8 disponible.']);
    expect(sendProblems(c, [const XpItem(XpKind.discipline, 'Auspex', 2, 3, 9)], usable: 20),
        ['La fiche a changé : Auspex est à ●●● (demande faite depuis ●●). Retirez cet achat puis ajoutez-le de nouveau.']);
    expect(sendProblems(c, [const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)], usable: 20), isEmpty);
  });

  test('appliquer une demande', () {
    final c = sample();
    final items = <XpItem>[];
    add(c, items, XpKind.skill, 'Représentation', note: 'opéra');
    add(c, items, XpKind.merit, 'Chanceux');
    add(c, items, XpKind.flawBuyback, 'Curiosité');
    add(c, items, XpKind.humanity, 'Humanité');
    add(c, items, XpKind.attribute, 'mental');
    add(c, items, XpKind.discipline, 'Présence');
    final after = applyRequest(c, items);
    expect(after.skills.single.level, 5);
    expect(after.skills.single.note, 'chant lyrique · opéra');
    expect(after.merits.map((m) => m.name), contains('Chanceux'));
    expect(after.flaws, isEmpty);
    expect(after.humanity, 1);
    expect(after.attributes[AttrCategory.mental]!.value, 1);
    expect(after.disciplines.firstWhere((d) => d.name == 'Présence').inClan, isTrue);
    expect(after.xpSpent, 46 + 10 + 2 + 4 + 10 + 3 + 3);
    expect(c.xpSpent, 46);
  });

  test('éléments proposés', () {
    final c = sample();
    expect(elementOptions(c, XpKind.background).keys, isNot(contains('Génération')));
    expect(elementOptions(c, XpKind.merit).keys, isNot(contains('Visage angélique')));
    expect(elementOptions(c, XpKind.flawBuyback), {'Curiosité': 'Curiosité (2)'});
    expect(elementOptions(c, XpKind.discipline).keys.take(3), ['Auspex', 'Célérité', 'Présence']);
  });
}
