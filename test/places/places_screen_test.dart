import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/places/places_repository.dart';
import 'package:portail_met/places/places_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'place_rules_test.dart' show opera, rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Future<FakePlacesRepository> pump(WidgetTester tester, {AppUser user = lea, List<Place>? places}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakePlacesRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        placesRepositoryProvider.overrideWith((ref) => repo),
        allPlacesProvider.overrideWith((ref) => Stream.value(places ?? [opera()])),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: PlacesScreen())),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('créer un lieu, l’attribuer, trop de qualités : avertissement, enregistrement possible', (tester) async {
    final repo = await pump(tester, places: const []);
    await tester.tap(find.byKey(const Key('pl-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pl-name')), 'Les docks');
    await choose(tester, 'pl-add-holder', 'Isaure de Valcourt (PJ)');
    await choose(tester, 'pl-add-quality', 'Artistique');
    await choose(tester, 'pl-add-quality', 'Luxe');
    expect(find.text('2 qualités sur 1 : trop pour un lieu standard de rang 1'), findsOneWidget);
    expect(find.text('Quête simple, difficulté 1 · infiltration en jeu : difficulté 5'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pl-note')), 'Contrebande.');
    await tester.tap(find.byKey(const Key('pl-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:Les docks']);
    expect(repo.lastSaved!.holderPlayers, ['u1']);
    expect(repo.lastSaved!.qualities.map((q) => q.name), ['Artistique', 'Luxe']);
    expect(repo.lastNote, 'Contrebande.');
  });

  testWidgets('connu de tous décoché, qualité négative, motif (Review Focus 1)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Opéra municipal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pl-public')));
    await tester.tap(find.byTooltip('Ajouter : Compromis'));
    await tester.enterText(find.byKey(const Key('pl-reason')), 'Sabotage réussi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pl-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.public, isFalse);
    expect(repo.lastSaved!.qualities.firstWhere((q) => q.name == 'Compromis').count, 3);
    expect(repo.lastReason, 'Sabotage réussi');
  });

  testWidgets('modifié entre-temps : message (Review Focus 3)', (tester) async {
    final repo = await pump(tester);
    repo.error = Exception('version');
    await tester.tap(find.text('Opéra municipal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pl-save')));
    await tester.pumpAndSettle();
    expect(find.text('Modifié entre-temps : rechargez la page.'), findsOneWidget);
  });

  testWidgets('retirer à tous, puis supprimer : confirmations', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Opéra municipal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pl-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.holders, isEmpty);
    expect(repo.lastReason, 'Retiré à tous');
    await tester.tap(find.byKey(const Key('pl-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:p1');
  });

  testWidgets('recherche par nom de personnage', (tester) async {
    await pump(tester, places: [opera(), Place(id: 'p2', name: 'Entrepôt 14')]);
    expect(find.text('Entrepôt 14'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pl-search')), 'isaure');
    await tester.pump();
    expect(find.text('Entrepôt 14'), findsNothing);
    expect(find.text('Opéra municipal'), findsOneWidget);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('pl-new')), findsNothing);
    await tester.tap(find.text('Opéra municipal'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pl-save')), findsNothing);
  });
}
