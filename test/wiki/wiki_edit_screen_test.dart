import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/offline/offline.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_repository.dart';
import 'package:portail_met/wiki/wiki_routes.dart';

import '../fakes.dart';
import 'wiki_rules_test.dart' show draftsWiki, julienUser, leaUser, pagesWiki, pg, rbWiki;

Future<void> pumpEdit(WidgetTester tester, String id,
    {AppUser user = leaUser, FakeWikiRepository? repo, List<WikiPage>? drafts, Stream<List<WikiPage>>? pages, double width = 1440}) async {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      rulebookProvider.overrideWith((ref) => rbWiki),
      wikiPagesProvider.overrideWith((ref) => pages ?? Stream.value(pagesWiki())),
      wikiDraftsProvider.overrideWith((ref) => Stream.value(drafts ?? draftsWiki())),
      wikiRepositoryProvider.overrideWithValue(repo ?? FakeWikiRepository()),
      wikiAudienceSyncProvider.overrideWith((ref) async {}),
      offlineProvider.overrideWith((ref) => Stream.value(false)),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: '/conteur/wiki/edition/$id', routes: [
        ShellRoute(builder: (_, _, child) => Scaffold(body: child), routes: [
          ...wikiRoutes(),
          GoRoute(path: '/conteur/referentiel/:cat', builder: (_, s) => Text('référentiel ${s.pathParameters['cat']}')),
        ]),
      ]),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> publishWith(WidgetTester tester, String note) async {
  await tester.tap(find.byKey(const Key('wk-publish')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('wk-note')), note);
  await tester.tap(find.byKey(const Key('wk-publish-ok')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('page de règle avec brouillon : bandeau, texte du brouillon, données ; publier avec une note', (tester) async {
    final repo = FakeWikiRepository();
    await pumpEdit(tester, 'r_disciplines_pre', repo: repo);
    expect(find.text('Brouillon en cours, non publié.'), findsOneWidget);
    expect(find.text('Brouillon de Présence'), findsWidgets);
    expect(find.text('Commune (achetable hors clan) : Oui'), findsOneWidget);
    expect(find.byKey(const Key('wk-rubric')), findsNothing);
    await publishWith(tester, 'Précision');
    expect(repo.calls, ['publish:r_disciplines_pre:1']);
    expect((repo.lastNote, repo.lastPage!.body, repo.lastPage!.entryId, repo.lastPage!.rubric, repo.lastPage!.title),
        ('Précision', 'Brouillon de Présence', 'pre', 'disciplines', 'Présence'));
    expect(find.text('Page publiée.'), findsOneWidget);
  });

  testWidgets('publication concurrente refusée : message, le texte reste (Review Focus 2)', (tester) async {
    final repo = FakeWikiRepository()..error = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    await pumpEdit(tester, 'cour', repo: repo);
    await tester.enterText(find.byKey(const Key('wk-body')), 'Nouveau texte');
    await publishWith(tester, '');
    expect(repo.calls, ['publish:cour:1']);
    expect(find.text('Cette page a été publiée entre-temps. Rechargez-la avant de publier.'), findsOneWidget);
    expect(find.text('Nouveau texte'), findsWidgets);
  });

  testWidgets('nouvelle page : titre obligatoire, barre d’outils, brouillon', (tester) async {
    final repo = FakeWikiRepository();
    await pumpEdit(tester, 'nouvelle', repo: repo, drafts: [draftsWiki().first]);
    await tester.tap(find.byKey(const Key('wk-save-draft')));
    await tester.pump();
    expect(find.text('Titre obligatoire.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byKey(const Key('wk-title')), 'Système de combat');
    await tester.tap(find.byKey(const Key('wk-tool-Gras')));
    await tester.pump();
    expect(find.text('**texte**'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wk-save-draft')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['draft:neuve:0']);
    expect((repo.lastPage!.title, repo.lastPage!.rubric, repo.lastPage!.body, repo.lastPage!.cat, repo.lastPage!.audience),
        ('Système de combat', 'systeme', '**texte**', null, 'all'));
  });

  testWidgets('abandonner le brouillon : confirmation, texte publié rechargé', (tester) async {
    final repo = FakeWikiRepository();
    await pumpEdit(tester, 'r_disciplines_pre', repo: repo);
    await tester.tap(find.byKey(const Key('wk-discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['discard:r_disciplines_pre']);
    expect(find.text('Brouillon de Présence'), findsNothing);
  });

  testWidgets('supprimer une page libre : confirmation, retour à la liste', (tester) async {
    final repo = FakeWikiRepository();
    await pumpEdit(tester, 'cour', repo: repo);
    await tester.tap(find.byKey(const Key('wk-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['delete:cour']);
    expect(find.byKey(const Key('wk-preview')), findsOneWidget);
  });

  testWidgets('narrateur : lecture seule (Review Focus 4)', (tester) async {
    await pumpEdit(tester, 'cour', user: julienUser);
    expect(find.byKey(const Key('wk-publish')), findsNothing);
    expect(find.byKey(const Key('wk-save-draft')), findsNothing);
    expect(find.byKey(const Key('wk-delete')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('wk-body'))).readOnly, isTrue);
  });

  testWidgets('page introuvable ; 390 px avec onglets Texte et Aperçu', (tester) async {
    await pumpEdit(tester, 'inconnue');
    expect(find.text('Page introuvable'), findsOneWidget);
    await pumpEdit(tester, 'r_disciplines_pre', width: 390);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Aperçu'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('wk-body')), findsNothing);
  });

  testWidgets('publication concurrente : la version de départ est celle du chargement (revue finale)', (tester) async {
    final repo = FakeWikiRepository();
    final pages = StreamController<List<WikiPage>>();
    addTearDown(pages.close);
    pages.add(pagesWiki());
    await pumpEdit(tester, 'cour', repo: repo, pages: pages.stream);
    await tester.enterText(find.byKey(const Key('wk-body')), 'Mon texte');
    // Un autre conteur publie la version 2 pendant la saisie.
    pages.add([for (final p in pagesWiki()) p.id == 'cour' ? pg('cour', title: 'La cour du Prince', body: 'Son texte', version: 2) : p]);
    await tester.pump();
    await publishWith(tester, '');
    expect(repo.calls, ['publish:cour:1']);
    expect(find.text('Mon texte'), findsWidgets);
  });

  testWidgets('deux publications de suite : la seconde part de la version publiée (revue finale)', (tester) async {
    final repo = FakeWikiRepository();
    await pumpEdit(tester, 'cour', repo: repo);
    await publishWith(tester, '');
    await publishWith(tester, '');
    expect(repo.calls, ['publish:cour:1', 'publish:cour:2']);
  });

  testWidgets('page orpheline : le conte peut la supprimer (revue finale)', (tester) async {
    final repo = FakeWikiRepository();
    await pumpEdit(tester, 'r_disciplines_gone', repo: repo);
    await tester.tap(find.byKey(const Key('wk-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['delete:r_disciplines_gone']);
  });

  testWidgets('longueurs bornées comme dans les règles (revue finale)', (tester) async {
    await pumpEdit(tester, 'cour');
    int? max(String key) => tester.widget<TextField>(find.byKey(Key(key))).maxLength;
    expect((max('wk-title'), max('wk-source'), max('wk-body')), (80, 200, 50000));
  });
}
