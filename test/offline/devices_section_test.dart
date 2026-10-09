import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/devices_repository.dart';
import 'package:portail_met/offline/devices_section.dart';

import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  final now = DateTime(2099, 10, 3, 21);
  final devices = [
    Device(id: 'd1', name: 'Navigateur · Windows', web: true, lastSeen: DateTime(2099, 10, 3, 18)),
    Device(id: 'd2', name: 'Android', lastSeen: DateTime(2099, 10, 2, 20), gameId: 'g2', preparedAt: DateTime(2099, 10, 2, 20)),
    Device(id: 'd3', name: 'Navigateur · Android', web: true, lastSeen: DateTime(2099, 9, 29), revokedAt: DateTime(2099, 10, 3, 20)),
  ];

  Future<(FakeDevicesRepository, List<String>)> pump(WidgetTester tester, {Size size = const Size(1440, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeDevicesRepository();
    final signedOut = <String>[];
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        myDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        deviceIdProvider.overrideWith((ref) async => 'd1'),
        gamesProvider.overrideWith((ref) => Stream.value([frozenGame(year: 2099)])),
        devicesRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(
          body: SingleChildScrollView(child: DevicesSection(now: () => now, onSignOut: () async => signedOut.add('moi'))),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (repo, signedOut);
  }

  testWidgets('liste : cet appareil, copie hors ligne, déconnexion en attente', (tester) async {
    await pump(tester);
    expect(find.text('APPAREILS CONNECTÉS'), findsOneWidget);
    expect(find.text('Navigateur · Windows · Cet appareil'), findsOneWidget);
    expect(find.text('Connexion web · aujourd’hui'), findsOneWidget);
    expect(find.text('Copie hors ligne · partie du 3 oct. · hier'), findsOneWidget);
    expect(find.text('Déconnexion en attente'), findsOneWidget);
    expect(find.text('Retirer'), findsNothing);
    expect(find.byKey(const Key('device-d3')), findsNothing);
    expect(find.text('Déconnecter un appareil efface aussi sa copie hors ligne.'), findsOneWidget);
    expect(find.text('Un appareil hors ligne est déconnecté à son prochain passage en ligne.'), findsOneWidget);
  });

  testWidgets('déconnecter un autre appareil : confirmation, puis marque', (tester) async {
    final (repo, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('device-d2')));
    await tester.pumpAndSettle();
    expect(find.text('Déconnecter « Android » ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Déconnecter'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['revoke:u1/d2']);
  });

  testWidgets('déconnecter un autre appareil : annuler ne fait rien', (tester) async {
    final (repo, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('device-d2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('cet appareil : même effet que « Se déconnecter »', (tester) async {
    final (repo, signedOut) = await pump(tester);
    await tester.tap(find.byKey(const Key('device-d1')));
    await tester.pumpAndSettle();
    expect(signedOut, ['moi']);
    expect(repo.calls, isEmpty);
  });

  testWidgets('mobile, 390 px', (tester) async {
    await pump(tester, size: const Size(390, 1200));
    expect(tester.takeException(), isNull);
  });
}
