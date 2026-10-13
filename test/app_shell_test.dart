import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/notifications/notifications_repository.dart';
import 'package:portail_met/shell/app_shell.dart';

void main() {
  test('destination active : préfixe le plus long', () {
    final items = destinationsFor(Role.joueur);
    expect(items[selectedIndex(items, '/joueur')!].label, 'Accueil');
    expect(items[selectedIndex(items, '/joueur/pnj')!].label, 'PNJ confiés');
    expect(selectedIndex(items, '/compte'), isNull);
  });

  test('le narrateur n’a pas l’onglet Comptes', () {
    expect(destinationsFor(Role.narrateur).map((d) => d.label), isNot(contains('Comptes')));
    expect(destinationsFor(Role.conteur).map((d) => d.label), contains('Comptes'));
  });

  Future<void> pumpShell(WidgetTester tester, Size size, {int unread = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const user = AppUser(uid: 'm', displayName: 'Marc D.', email: 'm@ex.fr', role: Role.conteur);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        chronicleProvider.overrideWith((ref) => Stream.value(null)),
        pendingUsersProvider.overrideWith((ref) => Stream.value(const [])),
        unreadNotificationsProvider.overrideWith((ref) => unread),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: const AppShell(location: '/conteur', child: Text('contenu')),
      ),
    ));
    await tester.pump();
  }

  testWidgets('Web : en-tête avec les onglets', (tester) async {
    await pumpShell(tester, const Size(1440, 900));
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Comptes'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('contenu'), findsOneWidget);
  });

  testWidgets('Mobile : barre d’onglets et Plus', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Plus'), findsOneWidget);
  });

  testWidgets('cloche : point rouge s’il y a des notifications non lues (Web et mobile)', (tester) async {
    await pumpShell(tester, const Size(1440, 900));
    expect(tester.widget<Badge>(find.byKey(const Key('nt-bell'))).isLabelVisible, isFalse);
    await pumpShell(tester, const Size(1440, 900), unread: 2);
    expect(tester.widget<Badge>(find.byKey(const Key('nt-bell'))).isLabelVisible, isTrue);
    await pumpShell(tester, const Size(390, 800), unread: 1);
    expect(tester.widget<Badge>(find.byKey(const Key('nt-bell'))).isLabelVisible, isTrue);
  });
}
