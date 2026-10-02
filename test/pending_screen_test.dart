import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/pending_screen.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';

import 'fakes.dart';

void main() {
  Future<FakeAuthRepository> pump(WidgetTester tester, AppUser? profile) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => fake),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        currentUserProvider.overrideWith((ref) => Stream.value(profile)),
        chronicleProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const PendingScreen()),
    ));
    await tester.pump();
    return fake;
  }

  testWidgets('profil absent : « Finaliser ma demande » relance la création', (tester) async {
    final fake = await pump(tester, null);
    await tester.tap(find.text('Finaliser ma demande'));
    await tester.pump();
    expect(fake.calls, ['ensureProfile']);
  });

  testWidgets('en attente : vérification d’une invitation', (tester) async {
    const zoe = AppUser(uid: 'z', displayName: 'Zoé A.', email: 'zoe@ex.fr', role: Role.pending);
    final fake = await pump(tester, zoe);
    expect(find.textContaining('Un conteur va valider votre compte'), findsOneWidget);
    await tester.tap(find.text('J’ai confirmé mon e-mail'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['applyInvitation']);
    expect(find.textContaining('Aucune invitation'), findsOneWidget);
  });
}
