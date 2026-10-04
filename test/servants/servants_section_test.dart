import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/edit_widgets.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servant_rules.dart';
import 'package:portail_met/servants/servants_repository.dart';
import 'package:portail_met/servants/servants_section.dart';

import 'servant_rules_test.dart' show isaure, rexFile;

void main() {
  final released = ServantFile(id: 'x-old', kind: 'human', name: 'Bruno', domitorId: 'x', releasedAt: DateTime.now(), version: 2);

  Widget app(Widget child) => ProviderScope(
        overrides: [
          characterProvider('x').overrideWith((ref) => Stream.value(isaure())),
          characterServantFilesProvider('x').overrideWith((ref) => Stream.value([rexFile(), released])),
        ],
        child: MaterialApp.router(
          theme: buildTheme(withFonts: false),
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child))),
            GoRoute(path: '/s/:sid', builder: (_, s) => Text('serviteur ${s.pathParameters['sid']}')),
          ]),
        ),
      );

  testWidgets('section : serviteurs, à compléter, points indisponibles, lien (Review Focus 5)', (tester) async {
    await tester.pumpWidget(app(ServantsSection(character: isaure(), linkOf: (id) => '/s/$id')));
    await tester.pumpAndSettle();
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mila'), findsOneWidget);
    expect(find.text('à compléter'), findsOneWidget);
    expect(find.text('Bruno : points indisponibles jusqu’au ${formatDay(unavailableUntil(released.releasedAt!, released.releasedRank))}'), findsOneWidget);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    expect(find.text('serviteur x-s1'), findsOneWidget);
  });

  testWidgets('fiche du joueur : détail sans note secrète', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const ServantScreen(characterId: 'x', servantId: 'x-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Rex'), findsWidgets);
    expect(find.text('Réserve 4 · santé 2 · pas de Volonté'), findsOneWidget);
    expect(find.text('Spécialités : Bagarre'), findsOneWidget);
    expect(find.text('Qualités animales : Costaud'), findsOneWidget);
    expect(find.text('Garde le salon.'), findsOneWidget);
    expect(find.textContaining('Note secrète'), findsNothing);
  });

  testWidgets('C3 : ajouter, renommer, retirer un serviteur', (tester) async {
    final items = <Servant>[Servant('x-s1', 'Rex', ServantKind.animal, 2)];
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: ServantListEditor(characterId: 'x', items: items, onChanged: () => setState(() => changes++)),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('+ Serviteur'));
    await tester.pump();
    expect(items, hasLength(2));
    expect(items.last.id, startsWith('x-s'));
    await tester.enterText(find.byKey(ValueKey('servant-name-${items.last.id}')), 'Mila');
    await tester.pump();
    expect(items.last.name, 'Mila');
    await tester.enterText(find.byKey(ValueKey('servant-name-${items.last.id}')), 'B' * 90);
    await tester.pump();
    expect(items.last.name.length, 80, reason: 'revue : 80 caractères au plus');
    await tester.enterText(find.byKey(ValueKey('servant-name-${items.last.id}')), 'Mila');
    await tester.pump();
    await tester.tap(find.text('+ Serviteur'));
    await tester.pump();
    expect(items.last.name, 'Nouveau serviteur', reason: 'revue : nom par défaut sans doublon');
    await tester.enterText(find.byKey(ValueKey('servant-name-${items.last.id}')), 'rex');
    await tester.pump();
    expect(find.text('Deux serviteurs portent le même nom : Rex'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer rex'));
    await tester.pump();
    await tester.tap(find.byTooltip('Retirer Rex'));
    await tester.pump();
    expect(items.map((s) => s.name), ['Mila']);
    expect(changes, greaterThanOrEqualTo(3));
  });
}
