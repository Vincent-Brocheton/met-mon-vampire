import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/devices_repository.dart';
import 'package:portail_met/offline/night.dart';
import 'package:portail_met/offline/night_repository.dart';
import 'package:portail_met/offline/night_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show ghoulState;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  // Gel en cours (partie du samedi 3 octobre 2099, levée le 4 à 6h) ; il est 21h le soir de la partie.
  final game = frozenGame(year: 2099);
  final now = DateTime(2099, 10, 3, 21);

  Character isaure() => sample()
    ..blood = 12
    ..willpower = 6
    ..allies = [Ally('a1', 'Maëlle Garnier', level: 1)];
  FrozenSheet snapshot([Character? c]) => FrozenSheet(characterId: 'x', gameId: game.id, sheet: (c ?? isaure()).toMap(), version: 4, gameDate: game.date);

  Future<(FakeNightRepository, FakeDevicesRepository)> pump(
    WidgetTester tester, {
    List<Game>? games,
    Stream<List<Game>>? gamesStream,
    NightView? view,
    Stream<FrozenSheet?>? frozen,
    List<Sin> sins = const [],
    Device? device,
    Size size = const Size(1440, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nights = FakeNightRepository({'x/${game.id}': ?view});
    final devices = FakeDevicesRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        characterProvider('x').overrideWith((ref) => Stream.value(isaure())),
        rulebookProvider.overrideWith((ref) => rbTitles),
        gamesProvider.overrideWith((ref) => gamesStream ?? Stream.value(games ?? [game])),
        frozenSheetProvider('x', game.id).overrideWith((ref) => frozen ?? Stream.value(snapshot())),
        nightRepositoryProvider.overrideWith((ref) => nights),
        devicesRepositoryProvider.overrideWith((ref) => devices),
        thisDeviceProvider.overrideWith((ref) => Stream.value(device)),
        characterSinsProvider('x').overrideWith((ref) => Stream.value(sins)),
        noItems,
        noPlaces,
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: NightScreen(characterId: 'x', now: () => now)),
      ),
    ));
    await tester.pumpAndSettle();
    return (nights, devices);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('en ligne : version, cases, pouvoirs, équipement ; la partie est préparée sur l’appareil', (tester) async {
    final (_, devices) = await pump(tester, device: const Device(id: 'd1', name: 'Android'));
    expect(find.text('Isaure en partie'), findsOneWidget);
    expect(find.text('Version figée du 29 sept.'), findsOneWidget);
    expect(find.text('Hors ligne'), findsNothing);
    expect(find.text('Sang dépensé'), findsOneWidget);
    expect(find.text('0 / 12 · reste 12'), findsOneWidget);
    expect(find.text('0 / 6 · reste 6'), findsOneWidget);
    expect(find.byKey(const Key('blood-12')), findsOneWidget);
    expect(find.byKey(const Key('blood-13')), findsNothing);
    expect(find.byKey(const Key('incapacitated-3')), findsOneWidget);
    expect(find.text('Auspex ●●●'), findsOneWidget);
    expect(find.text('Sens exacerbés'), findsOneWidget);
    expect(find.text('Maëlle Garnier ●'), findsOneWidget);
    expect(find.text('Tout est envoyé.'), findsOneWidget);
    expect(devices.calls, ['prepared:u1/d1/g2']);
  });

  testWidgets('préparée : la ligne de version le dit, pas de nouvelle écriture', (tester) async {
    final (_, devices) = await pump(tester, device: Device(id: 'd1', name: 'Android', gameId: 'g2', preparedAt: DateTime(2099, 10, 3, 18)));
    expect(find.text('Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h'), findsOneWidget);
    expect(devices.calls, isEmpty);
  });

  testWidgets('hors ligne : badge, bandeau, saisies en attente ; rien n’est noté sur l’appareil', (tester) async {
    final (_, devices) = await pump(tester, view: const NightView(Night(blood: 2), exists: true, fromCache: true, pending: true), device: const Device(id: 'd1', name: 'Android'));
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.text(offlineText), findsOneWidget);
    expect(find.text('Des saisies attendent le réseau.'), findsOneWidget);
    expect(find.text('2 / 12 · reste 10'), findsOneWidget);
    expect(devices.calls, isEmpty);
  });

  testWidgets('coches et annulation ; une note ajoutée ne s’annule pas (Review Focus 3)', (tester) async {
    final (nights, _) = await pump(tester);
    await tap(tester, find.byKey(const Key('blood-3')));
    expect(nights.saved.last.blood, 3);
    expect(find.text('3 / 12 · reste 9'), findsOneWidget);
    await tap(tester, find.byKey(const Key('hurt-2')));
    expect(nights.saved.last.health, [0, 2, 0]);
    await tester.ensureVisible(find.byKey(const Key('night-note')));
    await tester.enterText(find.byKey(const Key('night-note')), 'Inès Morel, galeriste');
    await tap(tester, find.text('Ajouter la note'));
    expect(nights.saved.last.notes.single.text, 'Inès Morel, galeriste');
    expect(find.text('21h · Inès Morel, galeriste'), findsOneWidget);
    await tap(tester, find.text('Annuler le dernier coup'));
    expect(nights.saved.last.health, [0, 0, 0]);
    expect(nights.saved.last.blood, 3);
    expect(nights.saved.last.notes.single.text, 'Inès Morel, galeriste');
    await tap(tester, find.text('Annuler le dernier coup'));
    expect(nights.saved.last.blood, 0);
    final undo = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Annuler le dernier coup'));
    expect(undo.onPressed, isNull);
  });

  testWidgets('refus du serveur : message (Review Focus 4)', (tester) async {
    final (nights, _) = await pump(tester);
    nights.error = Exception('permission-denied');
    await tap(tester, find.byKey(const Key('blood-1')));
    expect(find.text(refusedText), findsOneWidget);
  });

  testWidgets('traits de Bête de la soirée, en lecture', (tester) async {
    final (nights, _) = await pump(tester, sins: [
      Sin(id: 's1', date: DateTime(2099, 10, 3, 22), level: 2),
      Sin(id: 's2', date: DateTime(2099, 9, 20), level: 3),
    ]);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text(beastNote), findsOneWidget);
    await tap(tester, find.byKey(const Key('beast-4')));
    expect(nights.saved, isEmpty);
  });

  testWidgets('goule : Vitae dépensée, 5 cases', (tester) async {
    await pump(tester, frozen: Stream.value(snapshot(isaure()..ghoul = ghoulState())));
    expect(find.text('Vitae dépensée'), findsOneWidget);
    expect(find.byKey(const Key('blood-5')), findsOneWidget);
    expect(find.byKey(const Key('blood-6')), findsNothing);
  });

  testWidgets('fiche non figée : message', (tester) async {
    await pump(tester, games: const []);
    expect(find.text(notFrozenText), findsOneWidget);
  });

  testWidgets('gel levé pendant que l’écran est ouvert : il reste lisible', (tester) async {
    final games = StreamController<List<Game>>();
    addTearDown(games.close);
    games.add([game]);
    await pump(tester, gamesStream: games.stream);
    expect(find.text('Isaure en partie'), findsOneWidget);
    games.add([frozenGame(year: 2099, liftedAt: DateTime(2099, 10, 3, 20))]);
    await tester.pumpAndSettle();
    expect(find.text('Isaure en partie'), findsOneWidget);
    expect(find.text(notFrozenText), findsNothing);
  });

  testWidgets('version figée absente du cache : message de préparation', (tester) async {
    await pump(tester, frozen: StreamController<FrozenSheet?>().stream);
    expect(find.text(notPreparedText), findsOneWidget);
  });

  testWidgets('mobile, 390 px', (tester) async {
    await pump(tester, size: const Size(390, 2800));
    expect(tester.takeException(), isNull);
    expect(find.text('Isaure en partie'), findsOneWidget);
  });
}
