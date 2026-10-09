import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/character_screen.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;
import 'character_test.dart' show sample;

void main() {
  Future<void> pump(WidgetTester tester, Stream<Character?> stream, {bool history = false, String basePath = '/joueur/personnages/x', List<Game> games = const []}) async {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        characterProvider('x').overrideWith((ref) => stream),
        rulebookProvider.overrideWith((ref) => rbTitles),
        noPlaces,
        noServantFiles,
        noItems,
        noAllyFiles,
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        characterHistoryProvider('x').overrideWith((ref) => Stream.value([
              HistoryEntry(id: 'h', at: DateTime(2026, 9, 2), byName: 'Léa', kind: 'edit', summary: ['Présence ● → ●●'], reason: 'Demande validée', xpSpent: 6),
            ])),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: CharacterScreen(id: 'x', basePath: basePath, history: history)),
      ),
    ));
    await tester.pump();
    await tester.pump(); // l'historique s'abonne une fois la fiche chargée
  }

  testWidgets('J2 : en-tête et fiche', (tester) async {
    await pump(tester, Stream.value(sample()));
    expect(find.text('Isaure de Valcourt'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('COMPÉTENCES'), findsOneWidget);
  });

  testWidgets('J2 : fiche figée, bandeau du gel (sous-projet 8a)', (tester) async {
    await pump(tester, Stream.value(sample()), games: [frozenGame(year: 2099)]);
    expect(find.text('Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct.'), findsOneWidget);
  });

  testWidgets('J2 : gel d’une autre fiche ou gel levé, pas de bandeau', (tester) async {
    await pump(tester, Stream.value(sample()), games: [
      frozenGame(year: 2099, sheetIds: const ['y']),
      frozenGame(id: 'g1', year: 2099, liftedAt: DateTime(2026, 10, 1)),
    ]);
    expect(find.textContaining('Fiche figée'), findsNothing);
  });

  testWidgets('J6 : historique avec motif et XP', (tester) async {
    await pump(tester, Stream.value(sample()), history: true);
    expect(find.text('Présence ● → ●●'), findsOneWidget);
    expect(find.textContaining('Demande validée'), findsOneWidget);
    expect(find.text('− 6'), findsOneWidget);
  });

  testWidgets('fiche d’un autre joueur : accès refusé explicite (Review Focus 2)', (tester) async {
    await pump(tester, Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')));
    expect(find.text('Cette fiche n’est pas la vôtre'), findsOneWidget);
  });

  testWidgets('fiche absente : page introuvable', (tester) async {
    await pump(tester, Stream.value(null));
    expect(find.text('Cette fiche n’existe pas'), findsOneWidget);
  });

  testWidgets('titre caché : absent de la fiche du joueur, visible pour l’équipe (I1)', (tester) async {
    await pump(tester, Stream.value(sample()..title = 'Main du Prince'));
    expect(find.textContaining('Main du Prince'), findsNothing);
    await pump(tester, Stream.value(sample()..title = 'Harpie'));
    expect(find.text('Harpie'), findsOneWidget);
    await pump(tester, Stream.value(sample()..title = 'Main du Prince'), basePath: '/conteur/fiches/x');
    expect(find.text('Main du Prince'), findsOneWidget);
  });
}
