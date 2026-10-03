import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/creation/creation_screen.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../fakes.dart';
import 'creation_rules_test.dart' show valid;

void main() {
  const zoe = AppUser(uid: 'zoe', displayName: 'Zoé A.', email: 'z@ex.fr', role: Role.joueur);

  Future<FakeCharacterRepository> pump(WidgetTester tester, Character c, {Stream<Character?>? source, bool loading = false}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rulebookProvider.overrideWith((ref) => loading ? null : const Rulebook()),
        currentUserProvider.overrideWith((ref) => Stream.value(zoe)),
        characterRepositoryProvider.overrideWith((ref) => repo),
        characterProvider('n').overrideWith((ref) => source ?? Stream.value(c)),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: CreationScreen(id: 'n'))),
          GoRoute(path: '/joueur/personnages/:id/soumise', builder: (_, _) => const Text('soumise')),
          GoRoute(path: '/joueur', builder: (_, _) => const Text('accueil')),
        ]),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return repo;
  }

  testWidgets('enregistrement automatique 3 s après une saisie', (tester) async {
    final repo = await pump(tester, valid()..step = 1);
    await tester.enterText(find.byKey(const Key('field-Nom du personnage')), 'Nikolaï V.');
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(repo.calls, ['saveDraft']);
  });

  testWidgets('changer d’étape enregistre aussitôt (Review Focus 2)', (tester) async {
    final repo = await pump(tester, valid()..step = 1);
    await tester.enterText(find.byKey(const Key('field-Nom du personnage')), 'Nikolaï V.');
    await tester.tap(find.text('Suivant : XP initiale'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveDraft']);
    expect(find.text('XP initiale'), findsWidgets);
  });

  testWidgets('bonus du conte arrivé pendant la saisie : saisie gardée, bonus repris (Review Focus 1)', (tester) async {
    final ctrl = StreamController<Character?>();
    addTearDown(ctrl.close);
    final first = valid()..step = 1;
    ctrl.add(first);
    final repo = await pump(tester, first, source: ctrl.stream);
    await tester.enterText(find.byKey(const Key('field-Nom du personnage')), 'Nikolaï V.');
    ctrl.add(first.clone()
      ..version = 2
      ..xpBonus = 10);
    await tester.pump();
    await tester.tap(find.text('Suivant : XP initiale'));
    await tester.pumpAndSettle();
    final sent = repo.lastDraft!;
    expect((sent.name, sent.xpBonus, sent.version, sent.xpInitial), ('Nikolaï V.', 10, 2, 43));
  });

  testWidgets('quitter pendant un enregistrement en cours : la saisie part après lui (revue finale)', (tester) async {
    final repo = await pump(tester, valid()
      ..step = 1
      ..version = 1);
    final gate = Completer<void>();
    repo.saveGate = gate.future;
    await tester.enterText(find.byKey(const Key('field-Nom du personnage')), 'Nikolaï V.');
    await tester.pump(const Duration(seconds: 3));
    expect(repo.calls, ['saveDraft']);
    await tester.enterText(find.byKey(const Key('field-Nom du personnage')), 'Nikolaï Ve.');
    await tester.pumpWidget(const SizedBox());
    repo.saveGate = null;
    gate.complete();
    await tester.pump();
    expect(repo.calls, ['saveDraft', 'saveDraft']);
    expect((repo.lastDraft!.name, repo.lastDraft!.version), ('Nikolaï Ve.', 2));
  });

  testWidgets('soumission impossible tant qu’un contrôle bloque (Review Focus 5)', (tester) async {
    await pump(tester, valid()..name = '');
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Soumettre au conte'));
    expect(button.onPressed, isNull);
  });

  testWidgets('fiche complète : soumission confirmée', (tester) async {
    final repo = await pump(tester, valid());
    await tester.tap(find.text('Soumettre au conte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soumettre'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'submit:Nikolaï Vesk');
    expect(find.text('soumise'), findsOneWidget);
  });

  testWidgets('fiche hors brouillon : pas d’édition', (tester) async {
    await pump(tester, valid()..status = CharacterStatus.review);
    expect(find.text('Cette fiche n’est pas en brouillon'), findsOneWidget);
  });

  testWidgets('référentiel en chargement : la création attend (Review Focus 5)', (tester) async {
    await pump(tester, valid()..step = 1, loading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Suivant : XP initiale'), findsNothing);
  });
}
