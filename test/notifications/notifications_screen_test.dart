import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/notifications/notification_rules.dart';
import 'package:portail_met/notifications/notifications_repository.dart';
import 'package:portail_met/notifications/notifications_screen.dart';

import '../fakes.dart';

final zoe = AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur, notifSeenAt: DateTime(2026, 10, 5));

final items = [
  AppNotification(kind: NotifKind.decided, title: 'Une demande a été validée', detail: 'Isaure · la fiche est à jour.', at: DateTime(2026, 10, 10), link: '/joueur/demandes'),
  AppNotification(kind: NotifKind.xp, title: 'XP reçue : +3', detail: 'Isaure', at: DateTime(2026, 10, 1), link: '/joueur/personnages/c1/historique'),
];

Future<void> pumpNotif(WidgetTester tester, {List<AppNotification>? list, FakeNotificationsRepository? repo, AppUser? user, double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user ?? zoe)),
      notificationsProvider.overrideWith((ref) => list ?? items),
      notificationsRepositoryProvider.overrideWithValue(repo ?? FakeNotificationsRepository()),
    ],
    child: MaterialApp.router(
      theme: buildTheme(withFonts: false),
      routerConfig: GoRouter(initialLocation: '/n', routes: [
        GoRoute(path: '/n', builder: (_, _) => const Scaffold(body: NotificationsScreen())),
        GoRoute(path: '/joueur/demandes', builder: (_, _) => const Text('mes demandes')),
      ]),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('liste : non lues signalées, tout marquer comme lu, ouverture du lien', (tester) async {
    final repo = FakeNotificationsRepository();
    await pumpNotif(tester, repo: repo);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('1 non lue. La cloche en haut de l’écran les signale.'), findsOneWidget);
    expect(find.text('XP reçue : +3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nt-read')));
    await tester.pump();
    expect(repo.calls, ['read:zoe']);
    await tester.tap(find.byKey(const Key('nt-0')));
    await tester.pumpAndSettle();
    expect(find.text('mes demandes'), findsOneWidget);
  });

  testWidgets('rien de nouveau ; tout lu : bouton désactivé', (tester) async {
    await pumpNotif(tester, list: const []);
    expect(find.text('Rien de nouveau pour l’instant.'), findsOneWidget);
    expect(find.text('Aucune notification non lue.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('nt-read'))).onPressed, isNull);
    await pumpNotif(tester, user: const AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur));
    expect(find.text('2 non lues. La cloche en haut de l’écran les signale.'), findsOneWidget);
  });

  testWidgets('enregistrement refusé : message (Review Focus 3) ; 390 px', (tester) async {
    final repo = FakeNotificationsRepository()..error = Exception('hors ligne');
    await pumpNotif(tester, repo: repo);
    await tester.tap(find.byKey(const Key('nt-read')));
    await tester.pump();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.text('1 non lue. La cloche en haut de l’écran les signale.'), findsOneWidget);
    await pumpNotif(tester, width: 390);
    expect(tester.takeException(), isNull);
  });
}
