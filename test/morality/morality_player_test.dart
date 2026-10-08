import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/morality/morality_screen.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import 'morality_rules_test.dart' show rb;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  final sins = [
    Sin(id: 's1', date: DateTime(2026, 9, 20), level: 1, what: 'A ruiné la carrière d’un critique rival', remorse: Remorse.success),
    Sin(id: 's2', date: DateTime(2026, 8, 23), level: 1, what: 'A blessé un mortel en se nourrissant trop', remorse: Remorse.failed),
  ];

  Future<void> pump(WidgetTester tester, Character c, {List<Sin> list = const [], Size size = const Size(1440, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        rulebookProvider.overrideWith((ref) => rb),
        myRequestsProvider.overrideWith((ref) => Stream.value(const <XpRequest>[])),
        characterProvider('x').overrideWith((ref) => Stream.value(c)),
        characterSinsProvider('x').overrideWith((ref) => Stream.value(list)),
        characterBondsProvider('x').overrideWith((ref) async => const <Bond>[]),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: const Scaffold(body: CharacterMoralityScreen(characterId: 'x', basePath: '/joueur/personnages/x')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('carte : voie, valeur, échelle ; tableau des péchés ; lien d’achat', (tester) async {
    await pump(tester, sample()..humanity = 5, list: sins);
    expect(find.text('Humanité 5 · Normale'), findsOneWidget);
    expect(find.byKey(const Key('mo-scale-6')), findsOneWidget);
    expect(find.byKey(const Key('mo-scale-7')), findsNothing);
    expect(find.text('Niveau 1 · A ruiné la carrière d’un critique rival'), findsOneWidget);
    expect(find.text('Réussi (−1)'), findsOneWidget);
    expect(find.text('Échoué'), findsOneWidget);
    expect(find.byKey(const Key('mo-buy')), findsOneWidget);
    expect(find.byKey(const Key('sin-save')), findsNothing);
  });

  testWidgets('voie au maximum : échelle de la voie, pas de lien d’achat ; aucun péché', (tester) async {
    await pump(tester, sample()
      ..path = 'Voie de la Nuit'
      ..humanity = 4);
    expect(find.text('Voie de la Nuit 4 · Distante'), findsOneWidget);
    expect(find.byKey(const Key('mo-scale-5')), findsNothing);
    expect(find.byKey(const Key('mo-buy')), findsNothing);
    expect(find.text('Aucun péché.'), findsOneWidget);
  });

  testWidgets('mobile : une colonne', (tester) async {
    await pump(tester, sample()..humanity = 5, list: sins, size: const Size(390, 1800));
    expect(find.text('Humanité 5 · Normale'), findsOneWidget);
    expect(find.text('Niveau 1 · A blessé un mortel en se nourrissant trop'), findsOneWidget);
  });
}
