import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/morality/derangements_staff.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'derangement_rules_test.dart' show fire, rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeCharacterRepository> pump(WidgetTester tester, Character c, {bool canEdit = true}) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chars = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        characterProvider(c.id).overrideWith((ref) => Stream.value(c)),
        characterRepositoryProvider.overrideWith((ref) => chars),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: StaffDerangements(character: c, rb: rb, canEdit: canEdit))),
      ),
    ));
    await tester.pumpAndSettle();
    return chars;
  }

  Future<void> reason(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), text);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('ajouter un dérangement depuis un modèle, avec motif', (tester) async {
    final chars = await pump(tester, sample());
    expect(find.text('Aucun dérangement.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-add')));
    await tester.pumpAndSettle();
    await choose(tester, 'de-model', 'Peur du feu');
    await tester.enterText(find.byKey(const Key('de-trigger')), 'Le feu, même une bougie.');
    await tester.tap(find.byKey(const Key('de-severe')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('de-save')));
    await reason(tester, 'Traumatisme en jeu');
    expect(chars.calls, ['saveEdit:Traumatisme en jeu']);
    final d = chars.lastAfter!.derangements.single;
    expect((d.name, d.type, d.trigger, d.severe, d.clan), ('Peur du feu', 'phobia', 'Le feu, même une bougie.', true, false));
  });

  testWidgets('modifier sans faux doublon, puis retirer (Review Focus 4)', (tester) async {
    final chars = await pump(tester, sample()..derangements = [fire()]);
    expect(find.text('Phobie · Sévère · 3 pts'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-edit-x-d1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('de-trigger')), 'Les flammes');
    await tester.pump();
    expect(find.text('Un dérangement porte déjà ce nom'), findsNothing);
    await tester.tap(find.byKey(const Key('de-save')));
    await reason(tester, 'Précision');
    expect(chars.lastAfter!.derangements.single.trigger, 'Les flammes');
    await tester.tap(find.byKey(const Key('de-remove-x-d1')));
    await reason(tester, 'Guéri');
    expect(chars.lastAfter!.derangements, isEmpty);
  });

  testWidgets('détailler un handicap de création', (tester) async {
    final chars = await pump(tester, sample()..flaws = [Trait('Peur du feu', 3)]);
    expect(find.text('Peur du feu · handicap 3 pts'), findsOneWidget);
    await tester.tap(find.byKey(const Key('de-detail-Peur du feu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('de-save')));
    await reason(tester, 'Détail du handicap');
    final d = chars.lastAfter!.derangements.single;
    expect((d.name, d.type, d.severe), ('Peur du feu', 'phobia', true));
  });

  testWidgets('compteur : plancher Malkavien, motif automatique, retour au plancher (Review Focus 3)', (tester) async {
    final chars = await pump(tester, sample()
      ..clan = 'Malkavien'
      ..derangementTraits = 0);
    expect(find.text('min. 1 (Malkavien)'), findsOneWidget);
    expect(find.text('●○○'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('de-minus'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('de-plus')));
    await tester.pumpAndSettle();
    expect(chars.calls, ['saveEdit:Traits de dérangement']);
    expect(chars.lastAfter!.derangementTraits, 2);
    await pump(tester, sample()
      ..clan = 'Malkavien'
      ..derangementTraits = 3);
    expect(find.text('Réaction extrême, puis retour à 0.'), findsOneWidget);
    expect(find.byKey(const Key('de-reset')), findsOneWidget);
  });

  testWidgets('lecture seule : narrateur, ou fiche en brouillon (Review Focus 5)', (tester) async {
    await pump(tester, sample()..derangements = [fire()], canEdit: false);
    expect(find.byKey(const Key('de-add')), findsNothing);
    expect(find.byKey(const Key('de-plus')), findsNothing);
    await pump(tester, sample()
      ..status = CharacterStatus.draft
      ..derangements = [fire()]);
    expect(find.byKey(const Key('de-edit-x-d1')), findsNothing);
    expect(find.byKey(const Key('de-plus')), findsNothing);
  });
}
