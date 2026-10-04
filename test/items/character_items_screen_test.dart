import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/items/character_items_screen.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'item_rules_test.dart' show cane, rb;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  Item refused() => Item(
        id: 'f1',
        name: 'Fusil',
        category: ItemCategory.ranged,
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        state: ItemState.refused,
        refusal: 'Trop voyant.',
        version: 2,
      );

  Future<FakeItemsRepository> pump(WidgetTester tester, {List<Item>? items}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeItemsRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        rulebookProvider.overrideWith((ref) => rb),
        itemsRepositoryProvider.overrideWith((ref) => repo),
        characterItemsProvider('x').overrideWith((ref) => Stream.value(items ?? [cane(), refused()])),
        characterProvider('x').overrideWith((ref) => Stream.value(sample())),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterItemsScreen(characterId: 'x'))),
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

  testWidgets('demander un objet : envoyé pour le personnage, au nom du joueur', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byKey(const Key('rq-name')), 'Téléphone sécurisé');
    await choose(tester, 'rq-category', 'Matériel divers');
    await choose(tester, 'rq-q0', 'Sécurisé');
    await tester.enterText(find.byKey(const Key('rq-origin')), 'Acheté avec ses Ressources.');
    await tester.tap(find.byKey(const Key('rq-send')));
    await tester.pumpAndSettle();
    final r = repo.lastRequest!;
    expect((r.name, r.category, r.characterId, r.characterName, r.playerUid, r.origin, r.extraQuality),
        ('Téléphone sécurisé', ItemCategory.gear, 'x', 'Isaure de Valcourt', 'u1', 'Acheté avec ses Ressources.', null));
    expect(r.qualities, ['Sécurisé']);
  });

  testWidgets('demande invalide : pas d’envoi ; ni interdite ni hors limite proposées', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('rq-send')));
    await tester.pumpAndSettle();
    expect(find.text('Nom obligatoire'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.byKey(const Key('rq-extra')), findsNothing);
    await choose(tester, 'rq-category', 'Arme de mêlée');
    await tester.tap(find.byKey(const Key('rq-q0')));
    await tester.pumpAndSettle();
    expect(find.text('Brutale'), findsWidgets);
    expect(find.text('Fer froid'), findsNothing);
    expect(find.text('Chef-d’œuvre'), findsNothing);
  });

  testWidgets('liste : motif du refus, suppression d’une demande refusée seulement', (tester) async {
    final repo = await pump(tester);
    expect(find.text('Motif : Trop voyant.'), findsOneWidget);
    expect(find.byKey(const Key('rq-delete-i1')), findsNothing);
    await tester.tap(find.byKey(const Key('rq-delete-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls, ['deleteRequest:f1']);
  });
}
