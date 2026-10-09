import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/freeze_screen.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'game_rules_test.dart' show frozenGame, npc;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);
  const zoe = AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur);
  final now = DateTime(2026, 10, 1, 12);

  // Gel précédent, levé depuis longtemps : partie du samedi 29 août, figée le vendredi 28 à 20h.
  final g1 = Game(id: 'g1', date: DateTime(2026, 8, 29), frozenAt: DateTime(2026, 8, 28, 20), until: DateTime(2026, 8, 30, 6), byUid: 'lea', sheetIds: const ['x', 'y']);
  final g2 = frozenGame(sheetIds: const ['x', 'y', 'n1']);
  Character bastien() => Character.fromMap('y', {...sample().toMap(), 'name': 'Bastien Roche', 'playerUid': 'u2', 'playerName': 'Karim L.'});
  FrozenSheet snap(Game g, Character c) => FrozenSheet(characterId: c.id, gameId: g.id, sheet: c.toMap(), version: c.version, gameDate: g.date);
  final loan = NpcLoan(characterId: 'n1', characterName: 'Octave Marchetti', playerUid: 'u1', playerName: 'Camille R.', from: DateTime(2026, 9, 1), until: DateTime(2026, 10, 10));
  XpRequest auspex() => XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)],
      );

  // Gel en cours : Isaure a changé depuis le gel précédent, Bastien non, Octave est figé pour la première fois.
  // La fiche actuelle d'Isaure (version 5) a changé depuis sa version figée (version 4).
  final current = [snap(g2, sample()..humanity = 5), snap(g2, bastien()), snap(g2, npc('n1'))];
  final before = [snap(g1, sample()), snap(g1, bastien())];

  Future<FakeGamesRepository> pump(
    WidgetTester tester, {
    AppUser me = lea,
    List<Game> games = const [],
    List<Character>? chars,
    List<NpcLoan> loans = const [],
    List<XpRequest> requests = const [],
    Size size = const Size(1440, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeGamesRepository();
    await tester.pumpWidget(ProviderScope(
      // Clé neuve : un second pump dans le même test repart d'une portée vierge.
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(me)),
        gamesRepositoryProvider.overrideWith((ref) => repo),
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        allCharactersProvider.overrideWith((ref) => Stream.value(chars ?? [sample()..version = 5, bastien(), npc('n1')])),
        allNpcLoansProvider.overrideWith((ref) => Stream.value(loans)),
        openRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        gameSnapshotsProvider('g2', g2.date).overrideWith((ref) => Stream.value(current)),
        gameSnapshotsProvider('g1', g1.date).overrideWith((ref) => Stream.value(before)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: FreezeScreen(now: () => now))),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('sans gel : compte des fiches, levée prévue, figer', (tester) async {
    final repo = await pump(tester, games: [g1], loans: [loan]);
    expect(find.text('3 fiches seront figées : 2 PJ actifs et 1 PNJ confié.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('freeze-date')), '03/10/2026');
    await tester.pump();
    expect(find.text('Levée prévue : dimanche 4 oct. à 6h'), findsOneWidget);
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Figer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['freeze']);
    expect(repo.lastSheetIds, ['x', 'y', 'n1']);
    expect(repo.lastDate, DateTime(2026, 10, 3));
    expect(repo.lastUntil, DateTime(2026, 10, 4, 6));
  });

  testWidgets('sans gel : date invalide, levée passée, refus', (tester) async {
    final repo = await pump(tester, games: [g1]);
    expect(find.text('2 fiches seront figées : 2 PJ actifs et 0 PNJ confié.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('freeze-date')), 'xx');
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    expect(find.text('Date de partie invalide'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('freeze-date')), '03/10/2026');
    await tester.enterText(find.byKey(const Key('freeze-until-day')), '30/09/2026');
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    expect(find.text('La levée doit être dans le futur.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byKey(const Key('freeze-until-day')), '');
    repo.error = Exception('refusé');
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Figer'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('freeze-date'))).controller!.text, '03/10/2026');
  });

  testWidgets('gel dépassé : le formulaire revient (Review Focus 3)', (tester) async {
    final past = Game(id: 'g3', date: DateTime(2026, 9, 26), frozenAt: DateTime(2026, 9, 22), until: DateTime(2026, 9, 27, 6), sheetIds: const ['x']);
    await pump(tester, games: [past]);
    expect(find.text('Figer maintenant'), findsOneWidget);
    expect(find.text('Lever le gel'), findsNothing);
  });

  testWidgets('gel en cours : bandeau, tableau, comparaison, filtre', (tester) async {
    await pump(tester, games: [g1, g2], requests: [auspex()]);
    expect(find.text('Gel en cours · partie du samedi 3 octobre'), findsOneWidget);
    expect(find.text('Depuis le mardi 29 sept. à 20h, jusqu’au dimanche 4 oct. à 6h'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('kpi-sheets'))).data, '3');
    expect(tester.widget<Text>(find.byKey(const Key('kpi-requests'))).data, '1');
    expect(find.text('Depuis le gel du 28 août'), findsOneWidget);
    expect(find.text('1 changement'), findsOneWidget);
    expect(find.text('Aucun'), findsOneWidget);
    expect(find.text('Première version figée'), findsOneWidget);
    expect(find.text('Auspex ●●●● · 12 XP'), findsOneWidget);
    expect(find.text('Humanité 0 → 5'), findsOneWidget);
    await tester.tap(find.text('Modifiées'));
    await tester.pump();
    expect(find.text('Bastien Roche · PJ'), findsNothing);
    expect(find.text('Isaure de Valcourt · PJ'), findsOneWidget);
    expect(find.text('Octave Marchetti · PNJ'), findsOneWidget);
  });

  testWidgets('correction urgente : motif obligatoire, puis version figée mise à jour', (tester) async {
    final repo = await pump(tester, games: [g1, g2]);
    await tester.tap(find.text('Correction urgente…'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mettre à jour la version figée')).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('freeze-reason')), 'Erreur de saisie');
    await tester.pump();
    await tester.tap(find.text('Mettre à jour la version figée'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['correct:g2:x']);
    expect(repo.lastReason, 'Erreur de saisie');
    await tester.tap(find.byKey(const Key('freeze-row-y')));
    await tester.pump();
    expect(find.text('Aucun changement à reporter'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Correction urgente…')).onPressed, isNull);
  });

  testWidgets('sa propre fiche : pas de correction (Review Focus 5)', (tester) async {
    await pump(tester, games: [g1, g2], chars: [sample()
      ..version = 5
      ..playerUid = 'lea', bastien(), npc('n1')]);
    expect(find.text('Votre propre fiche : un autre conteur doit la corriger.'), findsOneWidget);
    expect(find.text('Correction urgente…'), findsNothing);
  });

  testWidgets('lever le gel', (tester) async {
    final repo = await pump(tester, games: [g1, g2]);
    await tester.tap(find.text('Lever le gel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lever'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['lift:g2']);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, me: julien, games: [g1, g2]);
    expect(find.text('Gel en cours · partie du samedi 3 octobre'), findsOneWidget);
    expect(find.text('Lever le gel'), findsNothing);
    expect(find.text('Correction urgente…'), findsNothing);
  });

  testWidgets('narrateur sans gel : rien à figer', (tester) async {
    await pump(tester, me: julien, games: [g1]);
    expect(find.text('Aucun gel en cours.'), findsOneWidget);
    expect(find.text('Figer maintenant'), findsNothing);
  });

  testWidgets('joueur : réservé à l’équipe', (tester) async {
    await pump(tester, me: zoe, games: [g2]);
    expect(find.text('Réservé à l’équipe'), findsOneWidget);
  });

  testWidgets('390 px : formulaire et gel en cours sans débordement', (tester) async {
    await pump(tester, games: [g1], size: const Size(390, 3000));
    expect(tester.takeException(), isNull);
    await pump(tester, games: [g1, g2], requests: [auspex()], size: const Size(390, 3000));
    expect(tester.takeException(), isNull);
  });
}
