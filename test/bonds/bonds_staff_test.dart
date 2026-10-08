import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/bonds/bonds_staff.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/story_event.dart';

import '../fakes.dart';
import 'bond_rules_test.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeBondsRepository> pump(WidgetTester tester, Character c,
      {List<Bond> bonds = const [], bool canEdit = true, Size size = const Size(1000, 1800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeBondsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allBondsProvider.overrideWith((ref) => Stream.value(bonds)),
        allCharactersProvider.overrideWith((ref) => Stream.value(cast())),
        bondsRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: StaffBonds(character: c, canEdit: canEdit, today: today))),
      ),
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

  testWidgets('subis et exercés : pastilles, échéances, connu du lié', (tester) async {
    await pump(tester, lucie(), bonds: [octLuc(), lucLem()]);
    expect(find.text('Subis'), findsOneWidget);
    expect(find.text('Exercés'), findsOneWidget);
    expect(find.text('Octave Marchetti'), findsOneWidget);
    expect(find.text('PNJ · Ventrue'), findsOneWidget);
    expect(find.text('Goule · PNJ'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('bo-dots-oct_luc'))).data, '●●○');
    expect(find.text('Dernière gorgée le 20 sept. · S’efface le 20 mars 2027 sans contact'), findsOneWidget);
    expect(find.text('Dernière gorgée le 1er sept. · Redescend à ●● le 1er déc.'), findsOneWidget);
    expect(find.text('Connu de Lucie Arnaud'), findsOneWidget);
    expect(find.text('Connu de Dr Lemaire'), findsOneWidget);
  });

  testWidgets('gorgée depuis la fiche : aperçu, lien complet, événement', (tester) async {
    final repo = await pump(tester, lucie(), bonds: [octLuc()]);
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.text('Lien envers Octave Marchetti : ●●○ → ●●●'), findsOneWidget);
    expect(find.text('Lien complet. Les liens moindres de Lucie Arnaud envers d’autres vampires sont effacés : aucun.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['drink:oct_luc:3']);
    expect(repo.lastDrink!.event.title, 'Boit le sang de Octave Marchetti · ●●●');
    expect(repo.lastDrink!.event.visibility, EventVisibility.player);
    expect(find.byKey(const Key('dr-save')), findsNothing);
  });

  testWidgets('lien complet ailleurs : refus, bouton inactif (Review Focus 2)', (tester) async {
    final agaFull = link(agathe(), lucie(), 3, DateTime(2026, 9, 25));
    final repo = await pump(tester, lucie(), bonds: [octLuc(), agaFull]);
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.text('Lucie Arnaud est déjà lié complètement à Sœur Agathe.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('dr-save'))).onPressed, isNull);
    expect(repo.calls, isEmpty);
  });

  testWidgets('lien complet : liens moindres effacés dans le même lot', (tester) async {
    final agaLuc = link(agathe(), lucie(), 1, DateTime(2026, 9, 1));
    final repo = await pump(tester, lucie(), bonds: [octLuc(), agaLuc]);
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.text('Lien complet. Les liens moindres de Lucie Arnaud envers d’autres vampires sont effacés : Sœur Agathe.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect([for (final e in repo.lastDrink!.erased) '${e.id}:${e.level}'], ['aga_luc:0']);
  });

  testWidgets('contact : date du jour, niveau du jour', (tester) async {
    final repo = await pump(tester, lucie(), bonds: [octLuc()]);
    await tester.tap(find.byKey(const Key('bo-contact-oct_luc')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:oct_luc:2']);
    expect(repo.lastSaved!.lastContact, today);
  });

  testWidgets('nouveau lien exercé', (tester) async {
    final repo = await pump(tester, lucie());
    expect(find.text('Aucun lien.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bo-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo-dir-exerted')));
    await tester.pumpAndSettle();
    await choose(tester, 'bo-partner', 'Sœur Agathe · PNJ · Malkavien');
    expect(find.text('Lien envers Lucie Arnaud : ○○○ → ●○○'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['drink:luc_aga:1']);
    expect(repo.lastDrink!.after.stored, isFalse);
  });

  testWidgets('goule à dater : créer le lien au niveau de la fiche', (tester) async {
    final repo = await pump(tester, lemaire());
    expect(find.text('Lien de Lucie Arnaud ●●● à dater'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bo-date-create')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:luc_lem:3']);
    await pump(tester, lemaire(), bonds: [lucLem()]);
    expect(find.byKey(const Key('bo-date')), findsNothing);
  });

  testWidgets('lecture seule : narrateur, fiche en brouillon', (tester) async {
    await pump(tester, lucie(), bonds: [octLuc()], canEdit: false);
    expect(find.byKey(const Key('bo-drink-oct_luc')), findsNothing);
    expect(find.byKey(const Key('bo-contact-oct_luc')), findsNothing);
    expect(find.byKey(const Key('bo-new')), findsNothing);
    await pump(tester, lucie()..status = CharacterStatus.draft, bonds: [octLuc()]);
    expect(find.byKey(const Key('bo-drink-oct_luc')), findsNothing);
    expect(find.byKey(const Key('bo-new')), findsNothing);
  });

  testWidgets('écriture refusée : message, formulaire gardé', (tester) async {
    final repo = await pump(tester, lucie(), bonds: [octLuc()]);
    repo.error = Exception('refusé');
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.byKey(const Key('dr-save')), findsOneWidget);
  });

  testWidgets('390 px : formulaire ouvert sans débordement (Review Focus 5)', (tester) async {
    await pump(tester, lucie(), bonds: [octLuc(), lucLem()], size: const Size(390, 1600));
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('bo-new')));
    await tester.pumpAndSettle();
    await choose(tester, 'bo-partner', 'Sœur Agathe · PNJ · Malkavien');
    expect(tester.takeException(), isNull);
  });
}
