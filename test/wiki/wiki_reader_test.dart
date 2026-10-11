import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/offline/offline.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_repository.dart';
import 'package:portail_met/wiki/wiki_routes.dart';

import 'wiki_rules_test.dart' show leaUser, pagesWiki, pagesZoe, rbWiki, zoeUser;

Future<void> pumpReader(WidgetTester tester, String location,
    {AppUser user = zoeUser, List<WikiPage>? pages, bool offline = false, List<StoryEvent> publicEvents = const [], double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      rulebookProvider.overrideWith((ref) => rbWiki),
      wikiPagesProvider.overrideWith((ref) => Stream.value(pages ?? pagesZoe())),
      offlineProvider.overrideWith((ref) => Stream.value(offline)),
      publicEventsProvider.overrideWith((ref) => Stream.value(publicEvents)),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: location, routes: [
        ShellRoute(builder: (_, _, child) => Scaffold(body: child), routes: wikiRoutes()),
      ]),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('accueil : rubriques visibles, mises à jour récentes, état hors ligne', (tester) async {
    await pumpReader(tester, '/joueur/wiki');
    expect(find.text('Wiki de la chronique'), findsOneWidget);
    expect(find.text('Copie hors ligne à jour'), findsOneWidget);
    final disciplines = find.byKey(const Key('wk-rub-disciplines'));
    expect(find.descendant(of: disciplines, matching: find.text('2')), findsOneWidget);
    expect(find.byKey(const Key('wk-recent-cour')), findsOneWidget);
    expect(find.byKey(const Key('wk-recent-rue')), findsNothing);
    await pumpReader(tester, '/joueur/wiki', offline: true);
    expect(find.text('Hors ligne · copie de l’appareil'), findsOneWidget);
  });

  testWidgets('rubrique : cartes, filtres, ouverture d’une page', (tester) async {
    await pumpReader(tester, '/joueur/wiki/rubrique/disciplines');
    expect(find.text('Présence'), findsOneWidget);
    expect(find.text('Thaumaturgie'), findsOneWidget);
    expect(find.text('En clan : Toreador'), findsOneWidget);
    expect(find.text('Discipline oubliée'), findsNothing);
    await tester.tap(find.byKey(const Key('wk-filter-1')));
    await tester.pump();
    expect(find.text('Thaumaturgie'), findsNothing);
    await tester.tap(find.byKey(const Key('wk-item-r_disciplines_pre')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wk-power-3-Envoûtement')), findsOneWidget);
    await pumpReader(tester, '/joueur/wiki/rubrique/inconnue');
    expect(find.text('Rubrique introuvable'), findsOneWidget);
  });

  testWidgets('page : données, texte, sommaire, lien visible, lien caché en texte simple (Review Focus 1)', (tester) async {
    await pumpReader(tester, '/joueur/wiki/page/r_disciplines_pre');
    expect(find.text('Presence'), findsOneWidget);
    expect(find.text('Rend la cible dévouée.'), findsOneWidget);
    expect(find.text('SUR CETTE PAGE'), findsOneWidget);
    expect(find.textContaining('Page cachée'), findsOneWidget);
    expect(find.text('Page cachée'), findsNothing);
    expect(find.text('Source : MET : VTM, p. 120 · mis à jour le 25 sept. par Léa'), findsOneWidget);
    expect(find.byKey(const Key('wk-edit')), findsNothing);
    await tester.tap(find.text('La cour du Prince'));
    await tester.pumpAndSettle();
    expect(find.text('La cour se réunit à l’Opéra.'), findsOneWidget);
  });

  testWidgets('page réservée, page sans texte, page introuvable, aperçu joueur (Review Focus 1)', (tester) async {
    await pumpReader(tester, '/joueur/wiki/page/opera');
    expect(find.text('Réservé au clan Toreador.'), findsOneWidget);
    await pumpReader(tester, '/joueur/wiki/page/r_disciplines_tha');
    expect(find.text('Le conte n’a pas encore rédigé cette page.'), findsOneWidget);
    await pumpReader(tester, '/joueur/wiki/page/rue');
    expect(find.text('Page introuvable'), findsOneWidget);
    await pumpReader(tester, '/conteur/wiki/page/opera?apercu=1', user: leaUser, pages: pagesWiki());
    expect(find.text('Page introuvable'), findsOneWidget);
    await pumpReader(tester, '/conteur/wiki/page/opera', user: leaUser, pages: pagesWiki());
    expect(find.text('Réservé au clan Toreador.'), findsOneWidget);
    expect(find.byKey(const Key('wk-edit')), findsOneWidget);
  });

  testWidgets('recherche : depuis l’accueil, groupes', (tester) async {
    await pumpReader(tester, '/joueur/wiki');
    await tester.enterText(find.byKey(const Key('wk-search')), 'opéra');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wk-hit-opera')), findsOneWidget);
    expect(find.byKey(const Key('wk-hit-cour')), findsOneWidget);
    expect(find.text('La recherche ne montre que les pages que vous pouvez voir. Elle fonctionne aussi hors ligne.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wk-group-1')));
    await tester.pump();
    expect(find.byKey(const Key('wk-hit-opera')), findsNothing);
  });

  testWidgets('390 px', (tester) async {
    for (final loc in ['/joueur/wiki', '/joueur/wiki/rubrique/disciplines', '/joueur/wiki/page/r_disciplines_pre', '/joueur/wiki/recherche?q=pr']) {
      await pumpReader(tester, loc, width: 390);
      expect(tester.takeException(), isNull);
    }
  });
}
