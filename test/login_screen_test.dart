import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/login_screen.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';

import 'fakes.dart';

void main() {
  Future<FakeAuthRepository> pumpLogin(WidgetTester tester, {bool disabled = false, String? emailLink}) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => fake),
        chronicleProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: LoginScreen(disabled: disabled, emailLink: emailLink)),
    ));
    return fake;
  }

  testWidgets('champs vides : messages de validation, aucun appel', (tester) async {
    final fake = await pumpLogin(tester);
    await tester.tap(find.text('Entrer'));
    await tester.pump();
    expect(find.text('Indiquez votre adresse e-mail.'), findsOneWidget);
    expect(find.text('Champ obligatoire.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('identifiants refusés : message générique', (tester) async {
    final fake = await pumpLogin(tester);
    fake.error = FirebaseAuthException(code: 'wrong-password');
    await tester.enterText(find.byType(TextFormField).at(0), 'camille@ex.fr');
    await tester.enterText(find.byType(TextFormField).at(1), 'mauvais');
    await tester.tap(find.text('Entrer'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['signIn:camille@ex.fr']);
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('compte désactivé : message affiché', (tester) async {
    await pumpLogin(tester, disabled: true);
    expect(find.textContaining('Ce compte est désactivé'), findsOneWidget);
  });

  testWidgets('retour d’un lien e-mail : on termine la connexion', (tester) async {
    final fake = await pumpLogin(tester, emailLink: 'http://localhost/connexion?mode=signIn&oobCode=x');
    expect(find.text('Terminer la connexion'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'camille@ex.fr');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['signInWithLink:camille@ex.fr']);
  });
}
