import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/creation/creation_steps.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rules/creation_rules.dart';

import '../characters/ghoul_test.dart' show mila;

List<(CheckLevel, String)> at(Character c, int step) => [for (final k in creationChecks(c)) if (k.step == step) (k.level, k.text)];

void main() {
  test('clan, génération et disciplines de goule (Review Focus 4)', () {
    final c = mila();
    expect(at(c, 3), [(CheckLevel.ok, 'Goule de Isaure de Valcourt · clan du domitor : Toreador')]);
    expect(at(c, 6).where((k) => k.$2.contains('Génération') || k.$2.contains('mortel')), isEmpty);
    setGhoulDiscipline(c, 'Auspex', 3);
    expect(at(c, 7), [(CheckLevel.todo, 'Disciplines de goule : 3 points sur 5')]);
    setGhoulDiscipline(c, 'Présence', 2);
    expect(at(c, 7), [(CheckLevel.ok, 'Disciplines de goule : 5 points sur 5')]);
    setGhoulDiscipline(c, 'Présence', 3);
    setGhoulDiscipline(c, 'Domination', 1);
    expect(at(c, 7), [
      (CheckLevel.error, 'Disciplines de goule : 7 points sur 5'),
      (CheckLevel.error, 'Présence : niveau 3 au-delà de celui du domitor (2)'),
      (CheckLevel.error, 'Domination : le domitor ne la possède pas'),
    ]);
    setGhoulDiscipline(c, 'Domination', 0);
    expect(c.disciplines.map((d) => d.name), ['Auspex', 'Présence']);
    c.backgrounds.add(Trait(generationName, 1));
    expect(at(c, 6), contains((CheckLevel.error, 'Une goule n’a pas de Génération')));
  });

  test('achats interdits, coûts Neonate, sang de goule (Review Focus 3)', () {
    final c = mila();
    expect(addPurchase(c, Buy.discipline, 'Auspex'), 'Les disciplines d’une goule ne s’achètent pas avec l’XP.');
    expect(addPurchase(c, Buy.technique, 'Regard ardent'), 'Une goule n’apprend ni technique ni pouvoir d’ancien.');
    expect(addPurchase(c, Buy.background, generationName), 'Une goule n’a pas de Génération.');
    expect(addPurchase(c, Buy.skill, 'Médecine'), isNull);
    expect(c.purchases.single.cost, 1, reason: 'Neonate : nouveau niveau × 1');
    applyDerived(c);
    expect((c.blood, c.bloodPerTurn, c.genRank, c.genNumber), (10, 1, null, null));
    expect(at(c, 9).where((k) => k.$2.contains('incohérentes')), isEmpty);
    expect(stepIntroOf(7, const CreationValues(), ghoul: true), contains('5 points'));
  });

  testWidgets('étapes : clan en lecture, disciplines du domitor, achats sans discipline', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mila();
    var step = 3;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return SingleChildScrollView(child: creationStep(step, c, () => setState(() {})));
        }),
      ),
    ));
    expect(find.text('Goule de Isaure de Valcourt · clan du domitor : Toreador'), findsOneWidget);
    rebuild(() => step = 7);
    await tester.pump();
    expect(find.text('0 / 5 points'), findsOneWidget);
    await tester.tap(find.byTooltip('Auspex : 3'));
    await tester.pump();
    expect(find.text('3 / 5 points'), findsOneWidget);
    expect(find.byTooltip('Présence : 3'), findsNothing, reason: 'plafond du domitor : 2');
    rebuild(() => step = 9);
    await tester.pump();
    await tester.tap(find.byKey(const Key('buy-kind')));
    await tester.pumpAndSettle();
    expect(find.text('Discipline'), findsNothing);
    expect(find.text('Technique'), findsOneWidget, reason: 'seulement la ligne du tableau des coûts, pas le menu');
    expect(find.text('COÛTS POUR UNE GOULE'), findsOneWidget, reason: 'titre de section en majuscules');
  });
}
