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
import 'package:portail_met/xp/corrections_screen.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  XpRequest accepted() => XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.accepted,
        items: [const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)],
        decidedAt: DateTime(2026, 9, 12),
      );

  Future<FakeXpRepository> pump(WidgetTester tester, Character sheet, {List<CorrectionEntry> recent = const [], List<Character> others = const [], List<Game> games = const []}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        xpRepositoryProvider.overrideWith((ref) => repo),
        allCharactersProvider.overrideWith((ref) => Stream.value([sheet, ...others])),
        correctionsProvider.overrideWith((ref) => Stream.value(recent)),
        characterRequestsProvider('x').overrideWith((ref) => Stream.value([accepted()])),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CorrectionsScreen())),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester tester, Key key, String text) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('fiches en création : absentes du choix (revue finale)', (tester) async {
    await pump(tester, sample(), others: [
      Character(id: 'd', name: 'Mira Kovač', kind: CharacterKind.pj, playerUid: 'u2', playerName: 'Inès T.'),
    ]);
    await tester.tap(find.byKey(const Key('corr-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Mira Kovač · Inès T.'), findsNothing);
    expect(find.text('Isaure de Valcourt · Camille R.'), findsWidgets);
  });

  testWidgets('fiche figée : proposée mais non sélectionnable (sous-projet 8a, Review Focus 2)', (tester) async {
    await pump(tester, sample(), games: [frozenGame(year: 2099)]);
    await tester.tap(find.byKey(const Key('corr-sheet')));
    await tester.pumpAndSettle();
    const label = 'Isaure de Valcourt · Camille R. · Fiche figée jusqu’au 4 oct.';
    expect(find.text(label), findsWidgets);
    await tester.tap(find.text(label).last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer la correction'), findsNothing);
  });

  testWidgets('dernières corrections affichées', (tester) async {
    await pump(tester, sample(), recent: [
      CorrectionEntry(
        'x',
        HistoryEntry(
          id: 'h',
          at: DateTime(2026, 9, 21),
          byName: 'Léa G.',
          kind: 'correction',
          summary: const ['Remboursement (règle changée, élément retiré)'],
          reason: 'Atout interdit aux goules',
          xpSpent: -2,
        ),
      ),
    ]);
    expect(find.text('Atout interdit aux goules'), findsOneWidget);
    expect(find.text('+ 2'), findsOneWidget);
  });

  testWidgets('rachat forcé : dette affichée, motif obligatoire (Review Focus 4)', (tester) async {
    final repo = await pump(tester, sample()..xpSpent = 63);
    await choose(tester, const Key('corr-sheet'), 'Isaure de Valcourt · Camille R.');
    await choose(tester, const Key('corr-kind'), 'Rachat forcé d’un handicap');
    await choose(tester, const Key('corr-flaw'), 'Curiosité (2)');
    expect(find.text('À payer : − 4 XP · dette de 1 XP'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Enregistrer la correction');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('corr-reason')), 'Vue faible annulée par Auspex');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.calls, ['correction:forcedBuyback:63→67:Vue faible annulée par Auspex']);
  });

  testWidgets('annulation d’un achat : trait changé depuis, bloqué', (tester) async {
    await pump(tester, sample());
    await choose(tester, const Key('corr-sheet'), 'Isaure de Valcourt · Camille R.');
    await choose(tester, const Key('corr-kind'), 'Annulation d’un achat');
    await choose(tester, const Key('corr-item'), 'Discipline · Auspex ●●●● · achat du 12 sept. · 12 XP');
    expect(find.text('Le trait a changé depuis : corrigez-le dans la fiche.'), findsOneWidget);
  });
}
