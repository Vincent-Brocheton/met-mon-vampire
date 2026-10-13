import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/offline/offline.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_repository.dart';
import 'package:portail_met/wiki/wiki_routes.dart';

import 'wiki_personal_test.dart' show isaure, lucie;
import 'wiki_rules_test.dart' show leaUser, pagesWiki, pagesZoe, rbWiki, sheet, zoeUser;

Future<void> pumpReader(WidgetTester tester, String location,
    {AppUser user = zoeUser,
    List<WikiPage>? pages,
    bool offline = false,
    List<Character> mine = const [],
    List<StoryEvent> publicEvents = const [],
    double width = 1440}) async {
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
      myCharactersProvider.overrideWith((ref) => Stream.value(mine)),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: location, routes: [
        ShellRoute(builder: (_, _, child) => Scaffold(body: child), routes: [
          ...wikiRoutes(),
          GoRoute(path: '/joueur/personnages/:id/xp', builder: (_, s) => Text('xp ${s.pathParameters['id']}')),
        ]),
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

  testWidgets('page : données, texte, sommaire, lien visible, lien caché en texte simple', (tester) async {
    await pumpReader(tester, '/joueur/wiki/page/r_disciplines_pre');
    expect(find.text('Presence'), findsOneWidget);
    expect(find.text('Rend la cible dévouée.'), findsOneWidget);
    expect(find.text('SUR CETTE PAGE'), findsOneWidget);
    expect(find.textContaining('Page cachée'), findsOneWidget);
    expect(find.text('Page cachée'), findsNothing);
    expect(find.text('Source : MET : VTM, p. 120 · mis à jour le 25 sept. par Léa'), findsOneWidget);
    expect(find.byKey(const Key('wk-edit')), findsNothing);
    expect(find.byKey(const Key('wk-owned-1')), findsNothing);
    await tester.tap(find.text('La cour du Prince'));
    await tester.pumpAndSettle();
    expect(find.text('La cour se réunit à l’Opéra.'), findsOneWidget);
  });

  testWidgets('page réservée, page sans texte, page introuvable, aperçu joueur', (tester) async {
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

  testWidgets('accueil personnalisé : un bloc par fiche active, lignes reliées aux pages (Review Focus 3)', (tester) async {
    await pumpReader(tester, '/joueur/wiki', mine: [isaure(), lucie(), sheet('morte', status: CharacterStatus.dead)]);
    final block = find.byKey(const Key('wk-mine-Isaure'));
    expect(find.descendant(of: block, matching: find.text('POUR ISAURE')), findsOneWidget);
    expect(find.descendant(of: block, matching: find.text('●● · vos 2 pouvoirs')), findsOneWidget);
    expect(find.descendant(of: block, matching: find.text('votre handicap')), findsOneWidget);
    expect(find.byKey(const Key('wk-mine-Lucie')), findsOneWidget);
    expect(find.byKey(const Key('wk-mine-morte')), findsNothing);
    await tester.tap(find.descendant(of: block, matching: find.text('Présence')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wk-next-Isaure')), findsOneWidget);
  });

  testWidgets('page de discipline personnalisée : « Vous l’avez », coût, encadrés, préparer l’achat (Review Focus 3, 5)', (tester) async {
    await pumpReader(tester, '/joueur/wiki/page/r_disciplines_pre',
        mine: [isaure(), sheet('Ancienne')..disciplines = [Discipline('Présence', 5, inClan: true)]]);
    expect(find.byKey(const Key('wk-owned-1')), findsOneWidget);
    expect(find.byKey(const Key('wk-owned-2')), findsOneWidget);
    expect(find.byKey(const Key('wk-owned-3')), findsNothing);
    expect(find.text('9 XP en clan'), findsOneWidget);
    final next = find.byKey(const Key('wk-next-Isaure'));
    expect(find.descendant(of: next, matching: find.text('Isaure · Présence ●●')), findsOneWidget);
    expect(find.descendant(of: next, matching: find.text('Prochain niveau : Envoûtement, 9 XP en clan.')), findsOneWidget);
    final top = find.byKey(const Key('wk-next-Ancienne'));
    expect(find.descendant(of: top, matching: find.textContaining('Prochain niveau')), findsNothing);
    expect(find.byKey(const Key('wk-buy-Ancienne')), findsNothing);
    await tester.tap(find.byKey(const Key('wk-buy-Isaure')));
    await tester.pumpAndSettle();
    expect(find.text('xp Isaure'), findsOneWidget);
  });

  testWidgets('rubrique personnalisée : puce « En clan pour Isaure », mention sur la carte', (tester) async {
    await pumpReader(tester, '/joueur/wiki/rubrique/disciplines', mine: [isaure()]);
    expect(find.text('●● · en clan'), findsOneWidget);
    expect(find.text('En clan pour Isaure'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wk-filter-3')));
    await tester.pump();
    expect(find.text('Présence'), findsOneWidget);
    expect(find.text('Thaumaturgie'), findsNothing);
  });

  testWidgets('conte et aperçu joueur : pas de personnalisation', (tester) async {
    await pumpReader(tester, '/conteur/wiki/accueil?apercu=1', user: leaUser, pages: pagesWiki(), mine: [isaure()]);
    expect(find.byKey(const Key('wk-mine-Isaure')), findsNothing);
    await pumpReader(tester, '/conteur/wiki/page/r_disciplines_pre', user: leaUser, pages: pagesWiki(), mine: [isaure()]);
    expect(find.byKey(const Key('wk-next-Isaure')), findsNothing);
    expect(find.byKey(const Key('wk-owned-1')), findsNothing);
  });

  testWidgets('390 px', (tester) async {
    for (final loc in ['/joueur/wiki', '/joueur/wiki/rubrique/disciplines', '/joueur/wiki/page/r_disciplines_pre', '/joueur/wiki/recherche?q=pr']) {
      await pumpReader(tester, loc, width: 390, mine: [isaure()]);
      expect(tester.takeException(), isNull);
    }
  });
}
