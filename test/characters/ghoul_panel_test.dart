import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/ghoul_panel.dart';
import 'package:portail_met/characters/sheet_widgets.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;

import 'ghoul_test.dart' show ghoulState, mila;

void main() {
  Widget scope(List<Bond> bonds, Widget child) => ProviderScope(
        overrides: [characterBondsProvider('g').overrideWith((ref) async => bonds)],
        child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  testWidgets('état de goule : domitor, sang, échéance proche', (tester) async {
    await tester.pumpWidget(scope(const [], GhoulPanel(ghoulState(), characterId: 'g', now: DateTime(2026, 10, 20))));
    await tester.pumpAndSettle();
    expect(find.text('Goule de Isaure de Valcourt · clan du domitor : Toreador'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('Buvez avant le ${formatDay(DateTime(2026, 10, 26))}, sinon son âge le rattrape : 10 ans par jour.'), findsOneWidget);
    expect(find.text('ne peut pas baisser'), findsOneWidget);
    expect(find.text('●○○'), findsOneWidget, reason: 'sans lien de sang enregistré : ancien niveau de la fiche');
    expect(identityLine(mila()), 'Goule de Isaure de Valcourt · clan du domitor : Toreador', reason: 'revue : en-tête de la spec');
  });

  Widget scopeAsync(Future<List<Bond>> Function() bonds) => ProviderScope(
        key: UniqueKey(),
        overrides: [characterBondsProvider('g').overrideWith((ref) => bonds())],
        child: MaterialApp(
          theme: buildTheme(withFonts: false),
          home: Scaffold(body: SingleChildScrollView(child: GhoulPanel(ghoulState(), characterId: 'g', now: DateTime(2026, 10, 20)))),
        ),
      );

  testWidgets('liens en chargement ou illisibles : pas de repli sur l’ancien niveau', (tester) async {
    await tester.pumpWidget(scopeAsync(() => Completer<List<Bond>>().future));
    await tester.pump();
    expect(find.text('●○○'), findsNothing);
    expect(find.text('…'), findsOneWidget);
    await tester.pumpWidget(scopeAsync(() => Future<List<Bond>>.error('boom')));
    await tester.pumpAndSettle();
    expect(find.text('●○○'), findsNothing);
    expect(find.text('Liens indisponibles.'), findsOneWidget);
  });

  testWidgets('lien de sang lu dans les liens, au niveau du jour', (tester) async {
    final b = Bond(
      regnantId: 'x',
      thrallId: 'g',
      level: 2,
      lastDrink: DateTime(2026, 10, 1),
      lastContact: DateTime(2026, 10, 1),
      stored: true,
    );
    await tester.pumpWidget(scope([b], GhoulPanel(ghoulState(), characterId: 'g', now: DateTime(2026, 10, 20))));
    await tester.pumpAndSettle();
    expect(find.text('●●○'), findsOneWidget);
  });

  testWidgets('fiche en lecture d’une goule : panneau affiché', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scope(const [], CharacterSheetView(mila())));
    await tester.pumpAndSettle();
    expect(find.text('ÉTAT DE GOULE'), findsOneWidget);
  });
}
