import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/npcs/loan_rules.dart';
import 'package:portail_met/npcs/my_npc_loans_screen.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'loan_rules_test.dart' show octave;

void main() {
  NpcLoan current({LoanMode mode = LoanMode.full, String id = 'l1'}) => octave(id: id)
    ..from = startOfDay(DateTime.now().subtract(const Duration(days: 1)))
    ..until = endOfDay(DateTime.now().add(const Duration(days: 19)))
    ..mode = mode;

  Future<FakeNpcLoansRepository> pump(WidgetTester tester, {required List<NpcLoan> loans, Map<String, dynamic>? sheet}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeNpcLoansRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        myNpcLoansProvider.overrideWith((ref) => Stream.value(loans)),
        for (final l in loans) npcLoanSheetProvider(l.id).overrideWith((ref) => Stream.value(sheet)),
        npcLoansRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: MyNpcLoansScreen())),
          GoRoute(path: '/joueur/pnj/:id', builder: (_, s) => Scaffold(body: NpcLoanScreen(loanId: s.pathParameters['id']!))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('un seul prêt : ouvert directement, bandeau, consignes, fiche complète, notes', (tester) async {
    final repo = await pump(tester, loans: [current()], sheet: sheetCopy(sample(), LoanMode.full));
    expect(find.textContaining('lecture seule, accès jusqu’au'), findsOneWidget);
    expect(find.text('Encore 19 jours'), findsOneWidget);
    expect(find.text('Courtois, patient.'), findsOneWidget);
    expect(find.textContaining('Auspex'), findsWidgets);
    await tester.enterText(find.byKey(const Key('loan-player-notes')), 'Promis une faveur.');
    await tester.tap(find.byKey(const Key('loan-notes-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['notes:l1']);
    expect(repo.lastNotes, 'Promis une faveur.');
  });

  testWidgets('fiche résumée : pas de récit ; notes interdites (Review Focus 4)', (tester) async {
    await pump(tester, loans: [current(mode: LoanMode.summary)..allowNotes = false], sheet: sheetCopy(sample()..story = 'Secret', LoanMode.summary));
    expect(find.text('Secret'), findsNothing);
    expect(find.text('Auspex'), findsOneWidget);
    expect(find.byKey(const Key('loan-player-notes')), findsNothing);
  });

  testWidgets('plusieurs prêts : liste des prêts en cours seulement', (tester) async {
    await pump(tester, loans: [current(), current(id: 'l2')..characterName = 'Jonas Ferrand', octave(id: 'old')..until = DateTime(2020)]);
    expect(find.text('Jonas Ferrand'), findsOneWidget);
    expect(find.text('Isaure de Valcourt'), findsOneWidget);
    expect(find.textContaining('lecture seule'), findsNothing);
  });

  testWidgets('prêt qui se termine pendant que la page est ouverte : fermé', (tester) async {
    await pump(tester, loans: [current()..until = DateTime.now().add(const Duration(seconds: 1))], sheet: sheetCopy(sample(), LoanMode.full));
    expect(find.text('Prêt terminé'), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Prêt terminé'), findsOneWidget);
  });

  Future<void> section(WidgetTester tester, Stream<List<NpcLoan>> stream) => tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [characterNpcLoansProvider('x').overrideWith((ref) => stream)],
        child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: NpcLoansSection(characterId: 'x'))),
      ));

  testWidgets('section « Prêts » : chargement et erreur ne disent pas « Jamais confié. »', (tester) async {
    final pending = StreamController<List<NpcLoan>>();
    addTearDown(pending.close);
    await section(tester, pending.stream);
    await tester.pump();
    expect(find.text('Jamais confié.'), findsNothing);
    await section(tester, Stream.error(Exception('refus')));
    await tester.pump();
    expect(find.text('Jamais confié.'), findsNothing);
    expect(find.text('Prêts indisponibles.'), findsOneWidget);
  });

  test('sans compte connecté : liste vide, pas de chargement sans fin', () async {
    final c = ProviderContainer(overrides: [currentUserProvider.overrideWith((ref) => Stream.value(null))]);
    addTearDown(c.dispose);
    c.listen(myNpcLoansProvider, (_, _) {});
    expect(await c.read(myNpcLoansProvider.future).timeout(const Duration(seconds: 1)), isEmpty);
  });

  testWidgets('aucun prêt en cours : état vide', (tester) async {
    await pump(tester, loans: [octave()..until = DateTime(2020)]);
    expect(find.text('Aucun PNJ confié'), findsOneWidget);
  });
}
