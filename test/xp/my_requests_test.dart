import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/character_screen.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/xp/my_requests_screen.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  XpRequest changes() => XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.changes,
        items: [const XpItem(XpKind.merit, 'Chanceux', 0, 2, 2)],
        justification: 'Une chance insolente sur scène.',
        thread: [XpMessage('lea', 'Léa G.', DateTime(2026, 9, 26), 'Précise l’origine de ce trait.')],
        submittedAt: DateTime(2026, 9, 12),
      );

  XpRequest accepted() => XpRequest(
        id: 'r2',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.accepted,
        items: [const XpItem(XpKind.discipline, 'Présence', 1, 2, 6)],
        submittedAt: DateTime(2026, 9, 2),
      );

  Future<FakeXpRepository> pump(WidgetTester tester, List<XpRequest> requests) async {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        myCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
        myRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        xpRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: MyRequestsScreen())),
          GoRoute(path: '/joueur/personnages/:id/xp', builder: (_, s) => Text('dépense ${s.pathParameters['id']} ${s.uri.queryParameters['demande']}')),
        ]),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return repo;
  }

  testWidgets('onglets, détail, réponse obligatoire puis renvoi', (tester) async {
    final repo = await pump(tester, [accepted(), changes()]);
    expect(find.text('En cours · 1'), findsOneWidget);
    expect(find.text('Traitées · 1'), findsOneWidget);
    expect(find.text('Précise l’origine de ce trait.'), findsOneWidget);
    expect(find.text('Les 2 XP restent réservés tant que la demande est ouverte.'), findsOneWidget);
    await tester.tap(find.text('Renvoyer au conte'));
    await tester.pump();
    expect(find.text('Écrivez votre réponse.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reply')), 'Elle chante depuis l’enfance.');
    await tester.tap(find.text('Renvoyer au conte'));
    await tester.pump();
    expect(repo.calls, ['reply:Elle chante depuis l’enfance.']);
  });

  testWidgets('annuler une demande, avec confirmation', (tester) async {
    final repo = await pump(tester, [changes()]);
    await tester.tap(find.text('Annuler la demande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler la demande').last);
    await tester.pumpAndSettle();
    expect(repo.calls, ['cancel:r1']);
  });

  testWidgets('dépenser : un seul personnage actif, accès direct', (tester) async {
    await pump(tester, const []);
    expect(find.text('Aucune demande pour l’instant.'), findsOneWidget);
    await tester.tap(find.text('Dépenser de l’XP'));
    await tester.pumpAndSettle();
    expect(find.text('dépense x null'), findsOneWidget);
  });

  test('historique : le filtre « Statut » ignore les entrées d’XP', () {
    HistoryEntry e(String kind) => HistoryEntry(id: kind, at: null, byName: '', kind: kind, summary: const [], reason: '');
    for (final k in ['xp', 'award', 'gain', 'correction']) {
      expect(HistoryFilter.status.matches(e(k)), isFalse, reason: k);
    }
    expect(HistoryFilter.status.matches(e('validation')), isTrue);
  });
}
