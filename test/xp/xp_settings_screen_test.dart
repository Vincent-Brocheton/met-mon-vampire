import 'dart:async';

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

  Future<FakeXpRepository> pump(WidgetTester tester, {AppUser user = lea, XpSettings settings = const XpSettings(monthlyEnabled: true, gainSince: '2026-10')}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        xpRepositoryProvider.overrideWith((ref) => repo),
        xpSettingsProvider.overrideWith((ref) => Stream.value(settings)),
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

  testWidgets('réactiver le gain : pas de rattrapage des mois désactivés (revue finale)', (tester) async {
    final repo = await pump(tester, settings: const XpSettings(gainSince: '2026-01'));
    await tester.tap(find.byKey(const Key('gain-enabled')));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(repo.calls.single, startsWith('settings:true:2026-10:'));
  });

  testWidgets('modification par un autre conteur : écran rechargé (petits défauts)', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = StreamController<XpSettings>();
    addTearDown(source.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        xpRepositoryProvider.overrideWith((ref) => FakeXpRepository()),
        xpSettingsProvider.overrideWith((ref) => source.stream),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: XpSettingsScreen(now: () => DateTime(2026, 10, 3)))),
    ));
    source.add(XpSettings(monthlyEnabled: true, gainSince: '2026-10', updatedAt: DateTime(2026, 9, 1), updatedByName: 'Léa G.'));
    await tester.pumpAndSettle();
    source.add(XpSettings(monthlyEnabled: true, gainSince: '2026-10', tiers: const [XpTier(null, 5, 1)], updatedAt: DateTime(2026, 10, 2), updatedByName: 'Marc D.'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dernière modification par Marc D.'), findsOneWidget);
    expect(find.text('Après 1 an : 60 XP'), findsOneWidget);
  });

  testWidgets('utilisateur pas encore chargé : attente (petits défauts)', (tester) async {
    final never = StreamController<AppUser?>();
    addTearDown(never.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => never.stream),
        xpSettingsProvider.overrideWith((ref) => Stream.value(const XpSettings())),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: XpSettingsScreen())),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('menu des paramètres : équipe réservée au principal (petits défauts)', (tester) async {
    Future<void> show(AppUser user) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [currentUserProvider.overrideWith((ref) => Stream.value(user))],
        child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ParametersScreen())),
      ));
      await tester.pumpAndSettle();
    }

    await show(lea);
    expect(find.text('Équipe de conteurs'), findsNothing);
    await show(const AppUser(uid: 'boss', displayName: 'Marc D.', email: 'm@ex.fr', role: Role.principal));
    expect(find.text('Équipe de conteurs'), findsOneWidget);
  });

  testWidgets('narrateur : accès refusé', (tester) async {
    await pump(tester, user: julien);
    expect(find.text('Réservé aux conteurs'), findsOneWidget);
  });
}
