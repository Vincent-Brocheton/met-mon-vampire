import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/offline/offline.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/wiki/wiki_repository.dart';
import 'package:portail_met/wiki/wiki_routes.dart';

import 'wiki_rules_test.dart' show draftsWiki, julienUser, leaUser, pagesWiki, rbWiki;

Future<void> pumpAdmin(WidgetTester tester, {AppUser user = leaUser, double width = 1440, void Function()? onSync}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      rulebookProvider.overrideWith((ref) => rbWiki),
      wikiPagesProvider.overrideWith((ref) => Stream.value(pagesWiki())),
      wikiDraftsProvider.overrideWith((ref) => Stream.value(draftsWiki())),
      wikiAudienceSyncProvider.overrideWith((ref) async => onSync?.call()),
      offlineProvider.overrideWith((ref) => Stream.value(false)),
      publicEventsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: '/conteur/wiki', routes: [
        ShellRoute(builder: (_, _, child) => Scaffold(body: child), routes: wikiRoutes()),
      ]),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('liste : origine, visibilité, état ; brouillons ; synchronisation lancée (Review Focus 5)', (tester) async {
    var synced = false;
    await pumpAdmin(tester, onSync: () => synced = true);
    expect(synced, isTrue);
    final opera = find.byKey(const Key('wk-row-opera'));
    expect(find.descendant(of: opera, matching: find.text('Clan Toreador')), findsOneWidget);
    expect(find.descendant(of: opera, matching: find.text('Page libre')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wk-row-r_disciplines_pre')), matching: find.text('Brouillon')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wk-row-r_disciplines_gone')), matching: find.text('Entrée supprimée')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wk-row-secret')), matching: find.text('Conte seul')), findsOneWidget);
    expect(find.text('1 sur 3'), findsOneWidget);
    await tester.tap(find.text('Brouillons · 2'));
    await tester.pump();
    expect(find.byKey(const Key('wk-row-opera')), findsNothing);
    expect(find.byKey(const Key('wk-row-neuve')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wk-empty')));
    await tester.pump();
    expect(find.byKey(const Key('wk-row-r_disciplines_tha')), findsOneWidget);
    expect(find.byKey(const Key('wk-row-cour')), findsNothing);
  });

  testWidgets('« Voir comme un joueur » ; narrateur sans « Nouvelle page »', (tester) async {
    await pumpAdmin(tester);
    expect(find.byKey(const Key('wk-new')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wk-preview')));
    await tester.pumpAndSettle();
    expect(find.text('Copie hors ligne à jour'), findsOneWidget);
    expect(find.byKey(const Key('wk-rub-disciplines')), findsOneWidget);
    await pumpAdmin(tester, user: julienUser);
    expect(find.byKey(const Key('wk-new')), findsNothing);
    expect(find.byKey(const Key('wk-preview')), findsOneWidget);
  });

  testWidgets('390 px', (tester) async {
    await pumpAdmin(tester, width: 390);
    expect(tester.takeException(), isNull);
  });
}
