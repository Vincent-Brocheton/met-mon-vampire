import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/wiki/wiki_chronology.dart';
import 'package:portail_met/wiki/wiki_rules.dart';

import 'wiki_admin_screen_test.dart' show pumpAdmin;
import 'wiki_reader_test.dart' show pumpReader;
import 'wiki_rules_test.dart' show pagesZoe, rbWiki;

StoryEvent ev(String title, int year, {int? month, String charName = '', String description = ''}) =>
    StoryEvent(id: title, title: title, year: year, month: month, visibility: EventVisibility.public, description: description)..charName = charName;

void main() {
  test('chronologie : années de la plus récente à la plus ancienne ; nom, sinon titre seul (Review Focus 1)', () {
    final groups = timelineGroups([ev('A', 1990), ev('B', 2026, month: 3, charName: 'Isaure'), ev('C', 2026, month: 9)]);
    expect([for (final g in groups) g.$1], [2026, 1990]);
    expect([for (final e in groups.first.$2) e.title], ['C', 'B']);
    expect(timelineLine(groups.first.$2.last), 'Isaure · B');
    expect(timelineLine(groups.last.$2.single), 'A');
  });

  test('index : la chronologie est une page de « La chronique », publiée et automatique', () {
    final c = wikiIndex(rbWiki, pagesZoe(), staff: false).firstWhere((i) => i.id == chronologyId);
    expect((c.title, c.rubric, stateOf(c), originLabel(c), c.isRule), ('Chronologie publique', 'chronique', WikiState.published, 'Événements publics, automatique', false));
  });

  testWidgets('page : événements publics groupés par année', (tester) async {
    await pumpReader(tester, '/joueur/wiki/page/chronologie',
        publicEvents: [ev('Arrivée du sire', 2026, month: 3, charName: 'Isaure', description: 'À l’Opéra.'), ev('Grand incendie', 1871)]);
    expect(find.text('Chronologie publique'), findsWidgets);
    expect(find.text('Isaure · Arrivée du sire'), findsOneWidget);
    expect(find.text('À l’Opéra.'), findsOneWidget);
    expect(find.text('Grand incendie'), findsOneWidget);
    expect(find.text('1871'), findsNWidgets(2));
    expect(find.text('Le conte n’a pas encore rédigé cette page.'), findsNothing);
    await pumpReader(tester, '/joueur/wiki/page/chronologie');
    expect(find.text('Aucun événement public pour l’instant.'), findsOneWidget);
  });

  testWidgets('conte : la ligne de la chronologie ouvre sa lecture', (tester) async {
    await pumpAdmin(tester);
    final row = find.byKey(const Key('wk-row-chronologie'));
    expect(find.descendant(of: row, matching: find.text('Événements publics, automatique')), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'La chronique'));
    await tester.pump();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Aucun événement public pour l’instant.'), findsOneWidget);
  });
}
