import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rule_form.dart';
import 'package:portail_met/rulebook/schema.dart';

void main() {
  Future<List<(RuleEntry, String)>> pump(WidgetTester tester, String cat, RuleEntry entry, {bool readOnly = false}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <(RuleEntry, String)>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RuleEntryForm(
            category: categoryById(cat)!,
            entry: entry,
            keyOptions: const {'sects': ['Camarilla', 'Sabbat']},
            existingNames: {nameKey('Chanceux')},
            readOnly: readOnly,
            note: 'Secret',
            onSave: (e, note) async => saved.add((e, note)),
          ),
        ),
      ),
    ));
    return saved;
  }

  testWidgets('édition d’un atout : nombre, choix, case, note', (tester) async {
    final saved = await pump(tester, 'merits', RuleEntry(id: 'm', name: 'Volonté de fer', data: {'cost': 3}));
    await tester.enterText(find.byKey(const Key('rf-cost')), '4');
    await tester.tap(find.byKey(const Key('rf-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('À la création'));
    await tester.enterText(find.byKey(const Key('rf-note')), 'À surveiller');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    final (e, note) = saved.single;
    expect(e.data, {'cost': 4, 'type': 'clan', 'atCreation': true});
    expect(note, 'À surveiller');
  });

  testWidgets('nom obligatoire, sans doublon', (tester) async {
    final saved = await pump(tester, 'merits', RuleEntry(name: ''));
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rf-name')), ' chanceux ');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    expect(find.text('Un élément porte déjà ce nom.'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('clan : liste, rareté par secte, lignées', (tester) async {
    final saved = await pump(tester, 'clans', RuleEntry(id: 'c', name: 'Tremere'));
    await tester.enterText(find.byKey(const Key('rf-disciplines')), 'Auspex\nDomination\n\nThaumaturgie');
    await tester.tap(find.byKey(const Key('rf-rarity-Sabbat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rare · 4 pts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-bloodlines-add')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rf-bloodlines-0-name')), 'Telyav');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    final e = saved.single.$1;
    expect(e.data['disciplines'], ['Auspex', 'Domination', 'Thaumaturgie']);
    expect(e.data['rarity'], {'Sabbat': 'rare'});
    expect(e.data['bloodlines'], [{'name': 'Telyav'}]);
  });

  testWidgets('lecture seule : pas de bouton', (tester) async {
    await pump(tester, 'merits', RuleEntry(id: 'm', name: 'Volonté de fer'), readOnly: true);
    expect(find.byKey(const Key('rf-save')), findsNothing);
    expect(tester.widget<TextFormField>(find.byKey(const Key('rf-name'))).enabled, isFalse);
  });
}
