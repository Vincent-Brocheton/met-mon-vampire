import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/creation/creation_steps.dart';
import 'package:portail_met/rules/creation_rules.dart';

import 'creation_rules_test.dart' show valid;

Future<void> pumpStep(WidgetTester tester, int step, Character c) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(withFonts: false),
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
          child: creationStep(step, c, () {
            applyDerived(c);
            setState(() {});
          }),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('étape 3 : choisir un clan fixe ses disciplines', (tester) async {
    final c = Character(id: 'n', name: 'N', kind: CharacterKind.pj);
    await pumpStep(tester, 3, c);
    await tester.tap(find.text('Brujah'));
    await tester.pump();
    expect(c.clan, 'Brujah');
    expect(c.disciplines.map((d) => d.name), containsAll(['Célérité', 'Puissance', 'Présence']));
  });

  testWidgets('étape 4 : classer les catégories et choisir les focus', (tester) async {
    final c = Character(id: 'n', name: 'N', kind: CharacterKind.pj);
    await pumpStep(tester, 4, c);
    await tester.tap(find.byKey(const Key('rank-0-mental')));
    await tester.tap(find.byKey(const Key('rank-1-social')));
    await tester.tap(find.byKey(const Key('rank-2-physical')));
    await tester.pump();
    expect(c.attributes[AttrCategory.mental]!.value, 7);
    await tester.tap(find.byKey(const Key('rank-0-social')));
    await tester.pump();
    expect(c.attributeRanks, [AttrCategory.social, null, AttrCategory.physical]);
    await tester.tap(find.text('Dextérité'));
    await tester.pump();
    expect(c.attributes[AttrCategory.physical]!.focus, 'Dextérité');
  });

  testWidgets('étape 5 : niveau gratuit d’une compétence et domaine', (tester) async {
    final c = valid();
    await pumpStep(tester, 5, c);
    await tester.tap(find.byTooltip('Représentation : 1'));
    await tester.pump();
    expect(levelOf(c, Buy.skill, 'Représentation'), 1);
    expect(find.byKey(const Key('field-Domaine de Représentation')), findsOneWidget);
  });
}
