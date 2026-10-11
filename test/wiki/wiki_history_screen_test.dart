import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/wiki/wiki_history_screen.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_repository.dart';

import '../fakes.dart';
import 'wiki_rules_test.dart' show julienUser, leaUser, pagesWiki, pg, rbWiki;

List<WikiPage> pagesV3() => [
      for (final p in pagesWiki())
        p.id == 'cour' ? pg('cour', title: 'La cour du Prince', body: 'La cour se réunit au Louvre.', version: 3) : p,
    ];

WikiVersion v(int n, String body, {String note = ''}) => WikiVersion(
    n: n, page: pg('cour', title: 'La cour du Prince', body: body, source: 'MET', version: 0), note: note, byName: 'Léa', at: DateTime(2026, 9, n));

final versions = [v(3, 'La cour se réunit au Louvre.', note: 'Lieu'), v(2, 'La cour se réunit à l’Opéra.'), v(1, 'La cour.', note: 'Création')];

Future<void> pumpHistory(WidgetTester tester,
    {AppUser user = leaUser, FakeWikiRepository? repo, List<WikiPage> drafts = const [], double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      rulebookProvider.overrideWith((ref) => rbWiki),
      wikiPagesProvider.overrideWith((ref) => Stream.value(pagesV3())),
      wikiDraftsProvider.overrideWith((ref) => Stream.value(drafts)),
      wikiVersionsProvider('cour').overrideWith((ref) => Stream.value(versions)),
      wikiRepositoryProvider.overrideWithValue(repo ?? FakeWikiRepository()),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: '/h', routes: [
        GoRoute(path: '/h', builder: (_, _) => const Scaffold(body: WikiHistoryScreen(pageId: 'cour'))),
        GoRoute(path: '/conteur/wiki/edition/:id', builder: (_, s) => Text('édition ${s.pathParameters['id']}')),
      ]),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

List<String> spans(WidgetTester tester, bool Function(TextStyle?) keep) => [
      for (final s in (tester.widget<Text>(find.byKey(const Key('wk-diff'))).textSpan! as TextSpan).children!.cast<TextSpan>())
        if (keep(s.style)) s.text!,
    ];

void main() {
  testWidgets('versions : la publiée « En ligne », comparaison avec la précédente', (tester) async {
    await pumpHistory(tester);
    expect(find.text('Historique de « La cour du Prince »'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wk-version-3')), matching: find.text('En ligne')), findsOneWidget);
    expect(find.text('VERSION 3 COMPARÉE À LA VERSION 2'), findsOneWidget);
    expect(spans(tester, (s) => s?.decoration == TextDecoration.lineThrough), contains('l’Opéra.'));
    expect(spans(tester, (s) => s?.backgroundColor != null && s?.decoration != TextDecoration.lineThrough), contains('Louvre.'));
    expect(find.byKey(const Key('wk-restore')), findsNothing);
    await tester.tap(find.byKey(const Key('wk-version-1')));
    await tester.pump();
    expect(find.text('VERSION 1 : CRÉATION'), findsOneWidget);
  });

  testWidgets('restaurer une ancienne version : nouvelle publication, note de restauration', (tester) async {
    final repo = FakeWikiRepository();
    await pumpHistory(tester, repo: repo);
    await tester.tap(find.byKey(const Key('wk-version-2')));
    await tester.pump();
    expect(find.text('Restaurer crée une version 4 identique à la 2. Aucune version n’est effacée.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wk-restore')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['publish:cour:3']);
    expect((repo.lastPage!.body, repo.lastPage!.source, repo.lastPage!.title, repo.lastNote),
        ('La cour se réunit à l’Opéra.', 'MET', 'La cour du Prince', 'Restauration de la version 2'));
    expect(find.text('Version 2 restaurée.'), findsOneWidget);
  });

  testWidgets('brouillon en cours : confirmation ; refus concurrent signalé (Review Focus 2)', (tester) async {
    final repo = FakeWikiRepository()..error = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    await pumpHistory(tester, repo: repo, drafts: [pg('cour', title: 'La cour du Prince', body: 'Brouillon', version: 3)]);
    await tester.tap(find.byKey(const Key('wk-version-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('wk-restore')));
    await tester.pumpAndSettle();
    expect(find.text('Le brouillon en cours sera abandonné.'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const Key('wk-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['publish:cour:3']);
    expect(find.text('Cette page a été publiée entre-temps. Rechargez-la avant de publier.'), findsOneWidget);
  });

  testWidgets('narrateur : pas de restauration ; retour à l’édition ; 390 px', (tester) async {
    await pumpHistory(tester, user: julienUser);
    await tester.tap(find.byKey(const Key('wk-version-2')));
    await tester.pump();
    expect(find.byKey(const Key('wk-restore')), findsNothing);
    await pumpHistory(tester, width: 390);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Retour à l’édition'));
    await tester.pumpAndSettle();
    expect(find.text('édition cour'), findsOneWidget);
  });
}
