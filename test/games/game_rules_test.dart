import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/game_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';

import '../characters/character_test.dart' show sample;

/// Partie de test : samedi 3 octobre, gel le mardi 29 septembre à 20h, levée le dimanche 4 octobre à 6h.
/// [year] 2099 pour les écrans qui lisent l'heure de l'appareil (le 3 octobre 2099 est aussi un samedi).
Game frozenGame({String id = 'g2', int year = 2026, List<String> sheetIds = const ['x'], DateTime? liftedAt}) => Game(
      id: id,
      date: DateTime(year, 10, 3),
      frozenAt: DateTime(year, 9, 29, 20),
      until: DateTime(year, 10, 4, 6),
      liftedAt: liftedAt,
      byUid: 'lea',
      sheetIds: sheetIds,
    );

Character npc(String id, {CharacterStatus status = CharacterStatus.active}) =>
    Character(id: id, name: 'Octave Marchetti', kind: CharacterKind.pnj, status: status);

void main() {
  test('partie et version figée lues depuis Firestore', () {
    final g = Game.fromMap('g2', {
      'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'frozenAt': Timestamp.fromDate(DateTime(2026, 9, 29, 20)),
      'until': Timestamp.fromDate(DateTime(2026, 10, 4, 6)),
      'liftedAt': null,
      'liftedByUid': null,
      'byUid': 'lea',
      'sheetIds': ['x', 'n1'],
    });
    expect(g.date, DateTime(2026, 10, 3));
    expect(g.until, DateTime(2026, 10, 4, 6));
    expect(g.liftedAt, isNull);
    expect(g.sheetIds, ['x', 'n1']);
    final s = FrozenSheet.fromMap('x', 'g2', {
      'sheet': sample().toMap(),
      'version': 4,
      'gameDate': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'at': null,
      'byUid': 'lea',
      'reason': null,
    });
    expect(s.character.name, 'Isaure de Valcourt');
    expect(s.character.id, 'x');
    expect(s.version, 4);
    expect(s.gameDate, DateTime(2026, 10, 3));
    expect(s.reason, isNull);
  });

  test('fiches à figer : PJ actifs et PNJ au prêt actif seulement', () {
    final now = DateTime(2026, 10, 2);
    NpcLoan loan(String id, {DateTime? until, DateTime? revokedAt}) =>
        NpcLoan(characterId: id, from: DateTime(2026, 10, 1), until: until ?? DateTime(2026, 10, 10), revokedAt: revokedAt);
    final sheets = [
      sample(),
      Character(id: 'd', name: 'Brouillon', kind: CharacterKind.pj, playerUid: 'u2'),
      Character.fromMap('m', {...sample().toMap(), 'status': 'dead'}),
      npc('n1'),
      npc('n2'),
      npc('n3'),
      npc('n4'),
      npc('n5', status: CharacterStatus.dead),
    ];
    final loans = [
      loan('n1'),
      loan('n3', until: DateTime(2026, 10, 1, 12)),
      loan('n4', revokedAt: DateTime(2026, 10, 1, 13)),
      loan('n5'),
    ];
    expect([for (final c in sheetsToFreeze(sheets, loans, now)) c.id], ['x', 'n1']);
  });

  test('gel en cours : avant la levée prévue, sans levée anticipée (Review Focus 3)', () {
    final g = frozenGame();
    expect(isRunning(g, DateTime(2026, 10, 4, 5, 59)), isTrue);
    expect(isRunning(g, DateTime(2026, 10, 4, 6)), isFalse);
    expect(isRunning(frozenGame(liftedAt: DateTime(2026, 10, 1)), DateTime(2026, 10, 2)), isFalse);
  });

  test('fiche figée : dans le gel en cours seulement', () {
    final now = DateTime(2026, 10, 2);
    final games = [frozenGame(id: 'g1', sheetIds: const ['y'], liftedAt: DateTime(2026, 10, 1)), frozenGame()];
    expect(frozenBy(games, 'x', now)?.id, 'g2');
    expect(frozenBy(games, 'y', now), isNull);
    expect(frozenBy(games, 'x', DateTime(2026, 10, 5)), isNull);
    expect(runningGame(games, now)?.id, 'g2');
    expect(runningGame(games, DateTime(2026, 10, 5)), isNull);
  });

  test('gel précédent : le dernier figé avant celui-ci', () {
    final a = Game(id: 'a', date: DateTime(2026, 7, 4), frozenAt: DateTime(2026, 7, 1), until: DateTime(2026, 7, 5));
    final b = Game(id: 'b', date: DateTime(2026, 8, 29), frozenAt: DateTime(2026, 8, 28, 20), until: DateTime(2026, 8, 30, 6));
    final c = frozenGame();
    expect(previousGame([c, b, a], c)?.id, 'b');
    expect(previousGame([a, c, b], c)?.id, 'b');
    expect(previousGame([c, b, a], a), isNull);
  });

  test('levée : par défaut le lendemain à 6h, sinon la saisie', () {
    final d = DateTime(2026, 10, 3);
    expect(defaultUntil(d), DateTime(2026, 10, 4, 6));
    expect(defaultUntil(DateTime(2026, 10, 31)), DateTime(2026, 11, 1, 6));
    expect(untilOf(d, '', ''), DateTime(2026, 10, 4, 6));
    expect(untilOf(d, '05/10/2026', ''), DateTime(2026, 10, 5, 6));
    expect(untilOf(d, '', '20h30'), DateTime(2026, 10, 4, 20, 30));
    expect(untilOf(d, '05/10/2026', '02:15'), DateTime(2026, 10, 5, 2, 15));
    expect(untilOf(d, '32/10/2026', ''), isNull);
    expect(untilOf(d, '', '25:00'), isNull);
  });

  test('heure : formes acceptées', () {
    expect(parseTime('6'), (6, 0));
    expect(parseTime('06:00'), (6, 0));
    expect(parseTime('20h'), (20, 0));
    expect(parseTime('20h30'), (20, 30));
    expect(parseTime(' 7:05 '), (7, 5));
    expect(parseTime('24:00'), isNull);
    expect(parseTime('7:60'), isNull);
    expect(parseTime('midi'), isNull);
  });

  test('nouveau gel : contrôles du formulaire', () {
    final now = DateTime(2026, 10, 1, 12);
    expect(freezePlan('xx', '', '', now).error, 'Date de partie invalide');
    expect(freezePlan('03/10/2026', 'demain', '', now).error, 'Levée invalide');
    expect(freezePlan('03/10/2026', '30/09/2026', '', now).error, 'La levée doit être dans le futur.');
    final ok = freezePlan('03/10/2026', '', '', now);
    expect(ok.error, isNull);
    expect(ok.date, DateTime(2026, 10, 3));
    expect(ok.until, DateTime(2026, 10, 4, 6));
  });

  test('changements depuis le gel précédent', () {
    final a = sample();
    expect(changeCount(a, sample()), 0);
    expect(changeLabel(changeCount(a, sample())), 'Aucun');
    expect(changeLabel(changeCount(a, sample()..humanity = 5)), '1 changement');
    expect(changeLabel(changeCount(a, sample()
      ..humanity = 5
      ..willpower = 4)), '2 changements');
    expect(changeCount(null, a), isNull);
    expect(changeLabel(null), 'Première version figée');
  });

  test('textes du gel', () {
    final g = frozenGame();
    expect(gameTitle(g), 'Gel en cours · partie du samedi 3 octobre');
    expect(gameSpanText(g), 'Depuis le mardi 29 sept. à 20h, jusqu’au dimanche 4 oct. à 6h');
    expect(playerFreezeText(g), 'Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct.');
    expect(staffFreezeText(g), 'Figée pour la partie du samedi 3 oct., jusqu’au dimanche 4 oct. à 6h : son XP ne peut pas changer.');
    expect(frozenUntilText(g), 'Fiche figée jusqu’au 4 oct.');
    expect(hourText(DateTime(2026, 10, 4, 20, 5)), '20h05');
    expect(shortDay(DateTime(2026, 10, 3)), 'samedi 3 oct.');
    expect(dayAndHour(DateTime(2026, 10, 4, 6)), 'dimanche 4 oct. à 6h');
    expect(slashDay(DateTime(2026, 10, 4)), '04/10/2026');
    // « mai » n'a pas de point d'abréviation : la phrase en reçoit un.
    final may = Game(date: DateTime(2026, 5, 2), frozenAt: DateTime(2026, 4, 28), until: DateTime(2026, 5, 3, 6));
    expect(playerFreezeText(may), 'Fiche figée pour la partie du samedi 2 mai. Vos demandes restent en file et seront traitées à partir du 3 mai.');
  });

  test('nombre de fiches à figer, gain retenu', () {
    final sheets = [for (var i = 0; i < 38; i++) sample(), for (var i = 0; i < 4; i++) npc('n$i')];
    expect(freezeCountText(sheets), '42 fiches seront figées : 38 PJ actifs et 4 PNJ confiés.');
    expect(freezeCountText([sample()]), '1 fiche sera figée : 1 PJ actif et 0 PNJ confié.');
    expect(frozenGainText(1), '1 fiche figée : son gain sera versé après le gel.');
    expect(frozenGainText(3), '3 fiches figées : leur gain sera versé après le gel.');
  });
}
