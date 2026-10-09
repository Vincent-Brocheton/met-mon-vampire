import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/print/print_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  // Gel en cours (2099 : l'écran lit l'heure de l'appareil).
  final game = frozenGame(year: 2099);

  Future<void> pump(
    WidgetTester tester, {
    Stream<Character?>? sheet,
    List<Game> games = const [],
    Stream<FrozenSheet?>? frozen,
    Stream<List<Item>>? items,
    Size size = const Size(1440, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        characterProvider('x').overrideWith((ref) => sheet ?? Stream.value(sample())),
        rulebookProvider.overrideWith((ref) => rbTitles),
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        frozenSheetProvider('x', game.id).overrideWith((ref) => frozen ?? Stream.value(null)),
        items == null ? noItems : characterItemsProvider('x').overrideWith((ref) => items),
        noPlaces,
        characterBondsProvider('x').overrideWith((ref) async => const <Bond>[]),
        myRequestsProvider.overrideWith((ref) => Stream.value(const <XpRequest>[])),
        chronicleProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(
          body: PrintScreen(
            characterId: 'x',
            basePath: '/joueur/personnages/x',
            preview: (s) => Text('aperçu ${s.stamp.join(' / ')}', key: const Key('preview')),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  FrozenSheet snapshot() => FrozenSheet(characterId: 'x', gameId: game.id, sheet: sample().toMap(), version: 4, gameDate: game.date);

  testWidgets('hors gel : version du jour, pas de choix', (tester) async {
    await pump(tester);
    expect(find.text('Imprimer la fiche'), findsOneWidget);
    expect(find.textContaining('aperçu Version du '), findsOneWidget);
    expect(find.byKey(const Key('print-frozen')), findsNothing);
  });

  testWidgets('pendant un gel : version figée par défaut, puis version actuelle', (tester) async {
    await pump(tester, games: [game], frozen: Stream.value(snapshot()));
    expect(find.text('Version figée · partie du samedi 3 oct.'), findsOneWidget);
    expect(find.textContaining('aperçu Version figée'), findsOneWidget);
    await tester.tap(find.byKey(const Key('print-current')));
    await tester.pump();
    expect(find.textContaining('aperçu Version actuelle'), findsOneWidget);
  });

  testWidgets('pendant un gel, version figée absente : version actuelle, non valable en jeu (Review Focus 3)', (tester) async {
    await pump(tester, games: [game]);
    expect(find.byKey(const Key('print-frozen')), findsNothing);
    expect(find.text('aperçu Version actuelle / Non valable en jeu'), findsOneWidget);
  });

  testWidgets('pendant un gel, version figée illisible : avis et version actuelle seule', (tester) async {
    await pump(tester, games: [game], frozen: Stream.error(StateError('illisible')));
    expect(find.text('Version figée illisible : seule la version actuelle peut être imprimée.'), findsOneWidget);
    expect(find.text('aperçu Version actuelle / Non valable en jeu'), findsOneWidget);
  });

  testWidgets('données de la fiche en cours de lecture : pas d’aperçu avant leur arrivée', (tester) async {
    final pending = StreamController<List<Item>>();
    addTearDown(pending.close);
    await pump(tester, items: pending.stream);
    expect(find.text('Chargement de la fiche…'), findsOneWidget);
    expect(find.byKey(const Key('preview')), findsNothing);
    pending.add(const <Item>[]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Chargement de la fiche…'), findsNothing);
    expect(find.byKey(const Key('preview')), findsOneWidget);
  });

  testWidgets('pendant un gel, version figée en cours de lecture', (tester) async {
    final pending = StreamController<FrozenSheet?>();
    addTearDown(pending.close);
    await pump(tester, games: [game], frozen: pending.stream);
    expect(find.text('Chargement de la version figée…'), findsOneWidget);
    expect(find.byKey(const Key('preview')), findsNothing);
  });

  testWidgets('fiche d’un autre joueur : refus (Review Focus 5)', (tester) async {
    await pump(tester, sheet: Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')));
    expect(find.text('Cette fiche n’est pas la vôtre'), findsOneWidget);
  });

  testWidgets('390 px : sans débordement', (tester) async {
    await pump(tester, games: [game], frozen: Stream.value(snapshot()), size: const Size(390, 1200));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('print-frozen')), findsOneWidget);
  });
}
