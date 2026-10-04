import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servants_repository.dart';
import 'package:portail_met/servants/servants_screen.dart';

import '../fakes.dart';
import 'servant_rules_test.dart' show isaure, rb, rexFile;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Future<FakeServantsRepository> pump(WidgetTester tester, {AppUser user = lea, List<ServantFile>? files, Stream<List<ServantFile>>? stream}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeServantsRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        servantsRepositoryProvider.overrideWith((ref) => repo),
        allServantFilesProvider.overrideWith((ref) => stream ?? Stream.value(files ?? [rexFile()])),
        allCharactersProvider.overrideWith((ref) => Stream.value([isaure()])),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: ServantsScreen())),
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

  testWidgets('liste : serviteurs des fiches, à compléter, recherche', (tester) async {
    await pump(tester);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mila'), findsOneWidget);
    expect(find.text('À compléter'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sv-search')), 'rex');
    await tester.pump();
    expect(find.text('Mila'), findsNothing);
  });

  testWidgets('compléter un serviteur : spécialité, gorgée, accès du joueur du domitor', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Mila'));
    await tester.pumpAndSettle();
    expect(find.text('Réserve 2 · santé 1 · pas de Volonté'), findsOneWidget);
    await choose(tester, 'sv-add-specialty', 'Médecine');
    await tester.tap(find.byKey(const Key('sv-drink')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    final f = repo.lastSaved!;
    expect((f.id, f.kind, f.name, f.domitorId, f.vitae), ('x-s2', 'human', 'Mila', 'x', 1));
    expect(f.holderPlayers, ['u1']);
    expect(f.specialties, ['Médecine']);
    expect(f.lastDrink, isNotNull);
    expect(repo.lastBefore!.version, 0, reason: 'première fiche détaillée : création');
  });

  testWidgets('goule animale : qualités et avertissement de points', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    await choose(tester, 'sv-add-quality', 'Monture (3)');
    expect(find.text('Qualités animales : 4 points sur 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSaved!.qualities, ['Costaud', 'Monture']);
  });

  testWidgets('modifié par un autre conteur pendant l’édition : base figée, message (Review Focus 4)', (tester) async {
    final files = StreamController<List<ServantFile>>();
    addTearDown(files.close);
    files.add([rexFile()]);
    final repo = await pump(tester, stream: files.stream);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    files.add([ServantFile.fromMap('x-s1', {...rexFile().toMap(), 'version': 2})]);
    await tester.pumpAndSettle();
    repo.error = Exception('version');
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    expect(repo.lastBefore!.version, 1);
    expect(find.text('Modifié entre-temps : rechargez la page.'), findsOneWidget);
  });

  testWidgets('nouveau mortel, puis suppression', (tester) async {
    final repo = await pump(tester, files: [ServantFile(id: 'm1', kind: 'mortal', name: 'Jeanne', attachment: 'Voisine', version: 1)]);
    await tester.tap(find.byKey(const Key('sv-new-mortal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sv-name')), 'Paul');
    await tester.enterText(find.byKey(const Key('sv-attachment')), 'Indic de la police');
    await tester.tap(find.byKey(const Key('sv-save')));
    await tester.pumpAndSettle();
    expect((repo.lastSaved!.kind, repo.lastSaved!.name), ('mortal', 'Paul'));
    expect(repo.lastSaved!.holderPlayers, isEmpty);
    await tester.tap(find.text('Jeanne'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sv-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete:m1');
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('sv-new-mortal')), findsNothing);
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sv-save')), findsNothing);
  });
}
