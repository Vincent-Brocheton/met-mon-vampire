import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/npcs/loan_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';
import 'package:portail_met/npcs/npc_loans_screen.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'loan_rules_test.dart' show octave;

/// Jour du calendrier dans [n] jours (le changement d'heure ne décale pas le jour).
DateTime _in(int n) {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day + n);
}

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  Character npc() => sample()
    ..kind = CharacterKind.pnj
    ..status = CharacterStatus.active
    ..playerUid = null;

  Future<FakeNpcLoansRepository> pump(WidgetTester tester, {List<NpcLoan> loans = const [], Stream<List<NpcLoan>>? stream}) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeNpcLoansRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allUsersProvider.overrideWith((ref) => Stream.value(const [lea, camille])),
        allCharactersProvider.overrideWith((ref) => Stream.value([npc()])),
        allNpcLoansProvider.overrideWith((ref) => stream ?? Stream.value(loans)),
        npcLoansRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: NpcLoansScreen())),
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

  testWidgets('confier un PNJ : copie résumée, consignes, dates incluses', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'loan-npc', 'Isaure de Valcourt');
    await choose(tester, 'loan-player', 'Camille R.');
    await tester.enterText(find.byKey(const Key('loan-from')), '28/09/2026');
    await tester.enterText(find.byKey(const Key('loan-until')), '17/10/2026');
    await tester.tap(find.text('Fiche résumée'));
    await tester.enterText(find.byKey(const Key('loan-personality')), 'Courtois.');
    await tester.pump();
    expect(find.text('Confier à Camille R.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loan-save')));
    await tester.pumpAndSettle();
    final l = repo.lastSaved!;
    expect((l.characterId, l.playerUid, l.mode, l.personality), ('x', 'u1', LoanMode.summary, 'Courtois.'));
    expect(l.from, DateTime(2026, 9, 28));
    expect(l.until, DateTime(2026, 10, 17, 23, 59, 59, 999));
    expect(repo.lastBefore!.version, 0);
    expect(repo.lastSheet!.containsKey('story'), isFalse);
  });

  NpcLoan running({int version = 1}) => NpcLoan.fromMap('l1', {
        ...(octave()
              ..from = startOfDay(DateTime.now())
              ..until = endOfDay(_in(3)))
            .toMap(),
        'version': version,
      });

  testWidgets('avertissements visibles avant de confier', (tester) async {
    await pump(tester, loans: [running()]);
    await choose(tester, 'loan-npc', 'Isaure de Valcourt');
    await choose(tester, 'loan-player', 'Camille R.');
    await tester.enterText(find.byKey(const Key('loan-until')), '${_in(2).day.toString().padLeft(2, '0')}/${_in(2).month.toString().padLeft(2, '0')}/${_in(2).year}');
    await tester.pump();
    expect(find.byKey(const Key('loan-form-warnings')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('loan-form-warnings')), matching: find.textContaining('Déjà confié à Camille R.')), findsOneWidget);
  });

  testWidgets('prêt modifié pendant la fenêtre « Prolonger » : conflit, rien n’est écrit', (tester) async {
    final loans = StreamController<List<NpcLoan>>();
    addTearDown(loans.close);
    loans.add([running()]);
    final repo = await pump(tester, stream: loans.stream);
    await tester.tap(find.byKey(const Key('loan-extend-l1')));
    await tester.pumpAndSettle();
    loans.add([running(version: 2)]);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('extend-until')), '31/12/2030');
    await tester.tap(find.byKey(const Key('extend-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Modifié entre-temps : rechargez la page.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('refus sans changement de version : message générique', (tester) async {
    final repo = await pump(tester, loans: [running()]);
    repo.error = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    await tester.tap(find.byKey(const Key('loan-refresh-l1')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
  });

  testWidgets('fin avant le début : refusé (Review Focus 5)', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'loan-npc', 'Isaure de Valcourt');
    await choose(tester, 'loan-player', 'Camille R.');
    await tester.enterText(find.byKey(const Key('loan-from')), '28/09/2026');
    await tester.enterText(find.byKey(const Key('loan-until')), '01/09/2026');
    await tester.tap(find.byKey(const Key('loan-save')));
    await tester.pumpAndSettle();
    expect(find.text('La fin précède le début'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('liste : prolonger, révoquer, mettre à jour la copie', (tester) async {
    final repo = await pump(tester, loans: [
      octave()
        ..from = startOfDay(DateTime.now())
        ..until = endOfDay(_in(3)),
    ]);
    expect(find.textContaining('1 en cours'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loan-extend-l1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('extend-until')), '31/02/2030');
    await tester.tap(find.byKey(const Key('extend-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Dates attendues au format JJ/MM/AAAA.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const Key('loan-extend-l1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('extend-until')), '31/12/2030');
    await tester.tap(find.byKey(const Key('extend-ok')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.until, DateTime(2030, 12, 31, 23, 59, 59, 999));
    expect(repo.lastSheet, isNull);
    await tester.tap(find.byKey(const Key('loan-refresh-l1')));
    await tester.pumpAndSettle();
    expect(repo.lastSheet, isNotNull);
    await tester.tap(find.byKey(const Key('loan-revoke-l1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Révoquer').last);
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.revokedAt, isNotNull);
  });
}
