import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/item_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

const _all = ['melee', 'ranged', 'armor', 'gear'];

final rb = Rulebook({
  'equipment': [
    RuleEntry(name: 'Précise', data: {'categories': ['melee', 'ranged']}),
    RuleEntry(name: 'Dissimulable', data: {'categories': _all, 'incompatible': ['Brutale']}),
    RuleEntry(name: 'Brutale', data: {'categories': ['melee']}),
    RuleEntry(name: 'Perforante', state: RuleState.approval, data: {'categories': ['ranged']}),
    RuleEntry(name: 'Fer froid', state: RuleState.forbidden, data: {'categories': ['melee']}),
    RuleEntry(name: 'Chef-d’œuvre', data: {'categories': _all, 'outsideLimit': true}),
    RuleEntry(name: 'Sécurisé', data: {'categories': ['gear']}),
  ],
}, const CreationValues(), {
  'equipment': {
    'rules': [
      {'category': 'melee', 'damage': '1 normal', 'hands': 1, 'qualitiesNormal': 2, 'qualitiesCheap': 1},
    ],
  },
});

/// Canne-épée d'Isaure : courante, deux qualités, en jeu.
Item cane() => Item(
      id: 'i1',
      name: 'Canne-épée',
      category: ItemCategory.melee,
      qualities: ['Dissimulable', 'Précise'],
      characterId: 'x',
      characterName: 'Isaure de Valcourt',
      playerUid: 'u1',
      description: 'Lame de 60 cm.',
      version: 1,
    );

List<String> errors(Item i, {bool byPlayer = false}) => itemChecks(i, rb, byPlayer: byPlayer).errors;

void main() {
  test('règles de base : réglage de la catégorie, sinon 2 et 1', () {
    final melee = categoryRules(rb, ItemCategory.melee);
    expect((melee.damage, melee.hands, melee.max(ItemGrade.normal), melee.max(ItemGrade.cheap)), ('1 normal', 1, 2, 1));
    final gear = categoryRules(rb, ItemCategory.gear);
    expect((gear.damage, gear.hands, gear.normal, gear.cheap), ('', null, 2, 1));
    expect(rulesText(rb, ItemCategory.melee), 'Arme de mêlée : dégâts 1 normal · 1 main');
    expect(rulesText(rb, ItemCategory.gear), '');
  });

  test('qualités proposées : de la catégorie, sans interdites ; hors limite à part', () {
    expect(qualityOptions(rb, ItemCategory.melee), ['Précise', 'Dissimulable', 'Brutale']);
    expect(qualityOptions(rb, ItemCategory.ranged), ['Précise', 'Dissimulable', 'Perforante']);
    expect(extraOptions(rb, ItemCategory.melee), ['Chef-d’œuvre']);
    expect(setQuality(['A', 'B'], 0, null), ['B']);
    expect(setQuality(['A'], 1, 'C'), ['A', 'C']);
    expect(setQuality(['A', 'B'], 1, 'C'), ['A', 'C']);
  });

  test('objet valide : aucune erreur', () {
    final c = itemChecks(cane(), rb);
    expect(c.errors, isEmpty);
    expect(c.warnings, isEmpty);
  });

  test('nombre de qualités selon la gamme ; nom obligatoire', () {
    expect(errors(cane()..qualities = ['Dissimulable', 'Précise', 'Chef-d’œuvre']), contains('2 qualités au plus pour un objet courant'));
    expect(errors(cane()..grade = ItemGrade.cheap), contains('1 qualité au plus pour un objet bon marché'));
    expect(errors(cane()..name = '  '), contains('Nom obligatoire'));
  });

  test('catégorie, interdite, accord du conte, en double', () {
    expect(errors(cane()..category = ItemCategory.gear), ['Précise : pas une qualité de cette catégorie']);
    expect(errors(cane()..qualities = ['Volante']), ['Volante : pas une qualité de cette catégorie']);
    expect(errors(cane()..qualities = ['Fer froid']), ['Fer froid est interdite']);
    expect(errors(cane()..qualities = ['Précise', 'précise']), ['précise en double']);
    final ranged = itemChecks(cane()
      ..category = ItemCategory.ranged
      ..qualities = ['Perforante'], rb);
    expect(ranged.errors, isEmpty);
    expect(ranged.warnings, ['Perforante demande l’accord du conte']);
  });

  test('incompatibles ; hors limite : place, demande du joueur', () {
    expect(errors(cane()..qualities = ['Dissimulable', 'Brutale']), ['Dissimulable et Brutale sont incompatibles']);
    expect(errors(cane()..qualities = ['Chef-d’œuvre']), ['Chef-d’œuvre ne compte pas dans la limite : à poser comme qualité hors limite']);
    expect(errors(cane()..extraQuality = 'Brutale'), [
      'Brutale compte dans la limite : à choisir parmi les qualités de la gamme',
      'Dissimulable et Brutale sont incompatibles',
    ]);
    final masterwork = cane()..extraQuality = 'Chef-d’œuvre';
    expect(errors(masterwork), isEmpty);
    expect(errors(masterwork, byPlayer: true), ['Les qualités hors limite sont posées par le conte']);
  });

  test('aller-retour, textes et changements tracés', () {
    final i = cane()..extraQuality = 'Chef-d’œuvre';
    expect(Item.fromMap('i1', i.toMap()).toMap(), i.toMap());
    expect(itemQualitiesText(i), 'Dissimulable · Précise · Chef-d’œuvre (hors limite)');
    expect(itemQualitiesText(Item()), '—');
    expect(holderText(Item()), 'Personne (réserve du conte)');
    final after = cane()
      ..state = ItemState.confiscated
      ..characterId = ''
      ..characterName = ''
      ..qualities = ['Précise'];
    expect(itemChanges(cane(), after), [
      'Qualités : Dissimulable · Précise → Précise',
      'Porté par : Isaure de Valcourt → Personne (réserve du conte)',
      'État : En jeu → Confisqué',
    ]);
  });
}
