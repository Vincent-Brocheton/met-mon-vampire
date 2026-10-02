import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';

Character sample() => Character(
      id: 'x',
      name: 'Isaure de Valcourt',
      kind: CharacterKind.pj,
      playerUid: 'u1',
      playerName: 'Camille R.',
      status: CharacterStatus.active,
    )
      ..clan = 'Toreador'
      ..sect = 'Camarilla'
      ..genRank = GenRank.ancilla
      ..genNumber = 10
      ..attributeRanks = [AttrCategory.social, AttrCategory.mental, AttrCategory.physical]
      ..attributes[AttrCategory.social] = Attribute(7, 'Charisme')
      ..skills = [Trait('Représentation', 4, note: 'chant lyrique')]
      ..backgrounds = [Trait('Ressources', 3, note: '4 500 € par mois')]
      ..disciplines = [Discipline('Auspex', 3, inClan: true, powers: ['Sens exacerbés'])]
      ..merits = [Trait('Visage angélique', 1)]
      ..flaws = [Trait('Curiosité', 2)]
      ..purchases = [Purchase('skill', 'Empathie', 3, 3)]
      ..submittedAt = DateTime.utc(2026, 9, 23)
      ..xpInitial = 33
      ..xpEarned = 33
      ..xpSpent = 46
      ..version = 4
      ..lastHistoryId = 'h4';

void main() {
  test('aller-retour toMap / fromMap sans perte', () {
    final c = sample();
    final back = Character.fromMap('x', c.toMap());
    expect(back.toMap(), c.toMap());
    expect(back.attributes[AttrCategory.social]!.focus, 'Charisme');
    expect(back.submittedAt!.isAtSameMomentAs(DateTime.utc(2026, 9, 23)), isTrue);
  });

  test('toMap écrit toutes les clés, même nulles', () {
    final m = Character(id: 'x', name: 'Sœur Agathe', kind: CharacterKind.pnj).toMap();
    expect(m.containsKey('playerUid'), isTrue);
    expect(m['playerUid'], isNull);
    expect(m.containsKey('sire'), isTrue);
  });

  test('valeurs par défaut sur un document presque vide', () {
    final c = Character.fromMap('x', {'name': 'X', 'kind': 'pnj'});
    expect(c.kind, CharacterKind.pnj);
    expect(c.status, CharacterStatus.draft);
    expect(c.skills, isEmpty);
    expect(c.attributes[AttrCategory.mental]!.value, 0);
  });

  test('XP disponible', () => expect(sample().xpAvailable, 20));

  test('clone indépendant', () {
    final c = sample();
    final d = c.clone()..skills.first.level = 5;
    expect(c.skills.first.level, 4);
    expect(d.skills.first.level, 5);
  });
}
