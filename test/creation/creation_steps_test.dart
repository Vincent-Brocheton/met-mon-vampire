import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/creation/creation_steps.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rules/creation_rules.dart';

import 'creation_rules_test.dart' show valid;

Future<void> pumpStep(WidgetTester tester, int step, Character c, {Rulebook rb = const Rulebook()}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(withFonts: false),
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
          child: creationStep(step, c, () {
            applyDerived(c, rb: rb);
            setState(() {});
          }, rb: rb),
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

  testWidgets('étape 6 : génération proposée selon le rang', (tester) async {
    final c = valid()..genNumber = null;
    await pumpStep(tester, 6, c);
    expect(find.text('Génération'), findsWidgets);
    await tester.tap(find.byKey(const Key('generation-number')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('13e').last);
    await tester.pumpAndSettle();
    expect(c.genNumber, 13);
  });

  testWidgets('étape 7 : choisir la discipline à 2 points', (tester) async {
    final c = valid();
    await pumpStep(tester, 7, c);
    await tester.tap(find.byKey(const Key('two-Auspex')));
    await tester.pump();
    expect(freeLevelOf(c, Buy.discipline, 'Auspex'), 2);
    expect(freeLevelOf(c, Buy.discipline, 'Thaumaturgie'), 1);
  });

  testWidgets('étape 8 : ajouter un atout', (tester) async {
    final c = valid();
    await pumpStep(tester, 8, c);
    await tester.tap(find.byKey(const Key('add-merit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chanceux (2)').last);
    await tester.pumpAndSettle();
    expect(c.merits.map((m) => m.name), contains('Chanceux'));
    expect(budgetOf(c).merits, 2);
  });

  testWidgets('étape 9 : achat d’une compétence, coût affiché, retrait', (tester) async {
    final c = valid();
    await pumpStep(tester, 9, c);
    await tester.tap(find.byKey(const Key('buy-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compétence').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-name-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informatique').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('3 XP'), findsWidgets);
    expect(levelOf(c, Buy.skill, 'Informatique'), 3);
    await tester.tap(find.byTooltip('Retirer l’achat'));
    await tester.pump();
    expect(levelOf(c, Buy.skill, 'Informatique'), 2);
  });

  testWidgets('étape 10 : récit et traits dérivés', (tester) async {
    final c = valid();
    await pumpStep(tester, 10, c);
    expect(find.text('10 · 1 par tour'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-Récit du personnage — visible par vous et le conte')), 'Nouveau récit');
    expect(c.story, 'Nouveau récit');
  });

  testWidgets('étape 3 : badge et règle du conte, clan interdit pour la secte absent', (tester) async {
    final clans = baseEntries('clans');
    clans.firstWhere((e) => e.name == 'Tremere')
      ..state = RuleState.approval
      ..description = 'Pyramide stricte.';
    clans.firstWhere((e) => e.name == 'Brujah').data['rarity'] = {'Camarilla': 'forbidden'};
    final c = Character(id: 'n', name: 'N', kind: CharacterKind.pj)..sect = 'Camarilla';
    await pumpStep(tester, 3, c, rb: Rulebook({'clans': clans}));
    expect(find.text('Accord du conte'), findsOneWidget);
    expect(find.text('Pyramide stricte.'), findsOneWidget);
    expect(find.text('Brujah'), findsNothing);
  });
}
