import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
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

  test('attribut 3 XP, Humanité niveau × 2', () {
    final c = valid();
    expect(addPurchase(c, Buy.attribute, AttrCategory.physical.name), isNull);
    expect(addPurchase(c, Buy.humanity, humanityName), isNull);
    applyDerived(c);
    expect(c.attributes[AttrCategory.physical]!.value, 4);
    expect(c.humanity, 6);
    expect(budgetOf(c).purchases, 3 + 12);
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
    expect(blocking(c), contains('Auspex hors clan : uniquement par achat'));
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
}
