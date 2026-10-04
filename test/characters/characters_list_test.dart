import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/characters/characters_list_screen.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../fakes.dart';

void main() {
  testWidgets('C2 : compteur, recherche, création d’un PNJ', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea])),
        characterRepositoryProvider.overrideWith((ref) => repo),
        allCharactersProvider.overrideWith((ref) => Stream.value([
              Character(id: '1', name: 'Isaure', kind: CharacterKind.pj, playerName: 'Camille R.', status: CharacterStatus.active),
              Character(id: '2', name: 'Bastien Roche', kind: CharacterKind.pj, playerName: 'Karim L.', status: CharacterStatus.active),
              Character(id: '3', name: 'Sœur Agathe', kind: CharacterKind.pnj, status: CharacterStatus.active),
            ])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: CharactersListScreen())),
          GoRoute(path: '/conteur/fiches/:id', builder: (_, s) => Text('édition ${s.pathParameters['id']}')),
        ]),
      ),
    ));
    await tester.pump();
    expect(find.text('3 fiches · 2 PJ actifs · 1 PNJ'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'isaure');
    await tester.pump();
    expect(find.text('Isaure'), findsOneWidget);
    expect(find.text('Bastien Roche'), findsNothing);

    await tester.tap(find.text('Nouvelle fiche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNJ').last); // le segment de la fenêtre, pas le filtre
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, 'Le Shérif Ansel');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['create:pnj:Le Shérif Ansel']);
    expect(find.text('édition new-id'), findsOneWidget);
  });

  testWidgets('filtres : clans du référentiel', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rulebookProvider.overrideWith((ref) => Rulebook({
              'clans': [RuleEntry(name: 'Ishtarri'), RuleEntry(name: 'Toreador')],
            })),
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea])),
        characterRepositoryProvider.overrideWith((ref) => FakeCharacterRepository()),
        allCharactersProvider.overrideWith((ref) => Stream.value(const <Character>[])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: CharactersListScreen())),
        ]),
      ),
    ));
    await tester.pump();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Clan'));
    await tester.pumpAndSettle();
    expect(find.text('Ishtarri'), findsWidgets);
  });

  testWidgets('C2 : nouvelle goule, avec son joueur et son domitor (6c)', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
    const ines = AppUser(uid: 'u2', displayName: 'Inès T.', email: 'i@ex.fr', role: Role.joueur);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea, ines])),
        characterRepositoryProvider.overrideWith((ref) => repo),
        allCharactersProvider.overrideWith((ref) => Stream.value([
              Character(id: '1', name: 'Isaure', kind: CharacterKind.pj, playerName: 'Camille R.', status: CharacterStatus.active)
                ..clan = 'Toreador'
                ..disciplines = [Discipline('Auspex', 3, inClan: true)],
            ])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: CharactersListScreen())),
          GoRoute(path: '/conteur/fiches/:id', builder: (_, s) => Text('édition ${s.pathParameters['id']}')),
        ]),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Nouvelle fiche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goule').last);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Mila Ferreira');
    await tester.tap(find.byKey(const Key('new-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inès T.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-domitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isaure').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['create:pj:Mila Ferreira']);
    expect((repo.lastGhoul!.domitorName, repo.lastGhoul!.domitorClan), ('Isaure', 'Toreador'));
  });

  testWidgets('C2 : nouvelle goule, liste des fiches rafraîchie pendant le choix (revue)', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    List<Character> sheets() => [
          Character(id: '1', name: 'Isaure', kind: CharacterKind.pj, playerName: 'Camille R.', status: CharacterStatus.active)
            ..clan = 'Toreador'
            ..disciplines = [Discipline('Auspex', 3, inClan: true)],
        ];
    final chars = StreamController<List<Character>>.broadcast();
    addTearDown(chars.close);
    const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
    const ines = AppUser(uid: 'u2', displayName: 'Inès T.', email: 'i@ex.fr', role: Role.joueur);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseRulebook,
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea, ines])),
        characterRepositoryProvider.overrideWith((ref) => repo),
        allCharactersProvider.overrideWith((ref) => chars.stream),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: CharactersListScreen())),
          GoRoute(path: '/conteur/fiches/:id', builder: (_, s) => Text('édition ${s.pathParameters['id']}')),
        ]),
      ),
    ));
    await tester.pump();
    chars.add(sheets());
    await tester.pump();
    await tester.tap(find.text('Nouvelle fiche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goule').last);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Mila Ferreira');
    await tester.tap(find.byKey(const Key('new-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inès T.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-domitor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isaure').last);
    await tester.pumpAndSettle();
    chars.add(sheets()); // un autre conteur enregistre une fiche : nouvelles instances
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['create:pj:Mila Ferreira']);
    expect((repo.lastGhoul!.domitorName, repo.lastGhoul!.domitorClan), ('Isaure', 'Toreador'));
  });
}
