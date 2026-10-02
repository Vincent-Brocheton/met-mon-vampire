import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/sheet_widgets.dart';
import 'package:portail_met/core/theme.dart';

import 'character_test.dart' show sample;

void main() {
  for (final (label, size) in [('Web', const Size(1440, 1800)), ('Mobile', const Size(390, 3200))]) {
    testWidgets('$label : toutes les sections de J2', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: CharacterSheetView(sample()))),
      ));
      for (final text in ['IDENTITÉ', 'TRAITS DÉRIVÉS', 'EXPÉRIENCE', 'ATTRIBUTS', 'COMPÉTENCES', 'HISTORIQUES', 'DISCIPLINES', 'ATOUTS ET HANDICAPS']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Représentation'), findsOneWidget);
      expect(find.text('chant lyrique'), findsOneWidget);
      expect(find.text('Focus : Charisme'), findsOneWidget);
      expect(find.text('Toreador'), findsOneWidget);
      expect(find.text('20'), findsOneWidget); // XP disponible
    });
  }
}
