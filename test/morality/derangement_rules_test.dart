import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart' show draftData;
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/morality/derangement_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'derangements': [
    RuleEntry(name: 'Peur du feu', data: {'type': 'phobia'}),
    RuleEntry(name: 'Mégalomanie', data: {'type': 'belief'}),
  ],
});

Derangement fire() => Derangement('x-d1', 'Peur du feu', type: 'phobia', trigger: 'Le feu, même une bougie.', severe: true);

void main() {
  test('contrôles, dont le doublon et la modification de soi-même (Review Focus 4)', () {
    expect(derangementChecks(fire(), const []), isEmpty);
    expect(derangementChecks(Derangement('', ' '), const []), ['Nom obligatoire']);
    expect(derangementChecks(Derangement('', 'x' * 81), const []), ['Nom : 80 caractères au plus']);
    expect(derangementChecks(Derangement('', 'A', type: 'lune'), const []), ['Type inconnu']);
    expect(derangementChecks(Derangement('', 'A', trigger: 'x' * 201), const []), ['Déclencheur : 200 caractères au plus']);
    expect(derangementChecks(Derangement('', 'peur du feu'), [fire()]), ['Un dérangement porte déjà ce nom']);
    expect(derangementChecks(fire()..trigger = 'Les flammes', [fire()]), isEmpty);
  });

  test('points, ligne, plancher Malkavien, bornes du compteur (Review Focus 3)', () {
    expect((derangementPoints(fire()), derangementPoints(fire()..severe = false)), (3, 2));
    expect([derangementLine(fire()), derangementLine(fire()..severe = false), derangementLine(fire()..clan = true)],
        ['Sévère · 3 pts', '2 pts', 'Principal · clan']);
    final malk = sample()..clan = 'Malkavien';
    expect((traitsFloor(sample()), traitsFloor(malk)), (0, 1));
    expect([clampTraits(malk, 0), clampTraits(sample(), 0), clampTraits(sample(), 5), clampTraits(malk, 2)], [1, 0, 3, 2]);
    expect(derangementTypes['phobia'], 'Phobie');
  });

  test('à détailler : handicap d’un modèle, fiche jouée, pas déjà détaillé ; prérempli', () {
    final c = sample()..flaws = [Trait('Peur du feu', 2), Trait('Curiosité', 2)];
    expect([for (final t in toDetail(c, rb)) t.name], ['Peur du feu']);
    expect(toDetail(c.clone()..derangements = [fire()], rb), isEmpty);
    final draft = sample()
      ..status = CharacterStatus.draft
      ..flaws = [Trait('Peur du feu', 2)];
    expect(toDetail(draft, rb), isEmpty);
    final m = fromModel(rb, 'Mégalomanie', id: 'x-d2');
    expect((m.id, m.name, m.type, m.severe, m.clan), ('x-d2', 'Mégalomanie', 'belief', false, false));
  });

  test('achat : détail porté', () {
    expect(derangementData(fire()), {'type': 'phobia', 'trigger': 'Le feu, même une bougie.', 'severe': true, 'clan': false});
  });

  test('fiche : clés tardives, jamais dans le brouillon, changements tracés (Review Focus 1)', () {
    expect(sample().toMap().keys, isNot(anyOf(contains('derangements'), contains('derangementTraits'))));
    final c = sample()
      ..derangements = [fire()]
      ..derangementTraits = 2;
    final back = Character.fromMap('x', c.toMap());
    expect(back.derangements.single.toMap(), fire().toMap());
    expect(back.derangementTraits, 2);
    expect(sample().laterKeys().keys, containsAll(['derangements', 'derangementTraits']));
    expect(draftData(c).keys, isNot(anyOf(contains('derangements'), contains('derangementTraits'))));
    final full = sample()
      ..allies = [Ally('x-a1', 'Maître', level: 2)]
      ..path = 'x'
      ..rituals = [Ritual('Rite', 'Thaumaturgie', 1)];
    expect(draftData(full).keys, isNot(anyOf(contains('allies'), contains('path'))));
    expect(draftData(full).keys, contains('rituals'));
    expect(newDerangementId('x'), startsWith('x-d'));
    expect(describeChanges(sample(), c), containsAll(['+ Dérangement Peur du feu', 'Traits de dérangement : 0 → 2']));
    final edited = c.clone();
    edited.derangements.single.trigger = 'Les flammes';
    expect(describeChanges(c, edited), contains('Dérangement Peur du feu modifié'));
    expect(describeChanges(c, sample()), contains('− Dérangement Peur du feu'));
  });
}
