import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/places/place_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import '../characters/character_test.dart' show sample;

final rb = Rulebook({
  'placeQualities': [
    RuleEntry(name: 'Artistique', data: {'family': 'standard'}),
    RuleEntry(name: 'Luxe', data: {'family': 'standard', 'placeTypes': ['prestige', 'iconic']}),
    RuleEntry(name: 'Mythique', data: {'family': 'iconic'}),
    RuleEntry(name: 'Hanté', data: {'family': 'supernatural'}),
    RuleEntry(name: 'Festin', data: {'family': 'supernatural'}),
    RuleEntry(name: 'Compromis', data: {'family': 'negative', 'repeatable': 3}),
    RuleEntry(name: 'Élysée', data: {'family': 'elysium'}),
    RuleEntry(name: 'Abandonné', state: RuleState.forbidden, data: {'family': 'standard'}),
    RuleEntry(name: 'Maudit', state: RuleState.forbidden, data: {'family': 'negative'}),
  ],
});

Place opera() => Place(
      id: 'p1',
      name: 'Opéra municipal',
      type: PlaceType.prestige,
      rank: 2,
      qualities: [PlaceQuality('Artistique'), PlaceQuality('Luxe'), PlaceQuality('Hanté'), PlaceQuality('Compromis', 2), PlaceQuality('Élysée')],
      holders: [const PlaceHolder('x', 'Isaure de Valcourt')],
      holderPlayers: ['u1'],
      known: 'Une salle prestigieuse.',
      public: true,
    );

void main() {
  test('maximum, quête, infiltration, compte', () {
    expect(maxQualities(PlaceType.standard, 3), 3);
    expect(maxQualities(PlaceType.prestige, 3), 6);
    expect(maxQualities(PlaceType.iconic, 2), 4);
    expect(questText(PlaceType.standard, 2), 'Quête simple, difficulté 2');
    expect(questText(PlaceType.prestige, 4), 'Quête complexe, difficulté 4');
    expect(questText(PlaceType.iconic, 5), 'Quête héroïque');
    expect(infiltration(4), 20);
    expect(qualityCount(opera(), rb), 2, reason: 'surnaturelle, négative et Élysée hors du maximum');
    expect(negativesText(opera(), rb), 'Compromis ×2');
  });

  test('aller-retour, résumé public, copie indépendante', () {
    final p = opera();
    expect(Place.fromMap('p1', p.toMap()).toMap(), p.toMap());
    expect(p.toMap()['holderIds'], ['x']);
    expect(p.publicMap(), {'name': 'Opéra municipal', 'type': 'prestige', 'known': 'Une salle prestigieuse.'});
    p.copy().qualities.first.count = 3;
    expect(p.qualities.first.count, 1);
  });

  test('avertissements de qualités (Review Focus 4)', () {
    final p = opera()
      ..type = PlaceType.standard
      ..rank = 1
      ..qualities.addAll([PlaceQuality('Mythique'), PlaceQuality('Festin'), PlaceQuality('Abandonné'), PlaceQuality('Disparue')]);
    p.qualities.firstWhere((q) => q.name == 'Compromis').count = 4;
    expect(placeWarnings(p, rb), [
      '5 qualités sur 1 : trop pour un lieu standard de rang 1',
      'Luxe : non permise pour un lieu standard',
      'Compromis : 4 fois, 3 au plus',
      'Mythique : qualité iconique, réservée aux lieux iconiques',
      'Abandonné est interdite dans la chronique',
      'Disparue : hors du référentiel',
      'Une seule qualité surnaturelle par lieu',
    ]);
    expect(placeWarnings(opera(), rb), isEmpty);
  });

  test('limite de contrôle avec Serviteurs, fiche retirée, joueur changé (Review Focus 5)', () {
    final isaure = sample();
    expect(controlLimit(isaure), 5);
    final others = [for (var i = 0; i < 5; i++) Place(id: 'o$i', name: 'Lieu $i', holders: [const PlaceHolder('x', 'Isaure de Valcourt')])];
    expect(placeWarnings(opera(), rb, places: others, characters: [isaure]), ['Isaure de Valcourt contrôle 6 lieux sur 5 (5 + Serviteurs)']);
    isaure.servants.add(Servant('x-s1', 'Rex', ServantKind.animal, 1));
    expect(placeWarnings(opera(), rb, places: others, characters: [isaure]), isEmpty);
    isaure.status = CharacterStatus.retired;
    expect(placeWarnings(opera(), rb, characters: [isaure]), ['Isaure de Valcourt est une fiche retirée ou morte']);
    expect(playersOf(opera().holders, [isaure]), ['u1']);
    isaure.playerUid = 'u2';
    expect(staleAccess(opera(), [isaure]), ['Le joueur de Isaure de Valcourt a changé : enregistrez pour mettre à jour l’accès']);
    isaure.playerUid = null;
    expect(staleAccess(opera(), [isaure]), ['Un ancien joueur a encore accès : enregistrez pour le retirer'], reason: 'revue : fiche sans joueur');
    isaure.playerUid = 'u1';
    expect(staleAccess(opera(), [isaure]), isEmpty);
  });

  test('résumé des changements', () {
    final a = opera();
    final b = a.copy()
      ..name = 'Grand Opéra'
      ..rank = 3
      ..holders = [const PlaceHolder('y', 'Lucie Arnaud')]
      ..public = false
      ..known = 'Autre chose';
    b.qualities
      ..removeWhere((q) => q.name == 'Luxe')
      ..add(PlaceQuality('Mythique'));
    b.qualities.firstWhere((q) => q.name == 'Compromis').count = 1;
    expect(placeChanges(a, b), [
      'Nom : Opéra municipal → Grand Opéra',
      'Rang 2 → 3',
      '+ Attribué à Lucie Arnaud',
      '− Retiré à Isaure de Valcourt',
      '+ Qualité Mythique',
      '− Qualité Luxe',
      'Compromis : ×2 → ×1',
      'Plus connu de tous',
      'Ce qui s’en sait modifié',
    ]);
  });
}
