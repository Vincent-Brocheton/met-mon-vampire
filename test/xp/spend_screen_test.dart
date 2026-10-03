import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/xp/spend_screen.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  XpRequest pendingAuspex() => XpRequest(
        id: 'r0',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)],
      );

  Future<FakeXpRepository> pump(WidgetTester tester, {List<XpRequest> requests = const [], Character? sheet}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        characterProvider('x').overrideWith((ref) => Stream.value(sheet ?? sample())),
        myRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        xpRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SpendScreen(characterId: 'x'))),
          GoRoute(path: '/joueur/demandes', builder: (_, s) => Text('demandes ${s.uri.queryParameters['d']}')),
        ]),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return repo;
  }

  Future<void> choose(WidgetTester tester, Key key, String text) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('XP réservée par une autre demande : ajout impossible', (tester) async {
    await pump(tester, requests: [pendingAuspex()]);
    expect(find.text('Réservé (Auspex ●●●● · 12 XP)'), findsOneWidget);
    await choose(tester, const Key('xp-kind'), 'Humanité');
    expect(find.text('XP libre insuffisante : 10 requis, 8 restant après les achats déjà ajoutés.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Ajouter à la demande')).onPressed, isNull);
  });

  testWidgets('ajout, justification obligatoire, envoi', (tester) async {
    final repo = await pump(tester);
    await choose(tester, const ValueKey('xp-name-skill'), 'Linguistique');
    expect(find.text('— → ● · 2 XP (Nouveau niveau × 2)'), findsOneWidget);
    await tester.tap(find.text('Ajouter à la demande'));
    await tester.pump();
    final send = find.widgetWithText(FilledButton, 'Envoyer au conte · 2 XP');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('xp-why')), 'Leçons d’italien auprès du Sénéchal.');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:submit:2']);
    expect(repo.lastSaved!.justification, 'Leçons d’italien auprès du Sénéchal.');
    expect(find.text('demandes new-req'), findsOneWidget);
  });

  testWidgets('retrait par le haut seulement', (tester) async {
    await pump(tester);
    await choose(tester, const ValueKey('xp-name-skill'), 'Linguistique');
    await tester.tap(find.text('Ajouter à la demande'));
    await tester.pump();
    await tester.tap(find.text('Ajouter à la demande'));
    await tester.pump();
    expect(find.text('Envoyer au conte · 6 XP'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer Linguistique').first);
    await tester.pump();
    expect(find.text('Retirez d’abord le niveau supérieur.'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer Linguistique').last);
    await tester.pump();
    expect(find.byTooltip('Retirer Linguistique'), findsOneWidget);
  });

  testWidgets('fiche d’un autre joueur : refus', (tester) async {
    await pump(tester, sheet: sample()..playerUid = 'u2');
    expect(find.text('Cette fiche n’est pas la vôtre'), findsOneWidget);
  });
}
