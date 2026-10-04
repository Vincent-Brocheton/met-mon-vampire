import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/items/items_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'item_rules_test.dart' show cane, rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Item phone() => Item(
        id: 'r1',
        name: 'Téléphone sécurisé',
        category: ItemCategory.gear,
        qualities: ['Sécurisé'],
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        state: ItemState.requested,
        origin: 'Acheté avec ses Ressources.',
        version: 1,
      );

  Future<FakeItemsRepository> pump(WidgetTester tester, {AppUser user = lea, List<Item>? items}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeItemsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        itemsRepositoryProvider.overrideWith((ref) => repo),
        allItemsProvider.overrideWith((ref) => Stream.value(items ?? [cane(), phone()])),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ItemsScreen())),
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

  testWidgets('créer un objet et le donner : joueur recopié, version 0', (tester) async {
    final repo = await pump(tester, items: const []);
    await tester.tap(find.byKey(const Key('it-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('it-name')), 'Dague');
    await tester.pump();
    expect(find.text('Arme de mêlée : dégâts 1 normal · 1 main'), findsOneWidget);
    await choose(tester, 'it-q0', 'Précise');
    await choose(tester, 'it-holder', 'Isaure de Valcourt');
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    final i = repo.lastSaved!;
    expect((i.name, i.characterId, i.characterName, i.playerUid, i.state), ('Dague', 'x', 'Isaure de Valcourt', 'u1', ItemState.active));
    expect(i.qualities, ['Précise']);
    expect(repo.lastBefore!.version, 0);
  });

  testWidgets('erreurs : enregistrement bloqué', (tester) async {
    final repo = await pump(tester, items: const []);
    await tester.tap(find.byKey(const Key('it-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(find.text('Nom obligatoire'), findsOneWidget);
    expect(find.text('Corrigez les erreurs avant d’enregistrer.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('qualité devenue interdite : erreur, enregistrement bloqué (Review Focus 4)', (tester) async {
    final repo = await pump(tester, items: [cane()..qualities = ['Fer froid']]);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    expect(find.text('Fer froid est interdite'), findsOneWidget);
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('joueur du porteur changé : recopié à l’enregistrement (Review Focus 5)', (tester) async {
    final repo = await pump(tester, items: [cane()..playerUid = 'ancien']);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.playerUid, 'u1');
  });

  testWidgets('changement de catégorie : seules les qualités de la nouvelle catégorie restent', (tester) async {
    final repo = await pump(tester, items: [cane()..extraQuality = 'Chef-d’œuvre']);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await choose(tester, 'it-category', 'Matériel divers');
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.qualities, ['Dissimulable']);
    expect(repo.lastSaved!.extraQuality, 'Chef-d’œuvre');
  });

  testWidgets('demande : valider', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('it-row-r1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Acheté avec ses Ressources.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('it-validate')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.state, ItemState.active);
    expect(repo.lastReason, 'Demande validée');
  });

  testWidgets('demande invalide : validation bloquée sans changer l’état, refus possible', (tester) async {
    final repo = await pump(tester, items: [phone()..qualities = ['Fer froid', 'Brutale']]);
    await tester.tap(find.byKey(const Key('it-row-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-validate')));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.descendant(of: find.byKey(const Key('it-state')), matching: find.text('Demande à valider')), findsOneWidget);
    await tester.tap(find.byKey(const Key('it-refuse')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refusal')), 'Qualités non autorisées.');
    await tester.tap(find.byKey(const Key('refusal-ok')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.state, repo.lastSaved!.refusal), (ItemState.refused, 'Qualités non autorisées.'));
  });

  testWidgets('demande : refuser avec motif', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('it-row-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-refuse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refusal-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Indiquez un motif.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const Key('it-refuse')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refusal')), 'Trop cher.');
    await tester.tap(find.byKey(const Key('refusal-ok')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.state, repo.lastSaved!.refusal, repo.lastReason), (ItemState.refused, 'Trop cher.', 'Demande refusée'));
  });

  testWidgets('confisquer puis supprimer', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await choose(tester, 'it-state', 'Confisqué');
    await tester.enterText(find.byKey(const Key('it-reason')), 'Fouille à l’Élysée');
    await tester.tap(find.byKey(const Key('it-save')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.state, repo.lastReason), (ItemState.confiscated, 'Fouille à l’Élysée'));
    await tester.tap(find.byKey(const Key('it-row-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('it-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:i1');
  });

  testWidgets('filtre des demandes', (tester) async {
    await pump(tester);
    await choose(tester, 'it-state-filter', 'Demandes à valider');
    expect(find.byKey(const Key('it-row-r1')), findsOneWidget);
    expect(find.byKey(const Key('it-row-i1')), findsNothing);
  });

  testWidgets('narrateur en lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('it-new')), findsNothing);
  });
}
