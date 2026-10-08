import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_player.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/core/theme.dart';

import 'bond_rules_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Bond> bonds, {Size size = const Size(1000, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [characterBondsProvider('luc').overrideWith((ref) async => bonds)],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: PlayerBonds(character: lucie(), today: today))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('liens subis et exercés, en lecture ; lien effacé absent (Review Focus 3)', (tester) async {
    final gone = link(agathe(), lucie(), 1, DateTime(2025, 1, 1));
    await pump(tester, [octLuc(), lucLem(), gone]);
    expect(find.text('Octave Marchetti'), findsOneWidget);
    expect(find.text('2 gorgées · dernière le 20 sept.'), findsOneWidget);
    expect(find.text('Disparaît après six mois sans le voir ni lui parler.'), findsOneWidget);
    expect(find.text('Dr Lemaire'), findsOneWidget);
    expect(find.text('votre goule'), findsOneWidget);
    expect(find.text('Dernière gorgée le 1er sept. · à renforcer avant le 1er déc.'), findsOneWidget);
    expect(find.text('●●○'), findsOneWidget);
    expect(find.text('●●●'), findsOneWidget);
    expect(find.text('Sœur Agathe'), findsNothing);
    expect(find.text('2 gorgées : 1 Volonté par heure pour lui nuire. 3 gorgées : lien complet, qui efface les liens moindres.'), findsOneWidget);
    expect(find.text('Le conte choisit ce que vous savez des liens envers vous.'), findsOneWidget);
    expect(find.text('+ Gorgée'), findsNothing);
  });

  Future<void> pumpAsync(WidgetTester tester, Future<List<Bond>> Function() bonds) async {
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [characterBondsProvider('luc').overrideWith((ref) => bonds())],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: PlayerBonds(character: lucie(), today: today))),
      ),
    ));
    await tester.pump();
  }

  testWidgets('liens en chargement : indicateur, pas « Aucun lien. »', (tester) async {
    await pumpAsync(tester, () => Completer<List<Bond>>().future);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(find.text('Aucun lien.'), findsNothing);
  });

  testWidgets('erreur de lecture : « Liens indisponibles. », pas « Aucun lien. »', (tester) async {
    await pumpAsync(tester, () => Future<List<Bond>>.error('boom'));
    await tester.pumpAndSettle();
    expect(find.text('Liens indisponibles.'), findsNWidgets(2));
    expect(find.text('Aucun lien.'), findsNothing);
  });

  testWidgets('aucun lien ; 390 px sans débordement', (tester) async {
    await pump(tester, const []);
    expect(find.text('Aucun lien.'), findsNWidgets(2));
    await pump(tester, [octLuc(), lucLem()], size: const Size(390, 1400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('390 px : nom de régnant très long, sans débordement', (tester) async {
    final long = link(octave()..name = 'Octave de Marchetti-Valcourt dit le Vieux Sage des Collines Lointaines', lucie(), 2, DateTime(2026, 9, 20));
    await pump(tester, [long], size: const Size(390, 1400));
    expect(find.textContaining('Octave de Marchetti-Valcourt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
