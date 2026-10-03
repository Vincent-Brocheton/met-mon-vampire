import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/schema.dart';
import 'package:portail_met/rulebook/usage.dart';

import '../characters/character_test.dart' show sample;

void main() {
  test('20 catégories cohérentes', () {
    expect(ruleCategories.length, 20);
    expect(ruleCategories.map((c) => c.id).toSet().length, 20);
    for (final c in ruleCategories) {
      final keys = {for (final f in c.fields) f.key};
      expect(keys.containsAll(c.columns), isTrue, reason: c.id);
      if (c.filter != null) expect(keys, contains(c.filter), reason: c.id);
      for (final f in [...c.fields, ...c.settings]) {
        if (f.type == FieldType.choice || f.type == FieldType.multi) expect(f.options, isNotEmpty, reason: '${c.id}.${f.key}');
        if (f.type == FieldType.keyed) expect(categoryById(f.keysFrom!), isNotNull, reason: '${c.id}.${f.key}');
        if (f.type == FieldType.rows) expect(f.rowFields, isNotEmpty, reason: '${c.id}.${f.key}');
      }
    }
    expect(categoryById('inconnu'), isNull);
  });

  test('aller-retour d’un élément, nom normalisé', () {
    final e = RuleEntry(id: 'a', name: 'Chanceux', vo: 'Lucky', state: RuleState.approval, source: 'Livre de base, p. 250', data: {'cost': 2, 'atCreation': true});
    final back = RuleEntry.fromMap('a', e.toMap());
    expect(back.toMap(), e.toMap());
    final copy = e.copy()..data['cost'] = 3;
    expect(e.data['cost'], 2);
    expect(copy.data['cost'], 3);
    expect(nameKey('  Volonté   de FER '), 'volonté de fer');
    expect([for (final s in RuleState.values) if (s.offered) s], [RuleState.available, RuleState.approval]);
  });

  test('valeurs de base reprises du code', () {
    final merits = baseEntries('merits');
    expect(merits.firstWhere((e) => e.name == 'Chanceux').data['cost'], 2);
    final tremere = baseEntries('clans').firstWhere((e) => e.name == 'Tremere');
    expect(tremere.data['disciplines'], ['Auspex', 'Domination', 'Thaumaturgie']);
    expect((tremere.data['rarity'] as Map)['Camarilla'], 'common');
    expect((baseEntries('clans').firstWhere((e) => e.name == 'Lasombra').data['rarity'] as Map)['Camarilla'], 'rare');
    expect(baseEntries('generations').map((e) => e.data['rank']), ['neonate', 'ancilla', 'pretender']);
    expect(baseEntries('generations').last.data['techniqueCost'], 20);
    expect(baseEntries('archetypes').length, 20);
    expect(baseEntries('sects').where((e) => e.data['isDefault'] == true).single.name, 'Camarilla');
    expect(baseEntries('skills').firstWhere((e) => e.name == 'Artisanat').data['domainMode'], 'perDot');
    expect(baseEntries('disciplines').firstWhere((e) => e.name == 'Auspex').data['common'], isTrue);
    expect(baseEntries('titles'), isEmpty);
  });

  test('nombre de fiches qui portent un nom', () {
    final chars = [sample(), sample()..clan = 'Brujah'];
    expect(usageCount('merits', 'Visage angélique', chars), 2);
    expect(usageCount('clans', 'Toreador', chars), 1);
    expect(usageCount('skills', 'représentation', chars), 2);
    expect(usageCount('titles', 'Prince', chars), isNull);
  });

  test('affichage des valeurs', () {
    final merits = categoryById('merits')!;
    expect(displayValue(merits.fields.firstWhere((f) => f.key == 'type'), 'clan'), 'Clan');
    expect(displayValue(merits.fields.firstWhere((f) => f.key == 'atCreation'), true), 'Oui');
    expect(displayValue(merits.fields.firstWhere((f) => f.key == 'cost'), null), '—');
    final clans = categoryById('clans')!;
    expect(displayValue(clans.fields.firstWhere((f) => f.key == 'disciplines'), ['Auspex', 'Présence']), 'Auspex, Présence');
    expect(displayValue(clans.fields.firstWhere((f) => f.key == 'bloodlines'), [{'name': 'Ishtarri'}]), '1 ligne');
  });
}
