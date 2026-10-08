import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/events/story_screen.dart';

import '../characters/character_test.dart' show sample;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  // Le provider renvoie volontairement un événement « conte seul » : l'écran doit le filtrer (Review Focus 3).
  final events = [
    StoryEvent(id: 'e1', title: 'Son sire arrive', year: 2026, month: 2, visibility: EventVisibility.staff),
    StoryEvent(id: 'e2', type: EventType.titleGained, title: 'Nommée Harpie', year: 2026, month: 3, visibility: EventVisibility.public),
    StoryEvent(id: 'e3', type: EventType.embrace, title: 'Étreinte au soir de sa dernière représentation', year: 1974),
  ];

  Future<void> pump(WidgetTester tester, AppUser user, Character c, {Size size = const Size(1440, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        characterProvider('x').overrideWith((ref) => Stream.value(c)),
        characterEventsProvider('x').overrideWith((ref) => Stream.value(events)),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: const Scaffold(body: CharacterStoryScreen(characterId: 'x', basePath: '/joueur/personnages/x')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Character isaure() => sample()
    ..concept = 'Cantatrice lyrique devenue faiseuse de réputations.'
    ..story = 'Soprano admirée de l’opéra municipal.';

  testWidgets('joueur : récit et événements ouverts, jamais « conte seul » (Review Focus 3)', (tester) async {
    await pump(tester, camille, isaure());
    expect(find.text('Cantatrice lyrique devenue faiseuse de réputations.'), findsOneWidget);
    expect(find.text('Soprano admirée de l’opéra municipal.'), findsOneWidget);
    expect(find.text('Nommée Harpie'), findsOneWidget);
    expect(find.text('Étreinte au soir de sa dernière représentation'), findsOneWidget);
    expect(find.text('Son sire arrive'), findsNothing);
    expect(find.text('Vous et le conte'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
  });

  testWidgets('équipe : tous les événements', (tester) async {
    await pump(tester, lea, isaure());
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.text('Conte seul'), findsOneWidget);
    expect(find.text('Joueur et conte'), findsOneWidget);
  });

  testWidgets('équipe sur sa propre fiche : pas de « conte seul »', (tester) async {
    await pump(tester, lea, isaure()..playerUid = 'lea');
    expect(find.text('Son sire arrive'), findsNothing);
    expect(find.text('Vous et le conte'), findsOneWidget);
  });

  testWidgets('sans récit ; mobile en une colonne', (tester) async {
    await pump(tester, camille, sample()..story = null, size: const Size(390, 1600));
    expect(find.text('Aucun récit.'), findsOneWidget);
    expect(find.text('Nommée Harpie'), findsOneWidget);
  });
}
