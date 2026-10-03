import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_edit_screen.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';

import '../fakes.dart';
import 'character_test.dart' show sample;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeCharacterRepository> pump(WidgetTester tester, Character c, {AppUser me = lea}) async {
    tester.view.physicalSize = const Size(1440, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        currentUserProvider.overrideWith((ref) => Stream.value(me)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea])),
        characterRepositoryProvider.overrideWith((ref) => repo),
        characterProvider('x').overrideWith((ref) => Stream.value(c)),
        characterNotesProvider('x').overrideWith((ref) => Stream.value('')),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterEditScreen(id: 'x'))),
    ));
    await tester.pump();
    return repo;
  }

  Character withHumanity() => sample()..humanity = 5;

  testWidgets('un point d’Humanité, motif obligatoire, enregistrement', (tester) async {
    final repo = await pump(tester, withHumanity());
    expect(find.textContaining('modification non enregistrée'), findsNothing);
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.pump();
    expect(find.text('1 modification non enregistrée'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Humanité 5 → 6'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.text('Indiquez un motif.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reason')), 'Correction');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveEdit:Correction']);
  });

  testWidgets('Annuler restaure exactement la fiche lue (Review Focus 5)', (tester) async {
    await pump(tester, withHumanity());
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.enterText(find.byKey(const Key('field-Sire')), 'Octave');
    await tester.pump();
    expect(find.text('2 modifications non enregistrées'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(find.textContaining('non enregistrée'), findsNothing);
    expect(find.text('Octave'), findsNothing);
  });

  testWidgets('valeur hors liste conservée dans le menu (Review Focus 4)', (tester) async {
    await pump(tester, withHumanity()..clan = 'Baali');
    expect(find.text('Baali'), findsOneWidget);
  });

  testWidgets('brouillon de PJ : lecture seule pour le conteur', (tester) async {
    await pump(tester, withHumanity()..status = CharacterStatus.draft);
    expect(find.textContaining('c’est au joueur de la remplir'), findsOneWidget);
    expect(find.byTooltip('Ajouter un point : Humanité'), findsNothing);
  });

  testWidgets('sa propre fiche : lecture seule (Review Focus 3)', (tester) async {
    await pump(tester, withHumanity()..playerUid = 'lea');
    expect(find.textContaining('votre propre fiche'), findsOneWidget);
    expect(find.byTooltip('Ajouter un point : Humanité'), findsNothing);
  });
}
