import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_settings.dart';
import 'package:portail_met/xp/xp_settings_screen.dart';

import '../fakes.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Future<FakeXpRepository> pump(WidgetTester tester, {AppUser user = lea}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        xpRepositoryProvider.overrideWith((ref) => repo),
        xpSettingsProvider.overrideWith((ref) => Stream.value(const XpSettings(monthlyEnabled: true, gainSince: '2026-10'))),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: XpSettingsScreen(now: () => DateTime(2026, 10, 3))),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('paliers par défaut, cumuls, enregistrement', (tester) async {
    final repo = await pump(tester);
    expect(find.text('Après 10 ans : 216 XP'), findsOneWidget);
    expect(find.text('Ensuite, sans limite'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tier-0-xp')), '4');
    await tester.pump();
    expect(find.text('Après 1 an : 48 XP'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(repo.calls, ['settings:true:2026-10:36/4/1,36/2/1,24/1/1,null/1/2']);
  });

  testWidgets('valeurs hors bornes : enregistrement impossible', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('tier-0-xp')), '30');
    await tester.pump();
    expect(find.text('Palier 1 : le gain va de 0 à 20 XP.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer')).onPressed, isNull);
  });

  testWidgets('ajouter un palier : l’ancien dernier prend une durée', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('tier-add')));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(repo.calls.single, 'settings:true:2026-10:36/3/1,36/2/1,24/1/1,12/1/2,null/1/2');
  });

  testWidgets('narrateur : accès refusé', (tester) async {
    await pump(tester, user: julien);
    expect(find.text('Réservé aux conteurs'), findsOneWidget);
  });
}
