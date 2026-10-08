import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart' show draftData;
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/morality/morality_rules.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'paths': [
    RuleEntry(name: 'Voie de la Nuit', data: {'maxMorality': 4, 'sins': ['Tuer sans raison', 'Épargner un ennemi', 'Avouer sa peur']}),
    RuleEntry(name: 'Voie du Sang', data: {'maxMorality': 4}),
  ],
});

Sin sin(String id, {int level = 1, Remorse remorse = Remorse.failed, DateTime? date, bool locked = false}) =>
    Sin(id: id, date: date ?? DateTime(2026, 9, 20, 23, 30), level: level, remorse: remorse, lossApplied: locked);

void main() {
  test('voie : nom, maximum, échelle, hiérarchie (voie inconnue : valeurs de base)', () {
    final night = sample()..path = 'Voie de la Nuit';
    expect((moralityName(sample()), moralityName(night)), ('Humanité', 'Voie de la Nuit'));
    expect((moralityMax(sample(), rb), moralityMax(night, rb), pathMax(rb, 'Voie inconnue')), (6, 4, 6));
    expect([for (var n = 0; n <= 6; n++) moralityLabel(n)], ['Wassail', 'Horrible', 'Bestiale', 'Insensible', 'Distante', 'Normale', 'Sainte']);
    expect(sinLevels(sample(), rb), defaultSinLevels);
    expect(sinLevels(night, rb), ['Tuer sans raison', 'Épargner un ennemi', 'Avouer sa peur']);
    expect(sinLevels(sample()..path = 'Voie du Sang', rb), defaultSinLevels);
  });

  test('traits de Bête : remords réussi −1, jamais négatif ; soirées triées', () {
    expect([sinTraits(sin('a', level: 3)), sinTraits(sin('b', level: 3, remorse: Remorse.success)), sinTraits(sin('c', remorse: Remorse.success))], [3, 2, 0]);
    final sins = [sin('a', level: 3), sin('b', level: 2, date: DateTime(2026, 9, 20, 1)), sin('c', date: DateTime(2026, 8, 23))];
    final evenings = eveningsOf(sins);
    expect([for (final (d, _) in evenings) d], [DateTime(2026, 9, 20), DateTime(2026, 8, 23)]);
    expect([for (final s in evenings.first.$2) s.id], ['a', 'b']);
    expect(eveningTraits(evenings.first.$2), 5);
  });

  test('perte : à 5 traits, une seule fois par soirée (Review Focus 1 et 4)', () {
    expect(lossDue([sin('a', level: 3), sin('b', level: 2)]), isTrue);
    expect(lossDue([sin('a', level: 3), sin('b', level: 1)]), isFalse);
    expect(lossDue([sin('a', level: 3, locked: true), sin('b', level: 2, locked: true), sin('c', level: 4)]), isFalse);
  });

  test('changement de voie : valeur ramenée au maximum ; perte jamais sous 0 (Review Focus 2 et 5)', () {
    final c = sample()..humanity = 5;
    final night = changePath(c, rb, 'Voie de la Nuit');
    expect((night.path, night.humanity, c.path, c.humanity), ('Voie de la Nuit', 4, null, 5));
    final back = changePath(night, rb, '');
    expect((back.path, back.humanity), (null, 4));
    expect(loseOne(c).humanity, 4);
    expect(loseOne(sample()..humanity = 0).humanity, 0);
  });

  test('contrôles d’un péché', () {
    expect(sinChecks(sin('a', level: 5), sample(), rb), isEmpty);
    expect(sinChecks(sin('a', level: 6), sample(), rb), ['Niveau de 1 à 5']);
    expect(sinChecks(sin('a', level: 4), sample()..path = 'Voie de la Nuit', rb), ['Niveau de 1 à 3']);
    expect(sinChecks(sin('a')..what = 'x' * 501, sample(), rb), ['Ce qui s’est passé : 500 caractères au plus']);
    expect(sinChecks(sin('a', date: DateTime(1800)), sample(), rb), ['Date invalide']);
  });

  test('événements et messages de la perte et de la voie', () {
    final evening = [sin('a', level: 3), sin('b', level: 2)];
    expect(lossMessage(sample()..humanity = 5, evening), '5 traits de Bête atteints : Isaure de Valcourt perd un point d’Humanité (5 → 4, Distante).');
    expect(lossMessage(sample()
      ..humanity = 5
      ..path = 'Voie de la Nuit', evening), '5 traits de Bête atteints : Isaure de Valcourt perd un point de Voie de la Nuit (5 → 4, Distante).');
    final before = sample()..humanity = 5;
    final e = lossEvent(before, loseOne(before), DateTime(2026, 9, 20, 23));
    expect((e.type, e.title, e.year, e.month, e.day, e.visibility, e.auto), (EventType.morality, 'Humanité 5 → 4, Distante', 2026, 9, 20, EventVisibility.player, true));
    expect(lossReason(DateTime(2026, 9, 20)), 'Traits de Bête : soirée du 20 sept.');
    final p = pathEvent(sample()..path = 'Voie de la Nuit', DateTime(2026, 10, 13));
    expect((p.type, p.title, p.auto), (EventType.pathAdopted, 'Adopte Voie de la Nuit', true));
    expect(pathEvent(sample(), DateTime(2026, 10, 13)).title, 'Revient à l’Humanité');
  });

  test('péché : aller-retour, soirée au jour, données écrites', () {
    final s = sin('a', level: 2, remorse: Remorse.success)..what = 'A blessé un vigile';
    final back = Sin.fromMap('a', s.toMap());
    expect((back.date, back.level, back.what, back.remorse, back.lossApplied), (DateTime(2026, 9, 20), 2, 'A blessé un vigile', Remorse.success, false));
    expect(newSinData(s, 'lea', 'Léa').keys.toSet(), {'date', 'level', 'what', 'remorse', 'lossApplied', 'byUid', 'byName', 'createdAt', 'updatedAt'});
    expect((Remorse.parse('inconnu'), Remorse.success.label, Remorse.success.choice), (Remorse.none, 'Réussi (−1)', 'Réussi (−1 trait)'));
  });

  test('voie sur la fiche : clé tardive, jamais dans le brouillon, changement tracé (Review Focus 3)', () {
    expect(sample().toMap().containsKey('path'), isFalse);
    final c = sample()..path = 'Voie de la Nuit';
    expect(Character.fromMap('x', c.toMap()).path, 'Voie de la Nuit');
    expect((c.laterKeys()['path'], sample().laterKeys().containsKey('path')), ('Voie de la Nuit', true));
    expect(draftData(c).containsKey('path'), isFalse);
    expect(describeChanges(sample(), c), contains('Voie : Humanité → Voie de la Nuit'));
    expect(EventType.parse('morality').label, 'Moralité');
  });
}
