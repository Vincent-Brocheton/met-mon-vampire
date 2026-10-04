import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/transformations.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/places/place_rules.dart';
import 'package:portail_met/rules/creation_rules.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servant_rules.dart';
import 'package:portail_met/xp/xp_rules.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show mila;
import '../places/place_rules_test.dart' as places show rb;
import '../servants/servant_rules_test.dart' as servants show isaure, rb;

/// Relecture contre les livres MET (Base, Volume 2 n° 1).
void main() {
  test('lieux : la qualité surnaturelle compte dans le maximum (V2 p. 131)', () {
    final p = Place(name: 'Ruelle', qualities: [PlaceQuality('Artistique'), PlaceQuality('Hanté')]);
    expect(qualityCount(p, places.rb), 2);
    expect(placeWarnings(p, places.rb), ['2 qualités sur 1 : trop pour un lieu standard de rang 1']);
  });

  test('serviteur libéré : indisponible deux semaines par point (Base p. 104)', () {
    expect(unavailableUntil(DateTime(2026, 10, 1), 3), DateTime(2026, 11, 12));
    expect(unavailableUntil(DateTime(2026, 10, 1), 1), DateTime(2026, 10, 15));
  });

  test('serviteur humain : une seule spécialité de discipline (Base p. 105)', () {
    final c = servants.isaure();
    final f = ServantFile(id: 'x-s2', kind: 'human', name: 'Mila', specialties: ['Auspex', 'Présence'], version: 1, holderPlayers: ['u1']);
    expect(servantWarnings(f, servants.rb, entry: Servant('x-s2', 'Mila', ServantKind.human, 2), domitor: c, now: DateTime(2026, 10, 1)),
        ['Une seule spécialité de discipline pour un serviteur']);
  });

  test('goule : disciplines du clan du domitor seulement, points restants plus tard (Base p. 296)', () {
    final d = sample()..disciplines.add(Discipline('Domination', 2));
    expect([for (final x in GhoulState.of(d).domitorDisciplines) x.name], ['Auspex'], reason: 'Domination est hors clan pour le domitor');
    final g = mila();
    setGhoulDiscipline(g, 'Auspex', 3);
    expect([for (final k in creationChecks(g)) if (k.step == 7) (k.level, k.text)],
        [(CheckLevel.warn, 'Disciplines de goule : 3 points sur 5, le reste pourra être placé plus tard')]);
  });

  test('goule : elle paie la rareté du clan de son domitor (Base p. 296)', () {
    final g = mila()..sect = 'Camarilla';
    g.ghoul!.domitorClan = 'Assamites';
    expect(budgetOf(g).merits, 2);
    expect(meritPoints(g, const []), 2);
  });

  test('étreinte d’une goule : Génération achetée, rareté remboursée ou payée (Base p. 297-298)', () {
    final g = mila()
      ..status = CharacterStatus.active
      ..sect = 'Camarilla'
      ..xpInitial = 30
      ..xpSpent = 10;
    g.ghoul!.domitorClan = 'Assamites';
    final neonate = embraceGhoul(g, sire: sample(), genNumber: 11).after!;
    expect(neonate.xpSpent, 10 + 1 - 2, reason: 'Génération ● : 1 XP ; Assamites (2) remboursé, Toreador commun');
    final ancilla = embraceGhoul(g, sire: sample()..genNumber = 9, genNumber: 10).after!;
    expect(ancilla.xpSpent, 10 + 6 - 2, reason: 'Génération ●● d’un Ancilla : 1×2 + 2×2');
  });

  test('génération en dessous de celle du rang : handicap Génération inférieure (Base p. 263)', () {
    expect(lesserGenerationPoints(11), 0);
    expect(lesserGenerationPoints(12), 1);
    expect(lesserGenerationPoints(13), 2);
    expect(lesserGenerationPoints(10), 1);
    expect(lesserGenerationPoints(8), 0);
    final pj = embracedDraft('Paul', playerUid: 'u2', playerName: 'Inès T.', sire: sample(), genNumber: 11).after!..genNumber = 12;
    expect([for (final k in creationChecks(pj)) if (k.step == 6) k.text], contains('Génération 12e : handicap Génération inférieure (1 point) attendu'));
    pj.flaws.add(Trait('Génération inférieure', 1));
    expect([for (final k in creationChecks(pj)) if (k.step == 6) k.text], isNot(contains(startsWith('Génération 12e'))));
  });
}
