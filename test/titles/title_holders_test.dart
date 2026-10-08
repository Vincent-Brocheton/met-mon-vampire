import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/referential_screen.dart';
import 'package:portail_met/rulebook/rules_repository.dart';
import 'package:portail_met/titles/court_entry.dart';
import 'package:portail_met/titles/title_holders.dart';
import 'package:portail_met/titles/titles_repository.dart';

import '../fakes.dart';
import 'title_rules_test.dart' show agathe, lucie, octave, rbTitles;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  final chars = [lucie(), octave(), agathe()];

  Future<FakeTitlesRepository> pumpSection(WidgetTester tester, String title, {List<CourtEntry> court = const [], bool readOnly = false, List<Character>? sheets}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeTitlesRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        titlesRepositoryProvider.overrideWith((ref) => repo),
        courtProvider.overrideWith((ref) => Stream.value(court)),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: TitleHoldersSection(title: title, chars: sheets ?? chars, rb: rbTitles, readOnly: readOnly))),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> confirmReason(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('reason')), text);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
  }

  testWidgets('détenteurs : retirer avec motif ; copie publique à mettre à jour', (tester) async {
    final repo = await pumpSection(tester, 'Sénéchal');
    expect(find.text('Octave Marchetti'), findsOneWidget);
    expect(find.text('Copie publique à mettre à jour'), findsOneWidget);
    await tester.tap(find.byKey(const Key('th-refresh-oct')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['court:oct']);
    await tester.tap(find.byKey(const Key('th-remove-oct')));
    await tester.pumpAndSettle();
    await confirmReason(tester, 'Démission');
    expect(repo.calls.last, 'assign:oct:aucun');
  });

  testWidgets('attribuer à une fiche : contrôles, puis écriture (Review Focus 1)', (tester) async {
    final repo = await pumpSection(tester, 'Primogène');
    await choose(tester, 'th-sheet', 'Lucie Arnaud');
    expect(find.text('Primogène est déjà tenu pour le clan Malkavian par Sœur Agathe.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('th-assign'))).onPressed, isNull);
    final harpie = await pumpSection(tester, 'Harpie');
    await choose(tester, 'th-sheet', 'Lucie Arnaud');
    await tester.enterText(find.byKey(const Key('th-since')), '01/03/2026');
    await tester.pump();
    await tester.tap(find.byKey(const Key('th-assign')));
    await tester.pumpAndSettle();
    await confirmReason(tester, 'Nommée');
    expect(harpie.calls, ['assign:luc:Harpie']);
    expect(repo.calls, isEmpty);
  });

  testWidgets('sa propre fiche : ni retrait ni mise à jour', (tester) async {
    await pumpSection(tester, 'Sénéchal', sheets: [octave()..playerUid = 'lea']);
    expect(find.text('Octave Marchetti'), findsOneWidget);
    expect(find.byKey(const Key('th-remove-oct')), findsNothing);
    expect(find.byKey(const Key('th-refresh-oct')), findsNothing);
  });

  testWidgets('lecture seule : ni retrait ni attribution', (tester) async {
    await pumpSection(tester, 'Sénéchal', readOnly: true);
    expect(find.byKey(const Key('th-remove-oct')), findsNothing);
    expect(find.byKey(const Key('th-assign')), findsNothing);
  });

  testWidgets('référentiel : colonne « Détenu par », filtre des titres vacants', (tester) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        rulesRepositoryProvider.overrideWith((ref) => FakeRulesRepository()),
        allRuleEntriesProvider.overrideWith((ref) => Stream.value({'titles': rbTitles.all('titles')})),
        allRuleSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        allCharactersProvider.overrideWith((ref) => Stream.value(<Character>[...chars])),
        courtProvider.overrideWith((ref) => Stream.value(const <CourtEntry>[])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: ReferentialScreen(categoryId: 'titles')))]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Octave Marchetti (PNJ)'), findsOneWidget);
    expect(find.text('Vacant'), findsWidgets);
    await tester.tap(find.byKey(const Key('ref-vacant')));
    await tester.pumpAndSettle();
    expect(find.text('Sénéchal'), findsNothing);
    expect(find.text('Harpie'), findsOneWidget);
  });
}
