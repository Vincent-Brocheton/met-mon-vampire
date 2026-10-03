import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/xp/xp_admin_screen.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_settings.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  List<Character> sheets() => [
        sample()..decidedAt = DateTime(2026, 8, 31),
        Character.fromMap('l', {...sample().toMap(), 'name': 'Gaspard Nolin', 'playerUid': 'lea', 'playerName': 'Léa G.'})
          ..decidedAt = DateTime(2026, 8, 31),
      ];

  Future<FakeXpRepository> pump(WidgetTester tester, {XpSettings settings = const XpSettings(monthlyEnabled: true, gainSince: '2026-01')}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        xpRepositoryProvider.overrideWith((ref) => repo),
        allCharactersProvider.overrideWith((ref) => Stream.value(sheets())),
        xpSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: XpAdminScreen(now: () => DateTime(2026, 10, 15))),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('gain mensuel : détail, fiche du conteur exclue, versement', (tester) async {
    final repo = await pump(tester);
    expect(find.text('oct. 2026 : 1 fiche, 6 XP à verser'), findsOneWidget);
    expect(find.text('À verser par un autre conteur : Gaspard Nolin'), findsOneWidget);
    await tester.tap(find.text('Voir le détail'));
    await tester.pump();
    expect(find.text('2 mois (sept.–oct. 2026)'), findsOneWidget);
    await tester.tap(find.text('Verser 6 XP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verser'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['gain:x=6@2026-10']);
  });

  testWidgets('versement : fiche refusée signalée (Review Focus 1)', (tester) async {
    final repo = await pump(tester);
    repo.refused = ['Isaure de Valcourt'];
    await tester.tap(find.text('Verser 6 XP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verser'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Refusé pour : Isaure de Valcourt'), findsOneWidget);
  });

  testWidgets('gain désactivé', (tester) async {
    await pump(tester, settings: const XpSettings());
    expect(find.text('Gain mensuel désactivé'), findsOneWidget);
  });

  testWidgets('bonus : motif obligatoire, fiche du conteur non sélectionnable', (tester) async {
    final repo = await pump(tester);
    expect(tester.widget<Checkbox>(find.byKey(const Key('award-l'))).onChanged, isNull);
    await tester.tap(find.byKey(const Key('award-x')));
    await tester.pump();
    await tester.tap(find.byTooltip('Plus : Isaure de Valcourt'));
    await tester.pump();
    final button = find.widgetWithText(FilledButton, 'Attribuer à 1 fiche');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('award-reason')), 'Scène de la Cour');
    await tester.pump();
    expect(find.textContaining('dont montant ajusté 1'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attribuer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['award:Scène de la Cour:x=2']);
  });
}
