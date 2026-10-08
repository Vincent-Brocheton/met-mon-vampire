import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/bonds/bonds_screen.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';

import '../fakes.dart';
import 'bond_rules_test.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Future<FakeBondsRepository> pump(WidgetTester tester, {AppUser user = lea, Size size = const Size(1440, 1400), List<Character>? chars}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeBondsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        allBondsProvider.overrideWith((ref) => Stream.value([octJon(), octLuc(), agaBas(), lucLem()])),
        allCharactersProvider.overrideWith((ref) => Stream.value(chars ?? cast())),
        bondsRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: BondsScreen(today: today))),
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

  Finder inKey(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  testWidgets('compteurs, liens triés par échéance', (tester) async {
    await pump(tester);
    expect(find.text('Liens de sang de la chronique'), findsOneWidget);
    expect(inKey('bo-stat-active', '4'), findsOneWidget);
    expect(inKey('bo-stat-full', '1'), findsOneWidget);
    expect(inKey('bo-stat-soon', '1'), findsOneWidget);
    expect(inKey('bo-stat-unknown', '1'), findsOneWidget);
    final y = [for (final id in ['aga_bas', 'luc_lem', 'oct_luc', 'oct_jon']) tester.getTopLeft(find.byKey(Key('bo-row-$id'))).dy];
    expect([...y]..sort(), y);
    expect(inKey('bo-row-aga_bas', 'S’efface le 3 oct. sans contact'), findsOneWidget);
    expect(inKey('bo-row-oct_jon', 'Connu du lié : non'), findsOneWidget);
  });

  testWidgets('filtres et recherche', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('bo-filter-full')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-row-luc_lem')), findsOneWidget);
    expect(find.byKey(const Key('bo-row-oct_luc')), findsNothing);
    await tester.tap(find.byKey(const Key('bo-filter-all')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bo-search')), 'jonas');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-row-oct_jon')), findsOneWidget);
    expect(find.byKey(const Key('bo-row-oct_luc')), findsNothing);
  });

  testWidgets('panneau : gorgée entre deux fiches choisies', (tester) async {
    final repo = await pump(tester);
    expect(find.text('Choisissez qui donne son sang'), findsOneWidget);
    await choose(tester, 'bo-regnant', 'Octave Marchetti · PNJ · Ventrue');
    await choose(tester, 'bo-thrall', 'Lucie Arnaud · PJ · Malkavien');
    expect(find.text('Lien envers Octave Marchetti : ●●○ → ●●●'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['drink:oct_luc:3']);
  });

  testWidgets('une ligne charge le panneau ; simple contact', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('bo-row-luc_lem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dr-contact')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:luc_lem:3']);
  });

  testWidgets('panneau : fiches de PJ en brouillon ou en validation écartées, PNJ gardés', (tester) async {
    final draftPj = person('d1', 'Pj Brouillon', kind: CharacterKind.pj, player: 'p1')..status = CharacterStatus.draft;
    final reviewPj = person('d2', 'Pj Validation', kind: CharacterKind.pj, player: 'p2')..status = CharacterStatus.review;
    final draftNpc = person('d3', 'Pnj Brouillon')..status = CharacterStatus.draft;
    await pump(tester, chars: [...cast(), draftPj, reviewPj, draftNpc]);
    await tester.tap(find.byKey(const Key('bo-regnant')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pnj Brouillon'), findsOneWidget);
    expect(find.textContaining('Pj Brouillon'), findsNothing);
    expect(find.textContaining('Pj Validation'), findsNothing);
  });

  testWidgets('même fiche des deux côtés : refus', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'bo-regnant', 'Octave Marchetti · PNJ · Ventrue');
    await choose(tester, 'bo-thrall', 'Octave Marchetti · PNJ · Ventrue');
    expect(find.text('Une fiche ne peut pas se lier elle-même'), findsOneWidget);
    expect(find.byKey(const Key('dr-save')), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('narrateur : la page sans le panneau', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('bo-row-oct_luc')), findsOneWidget);
    expect(find.byKey(const Key('bo-panel')), findsNothing);
  });

  testWidgets('mobile : alerte d’échéance, panneau en pleine page, 390 px (Review Focus 5)', (tester) async {
    await pump(tester, size: const Size(390, 1600));
    expect(find.text('Échéance dans 6 jours'), findsOneWidget);
    expect(find.text('Le lien de Bastien Roche envers Sœur Agathe : s’efface le 3 oct. sans contact.'), findsOneWidget);
    expect(find.byKey(const Key('bo-panel')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('bo-m-drink')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('bo-m-drink')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-panel')), findsOneWidget);
    expect(find.byKey(const Key('bo-back')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('bo-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-panel')), findsNothing);
  });

  testWidgets('390 px : panneau d’un lien chargé, sans exception', (tester) async {
    await pump(tester, size: const Size(390, 1600));
    await tester.scrollUntilVisible(find.byKey(const Key('bo-row-oct_luc')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('bo-row-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-panel')), findsOneWidget);
    expect(find.byKey(const Key('dr-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('écriture refusée : message sur la page, panneau gardé', (tester) async {
    final repo = await pump(tester);
    repo.error = Exception('refusé');
    await tester.tap(find.byKey(const Key('bo-row-oct_luc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.byKey(const Key('dr-save')), findsOneWidget);
  });
}
