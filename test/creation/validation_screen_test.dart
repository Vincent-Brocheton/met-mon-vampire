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
import 'package:portail_met/creation/validation_screen.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import 'creation_rules_test.dart' show valid;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  XpRequest auspex() => XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)],
        justification: 'Études auprès du Primogène.',
        submittedAt: DateTime(2026, 9, 24),
        version: 1,
      );

  Future<(FakeCharacterRepository, FakeXpRepository)> pump(
    WidgetTester tester,
    List<Character> queue, {
    List<XpRequest> requests = const [],
    Character? sheet,
    AppUser user = lea,
    List<Game> games = const [],
  }) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    final xp = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        characterRepositoryProvider.overrideWith((ref) => repo),
        xpRepositoryProvider.overrideWith((ref) => xp),
        reviewQueueProvider.overrideWith((ref) => Stream.value(queue)),
        pendingRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        characterProvider('x').overrideWith((ref) => Stream.value(sheet ?? sample())),
        characterRequestsProvider('x').overrideWith((ref) => Stream.value(requests)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ValidationScreen())),
    ));
    await tester.pumpAndSettle();
    return (repo, xp);
  }

  testWidgets('dépense sur une fiche figée : validation bloquée, refus possible (sous-projet 8a, Review Focus 2)', (tester) async {
    await pump(tester, const [], requests: [auspex()], games: [frozenGame(year: 2099)]);
    expect(find.text('Fiche figée jusqu’au 4 oct.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider la dépense')).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Refuser')).onPressed, isNotNull);
  });

  testWidgets('dépense : gel d’une autre fiche, validation possible (sous-projet 8a)', (tester) async {
    await pump(tester, const [], requests: [auspex()], games: [frozenGame(year: 2099, sheetIds: const ['y'])]);
    expect(find.textContaining('Fiche figée'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider la dépense')).onPressed, isNotNull);
  });

  testWidgets('file vide', (tester) async {
    await pump(tester, const []);
    expect(find.text('Aucune demande en attente'), findsOneWidget);
  });

  testWidgets('création : contrôles affichés, corrections commentées, validation', (tester) async {
    final (repo, _) = await pump(tester, [valid()..status = CharacterStatus.review]);
    expect(find.text('Nikolaï Vesk'), findsWidgets);
    expect(find.text('Attributs répartis 7 / 5 / 3, un focus chacun'), findsOneWidget);
    await tester.tap(find.text('Demander des corrections'));
    await tester.pump();
    expect(find.text('Expliquez les corrections attendues.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byKey(const Key('decision-comment')), 'Précise le sire.');
    await tester.tap(find.text('Demander des corrections'));
    await tester.pump();
    expect(repo.calls, ['decide:draft:Précise le sire.']);
    expect(tester.widget<TextField>(find.byKey(const Key('decision-comment'))).controller!.text, isEmpty);
    await tester.tap(find.text('Valider et activer la fiche'));
    await tester.pump();
    expect(repo.calls.last, 'decide:active:');
  });

  testWidgets('création : sa propre fiche, pas de décision', (tester) async {
    await pump(tester, [valid()
      ..status = CharacterStatus.review
      ..playerUid = 'lea']);
    expect(find.text('Valider et activer la fiche'), findsNothing);
    expect(find.textContaining('votre propre fiche'), findsOneWidget);
  });

  testWidgets('dépense : solde, compléments commentés, validation', (tester) async {
    final (_, xp) = await pump(tester, const [], requests: [auspex()]);
    expect(find.text('Niveaux et coûts conformes à la fiche'), findsOneWidget);
    expect(find.textContaining('Après validation 8'), findsOneWidget);
    await tester.tap(find.text('Demander des compléments'));
    await tester.pump();
    expect(find.text('Expliquez ce qu’il faut compléter.'), findsOneWidget);
    expect(xp.calls, isEmpty);
    await tester.enterText(find.byKey(const Key('decision-comment')), 'Quel mentor ?');
    await tester.tap(find.text('Demander des compléments'));
    await tester.pump();
    expect(xp.calls, ['decide:changes:Quel mentor ?']);
    await tester.tap(find.text('Valider la dépense'));
    await tester.pump();
    expect(xp.calls.last, 'decide:accepted:');
  });

  testWidgets('dépense : fiche changée depuis l’envoi, validation bloquée (Review Focus 1)', (tester) async {
    await pump(tester, const [], requests: [auspex()], sheet: sample()..disciplines.first.level = 4);
    expect(find.text('La fiche a changé : Auspex est à ●●●● (demande faite depuis ●●●)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider la dépense')).onPressed, isNull);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, [valid()..status = CharacterStatus.review], requests: [auspex()], user: julien);
    expect(find.text('Lecture seule : les conteurs décident.'), findsOneWidget);
    expect(find.text('Valider et activer la fiche'), findsNothing);
    await tester.tap(find.text('Isaure de Valcourt'));
    await tester.pumpAndSettle();
    expect(find.text('Valider la dépense'), findsNothing);
    expect(find.text('Lecture seule : les conteurs décident.'), findsOneWidget);
  });
}
