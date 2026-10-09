import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/titles/court_entry.dart';
import 'package:portail_met/titles/court_screen.dart';
import 'package:portail_met/titles/titles_repository.dart';

import 'title_rules_test.dart' show rbTitles;

void main() {
  Future<void> pump(WidgetTester tester, Stream<List<CourtEntry>> court, {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        rulebookProvider.overrideWith((ref) => rbTitles),
        courtProvider.overrideWith((ref) => court),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CourtScreen())),
    ));
    await tester.pump();
    await tester.pump();
  }

  final entries = [
    CourtEntry(characterId: 'a', name: 'Octave Marchetti', title: 'Sénéchal', sect: 'Camarilla', under: 'Prince', since: DateTime(2019, 3, 1)),
    const CourtEntry(characterId: 'b', name: 'Lucie Arnaud', title: 'Harpie', sect: 'Camarilla', under: 'Sénéchal'),
    const CourtEntry(characterId: 'c', name: 'Jonas Ferrand', title: 'Baron', sect: 'Anarchs'),
  ];

  testWidgets('titres publics groupés par secte, en retrait sous leur supérieur', (tester) async {
    await pump(tester, Stream.value(entries));
    expect(find.text('La Cour'), findsOneWidget);
    expect(find.byKey(const Key('co-sect-Camarilla')), findsOneWidget);
    expect(find.byKey(const Key('co-sect-Anarchs')), findsOneWidget);
    expect(find.text('Octave Marchetti · depuis mars 2019'), findsOneWidget);
    expect(find.text('Lucie Arnaud'), findsOneWidget);
    final senechal = tester.getTopLeft(find.byKey(const Key('co-title-Sénéchal'))).dx;
    final harpie = tester.getTopLeft(find.byKey(const Key('co-title-Harpie'))).dx;
    expect(harpie, greaterThan(senechal));
  });

  testWidgets('aucun titre public ; 390 px', (tester) async {
    await pump(tester, Stream.value(const []));
    expect(find.text('Aucun titre public pour l’instant.'), findsOneWidget);
    await pump(tester, Stream.value(entries), width: 390);
    expect(tester.takeException(), isNull);
  });
}
