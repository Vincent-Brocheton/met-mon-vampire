import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/creation/validation_screen.dart';

import '../fakes.dart';
import 'creation_rules_test.dart' show valid;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeCharacterRepository> pump(WidgetTester tester, List<Character> queue) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        characterRepositoryProvider.overrideWith((ref) => repo),
        reviewQueueProvider.overrideWith((ref) => Stream.value(queue)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ValidationScreen())),
    ));
    await tester.pump();
    return repo;
  }

  testWidgets('file vide', (tester) async {
    await pump(tester, const []);
    expect(find.text('Aucune fiche en attente'), findsOneWidget);
  });

  testWidgets('contrôles affichés, corrections commentées, validation', (tester) async {
    final repo = await pump(tester, [valid()..status = CharacterStatus.review]);
    expect(find.text('Nikolaï Vesk'), findsWidgets);
    expect(find.text('Attributs répartis 7 / 5 / 3, un focus chacun'), findsOneWidget);
    await tester.tap(find.text('Demander des corrections'));
    await tester.pump();
    expect(find.text('Expliquez les corrections attendues.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byKey(const Key('decision-comment')), 'Précise le sire.');
    await tester.tap(find.text('Demander des corrections'));
    await tester.pump();
    expect(repo.calls, ['decide:draft:Précise le sire.']);
    await tester.tap(find.text('Valider et activer la fiche'));
    await tester.pump();
    expect(repo.calls.last, 'decide:active:Précise le sire.');
  });

  testWidgets('sa propre fiche : pas de décision', (tester) async {
    await pump(tester, [valid()
      ..status = CharacterStatus.review
      ..playerUid = 'lea']);
    expect(find.text('Valider et activer la fiche'), findsNothing);
    expect(find.textContaining('votre propre fiche'), findsOneWidget);
  });
}
