import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/morality/derangements_player.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'derangement_rules_test.dart' show fire, rb;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  Future<FakeXpRepository> pump(WidgetTester tester, Character c, {List<XpRequest> requests = const []}) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        myRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        xpRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: PlayerDerangements(character: c, rb: rb, basePath: '/joueur/personnages/x'))),
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

  testWidgets('liste, compteur, rappel ; demande envoyée à 0 XP', (tester) async {
    final repo = await pump(tester, sample()
      ..derangements = [fire()]
      ..derangementTraits = 1);
    expect(find.text('Peur du feu'), findsOneWidget);
    expect(find.text('●○○'), findsOneWidget);
    expect(find.text('Handicaps de 2 points, déclencheur au choix.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('de-clan')), findsNothing, reason: 'le joueur ne déclare pas de dérangement de clan');
    await choose(tester, 'de-model', 'Mégalomanie');
    await tester.enterText(find.byKey(const Key('de-trigger')), 'Être contredit en public');
    await tester.enterText(find.byKey(const Key('de-why')), 'Suite à l’humiliation à l’Élysée.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('de-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:submit:0']);
    final r = repo.lastSaved!;
    final i = r.items.single;
    expect((i.kind, i.name, i.fromLevel, i.toLevel, i.cost), (XpKind.derangement, 'Mégalomanie', 0, 1, 0));
    expect(i.derangement, {'type': 'belief', 'trigger': 'Être contredit en public', 'severe': false, 'clan': false});
    expect(r.justification, 'Suite à l’humiliation à l’Élysée.');
  });

  testWidgets('demande ouverte : « En attente du conte » ; doublon refusé (Review Focus 2)', (tester) async {
    await pump(tester, sample()..derangements = [fire()], requests: [
      XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.derangement, 'Mégalomanie', 0, 1, 0, derangement: {'type': 'belief', 'trigger': '', 'severe': false, 'clan': false})],
      ),
    ]);
    expect(find.byKey(const Key('de-pending-Mégalomanie')), findsOneWidget);
    expect(find.text('En attente du conte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-ask')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('de-name')), 'mégalomanie');
    await tester.enterText(find.byKey(const Key('de-why')), 'Encore.');
    await tester.pump();
    expect(find.text('Un dérangement porte déjà ce nom'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('de-name')), 'Peur du feu');
    await tester.pump();
    expect(find.text('Un dérangement porte déjà ce nom'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('de-save'))).onPressed, isNull);
  });

  testWidgets('fiche inactive : pas de demande', (tester) async {
    await pump(tester, sample()..status = CharacterStatus.retired);
    expect(find.byKey(const Key('de-ask')), findsNothing);
  });

  testWidgets('390 px : pas de débordement', (tester) async {
    await pump(tester, sample()
      ..derangements = [fire()]
      ..derangementTraits = 1, requests: [
      XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.derangement, 'Mégalomanie', 0, 1, 0, derangement: {'type': 'belief', 'trigger': '', 'severe': false, 'clan': false})],
      ),
    ]);
    tester.view.physicalSize = const Size(390, 844);
    await tester.tap(find.byKey(const Key('de-ask')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
