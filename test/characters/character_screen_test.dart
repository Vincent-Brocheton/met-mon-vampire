import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/character_screen.dart';
import 'package:portail_met/core/theme.dart';

import '../fakes.dart';
import 'character_test.dart' show sample;

void main() {
  Future<void> pump(WidgetTester tester, Stream<Character?> stream, {bool history = false}) async {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        characterProvider('x').overrideWith((ref) => stream),
        noPlaces,
        noServantFiles,
        noItems,
        characterHistoryProvider('x').overrideWith((ref) => Stream.value([
              HistoryEntry(id: 'h', at: DateTime(2026, 9, 2), byName: 'Léa', kind: 'edit', summary: ['Présence ● → ●●'], reason: 'Demande validée', xpSpent: 6),
            ])),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: CharacterScreen(id: 'x', basePath: '/joueur/personnages/x', history: history)),
      ),
    ));
    await tester.pump();
    await tester.pump(); // l'historique s'abonne une fois la fiche chargée
  }

  testWidgets('J2 : en-tête et fiche', (tester) async {
    await pump(tester, Stream.value(sample()));
    expect(find.text('Isaure de Valcourt'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('COMPÉTENCES'), findsOneWidget);
  });

  testWidgets('J6 : historique avec motif et XP', (tester) async {
    await pump(tester, Stream.value(sample()), history: true);
    expect(find.text('Présence ● → ●●'), findsOneWidget);
    expect(find.textContaining('Demande validée'), findsOneWidget);
    expect(find.text('− 6'), findsOneWidget);
  });

  testWidgets('fiche d’un autre joueur : accès refusé explicite (Review Focus 2)', (tester) async {
    await pump(tester, Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')));
    expect(find.text('Cette fiche n’est pas la vôtre'), findsOneWidget);
  });

  testWidgets('fiche absente : page introuvable', (tester) async {
    await pump(tester, Stream.value(null));
    expect(find.text('Cette fiche n’existe pas'), findsOneWidget);
  });
}
