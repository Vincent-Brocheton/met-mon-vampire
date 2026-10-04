import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servant_rules.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'animalQualities': [
    RuleEntry(name: 'Costaud', data: {'cost': 1}),
    RuleEntry(name: 'Monture', data: {'cost': 3, 'requires': 'Costaud'}),
    RuleEntry(name: 'Venimeux', state: RuleState.forbidden, data: {'cost': 2}),
  ],
});

Character isaure() => sample()..servants = [Servant('x-s1', 'Rex', ServantKind.animal, 2), Servant('x-s2', 'Mila', ServantKind.human, 1)];

ServantFile rexFile() => ServantFile(
      id: 'x-s1',
      kind: 'animal',
      name: 'Rex',
      domitorId: 'x',
      domitorName: 'Isaure de Valcourt',
      holderPlayers: ['u1'],
      specialties: ['Bagarre'],
      qualities: ['Costaud'],
      vitae: 2,
      bond: 1,
      lastDrink: DateTime(2026, 9, 26),
      description: 'Garde le salon.',
      version: 1,
    );

void main() {
  test('réserve, échéance, indisponibilité, points animaux', () {
    expect(pool(3), 6);
    expect(dueDate(DateTime(2026, 9, 26)), DateTime(2026, 10, 26));
    expect(dueState(DateTime(2026, 9, 26), DateTime(2026, 10, 1)), DueState.ok);
    expect(dueState(DateTime(2026, 9, 26), DateTime(2026, 10, 20)), DueState.soon);
    expect(dueState(DateTime(2026, 9, 26), DateTime(2026, 10, 27)), DueState.late);
    expect(dueState(null, DateTime(2026, 10, 27)), isNull);
    expect(unavailableUntil(DateTime(2026, 10, 1)), DateTime(2026, 11, 12));
    expect(animalPoints(['Costaud', 'Monture', 'Inconnue'], rb), 4);
    expect(specialtyOptions(isaure(), rb), containsAll(['Médecine', 'Auspex', 'Présence']));
    expect(servantKindLabel('mortal'), 'Mortel');
  });

  test('aller-retour et copie indépendante', () {
    final f = rexFile();
    expect(ServantFile.fromMap('x-s1', f.toMap()).toMap(), f.toMap());
    f.copy().specialties.add('Furtivité');
    expect(f.specialties, ['Bagarre']);
  });

  test('avertissements', () {
    final c = isaure();
    final f = rexFile()
      ..specialties.addAll(['Domination', 'Auspex'])
      ..qualities.addAll(['Monture', 'Venimeux', 'Disparue'])
      ..qualities.remove('Costaud')
      ..lastDrink = DateTime(2026, 8, 1);
    c.status = CharacterStatus.dead;
    c.playerUid = 'u2';
    expect(servantWarnings(f, rb, entry: c.servants.first, domitor: c, now: DateTime(2026, 10, 5)), [
      '3 spécialités sur 2',
      'Domination : discipline hors du clan du domitor',
      'Qualités animales : 5 points sur 2',
      'Monture demande Costaud',
      'Venimeux est interdite dans la chronique',
      'Disparue : hors du référentiel',
      'Plus de vitae depuis le ${formatDay(DateTime(2026, 8, 1))} : son âge le rattrape',
      'Le domitor est une fiche retirée ou morte',
      'Le joueur du domitor a changé : enregistrez pour mettre à jour l’accès',
    ]);
    expect(servantWarnings(rexFile(), rb, entry: isaure().servants.first, domitor: isaure(), now: DateTime(2026, 10, 1)), isEmpty);
  });

  test('résumé des changements', () {
    final a = rexFile();
    final b = a.copy()
      ..vitae = 3
      ..bond = 2
      ..lastDrink = DateTime(2026, 10, 2)
      ..description = 'Autre'
      ..releasedAt = DateTime(2026, 10, 3);
    b.specialties
      ..remove('Bagarre')
      ..add('Furtivité');
    b.qualities.add('Monture');
    expect(servantChanges(a, b), [
      '+ Spécialité Furtivité',
      '− Spécialité Bagarre',
      '+ Qualité Monture',
      'Vitae 2 → 3',
      'Lien 1 → 2',
      'Gorgée du ${formatDay(DateTime(2026, 10, 2))}',
      'Description modifiée',
      'Libéré de la fiche du domitor',
    ]);
  });

  test('lignes de la liste : serviteurs des fiches, fiches libérées, mortels, à compléter', () {
    final c = isaure();
    final mortal = ServantFile(id: 'm1', kind: 'mortal', name: 'Jeanne', attachment: 'Voisine du refuge');
    final released = ServantFile(id: 'x-old', kind: 'human', name: 'Bruno', domitorId: 'x', releasedAt: DateTime(2026, 9, 1));
    final rows = servantRows([c], [rexFile(), mortal, released]);
    expect([for (final r in rows) (r.id, r.name, r.typeLabel, r.toComplete, r.released)], [
      ('x-s1', 'Rex', 'Goule animale', false, false),
      ('x-s2', 'Mila', 'Goule humaine', true, false),
      ('m1', 'Jeanne', 'Mortel', false, false),
      ('x-old', 'Bruno', 'Goule humaine', false, true),
    ]);
    expect(rows.first.owner, 'Isaure de Valcourt');
    expect(rows[2].owner, 'Voisine du refuge');
  });
}
