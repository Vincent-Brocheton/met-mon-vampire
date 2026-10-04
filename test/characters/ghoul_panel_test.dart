import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/ghoul_panel.dart';
import 'package:portail_met/characters/sheet_widgets.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;

import 'ghoul_test.dart' show ghoulState, mila;

void main() {
  testWidgets('état de goule : domitor, sang, échéance proche', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: GhoulPanel(ghoulState(), now: DateTime(2026, 10, 20)))),
    ));
    expect(find.text('Goule de Isaure de Valcourt · clan du domitor : Toreador'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('Buvez avant le ${formatDay(DateTime(2026, 10, 26))}, sinon son âge le rattrape : 10 ans par jour.'), findsOneWidget);
    expect(find.text('ne peut pas baisser'), findsOneWidget);
    expect(identityLine(mila()), 'Goule de Isaure de Valcourt · clan du domitor : Toreador', reason: 'revue : en-tête de la spec');
  });

  testWidgets('fiche en lecture d’une goule : panneau affiché', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: CharacterSheetView(mila()))),
    ));
    expect(find.text('ÉTAT DE GOULE'), findsOneWidget);
  });
}
