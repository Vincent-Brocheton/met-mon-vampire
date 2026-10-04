import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';

import 'character_test.dart' show sample;

void main() {
  test('liste tardive : absente tant que vide, aller-retour, identifiants neufs distincts', () {
    final c = sample();
    expect(c.toMap().containsKey('servants'), isFalse);
    c.servants.add(Servant('x-s1', 'Rex', ServantKind.animal, 2));
    final back = Character.fromMap('x', c.toMap());
    expect(back.servants.single.toMap(), {'id': 'x-s1', 'name': 'Rex', 'kind': 'animal', 'rank': 2});
    back.servants.clear();
    expect(back.toMap()['servants'], isEmpty, reason: 'déjà écrite : la liste vide efface');
    expect(back.laterKeys()['servants'], isEmpty);
    final a = newServantId('x'), b = newServantId('x');
    expect(a, startsWith('x-s'));
    expect(a, isNot(b));
  });

  test('ancien historique Serviteurs : converti sur une fiche active, une seule fois ; pas en brouillon (Review Focus 1)', () {
    final m = {
      ...sample().toMap(),
      'backgrounds': [
        {'name': 'Serviteurs', 'level': 3, 'note': 'Dr Lemaire'},
        {'name': 'Ressources', 'level': 3},
      ],
    };
    final c = Character.fromMap('x', m);
    expect(c.backgrounds.map((b) => b.name), ['Ressources']);
    expect(c.servants.single.toMap(), {'id': 'x-s1', 'name': 'Dr Lemaire', 'kind': 'human', 'rank': 3});
    expect(c.clone().servants, hasLength(1));
    expect(Character.fromMap('x', c.toMap()).servants, hasLength(1));
    final draft = Character.fromMap('x', {...m, 'status': 'draft'});
    expect(draft.servants, isEmpty);
    expect(draft.backgrounds.map((b) => b.name), contains('Serviteurs'));
    final unnamed = Character.fromMap('x', {
      ...m,
      'backgrounds': [
        {'name': 'Serviteurs', 'level': 1},
      ],
    });
    expect(unnamed.servants.single.name, 'Serviteur');
    expect(withConversion(c.clone(), ['Gain mensuel']), ['Gain mensuel', 'Historique « Serviteurs » converti en serviteur'], reason: 'revue : la conversion laisse une trace');
    expect(withConversion(Character.fromMap('x', c.toMap()), ['Gain mensuel']), ['Gain mensuel'], reason: 'déjà convertie : pas de nouvelle ligne');
    final long = Character.fromMap('x', {
      ...m,
      'backgrounds': [
        {'name': 'Serviteurs', 'level': 2, 'note': 'A' * 120},
      ],
    });
    expect(long.servants.single.name.length, 80, reason: 'revue : la fiche détaillée refuse plus de 80 caractères');
  });

  test('résumé des changements', () {
    final a = sample()..servants = [Servant('x-s1', 'Rex', ServantKind.animal, 2), Servant('x-s2', 'Mila', ServantKind.human, 1)];
    final b = a.clone();
    b.servants.first
      ..name = 'Rex II'
      ..rank = 3;
    b.servants.removeLast();
    b.servants.add(Servant('x-s3', 'Lune', ServantKind.animal, 1));
    expect(describeChanges(a, b), ['Serviteur : Rex → Rex II', 'Serviteur Rex II ●● → ●●●', '+ Serviteur Lune ●', '− Serviteur Mila ●']);
  });
}
