import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/morality/morality_screen.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'morality_rules_test.dart' show rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  final evening = [
    Sin(id: 's1', date: DateTime(2026, 9, 20), level: 3, what: 'A tué le journaliste', remorse: Remorse.failed),
    Sin(id: 's2', date: DateTime(2026, 9, 20), level: 2, what: 'A rendu fou un témoin', remorse: Remorse.failed),
  ];

  Future<(FakeSinsRepository, FakeCharacterRepository)> pump(WidgetTester tester,
      {AppUser user = lea, Character? c, List<Sin> sins = const [], Size size = const Size(1440, 2000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sinsRepo = FakeSinsRepository();
    final chars = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        characterProvider('x').overrideWith((ref) => Stream.value(c ?? (sample()..humanity = 5))),
        characterSinsProvider('x').overrideWith((ref) => Stream.value(sins)),
        sinsRepositoryProvider.overrideWith((ref) => sinsRepo),
        characterRepositoryProvider.overrideWith((ref) => chars),
        allBondsProvider.overrideWith((ref) => Stream.value(const <Bond>[])),
        bondsRepositoryProvider.overrideWith((ref) => FakeBondsRepository()),
        allCharactersProvider.overrideWith((ref) => Stream.value(const <Character>[])),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: const Scaffold(body: CharacterMoralityScreen(characterId: 'x', basePath: '/conteur/fiches/x')),
      ),
    ));
    await tester.pumpAndSettle();
    return (sinsRepo, chars);
  }

  Future<void> reason(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), text);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
  }

  testWidgets('enregistrer un péché : niveau, remords, traits annoncés', (tester) async {
    final (sins, _) = await pump(tester);
    await tester.enterText(find.byKey(const Key('sin-date')), '20/09/2026');
    await tester.tap(find.byKey(const Key('sin-level-3')));
    await tester.enterText(find.byKey(const Key('sin-what')), 'A tué le journaliste');
    await tester.tap(find.byKey(const Key('sin-remorse-failed')));
    await tester.pump();
    expect(find.text('Ajouter · 3 traits'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sin-save')));
    await tester.pumpAndSettle();
    expect(sins.calls, ['save:x:new']);
    final s = sins.lastSaved!;
    expect((s.date, s.level, s.what, s.remorse), (DateTime(2026, 9, 20), 3, 'A tué le journaliste', Remorse.failed));
  });

  testWidgets('5 traits : message et perte appliquée en un lot', (tester) async {
    final (sins, _) = await pump(tester, sins: evening);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('5 traits de Bête atteints : Isaure de Valcourt perd un point d’Humanité (5 → 4, Distante).'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sin-loss')));
    await tester.pumpAndSettle();
    expect(sins.calls, ['loss:x:s1,s2']);
  });

  testWidgets('soirée déjà appliquée : pas de nouvelle perte, péchés verrouillés (Review Focus 1)', (tester) async {
    await pump(tester, sins: [for (final s in evening) s.copy()..lossApplied = true]);
    expect(find.byKey(const Key('sin-loss')), findsNothing);
    expect(find.byKey(const Key('sin-edit-s1')), findsNothing);
    expect(find.text('Perte appliquée'), findsOneWidget);
  });

  testWidgets('changer de voie : valeur ramenée, motif, événement « Voie adoptée » (Review Focus 2)', (tester) async {
    final (_, chars) = await pump(tester);
    await tester.tap(find.byKey(const Key('mo-path-Voie de la Nuit')));
    await reason(tester, 'Adopte la voie après la diablerie');
    expect(chars.calls, ['saveEdit:Adopte la voie après la diablerie']);
    expect((chars.lastAfter!.path, chars.lastAfter!.humanity), ('Voie de la Nuit', 4));
    final e = chars.lastEvents.single;
    expect((e.type, e.title), (EventType.pathAdopted, 'Adopte Voie de la Nuit'));
  });

  testWidgets('régler la valeur avec motif ; « − » désactivé à 0 (Review Focus 5)', (tester) async {
    final (_, chars) = await pump(tester);
    await tester.tap(find.byKey(const Key('mo-minus')));
    await reason(tester, 'Correction');
    expect(chars.calls, ['saveEdit:Correction']);
    expect(chars.lastAfter!.humanity, 4);
    await pump(tester, c: sample()..humanity = 0);
    expect(tester.widget<IconButton>(find.byKey(const Key('mo-minus'))).onPressed, isNull);
    expect(find.text('Wassail'), findsOneWidget);
  });

  testWidgets('modifier puis supprimer un péché', (tester) async {
    final (sins, _) = await pump(tester, sins: evening);
    await tester.tap(find.byKey(const Key('sin-edit-s2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sin-remorse-success')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sin-save')));
    await tester.pumpAndSettle();
    expect(sins.calls, ['save:x:s2']);
    expect(sins.lastSaved!.remorse, Remorse.success);
    await tester.tap(find.byKey(const Key('sin-delete-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sin-delete-confirm')));
    await tester.pumpAndSettle();
    expect(sins.calls.last, 'delete:x:s1');
  });

  testWidgets('refus d’écriture : message', (tester) async {
    final (sins, _) = await pump(tester);
    sins.error = Exception('refus');
    await tester.enterText(find.byKey(const Key('sin-what')), 'A tué le journaliste');
    await tester.tap(find.byKey(const Key('sin-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'A tué le journaliste'), findsOneWidget);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien, sins: evening);
    expect(find.text('A tué le journaliste'), findsWidgets);
    expect(find.byKey(const Key('sin-save')), findsNothing);
    expect(find.byKey(const Key('sin-loss')), findsNothing);
    expect(find.byKey(const Key('mo-minus')), findsNothing);
  });

  testWidgets('brouillon ou fiche en validation : voie, valeur et perte en lecture seule, péchés saisissables', (tester) async {
    await pump(tester, c: sample()..humanity = 5..status = CharacterStatus.draft, sins: evening);
    expect(find.byKey(const Key('mo-minus')), findsNothing);
    expect(find.byKey(const Key('mo-plus')), findsNothing);
    expect(find.byKey(const Key('sin-loss')), findsNothing);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('mo-path-Humanité'))).onSelected, isNull);
    expect(find.byKey(const Key('sin-save')), findsOneWidget);
    await pump(tester, c: sample()..humanity = 5..kind = CharacterKind.pnj..status = CharacterStatus.draft, sins: evening);
    expect(find.byKey(const Key('mo-minus')), findsOneWidget);
    expect(find.byKey(const Key('sin-loss')), findsOneWidget);
  });

  testWidgets('Humanité à 0 : la perte n’est pas proposée', (tester) async {
    await pump(tester, c: sample()..humanity = 0, sins: evening);
    expect(find.byKey(const Key('sin-loss')), findsNothing);
    expect(find.textContaining('perd un point'), findsNothing);
  });

  testWidgets('menu des soirées : clé par soirée, ancienne clé conservée', (tester) async {
    final two = [...evening, Sin(id: 's3', date: DateTime(2026, 9, 10), level: 1, what: 'Mensonge', remorse: Remorse.failed)];
    await pump(tester, sins: two);
    expect(find.byKey(const Key('sin-evening')), findsOneWidget);
    expect(find.byKey(ValueKey(DateTime(2026, 9, 20))), findsOneWidget);
  });

  testWidgets('mobile : une colonne', (tester) async {
    await pump(tester, sins: evening, size: const Size(390, 2600));
    expect(find.byKey(const Key('sin-save')), findsOneWidget);
    expect(find.byKey(const Key('sin-loss')), findsOneWidget);
  });
}
