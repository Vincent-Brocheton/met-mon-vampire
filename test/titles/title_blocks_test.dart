import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/titles/title_blocks.dart';
import 'package:portail_met/titles/titles_repository.dart';

import '../fakes.dart';
import 'title_rules_test.dart' show agathe, lucie, octave, rbTitles;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeTitlesRepository> pump(WidgetTester tester, Widget child, {Stream<List<Character>>? chars, double width = 1200}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeTitlesRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allCharactersProvider.overrideWith((ref) => chars ?? Stream.value([lucie(), octave(), agathe()])),
        titlesRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: SingleChildScrollView(child: child))),
    ));
    await tester.pump();
    await tester.pump();
    return repo;
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('conte : attribuer un titre, avec motif', (tester) async {
    final repo = await pump(tester, StaffTitle(character: lucie(), rb: rbTitles, canEdit: true));
    await choose(tester, 'ti-title', 'Harpie');
    await tester.enterText(find.byKey(const Key('ti-since')), '01/03/2026');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ti-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Nommée à l’Élysée');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['assign:luc:Harpie']);
    expect((repo.lastSince, repo.lastReason), (DateTime(2026, 3, 1), 'Nommée à l’Élysée'));
  });

  testWidgets('conte : titre unique déjà tenu, refus visible, pas d’écriture (Review Focus 1)', (tester) async {
    final repo = await pump(tester, StaffTitle(character: lucie(), rb: rbTitles, canEdit: true));
    await choose(tester, 'ti-title', 'Sénéchal');
    expect(find.text('Sénéchal est déjà tenu par Octave Marchetti.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('ti-save'))).onPressed, isNull);
    expect(repo.calls, isEmpty);
  });

  testWidgets('conte : titre unique pris pendant le motif, refus avant écriture (Review Focus 1)', (tester) async {
    final live = StreamController<List<Character>>();
    addTearDown(live.close);
    live.add([lucie(), agathe()]);
    final repo = await pump(tester, StaffTitle(character: lucie(), rb: rbTitles, canEdit: true), chars: live.stream);
    await choose(tester, 'ti-title', 'Sénéchal');
    await tester.tap(find.byKey(const Key('ti-save')));
    await tester.pumpAndSettle();
    live.add([lucie(), octave(), agathe()]);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('reason')), 'Nommé');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.text('Sénéchal est déjà tenu par Octave Marchetti.'), findsWidgets);
  });

  testWidgets('conte : retirer le titre ; hors liste signalé', (tester) async {
    final repo = await pump(tester, StaffTitle(character: lucie()..title = 'Ancien rang', rb: rbTitles, canEdit: true));
    expect(find.textContaining('hors liste'), findsOneWidget);
    await choose(tester, 'ti-title', 'Aucun');
    await tester.tap(find.byKey(const Key('ti-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Destitué');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['assign:luc:aucun']);
  });

  testWidgets('conte : refus du dépôt, formulaire gardé', (tester) async {
    final repo = await pump(tester, StaffTitle(character: lucie(), rb: rbTitles, canEdit: true));
    repo.error = Exception('refus');
    await choose(tester, 'ti-title', 'Harpie');
    await tester.tap(find.byKey(const Key('ti-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'x');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.text('Harpie'), findsWidgets);
  });

  testWidgets('conte : lecture seule et fiches non lues', (tester) async {
    await pump(tester, StaffTitle(character: octave(), rb: rbTitles, canEdit: false));
    expect(find.byKey(const Key('ti-save')), findsNothing);
    expect(find.text('Sénéchal · depuis mars 2019'), findsOneWidget);
    final pending = StreamController<List<Character>>();
    addTearDown(pending.close);
    await pump(tester, StaffTitle(character: lucie(), rb: rbTitles, canEdit: true), chars: pending.stream);
    expect(find.byKey(const Key('ti-save')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('joueur : son titre, ou rien s’il est caché (Review Focus 2)', (tester) async {
    await pump(tester, PlayerTitle(character: lucie()
      ..title = 'Harpie'
      ..titleSince = DateTime(2026, 3, 1), rb: rbTitles, basePath: '/joueur/personnages/luc'));
    expect(find.text('Harpie · depuis mars 2026'), findsOneWidget);
    expect(find.byKey(const Key('ti-court')), findsOneWidget);
    await pump(tester, PlayerTitle(character: lucie()..title = 'Main du Prince', rb: rbTitles, basePath: '/joueur/personnages/luc'));
    expect(find.text('Aucun titre.'), findsOneWidget);
    expect(find.textContaining('Main du Prince'), findsNothing);
  });

  testWidgets('390 px : bloc du conte sans débordement', (tester) async {
    await pump(tester, StaffTitle(character: lucie(), rb: rbTitles, canEdit: true), width: 390);
    await choose(tester, 'ti-title', 'Baron');
    expect(tester.takeException(), isNull);
  });

  testWidgets('conte : « Depuis » reprend la date de la fiche, puis le jour si le titre change (I2)', (tester) async {
    final today = DateTime.now();
    final day = '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
    await pump(tester, StaffTitle(character: octave(), rb: rbTitles, canEdit: true));
    expect(find.widgetWithText(TextField, '01/03/2019'), findsOneWidget);
    await choose(tester, 'ti-title', 'Harpie');
    expect(find.widgetWithText(TextField, day), findsOneWidget);
  });

  testWidgets('conte : titre tenu sans date, Enregistrer reste inactif sans changement (I2)', (tester) async {
    await pump(tester, StaffTitle(character: agathe(), rb: rbTitles, canEdit: true));
    expect(tester.widget<FilledButton>(find.byKey(const Key('ti-save'))).onPressed, isNull);
  });

  testWidgets('joueur : le lien de la Cour suit l’espace (I4)', (tester) async {
    String? went;
    Future<void> go(String base) async {
      await tester.pumpWidget(MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => Scaffold(body: PlayerTitle(character: lucie(), rb: rbTitles, basePath: base))),
            GoRoute(path: '/:a/cour', builder: (_, s) { went = s.uri.path; return const Scaffold(); }),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ti-court')));
      await tester.pumpAndSettle();
    }
    await go('/conteur/fiches/luc');
    expect(went, '/conteur/cour');
    await go('/joueur/personnages/luc');
    expect(went, '/joueur/cour');
  });
}
