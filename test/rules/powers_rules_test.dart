import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rules/powers_rules.dart';

import '../characters/character_test.dart' show sample;

Rulebook rulebook({Map<String, List<RuleEntry>> more = const {}}) => Rulebook({
      'disciplines': [...baseEntries('disciplines'), RuleEntry(name: 'Voie du Sang', data: {'parent': 'Thaumaturgie'})],
      'rituals': [
        RuleEntry(name: 'Goût du sang', data: {'school': 'thaumaturgy', 'level': 1, 'atCreation': true, 'withXp': true}),
        RuleEntry(name: 'Défense du refuge', data: {'school': 'thaumaturgy', 'level': 2, 'atCreation': true, 'withXp': true}),
        RuleEntry(name: 'Communion avec Kindred', data: {'school': 'thaumaturgy', 'level': 1, 'withXp': true}),
        RuleEntry(name: 'Appel des morts', data: {'school': 'necromancy', 'level': 1, 'withXp': true}),
      ],
      'techniques': [
        RuleEntry(name: 'Regard ardent', data: {'prerequisites': ['Présence 2 + Auspex 1', 'Domination 3']}),
        RuleEntry(name: 'Illisible', data: {'prerequisites': ['Présence deux']}),
      ],
      'elderPowers': [
        RuleEntry(name: 'Clairvoyance', data: {'discipline': 'Auspex', 'costInClan': 18, 'costOutOfClan': 24}),
        RuleEntry(name: 'Prophétie', data: {'discipline': 'Auspex'}),
        RuleEntry(name: 'Possession', data: {'discipline': 'Domination'}),
      ],
      ...more,
    }, const CreationValues(), {
      'rituals': {'costPerLevel': 3},
    });

/// Toreador Ancilla, Thaumaturgie ● et Voie du Sang ● (école : 2 points), Auspex ●●● en clan.
Character thaumaturge() => sample()
  ..disciplines = [
    Discipline('Thaumaturgie', 1, inClan: true),
    Discipline('Voie du Sang', 1),
    Discipline('Auspex', 3, inClan: true),
  ];

void main() {
  test('rituels : école, nombre, niveaux inférieurs, doublon, coût', () {
    final rb = rulebook();
    final c = thaumaturge();
    expect(schoolDots(c, 'thaumaturgy', rb), 2);
    expect(ritualError(c, 'Appel des morts', rb), 'Il faut une discipline ou une voie de l’école Nécromancie.');
    expect(ritualError(c, 'Défense du refuge', rb), 'Il manque un rituel de niveau 1');
    expect(ritualError(c, 'Goût du sang', rb), isNull);
    c.rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1));
    expect(ritualError(c, 'Goût du sang', rb), 'Rituel déjà connu.');
    expect(ritualError(c, 'Défense du refuge', rb), isNull);
    c.rituals.add(Ritual('Défense du refuge', 'thaumaturgy', 2));
    expect(ritualError(c, 'Communion avec Kindred', rb), 'Thaumaturgie ●● : 2 rituels au plus, vous en avez 2');
    expect(ritualCost('Défense du refuge', rb), 6);
  });

  test('voie qui baisse après coup : limite et niveaux signalés (Review Focus 2)', () {
    final rb = rulebook();
    final c = thaumaturge()
      ..rituals = [Ritual('Goût du sang', 'thaumaturgy', 1), Ritual('Défense du refuge', 'thaumaturgy', 2)];
    expect(powerProblems(c, rb), isEmpty);
    c.disciplines[1].level = 0;
    expect(powerProblems(c, rb), ['Thaumaturgie ● : 1 rituel au plus, vous en avez 2']);
    c.rituals.removeAt(0);
    expect(powerProblems(c, rb), contains('Il manque un rituel de niveau 1 (Thaumaturgie)'));
  });

  test('techniques : rang, alternatives de prérequis, ligne illisible', () {
    final rb = rulebook();
    final c = thaumaturge();
    expect(techniqueError(c, 'Regard ardent', rb), 'Prérequis manquant : Présence ●●');
    c.disciplines.add(Discipline('Présence', 2));
    expect(techniqueError(c, 'Regard ardent', rb), isNull);
    expect(techniqueError(c, 'Illisible', rb), 'Prérequis de Illisible illisibles : à vérifier par le conte.');
    c.techniques.add('Regard ardent');
    expect(techniqueError(c, 'Regard ardent', rb), 'Technique déjà connue.');
    final closed = rulebook(more: {
      'generations': [RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'techniqueCost': 0})],
    });
    expect(techniqueError(thaumaturge(), 'Regard ardent', closed), 'Techniques interdites au rang Ancilla.');
    expect(techniqueCost(thaumaturge(), rb), 12);
    c.disciplines.removeLast();
    expect(powerProblems(c, rb), ['Regard ardent : prérequis manquant : Présence ●●']);
  });

  test('pouvoirs d’anciens : rang, 5 points, nombre, coût en clan ou hors clan', () {
    final rb = rulebook();
    final c = thaumaturge();
    expect(elderError(c, 'Clairvoyance', rb), 'Pouvoirs d’anciens interdits au rang Ancilla.');
    c.genRank = GenRank.pretender;
    expect(elderError(c, 'Clairvoyance', rb), 'Pouvoir d’ancien : 5 points de Auspex requis');
    c.disciplines.last.level = 5;
    expect(elderError(c, 'Clairvoyance', rb), isNull);
    expect((elderCost(c, 'Clairvoyance', rb), elderInClan(c, 'Clairvoyance', rb)), (18, true));
    expect(elderCost(c, 'Possession', rb), 24);
    c.elderPowers.add(ElderPower('Clairvoyance', 'Auspex'));
    expect(elderError(c, 'Prophétie', rb), 'Pouvoirs d’anciens : 1 au plus au rang Pretender Elder.');
    c.disciplines.last.level = 4;
    expect(powerProblems(c, rb), ['Clairvoyance : 5 points de Auspex requis']);
  });
}
