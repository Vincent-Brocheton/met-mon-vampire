import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/events_screen.dart';
import 'package:portail_met/events/story_event.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  StoryEvent ev(String id, String title, {EventVisibility v = EventVisibility.player, EventType type = EventType.intrigue, int year = 2026, int? month}) =>
      StoryEvent(id: id, type: type, title: title, year: year, month: month, visibility: v, byName: 'Marc');

  final events = [
    ev('e2', 'Nommée Harpie', v: EventVisibility.public, type: EventType.titleGained, month: 3),
    ev('e1', 'Son sire arrive', v: EventVisibility.staff, month: 2),
    ev('e3', 'Étreinte à Lyon', type: EventType.embrace, year: 1998),
  ];

  Future<FakeEventsRepository> pump(WidgetTester tester, {AppUser user = lea, Character? c, Size size = const Size(1440, 1800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeEventsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        characterProvider('x').overrideWith((ref) => Stream.value(c ?? sample())),
        characterEventsProvider('x').overrideWith((ref) => Stream.value(events)),
        eventsRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterEventsScreen(characterId: 'x'))),
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

  testWidgets('ajouter un événement daté au mois, public', (tester) async {
    final repo = await pump(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('ev-save'))).onPressed, isNull, reason: 'titre obligatoire');
    expect(find.text('Titre obligatoire'), findsOneWidget);
    await choose(tester, 'ev-type', 'Chasse de sang');
    await tester.enterText(find.byKey(const Key('ev-year')), '2026');
    await choose(tester, 'ev-month', 'août');
    await tester.enterText(find.byKey(const Key('ev-title')), 'Chasse de sang prononcée');
    await tester.enterText(find.byKey(const Key('ev-desc')), 'Au musée des Beaux-Arts.');
    await tester.tap(find.byKey(const Key('ev-vis-public')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:x:new']);
    final e = repo.lastSaved!;
    expect((e.type, e.year, e.month, e.day, e.title, e.description, e.visibility, e.auto),
        (EventType.bloodHunt, 2026, 8, null, 'Chasse de sang prononcée', 'Au musée des Beaux-Arts.', EventVisibility.public, false));
  });

  testWidgets('modifier, puis supprimer après confirmation', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('ev-row-e2')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nommée Harpie'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ev-title')), 'Nommée Harpie par le Prince');
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:x:e2']);
    expect(repo.lastSaved!.title, 'Nommée Harpie par le Prince');
    await tester.tap(find.byKey(const Key('ev-row-e2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ev-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ev-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:x:e2');
  });

  testWidgets('jour sans mois impossible : retirer le mois vide le jour (Review Focus 2)', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'ev-month', 'mars');
    await choose(tester, 'ev-day', '14');
    await choose(tester, 'ev-month', '—');
    await tester.enterText(find.byKey(const Key('ev-title')), 'Nommée');
    await tester.pump();
    expect(find.text('Jour sans mois'), findsNothing);
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.month, repo.lastSaved!.day), (null, null));
  });

  testWidgets('filtres : conte seul, puis par type', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('ev-filter-staff')));
    await tester.pumpAndSettle();
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.text('Nommée Harpie'), findsNothing);
    await tester.tap(find.byKey(const Key('ev-filter-all')));
    await tester.pumpAndSettle();
    await choose(tester, 'ev-type-filter', 'Étreinte');
    expect(find.text('Étreinte à Lyon'), findsOneWidget);
    expect(find.text('Son sire arrive'), findsNothing);
  });

  testWidgets('refus d’écriture : message', (tester) async {
    final repo = await pump(tester);
    repo.error = Exception('refus');
    await tester.enterText(find.byKey(const Key('ev-title')), 'Torpeur');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ev-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
  });

  testWidgets('narrateur, ou conte sur sa propre fiche : lecture seule (Review Focus 5)', (tester) async {
    await pump(tester, user: julien);
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.byKey(const Key('ev-save')), findsNothing);
    await pump(tester, c: Character(id: 'x', name: 'Léa joue', kind: CharacterKind.pj, playerUid: 'lea', status: CharacterStatus.active));
    expect(find.text('Son sire arrive'), findsOneWidget);
    expect(find.byKey(const Key('ev-save')), findsNothing);
  });

  testWidgets('mobile : la liste, puis le formulaire en pleine page', (tester) async {
    await pump(tester, size: const Size(390, 1600));
    expect(find.byKey(const Key('ev-save')), findsNothing);
    await tester.tap(find.byKey(const Key('ev-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ev-save')), findsOneWidget);
    expect(find.text('← Retour'), findsOneWidget);
  });
}
