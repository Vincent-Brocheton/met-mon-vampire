import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rules/creation_rules.dart';

/// Nikolaï Vesk (maquettes) : Tremere Neonate, répartitions gratuites complètes, 3 XP de handicaps.
Character valid() {
  final c = Character(id: 'n', name: 'Nikolaï Vesk', kind: CharacterKind.pj, playerUid: 'zoe', playerName: 'Zoé A.')
    ..concept = 'Archiviste étreint pour sa mémoire'
    ..archetype = 'Je-sais-tout'
    ..sect = 'Camarilla'
    ..attributeRanks = [AttrCategory.mental, AttrCategory.social, AttrCategory.physical]
    ..story = 'Archiviste à la bibliothèque municipale.'
    ..step = 10;
  setClan(c, 'Tremere');
  c.attributes[AttrCategory.physical]!.focus = 'Dextérité';
  c.attributes[AttrCategory.social]!.focus = 'Manipulation';
  c.attributes[AttrCategory.mental]!.focus = 'Intelligence';
  for (final (name, level) in [
    ('Occultisme', 4), ('Érudition', 3), ('Investigation', 3), ('Vigilance', 2), ('Informatique', 2),
    ('Subterfuge', 2), ('Esquive', 1), ('Linguistique', 1), ('Sécurité', 1), ('Furtivité', 1),
  ]) {
    setFreeLevel(c, Buy.skill, name, level);
  }
  setFreeLevel(c, Buy.background, 'Alliés', 3);
  setFreeLevel(c, Buy.background, 'Ressources', 2);
  setFreeLevel(c, Buy.background, generationName, 1);
  for (final b in c.backgrounds) {
    if (b.name != generationName) b.note = 'Précisé';
  }
  c.genNumber = 12;
  setDisciplineFree(c, 'Thaumaturgie', 2);
  setDisciplineFree(c, 'Auspex', 1);
  setDisciplineFree(c, 'Domination', 1);
  c.flaws = [Trait('Curiosité', 2), Trait('Intolérance', 1)];
  applyDerived(c);
  return c;
}

List<String> blocking(Character c) => [
      for (final k in creationChecks(c))
        if (k.level == CheckLevel.todo || k.level == CheckLevel.error) k.text,
    ];

void main() {
  test('fiche complète : soumissible, traits dérivés Neonate', () {
    final c = valid();
    expect(blocking(c), isEmpty);
    expect(canSubmit(creationChecks(c)), isTrue);
    expect(c.genRank, GenRank.neonate);
    expect((c.blood, c.bloodPerTurn, c.willpower, c.humanity), (10, 1, 6, 5));
    expect(c.attributes[AttrCategory.mental]!.value, 7);
    expect(c.attributes[AttrCategory.physical]!.value, 3);
    final b = budgetOf(c);
    expect((b.total, b.spent, b.remaining, b.setAside, b.lost), (33, 0, 33, 5, 28));
    expect((c.xpInitial, c.xpSpent, c.xpEarned), (33, 0, 5));
  });

  test('coûts Neonate puis Ancilla', () {
    final c = valid();
    expect(addPurchase(c, Buy.skill, 'Informatique'), isNull);
    expect(c.purchases.last.cost, 3);
    expect(addPurchase(c, Buy.background, generationName), isNull);
    expect(c.purchases.last.cost, 4);
    applyDerived(c);
    expect(c.genRank, GenRank.ancilla);
    expect(c.blood, 12);
    expect(purchaseCost(c, Buy.skill, 'Informatique', 3), 6);
  });

  test('disciplines : en clan × 3, hors clan × 4, communes seulement, 3 points au plus', () {
    final c = valid();
    expect(addPurchase(c, Buy.discipline, 'Auspex'), isNull);
    expect(c.purchases.last.cost, 6);
    expect(addPurchase(c, Buy.discipline, 'Présence'), isNull);
    expect(c.purchases.last.cost, 4);
    expect(addPurchase(c, Buy.discipline, 'Vicissitude'), contains('communes'));
    expect(addPurchase(c, Buy.discipline, 'Présence'), isNull);
    expect(addPurchase(c, Buy.discipline, 'Présence'), isNull);
    expect(addPurchase(c, Buy.discipline, 'Célérité'), contains('3 points'));
  });

  test('attribut 3 XP ; Humanité 10 XP le point, 6 au plus (livre de base p. 107 et 300)', () {
    final c = valid();
    expect(addPurchase(c, Buy.attribute, AttrCategory.physical.name), isNull);
    expect(addPurchase(c, Buy.humanity, humanityName), isNull);
    applyDerived(c);
    expect(c.attributes[AttrCategory.physical]!.value, 4);
    expect(c.humanity, 6);
    expect(budgetOf(c).purchases, 3 + 10);
    expect(addPurchase(c, Buy.humanity, humanityName), 'Plafond atteint (6).');
  });

  test('retrait dans l’ordre seulement (Review Focus 3)', () {
    final c = valid();
    addPurchase(c, Buy.skill, 'Informatique');
    addPurchase(c, Buy.skill, 'Informatique');
    expect(removePurchase(c, 0), contains('niveau supérieur'));
    expect(removePurchase(c, 1), isNull);
    expect(levelOf(c, Buy.skill, 'Informatique'), 3);
  });

  test('changer de clan retire les anciennes disciplines non achetées (Review Focus 4)', () {
    final c = valid();
    addPurchase(c, Buy.discipline, 'Auspex');
    setClan(c, 'Brujah');
    final names = c.disciplines.map((d) => d.name).toSet();
    expect(names, containsAll(['Célérité', 'Puissance', 'Présence', 'Auspex']));
    expect(names, isNot(contains('Thaumaturgie')));
    expect(c.disciplines.where((d) => d.inClan).map((d) => d.name).toSet(), {'Célérité', 'Puissance', 'Présence'});
    // Revue finale : la discipline achetée sort du clan avec ses seuls points achetés, sans impasse.
    applyDerived(c);
    expect(levelOf(c, Buy.discipline, 'Auspex'), 1);
    expect(blocking(c).where((t) => t.contains('Auspex')), isEmpty);
    expect(removePurchase(c, 0), isNull);
    expect(c.disciplines.map((d) => d.name), isNot(contains('Auspex')));
  });

  test('changer un niveau gratuit après un achat renumérote l’achat (revue finale)', () {
    final c = valid();
    addPurchase(c, Buy.skill, 'Esquive');
    expect(budgetOf(c).purchases, 2);
    setFreeLevel(c, Buy.skill, 'Esquive', 4);
    applyDerived(c);
    expect(c.purchases.single.toLevel, 5);
    expect(budgetOf(c).purchases, 5);
    expect(removePurchase(c, 0), isNull);
    expect(levelOf(c, Buy.skill, 'Esquive'), 4);
    addPurchase(c, Buy.attribute, AttrCategory.physical.name);
    c.attributeRanks = [AttrCategory.physical, AttrCategory.social, AttrCategory.mental];
    applyDerived(c);
    expect(removePurchase(c, 0), isNull);
    applyDerived(c);
    expect(c.attributes[AttrCategory.physical]!.value, 7);
  });

  test('valeurs enregistrées falsifiées : bloquant (revue finale)', () {
    expect(blocking(valid()..xpEarned = 500), contains('Valeurs calculées incohérentes : réenregistrez la fiche depuis l’application'));
    expect(blocking(valid()..willpower = 10), isNotEmpty);
  });

  test('Humanité au-delà de 6 (brouillon d’avant le plafond) : bloquant (revue finale)', () {
    final c = valid()
      ..purchases.addAll([Purchase(Buy.humanity, humanityName, 6, 10), Purchase(Buy.humanity, humanityName, 7, 10)]);
    applyDerived(c);
    expect(c.humanity, 7);
    expect(blocking(c), contains('Humanité : 6 au plus.'));
  });

  test('rareté de clan comptée dans les atouts', () {
    final c = valid();
    setClan(c, 'Giovanni');
    expect(budgetOf(c).merits, 2);
  });

  test('handicaps plafonnés à 7 XP, avec avertissement', () {
    final c = valid()..flaws = [Trait('Traqué', 4), Trait('Addiction', 2), Trait('Impatient', 2), Trait('Sombre secret', 1)];
    expect(budgetOf(c).flaws, 7);
    expect(creationChecks(c).any((k) => k.level == CheckLevel.warn && k.text.contains('au-delà de 7')), isTrue);
  });

  test('contrôles bloquants', () {
    expect(blocking(valid()..name = ''), isNotEmpty);
    final missing = valid();
    setFreeLevel(missing, Buy.skill, 'Furtivité', 0);
    expect(blocking(missing), contains('Il reste 1 compétence à placer à 1 point.'));
    final domain = valid();
    setFreeLevel(domain, Buy.skill, 'Sécurité', 0);
    setFreeLevel(domain, Buy.skill, 'Représentation', 1);
    expect(blocking(domain), contains('Précisez le domaine de Représentation'));
    final mortal = valid();
    setFreeLevel(mortal, Buy.background, generationName, 0);
    setFreeLevel(mortal, Buy.background, 'Refuge', 1);
    expect(blocking(mortal), contains('Sans point de Génération, le personnage est un mortel'));
    final outOfClan = valid()..disciplines.add(Discipline('Présence', 1));
    expect(blocking(outOfClan), contains('Présence hors clan : uniquement par achat'));
    final over = valid();
    for (var i = 0; i < 3; i++) {
      addPurchase(over, Buy.discipline, 'Présence');
    }
    addPurchase(over, Buy.discipline, 'Auspex');
    addPurchase(over, Buy.discipline, 'Auspex');
    expect(blocking(over).any((t) => t.startsWith('Budget dépassé')), isTrue);
    expect(canSubmit(creationChecks(over)), isFalse);
  });

  test('étapes complètes', () {
    final c = valid();
    expect([for (var s = 1; s <= 10; s++) stepComplete(c, s, creationChecks(c))], everyElement(isTrue));
    final fresh = Character(id: 'f', name: '', kind: CharacterKind.pj);
    expect(stepComplete(fresh, 1, creationChecks(fresh)), isFalse);
  });

  group('référentiel', () {
    List<String> blockingWith(Character c, Rulebook rb) => [
          for (final k in creationChecks(c, rb: rb))
            if (k.level == CheckLevel.todo || k.level == CheckLevel.error) k.text,
        ];
    List<String> warnings(Character c, Rulebook rb) => [for (final k in creationChecks(c, rb: rb)) if (k.level == CheckLevel.warn) k.text];

    /// Catégorie de base, avec [edit] appliqué à l'élément [name].
    List<RuleEntry> tweak(String cat, String name, void Function(RuleEntry) edit) {
      final list = baseEntries(cat);
      edit(list.firstWhere((e) => e.name == name));
      return list;
    }

    test('référentiel à moitié rempli : clans et compétences de base (Review Focus 1)', () {
      final rb = Rulebook({
        'merits': [RuleEntry(name: 'Mécène', data: {'cost': 3, 'atCreation': true})],
      });
      final c = valid();
      applyDerived(c, rb: rb);
      expect(blockingWith(c, rb), isEmpty);
      c.merits = [Trait('Chanceux', 2)];
      expect(warnings(c, rb), contains('Atout Chanceux hors liste : à confirmer par le conte'));
    });

    test('états : accord du conte, interdit, hors liste', () {
      final skills = [
        for (final e in baseEntries('skills'))
          if (e.name != 'Vigilance')
            (e..state = switch (e.name) {'Occultisme' => RuleState.approval, 'Érudition' => RuleState.forbidden, _ => e.state}),
      ];
      final rb = Rulebook({'skills': skills});
      final c = valid();
      expect(warnings(c, rb), containsAll(['Occultisme : accord du conte nécessaire', 'Compétence Vigilance hors liste : à confirmer par le conte']));
      expect(blockingWith(c, rb), ['Érudition est interdit dans la chronique']);
    });

    test('clan interdit pour la secte : erreur, fiche inchangée (Review Focus 2)', () {
      final rb = Rulebook({'clans': tweak('clans', 'Tremere', (e) => e.data['rarity'] = {'Camarilla': 'forbidden'})});
      final c = valid();
      final before = c.toMap();
      expect(blockingWith(c, rb), ['Clan Tremere : interdit pour la secte Camarilla']);
      expect(c.toMap(), before);
    });

    test('rareté lue pour la secte de la fiche', () {
      final rb = Rulebook({'clans': tweak('clans', 'Lasombra', (e) => e.data['rarity'] = {'Camarilla': 'rare', 'Sabbat': 'common'})});
      final c = valid();
      setClan(c, 'Lasombra', rb: rb);
      expect(budgetOf(c, rb: rb).merits, 4);
      c.sect = 'Sabbat';
      expect(budgetOf(c, rb: rb).merits, 0);
      c.sect = 'Anarchs';
      expect(budgetOf(c, rb: rb).merits, 4, reason: 'secte absente : celle par défaut');
    });

    test('atout de lignée compté une seule fois', () {
      final rb = Rulebook({
        'clans': tweak('clans', 'Tremere', (e) => e.data['bloodlines'] = [
              {'name': 'Telyav', 'merit': 'Lignée Telyav'},
            ]),
        'merits': [RuleEntry(name: 'Lignée Telyav', data: {'cost': 2, 'atCreation': true})],
      });
      final c = valid()..lineage = 'telyav';
      expect(budgetOf(c, rb: rb).merits, 2);
      c.merits = [Trait('Lignée Telyav', 2)];
      expect(budgetOf(c, rb: rb).merits, 2);
    });

    test('sectes jouables', () {
      final rb = Rulebook({
        'sects': [
          RuleEntry(name: 'Camarilla', data: {'playable': 'all', 'isDefault': true}),
          RuleEntry(name: 'Sabbat', data: {'playable': 'npcOnly'}),
          RuleEntry(name: 'Anarchs', data: {'playable': 'pjOnApproval'}),
        ],
      });
      expect(blockingWith(valid()..sect = 'Sabbat', rb), ['Secte Sabbat : réservée aux PNJ']);
      expect(warnings(valid()..sect = 'Anarchs', rb), contains('Secte Anarchs : PJ sur accord du conte'));
      expect(blockingWith(valid()..sect = 'Sabbat'..kind = CharacterKind.pnj, rb), isEmpty);
    });

    test('domaines selon la compétence', () {
      final multiple = Rulebook({'skills': tweak('skills', 'Occultisme', (e) => e.data['domainMode'] = 'multiple')});
      expect(blockingWith(valid(), multiple), ['Précisez le domaine de Occultisme']);
      final optional = Rulebook({'skills': tweak('skills', 'Occultisme', (e) => e.data['domainMode'] = 'optional')});
      expect(blockingWith(valid(), optional), isEmpty);
    });

    test('historiques : précision, plafond, barème', () {
      final backgrounds = tweak('backgrounds', 'Ressources', (e) => e.data.addAll({'ask': 'monthly', 'scale': ['500 €', '1 000 €']}));
      backgrounds.firstWhere((e) => e.name == 'Alliés').data['cap'] = 2;
      final rb = Rulebook({'backgrounds': backgrounds});
      final c = valid();
      expect(blockingWith(c, rb), ['Alliés : 2 au plus']);
      expect(warnings(c, rb), contains('Ressources : montant hors barème, à valider par le conte'));
      final resources = c.backgrounds.firstWhere((t) => t.name == 'Ressources');
      resources.note = '1 000 €';
      expect(warnings(c, rb), isNot(contains('Ressources : montant hors barème, à valider par le conte')));
      resources.note = null;
      expect(blockingWith(c, rb), contains('Précisez Ressources'));
    });

    test('générations : coûts, Sang et plafonds du référentiel', () {
      final rb = Rulebook({
        'generations': [
          RuleEntry(name: 'Neonate', data: {'rank': 'neonate', 'numbers': ['12'], 'blood': 11, 'traitFactor': 2, 'outOfClanFactor': 5, 'skillCap': 4}),
        ],
      });
      final c = valid();
      applyDerived(c, rb: rb);
      expect((c.blood, c.bloodPerTurn, c.genNumber), (11, 1, 12));
      expect(purchaseCost(c, Buy.skill, 'Informatique', 3, rb: rb), 6);
      expect(addPurchase(c, Buy.discipline, 'Présence', rb: rb), isNull);
      expect(c.purchases.last.cost, 5);
      expect(addPurchase(c, Buy.skill, 'Occultisme', rb: rb), 'Plafond atteint (4).');
      final other = valid()..genNumber = 13;
      applyDerived(other, rb: rb);
      expect(other.genNumber, isNull);
    });

    test('valeurs de création ; fiche soumise avant le changement (Review Focus 3)', () {
      const values = CreationValues(attributeSlots: [8, 5, 3], startingXp: 35, defaultBonus: 2, maxSetAside: 3);
      const rb = Rulebook({}, values);
      expect(blockingWith(valid(), rb), contains('Valeurs calculées incohérentes : réenregistrez la fiche depuis l’application'));
      final c = valid();
      applyDerived(c, rb: rb);
      final b = budgetOf(c, rb: rb);
      expect((b.total, b.setAside, c.xpInitial), (40, 3, 40));
      expect(c.attributes[AttrCategory.mental]!.value, 8);
      expect(creationChecks(c, rb: rb).map((k) => k.text), contains('Attributs répartis 8 / 5 / 3, un focus chacun'));
      expect(blockingWith(c, rb), isEmpty);
    });

    test('disciplines communes lues dans le référentiel', () {
      final rb = Rulebook({'disciplines': tweak('disciplines', 'Présence', (e) => e.data['common'] = false)});
      expect(addPurchase(valid(), Buy.discipline, 'Présence', rb: rb), contains('communes'));
    });
  });
}
