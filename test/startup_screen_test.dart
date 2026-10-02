import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/chronicle/startup_screen.dart';
import 'package:portail_met/core/theme.dart';

void main() {
  testWidgets('principal, chronique sans nom : « Nommer » ouvre le formulaire', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const marc = AppUser(uid: 'm', displayName: 'Marc D.', email: 'm@ex.fr', role: Role.principal);
    const config = ChronicleConfig(name: 'x', associationName: 'x', defaultSect: 'Camarilla', ownerUid: 'm');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(marc)),
        chronicleProvider.overrideWith((ref) => Stream.value(config)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: StartupScreen())),
    ));
    await tester.pump();
    expect(find.text('1 étape terminée sur 6.'), findsOneWidget);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Nom de la chronique'), findsOneWidget);
  });
}
