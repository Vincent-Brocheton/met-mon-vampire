import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/places/character_places_screen.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/places/places_repository.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import 'place_rules_test.dart' show opera, rb;

void main() {
  Widget app(Widget child, {List<Place> public = const []}) => ProviderScope(
        overrides: [
          rulebookProvider.overrideWith((ref) => rb),
          characterProvider('x').overrideWith((ref) => Stream.value(sample())),
          characterPlacesProvider('x').overrideWith((ref) => Stream.value([opera()])),
          publicPlacesProvider.overrideWith((ref) => Stream.value(public)),
        ],
        child: MaterialApp.router(
          theme: buildTheme(withFonts: false),
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child))),
            GoRoute(path: '/joueur/personnages/x/lieux', builder: (_, _) => const Text('page des lieux')),
          ]),
        ),
      );

  testWidgets('ses lieux en détail, les lieux publics des autres, rien de privé', (tester) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(
      const CharacterPlacesScreen(characterId: 'x'),
      public: [
        Place(id: 'p1', name: 'Opéra municipal', type: PlaceType.prestige, known: 'Une salle prestigieuse.'),
        Place(id: 'p2', name: 'Hôtel de ville', type: PlaceType.prestige, known: 'La mairie.'),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Opéra municipal'), findsOneWidget, reason: 'le lieu public déjà à soi n’est pas répété');
    expect(find.text('Qualités : Artistique · Luxe · Hanté · Élysée · Compromis ×2'), findsOneWidget);
    expect(find.text('À vous seul'), findsOneWidget);
    expect(find.text('Hôtel de ville'), findsOneWidget);
    expect(find.text('La mairie.'), findsOneWidget);
  });

  testWidgets('section « Lieux » de la fiche : noms et lien', (tester) async {
    await tester.pumpWidget(app(const PlacesSection(characterId: 'x', link: '/joueur/personnages/x/lieux')));
    await tester.pumpAndSettle();
    expect(find.text('Opéra municipal'), findsOneWidget);
    await tester.tap(find.text('Voir les lieux'));
    await tester.pumpAndSettle();
    expect(find.text('page des lieux'), findsOneWidget);
  });
}
