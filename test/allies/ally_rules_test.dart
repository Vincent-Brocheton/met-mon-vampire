import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/allies/ally_rules.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'allies': [
    RuleEntry(name: 'Contact', data: {'condition': 'Tout niveau'}),
    RuleEntry(name: 'Nocturne', data: {'condition': 'Tout niveau'}),
    RuleEntry(name: 'Double expertise', data: {'condition': 'Tout niveau'}),
    RuleEntry(name: 'Influent', data: {'condition': '1 à 3 fois'}),
    RuleEntry(name: 'Expert', data: {'condition': 'Si Influent'}),
    RuleEntry(name: 'Remplaçable', data: {'condition': 'Si Influent'}),
    RuleEntry(name: 'Sécurité', data: {'condition': 'Si Influent'}),
    RuleEntry(name: 'Interdit', state: RuleState.forbidden),
  ],
}, const CreationValues(), {
  'allies': {'maxLevel': 5},
});

/// Me Castan, allié de niveau 4 avec Influence 4 : il reste 2 spécialisations.
Ally castan() => Ally('x-a1', 'Me Hervé Castan, notaire',
    level: 4, type: 'Gotha', domain: 'Finance & Industrie', influence: 4, specialties: ['Expert', 'Sécurité']);

List<String> errors(Ally a) => allyChecks(a, rb);

void main() {
  test('référentiel : spécialisations sans Influent, types et domaines par défaut, réglages', () {
    expect(allySpecialtyOptions(rb), ['Contact', 'Nocturne', 'Double expertise', 'Expert', 'Remplaçable', 'Sécurité']);
    expect(needsInfluence(rb, 'Expert'), isTrue);
    expect(needsInfluence(rb, 'Contact'), isFalse);
    expect(allyTypes(rb), ['Gotha', 'Pègre']);
    expect(allyDomains(rb).length, 10);
    expect(allyMaxLevel(rb), 5);
    final own = Rulebook(const {}, const CreationValues(), {
      'allies': {'types': ['Gotha'], 'domains': ['Police'], 'maxLevel': 3},
    });
    expect(allyTypes(own), ['Gotha']);
    expect(allyDomains(own), ['Police']);
    expect(allyMaxLevel(own), 3);
    expect(allySpecialtyOptions(const Rulebook()), contains('Contact'));
  });

  test('allié valide : aucune erreur, aide affichée', () {
    expect(errors(castan()), isEmpty);
    expect(allySummary(castan(), rb), 'Influence 4 prend 2 spécialisations sur 4 : il en reste 2. Retour après usage : 4 mois.');
    expect(allySummary(Ally('', 'X', level: 1), rb), 'Sans Influence : 1 spécialisation à choisir. Retour après usage : 1 mois.');
  });

  test('contrôles : nom, niveau, Influence, nombre (Review Focus 1)', () {
    expect(errors(castan()..name = ' '), ['Nom obligatoire']);
    expect(errors(castan()..level = 6), contains('Niveau de 1 à 5'));
    expect(errors(castan()..influence = 3), contains('Influence : 2, 4 ou 5'));
    expect(errors(castan()
      ..level = 2
      ..specialties = []), contains('Influence 4 au-delà du niveau de l’allié'));
    expect(errors(castan()..specialties = ['Expert']), ['2 spécialisations attendues pour un allié de niveau 4, 1 choisie']);
  });

  test('contrôles : condition, doublon, hors référentiel, type et domaine', () {
    Ally one(List<String> s, {int level = 1}) => Ally('', 'X', level: level, type: 'Pègre', domain: 'Crime', specialties: s);
    expect(errors(one(['Expert'])), ['Expert demande un allié influent']);
    expect(errors(one(['Contact', 'contact'], level: 2)), ['contact en double']);
    expect(errors(one(['Interdit'])), ['Interdit : pas une spécialisation d’allié']);
    expect(errors(one(['Influent'])), ['Influent : pas une spécialisation d’allié']);
    expect(errors(one(['Contact'])
      ..type = 'Autre'
      ..domain = 'Lune'), ['Type hors liste', 'Domaine hors liste']);
  });

  test('retour après usage : niveau en mois, 2 mois si Remplaçable ; état', () {
    final used = DateTime(2026, 9, 20);
    expect(returnDate(castan(), used), DateTime(2027, 1, 20));
    final quick = Ally('', 'Y', level: 3, influence: 2, specialties: ['Remplaçable', 'Contact']);
    expect(returnMonths(quick), 2);
    expect(returnDate(quick, used), DateTime(2026, 11, 20));
    final now = DateTime(2026, 10, 1);
    expect(allyStatus(pending: true, returnAt: null, now: now), 'En attente du conte');
    expect(allyStatus(pending: false, returnAt: DateTime(2026, 12, 20), now: now), 'De retour le 20 déc.');
    expect(allyStatus(pending: false, returnAt: DateTime(2026, 9, 1), now: now), 'Disponible');
  });

  test('conversion : niveau borné, historique diminué puis retiré (Review Focus 4)', () {
    final c = sample()..backgrounds = [Trait('Contacts', 3), Trait('Ressources', 3)];
    expect([for (final t in legacyAllies(c)) t.name], ['Contacts']);
    final big = Ally('x-a9', 'Dédé', level: 4, type: 'Pègre', domain: 'Crime');
    expect(conversionError(c, 'Contacts', big), 'Niveau 4 au-delà de l’historique Contacts (3)');
    final first = convertLegacy(c, 'Contacts', Ally('x-a2', 'Dédé', level: 2, type: 'Pègre', domain: 'Crime'));
    expect(first.backgrounds.firstWhere((t) => t.name == 'Contacts').level, 1);
    expect(first.allies.single.name, 'Dédé');
    final second = convertLegacy(first, 'Contacts', Ally('x-a3', 'Lulu', level: 1, type: 'Pègre', domain: 'Rue & Transport'));
    expect(second.backgrounds.map((t) => t.name), ['Ressources']);
    expect(second.allies.length, 2);
    expect(c.backgrounds.length, 2, reason: 'la fiche d’origine ne change pas');
  });

  test('fiche : aller-retour, clé tardive, changements tracés', () {
    final c = sample()..allies = [castan()];
    expect(Character.fromMap('x', c.toMap()).allies.single.toMap(), castan().toMap());
    expect(sample().toMap().containsKey('allies'), isFalse);
    expect(sample().laterKeys().containsKey('allies'), isTrue);
    expect(newAllyId('x'), startsWith('x-a'));
    expect(describeChanges(sample(), c), contains('+ Allié Me Hervé Castan, notaire ●●●●'));
    final up = c.clone()..allies.single.level = 5;
    expect(describeChanges(c, up), contains('Allié Me Hervé Castan, notaire ●●●● → ●●●●●'));
    final other = c.clone()..allies.single.specialties = ['Expert', 'Remplaçable'];
    expect(describeChanges(c, other), contains('Allié Me Hervé Castan, notaire modifié'));
    expect(describeChanges(c, sample()), contains('− Allié Me Hervé Castan, notaire ●●●●'));
  });
}
