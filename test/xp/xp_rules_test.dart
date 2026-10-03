import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
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

String? err(Character c, XpKind k, String name, {String? note, int usable = 100, List<XpItem>? items, Rulebook rb = const Rulebook()}) {
  final list = items ?? <XpItem>[];
  return itemError(c, list, draftItem(c, list, k, name, note: note, rb: rb), usable: usable, rb: rb);
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

  test('Humanité : 6 au plus (livre de base p. 300)', () {
    expect(err(sample()..humanity = 6, XpKind.humanity, 'Humanité'), 'Plafond atteint (6).');
    expect(err(sample()..humanity = 5, XpKind.humanity, 'Humanité'), isNull);
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
    expect(requestChecks(sample(), vicissitude, reservedOthers: 0).any((k) => k.text.startsWith('Professeur nécessaire')), isTrue);
    final domination = req([const XpItem(XpKind.discipline, 'Domination', 0, 1, 4)]);
    expect(requestChecks(sample(), domination, reservedOthers: 0).map((k) => k.text),
        contains('Professeur nécessaire : Domination hors clan, à confirmer par le conte'));
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

  test('fiche retirée : validation impossible (petits défauts)', () {
    final retired = sample()..status = CharacterStatus.retired;
    expect(
      requestChecks(retired, req([const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)]), reservedOthers: 0)
          .where((k) => k.level == CheckLevel.error)
          .map((k) => k.text),
      contains('La fiche n’est plus active : refusez la demande.'),
    );
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

  group('référentiel', () {
    List<RuleEntry> tweak(String cat, String name, void Function(RuleEntry) edit) {
      final list = baseEntries(cat);
      edit(list.firstWhere((e) => e.name == name));
      return list;
    }

    test('coûts selon la ligne du rang', () {
      final rb = Rulebook({
        'generations': [RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'traitFactor': 3, 'outOfClanFactor': 5})],
      });
      final c = sample();
      expect(draftItem(c, const [], XpKind.skill, 'Linguistique', rb: rb).cost, 3);
      final domination = draftItem(c, const [], XpKind.discipline, 'Domination', rb: rb);
      expect(domination.cost, 5);
      expect(ruleText(c, domination, rb: rb), 'Hors clan · nouveau niveau × 5');
      expect(costTable(c, rb: rb), contains(('Compétence', 'Nouveau niveau × 3')));
    });

    test('états : élément interdit refusé, accord du conte signalé', () {
      final skills = [
        for (final e in baseEntries('skills'))
          (e..state = switch (e.name) {'Linguistique' => RuleState.forbidden, 'Bagarre' => RuleState.approval, _ => e.state}),
      ];
      final rb = Rulebook({'skills': skills});
      final c = sample();
      final options = elementOptions(c, XpKind.skill, rb: rb);
      expect(options, isNot(contains('Linguistique')));
      expect(options['Bagarre'], 'Bagarre · accord du conte');
      final forbidden = draftItem(c, const [], XpKind.skill, 'Linguistique', rb: rb);
      expect(itemError(c, const [], forbidden, usable: 100, rb: rb), 'Linguistique est interdit dans la chronique.');
      final r = req([draftItem(c, const [], XpKind.skill, 'Bagarre', rb: rb)]);
      expect(requestChecks(c, r, reservedOthers: 0, rb: rb).map((k) => k.text), contains('Bagarre : accord du conte nécessaire'));
    });

    test('domaines et plafonds du référentiel', () {
      final skills = tweak('skills', 'Bagarre', (e) => e.data['domainMode'] = 'optional');
      skills.firstWhere((e) => e.name == 'Représentation').data['cap'] = 4;
      final rb = Rulebook({'skills': skills});
      final c = sample();
      expect(noteSpec(XpKind.skill, 'Bagarre', rb: rb), ('Domaine', false));
      expect(noteSpec(XpKind.skill, 'Représentation', rb: rb), ('Domaine', true));
      expect(noteSpec(XpKind.skill, 'Esquive', rb: rb), isNull);
      expect(noteSpec(XpKind.background, 'Ressources', rb: rb), ('Détail du nouveau point', true));
      expect(err(c, XpKind.skill, 'Bagarre', rb: rb), isNull);
      expect(err(c, XpKind.skill, 'Représentation', note: 'opéra', rb: rb), 'Plafond atteint (4).');
    });

    test('atout : valeur du référentiel ; valeur changée après l’envoi (Review Focus 4)', () {
      final c = sample();
      final sent = req([draftItem(c, const [], XpKind.merit, 'Chanceux')]);
      final rb = Rulebook({'merits': tweak('merits', 'Chanceux', (e) => e.data['cost'] = 3)});
      expect(draftItem(c, const [], XpKind.merit, 'Chanceux', rb: rb).toLevel, 3);
      final errors = [for (final k in requestChecks(c, sent, reservedOthers: 0, rb: rb)) if (k.level == CheckLevel.error) k.text];
      expect(errors, ['Achat invalide : Atout · Chanceux vaut 3 points, la demande en compte 2']);
    });

    test('rareté par secte et disciplines du clan du référentiel', () {
      final clans = tweak('clans', 'Toreador', (e) => e.data
        ..['rarity'] = {'Camarilla': 'rare'}
        ..['disciplines'] = ['Auspex', 'Domination', 'Présence']);
      final rb = Rulebook({'clans': clans});
      final c = sample();
      expect(meritPoints(c, const [], rb: rb), 5);
      final after = applyRequest(c, [draftItem(c, const [], XpKind.discipline, 'Domination', rb: rb)], rb: rb);
      expect(after.disciplines.firstWhere((d) => d.name == 'Domination').inClan, isTrue);
      expect(after.xpSpent, c.xpSpent + 3);
    });
  });

  test('demande renvoyée au joueur : atout dont la valeur a changé signalé avant l’envoi (revue)', () {
    final c = sample();
    final items = [draftItem(c, const [], XpKind.merit, 'Chanceux')];
    final merits = baseEntries('merits');
    merits.firstWhere((e) => e.name == 'Chanceux').data['cost'] = 3;
    expect(sendProblems(c, items, usable: 100, rb: Rulebook({'merits': merits})),
        ['Atout · Chanceux vaut maintenant 3 points. Retirez cet achat puis ajoutez-le de nouveau.']);
  });

  test('historique sans précision demandée par le référentiel : note facultative (revue)', () {
    final backgrounds = baseEntries('backgrounds');
    backgrounds.firstWhere((e) => e.name == 'Ressources').data.remove('ask');
    final rb = Rulebook({'backgrounds': backgrounds});
    expect(noteSpec(XpKind.background, 'Ressources', rb: rb), ('Détail du nouveau point', false));
    expect(err(sample(), XpKind.background, 'Ressources', rb: rb), isNull);
  });
}
