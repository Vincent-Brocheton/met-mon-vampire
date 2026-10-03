import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/rulebook/rules_repository.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_settings.dart';

void main() {
  test('valeurs de base', () {
    const rb = Rulebook();
    expect(rb.cost('merits', 'chanceux'), 2);
    expect(rb.clanDisciplines('Tremere'), ['Auspex', 'Domination', 'Thaumaturgie']);
    expect(rb.rarity('Lasombra', 'Camarilla'), 'rare');
    expect(rb.rarity('Lasombra', 'Sabbat'), 'rare', reason: 'secte absente : celle par défaut');
    expect(rb.rarityCost('Giovanni', 'Camarilla'), 2);
    expect(rb.commonDisciplines(), contains('Auspex'));
    expect(rb.isCommon('Thaumaturgie'), isFalse);
    expect(rb.domainMode('Artisanat'), 'perDot');
    expect(rb.domainMode('Bagarre'), 'none');
    expect(rb.gen(GenRank.ancilla).blood, 12);
    expect(rb.gen(GenRank.ancilla).traitFactor, 2);
    expect(rb.gen(GenRank.neonate).numbers, [13, 12, 11]);
    expect(rb.gen(GenRank.pretender).eldersAllowed, isTrue);
    expect(rb.playable('Camarilla'), 'all');
    expect(rb.defaultSect, 'Camarilla');
    expect(rb.skillCap('Bagarre', null), 5);
  });

  test('repli catégorie par catégorie, états proposés', () {
    final rb = Rulebook({
      'merits': [
        RuleEntry(name: 'Mécène', state: RuleState.approval, data: {'cost': 3}),
        RuleEntry(name: 'Secret', state: RuleState.draft, data: {'cost': 1}),
      ],
    });
    expect(rb.find('merits', 'Chanceux'), isNull);
    expect(rb.find('clans', 'Tremere'), isNotNull);
    expect(rb.offeredNames('merits'), ['Mécène']);
    expect(rb.cost('merits', 'mécène'), 3);
  });

  test('rareté par secte, lignée, générations du référentiel', () {
    final rb = Rulebook({
      'clans': [
        RuleEntry(name: 'Tremere', data: {
          'disciplines': ['Auspex', 'Domination', 'Thaumaturgie'],
          'rarity': {'Sabbat': 'common', 'Camarilla': 'forbidden'},
          'bloodlines': [
            {'name': 'Telyav', 'merit': 'Lignée Telyav'},
          ],
        }),
      ],
      'merits': [RuleEntry(name: 'Lignée Telyav', data: {'cost': 2})],
      'generations': [
        RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'traitFactor': 3, 'numbers': ['10']}),
      ],
    });
    expect(rb.rarity('Tremere', 'Camarilla'), 'forbidden');
    expect(rb.rarity('Tremere', 'Sabbat'), 'common');
    expect(rb.rarity('Tremere', 'Anarchs'), 'forbidden', reason: 'secte absente : celle par défaut');
    expect(rb.rarityCost('Tremere', 'Camarilla'), 0);
    expect(rb.lineageMerit('Tremere', ' telyav '), ('Lignée Telyav', 2));
    expect(rb.lineageMerit('Tremere', 'Inconnue'), isNull);
    final ancilla = rb.gen(GenRank.ancilla);
    expect((ancilla.traitFactor, ancilla.blood, ancilla.eldersAllowed), (3, 12, false));
    expect(ancilla.numbers, [10]);
    expect(rb.gen(GenRank.neonate).traitFactor, 1, reason: 'rang absent : valeurs de base');
  });

  test('valeurs de création : défauts, invalides, aller-retour', () {
    expect(slotsText([4, 3, 3, 2, 2, 2, 1, 1, 1, 1]), '4 / 3-3 / 2-2-2 / 1-1-1-1');
    const d = CreationValues();
    expect(d.attributeSlots, [7, 5, 3]);
    expect((d.startingXp, d.maxFlawXp, d.maxSetAside, d.defaultBonus), (30, 7, 5, 0));
    final bad = CreationValues.fromMap({'attributeSlots': [7, 5], 'skillSlots': [4, 'x'], 'startingXp': -1, 'maxFlawXp': 6});
    expect(bad.attributeSlots, [7, 5, 3]);
    expect(bad.skillSlots, d.skillSlots);
    expect((bad.startingXp, bad.maxFlawXp), (30, 6));
    const custom = CreationValues(attributeSlots: [8, 5, 3], startingXp: 35, defaultBonus: 2);
    expect(CreationValues.fromMap(custom.toMap()).toMap(), custom.toMap());
    const s = XpSettings(creation: custom);
    expect(XpSettings.fromMap(s.toMap()).creation.toMap(), custom.toMap());
    expect(XpSettings.fromMap(const {}).creation.startingXp, 30);
  });

  test('provider : null pendant le chargement, valeurs de base si la lecture échoue (Review Focus 5)', () async {
    final entries = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(entries.close);
    final container = ProviderContainer(overrides: [
      allRuleEntriesProvider.overrideWith((ref) => entries.stream),
      xpSettingsProvider.overrideWith((ref) => Stream.value(const XpSettings(creation: CreationValues(startingXp: 35)))),
    ]);
    addTearDown(container.dispose);
    container.listen(rulebookProvider, (_, _) {});
    expect(container.read(rulebookProvider), isNull);
    await container.read(xpSettingsProvider.future);
    entries.addError(Exception('lecture refusée'));
    await Future<void>.delayed(Duration.zero);
    final rb = container.read(rulebookProvider);
    expect(rb, isNotNull);
    expect(rb!.creation.startingXp, 35);
    expect(rb.clanDisciplines('Tremere'), ['Auspex', 'Domination', 'Thaumaturgie']);
  });

  test('catégorie sans élément proposé : valeurs de base ; ligne de génération en brouillon ignorée (revue)', () {
    final rb = Rulebook({
      'clans': [RuleEntry(name: 'Tremere', state: RuleState.draft, data: {'disciplines': ['Auspex']})],
      'generations': [RuleEntry(name: 'Neonate', state: RuleState.draft, data: {'rank': 'neonate', 'traitFactor': 3})],
    });
    expect(rb.offeredNames('clans'), contains('Brujah'));
    expect(rb.gen(GenRank.neonate).traitFactor, 1);
  });

  test('aucune secte marquée par défaut : Camarilla, comme les valeurs de base (revue)', () {
    final rb = Rulebook({
      'sects': [RuleEntry(name: 'Camarilla'), RuleEntry(name: 'Sabbat')],
    });
    expect(rb.rarity('Lasombra', 'Sabbat'), 'rare');
  });
}
