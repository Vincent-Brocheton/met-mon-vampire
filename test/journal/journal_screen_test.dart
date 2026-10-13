import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/journal/journal_repository.dart';
import 'package:portail_met/journal/journal_rules.dart';
import 'package:portail_met/journal/journal_screen.dart';
import 'package:portail_met/xp/xp_settings_screen.dart';

final now = DateTime(2026, 10, 13, 12);
final since30 = DateTime(2026, 9, 13);

final lines = [
  JournalLine(
      cat: JournalCat.wiki,
      at: DateTime(2026, 9, 25, 18, 40),
      who: 'Léa G.',
      action: 'Wiki',
      target: 'Page « Présence »',
      detail: 'Version 4 publiée',
      link: '/conteur/wiki/edition/p1/historique'),
  JournalLine(cat: JournalCat.accounts, at: DateTime(2026, 9, 22, 19, 30), who: 'Marc D.', action: 'Rôle', target: 'Julien P.', detail: 'Joueur → Narrateur'),
];

Game played(DateTime date) => Game(id: 'g1', date: date, frozenAt: date.subtract(const Duration(days: 4)), until: date.add(const Duration(days: 1)), byUid: 'marc');

Future<void> pump(WidgetTester tester, {JournalFeed? feed, JournalFeed? all, List<Game> games = const [], double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      gamesProvider.overrideWith((ref) => Stream.value(games)),
      journalProvider(since30).overrideWith((ref) => feed ?? JournalFeed(lines)),
      journalProvider(null).overrideWith((ref) => all ?? const JournalFeed([])),
      journalProvider(DateTime(2026, 10, 3)).overrideWith((ref) => JournalFeed([lines.first])),
    ],
    child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: JournalScreen(now: () => now))),
  ));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tableau : colonnes, lignes, mention', (tester) async {
    await pump(tester);
    expect(find.text('Journal de la chronique'), findsOneWidget);
    expect(find.text('Quand'), findsOneWidget);
    expect(find.text('25 sept. · 18:40'), findsOneWidget);
    expect(find.text('Page « Présence »'), findsOneWidget);
    expect(find.text('Joueur → Narrateur'), findsOneWidget);
    expect(find.textContaining('Le journal ne peut être ni modifié ni effacé.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('puces et auteur filtrent la liste', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Wiki'));
    await tester.pumpAndSettle();
    expect(find.text('Julien P.'), findsNothing);
    expect(find.text('Page « Présence »'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tout'));
    await tester.pumpAndSettle();
    await choose(tester, 'jn-author', 'Marc D.');
    expect(find.text('Page « Présence »'), findsNothing);
    expect(find.text('Julien P.'), findsOneWidget);
  });

  testWidgets('auteur choisi, puis période sans cet auteur : retour à « Tous les auteurs » (Review Focus 5)', (tester) async {
    await pump(tester, all: JournalFeed([lines.first]));
    await choose(tester, 'jn-author', 'Marc D.');
    await choose(tester, 'jn-period', 'Tout');
    expect(tester.takeException(), isNull);
    expect(find.text('Tous les auteurs'), findsOneWidget);
    expect(find.text('Page « Présence »'), findsOneWidget);
  });

  testWidgets('période : « Depuis la dernière partie » seulement après une partie jouée', (tester) async {
    await pump(tester, games: [played(DateTime(2026, 10, 24))]);
    await tester.tap(find.byKey(const Key('jn-period')));
    await tester.pumpAndSettle();
    expect(find.text('Depuis la dernière partie'), findsNothing);
    await tester.tap(find.text('Tout').last);
    await tester.pumpAndSettle();
    expect(find.text('Rien sur cette période.'), findsOneWidget);

    await pump(tester, games: [played(DateTime(2026, 10, 3))]);
    await choose(tester, 'jn-period', 'Depuis la dernière partie');
    expect(find.text('Page « Présence »'), findsOneWidget);
    expect(find.text('Julien P.'), findsNothing);
  });

  testWidgets('liste vide, source en erreur (Review Focus 3)', (tester) async {
    await pump(tester, feed: const JournalFeed([], partial: true));
    expect(find.text('Rien sur cette période.'), findsOneWidget);
    expect(find.text('Une partie du journal n’a pas pu être chargée.'), findsOneWidget);
  });

  testWidgets('export : CSV des lignes affichées dans le presse-papiers', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester);
    await tester.tap(find.byKey(const Key('jn-csv')));
    await tester.pumpAndSettle();
    expect(copied, toCsv(lines));
    expect(find.text('CSV copié : 2 lignes.'), findsOneWidget);
  });

  testWidgets('390 px : cartes, sans débordement', (tester) async {
    await pump(tester, width: 390);
    expect(find.text('Quand'), findsNothing);
    expect(find.text('Julien P. · Joueur → Narrateur'), findsOneWidget);
    expect(find.text('Rôle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Paramètres : journal pour le conteur, absent pour le narrateur (Review Focus 4)', (tester) async {
    Future<void> show(AppUser user) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [currentUserProvider.overrideWith((ref) => Stream.value(user))],
        child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ParametersScreen())),
      ));
      await tester.pumpAndSettle();
    }

    await show(const AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur));
    expect(find.text('Journal de la chronique'), findsOneWidget);
    expect(find.text('Toutes les modifications du conte.'), findsOneWidget);
    await show(const AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur));
    expect(find.text('Journal de la chronique'), findsNothing);
  });
}
