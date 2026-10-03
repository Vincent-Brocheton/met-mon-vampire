import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/referential_screen.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rules_repository.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Map<String, List<RuleEntry>> data() => {
        'merits': [
          RuleEntry(id: 'm1', name: 'Chanceux', vo: 'Lucky', data: {'cost': 2, 'type': 'general'}, updatedAt: DateTime(2026, 9, 1)),
          RuleEntry(id: 'm2', name: 'Visage angélique', data: {'cost': 1, 'type': 'clan'}, updatedAt: DateTime(2026, 9, 1)),
          RuleEntry(id: 'm3', name: 'Volonté de fer', state: RuleState.forbidden, data: {'cost': 3}, updatedAt: DateTime(2026, 9, 1)),
        ],
      };

  Future<FakeRulesRepository> pump(WidgetTester tester, {String cat = 'merits', AppUser user = lea, Stream<Map<String, List<RuleEntry>>>? source, Stream<Map<String, Map<String, dynamic>>>? settings, double width = 1440}) async {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRulesRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulesRepositoryProvider.overrideWith((ref) => repo),
        allRuleEntriesProvider.overrideWith((ref) => source ?? Stream.value(data())),
        allRuleSettingsProvider.overrideWith((ref) => settings ?? Stream.value(const {})),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => Scaffold(body: ReferentialScreen(categoryId: cat))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('liste, recherche, filtre par état', (tester) async {
    await pump(tester);
    expect(find.text('Chanceux'), findsOneWidget);
    expect(find.text('Volonté de fer'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ref-search')), 'luck');
    await tester.pump();
    expect(find.text('Chanceux'), findsOneWidget);
    expect(find.text('Volonté de fer'), findsNothing);
    await tester.enterText(find.byKey(const Key('ref-search')), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Interdit'));
    await tester.pump();
    expect(find.text('Chanceux'), findsNothing);
    expect(find.text('Volonté de fer'), findsOneWidget);
  });

  testWidgets('modifier puis enregistrer', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rf-cost')), '3');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Chanceux:available']);
    expect(repo.lastSaved!.data['cost'], 3);
  });

  testWidgets('modifié par un autre conteur : recharger ou écraser (Review Focus 2)', (tester) async {
    final controller = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(controller.close);
    controller.add(data());
    final repo = await pump(tester, source: controller.stream);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    final changed = data();
    changed['merits']![0] = RuleEntry(id: 'm1', name: 'Chanceux', data: {'cost': 5}, updatedAt: DateTime(2026, 10, 2), updatedByName: 'Marc D.');
    controller.add(changed);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.text('Modifié par Marc D. à l’instant'), findsOneWidget);
    await tester.tap(find.text('Écraser'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Chanceux:available']);
    expect(repo.lastSaved!.data['cost'], 2);
  });

  testWidgets('supprimer un élément utilisé : marquer Interdit (Review Focus 3)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Visage angélique'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Utilisé par 1 fiche'), findsOneWidget);
    await tester.tap(find.text('Marquer Interdit'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Visage angélique:forbidden']);
  });

  testWidgets('renommer un élément utilisé : confirmation', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Visage angélique'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rf-name')), 'Visage de porcelaine');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 fiche porte l’ancien nom'), findsOneWidget);
    await tester.tap(find.text('Renommer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Visage de porcelaine:available']);
  });

  testWidgets('catégorie vide : charger les valeurs de base', (tester) async {
    final repo = await pump(tester, cat: 'archetypes');
    await tester.tap(find.byKey(const Key('ref-base')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['import:archetypes:20']);
  });

  testWidgets('import : aperçu puis écriture (Review Focus 1)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('ref-io')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-text')),
      'name;state;cost\nVisage angélique;available;2\nNouveau;available;1\n;available;1',
    );
    await tester.tap(find.byKey(const Key('import-analyse')));
    await tester.pumpAndSettle();
    expect(find.text('1 nouveau, 1 modifié, 1 ligne en erreur'), findsOneWidget);
    expect(find.text('Modifié : Visage angélique (utilisé par 1 fiche)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-go')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['import:merits:2']);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('ref-new')), findsNothing);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rf-save')), findsNothing);
  });

  RuleEntry chanceux(DateTime at, String by, int cost) =>
      RuleEntry(id: 'm1', name: 'Chanceux', data: {'cost': cost}, updatedAt: at, updatedByName: by);

  testWidgets('second enregistrement : le conflit est encore détecté (revue)', (tester) async {
    final controller = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(controller.close);
    controller.add(data());
    final repo = await pump(tester, source: controller.stream);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    controller.add(data()..['merits']![0] = chanceux(DateTime(2026, 10, 1), 'Léa G.', 2));
    await tester.pumpAndSettle();
    controller.add(data()..['merits']![0] = chanceux(DateTime(2026, 10, 2), 'Marc D.', 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.text('Modifié par Marc D. à l’instant'), findsOneWidget);
    expect(repo.calls, ['save:merits:Chanceux:available']);
  });

  testWidgets('après « Marquer Interdit », le formulaire suit (revue)', (tester) async {
    final controller = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(controller.close);
    controller.add(data());
    final repo = await pump(tester, source: controller.stream);
    await tester.tap(find.text('Visage angélique'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marquer Interdit'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('rf-state')), matching: find.text('Interdit')), findsOneWidget);
    controller.add(data()
      ..['merits']![1] = RuleEntry(
          id: 'm2', name: 'Visage angélique', state: RuleState.forbidden, data: {'cost': 1, 'type': 'clan'},
          updatedAt: DateTime(2026, 10, 1), updatedByName: 'Léa G.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Modifié par'), findsNothing);
    expect(repo.calls, ['save:merits:Visage angélique:forbidden', 'save:merits:Visage angélique:forbidden']);
  });

  testWidgets('import refusé : message, bouton de nouveau actif (revue)', (tester) async {
    final repo = await pump(tester);
    repo.importError = Exception('refusé');
    await tester.tap(find.byKey(const Key('ref-io')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-text')), 'name;state\nNouveau;available');
    await tester.tap(find.byKey(const Key('import-analyse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-go')));
    await tester.pumpAndSettle();
    expect(find.text('Import impossible. Réessayez.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('import-go'))).onPressed, isNotNull);
  });

  testWidgets('paramètres : rechargés si un autre conteur les change, champ vidé supprimé (revue)', (tester) async {
    final settings = StreamController<Map<String, Map<String, dynamic>>>();
    addTearDown(settings.close);
    settings.add({'rituals': {'costPerLevel': 2, 'updatedAt': Timestamp(1, 0)}});
    final repo = await pump(tester, cat: 'rituals', settings: settings.stream);
    await tester.tap(find.text('Paramètres de la catégorie'));
    await tester.pumpAndSettle();
    String cost() => tester
        .widget<EditableText>(find.descendant(of: find.byKey(const Key('rs-costPerLevel')), matching: find.byType(EditableText)))
        .controller
        .text;
    expect(cost(), '2');
    settings.add({'rituals': {'costPerLevel': 3, 'updatedAt': Timestamp(2, 0)}});
    await tester.pumpAndSettle();
    expect(cost(), '3');
    await tester.enterText(find.byKey(const Key('rs-costPerLevel')), '');
    await tester.tap(find.text('Enregistrer les paramètres'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['settings:rituals']);
    expect(repo.lastSettings, {'costPerLevel': null});
    expect(find.text('Paramètres enregistrés.'), findsOneWidget);
  });

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;

  testWidgets('écriture en attente : pas de faux conflit (revue)', (tester) async {
    final controller = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(controller.close);
    controller.add(data()..['merits']![0] = RuleEntry(id: 'm1', name: 'Chanceux', data: {'cost': 2}));
    final repo = await pump(tester, source: controller.stream);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    controller.add(data()..['merits']![0] = chanceux(DateTime(2026, 10, 1), 'Léa G.', 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Modifié par'), findsNothing);
    expect(repo.calls, ['save:merits:Chanceux:available']);
  });

  testWidgets('note : un seul abonnement malgré les reconstructions (revue)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ref-search')), 'c');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ref-search')), 'ch');
    await tester.pump();
    expect(repo.noteWatches, 1);
  });

  testWidgets('écran moyen : le menu se replie quand le formulaire est ouvert (revue)', (tester) async {
    await pump(tester, width: 1100);
    expect(find.text('Handicaps'), findsOneWidget);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    expect(find.text('Handicaps'), findsNothing);
  });

  testWidgets('modifications non enregistrées : confirmation avant de changer d’élément (revue)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rf-cost')), '9');
    await tester.tap(find.text('Volonté de fer'));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    await tester.tap(find.text('Continuer l’édition'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'rf-cost'), '9');
    await tester.tap(find.text('Volonté de fer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'rf-name'), 'Volonté de fer');
  });

  testWidgets('élément supprimé par un autre conteur : le formulaire reste, avec un avertissement (revue)', (tester) async {
    final controller = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(controller.close);
    controller.add(data());
    final repo = await pump(tester, source: controller.stream);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    controller.add(data()..['merits']!.removeAt(0));
    await tester.pumpAndSettle();
    expect(find.textContaining('supprimé entre-temps'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Chanceux:available']);
  });

  testWidgets('valeurs de base : un double clic n’importe qu’une fois (revue)', (tester) async {
    final repo = await pump(tester, cat: 'archetypes');
    repo.importGate = Completer<void>();
    await tester.tap(find.byKey(const Key('ref-base')));
    await tester.tap(find.byKey(const Key('ref-base')));
    repo.importGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.calls, ['import:archetypes:20']);
  });

  testWidgets('nouvel atout : proposé à la création et à l’XP par défaut (revue)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('ref-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rf-name')), 'Mécène');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.data, {'atCreation': true, 'withXp': true});
  });
}
