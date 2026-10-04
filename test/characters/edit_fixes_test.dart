import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_edit_screen.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/characters/edit_widgets.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';

import '../fakes.dart';
import 'character_test.dart' show sample;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<(FakeCharacterRepository, StreamController<Character?>)> pump(WidgetTester tester, Character c) async {
    tester.view.physicalSize = const Size(1440, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    final stream = StreamController<Character?>.broadcast();
    addTearDown(stream.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea])),
        characterRepositoryProvider.overrideWith((ref) => repo),
        characterProvider('x').overrideWith((ref) => stream.stream),
        noPlaces,
        characterNotesProvider('x').overrideWith((ref) => Stream.value('')),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterEditScreen(id: 'x'))),
    ));
    stream.add(c);
    await tester.pump();
    await tester.pump();
    return (repo, stream);
  }

  Character v(int version, {int humanity = 5, String? sire}) => sample()
    ..version = version
    ..humanity = humanity
    ..sire = sire;

  testWidgets('I1 : pas de faux bandeau de conflit après son propre enregistrement', (tester) async {
    final (repo, stream) = await pump(tester, v(4));
    repo.onSaveEdit = () => stream.add(v(5, humanity: 6));
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Correction');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('quelqu’un d’autre'), findsNothing);
    expect(find.textContaining('non enregistrée'), findsNothing);
  });

  testWidgets('I2 : repartir de la dernière version garde les changements de l’autre conteur', (tester) async {
    final (_, stream) = await pump(tester, v(4));
    await tester.enterText(find.byKey(const Key('field-Sire')), 'Octave');
    await tester.pump();
    stream.add(v(5, humanity: 4)); // l'autre conteur a baissé l'Humanité
    await tester.pump();
    await tester.tap(find.text('Repartir de la dernière version'));
    await tester.pump();
    expect(find.text('1 modification non enregistrée'), findsOneWidget); // seulement le Sire
    expect(find.text('Octave'), findsOneWidget);
  });

  test('I2 : rebase réapplique seulement les champs modifiés localement', () {
    final merged = rebase(v(4), v(4, sire: 'Octave'), v(5, humanity: 4));
    expect(merged.humanity, 4);
    expect(merged.sire, 'Octave');
    expect(merged.version, 5);
  });

  testWidgets('I3 : retirer une ligne ne décale pas les domaines', (tester) async {
    final items = [Trait('Artisanat', 1, note: 'ébénisterie'), Trait('Représentation', 2, note: 'chant')];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: TraitListEditor(items: items, options: const [], noteLabel: 'Domaine', onChanged: () => setState(() {})),
          ),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Retirer Artisanat'));
    await tester.pump();
    expect(find.text('chant'), findsOneWidget);
    expect(find.text('ébénisterie'), findsNothing);
  });

  testWidgets('I4 : Annuler ne perd pas les notes en cours de saisie', (tester) async {
    await pump(tester, v(4));
    await tester.enterText(find.widgetWithText(TextField, 'Jamais visibles par les joueurs.'), 'Sire réel : Octave');
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.pump();
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(find.text('Sire réel : Octave'), findsOneWidget);
  });

  test('describeChanges reste vide après rebase sans changement local', () {
    expect(describeChanges(v(5), rebase(v(4), v(4), v(5))), isEmpty);
  });
}
