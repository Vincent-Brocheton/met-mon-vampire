import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/allies/allies_admin_screen.dart';
import 'package:portail_met/allies/allies_repository.dart';
import 'package:portail_met/allies/ally_file.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'ally_rules_test.dart' show castan, rb;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Character victor() => Character(id: 'y', name: 'Victor Laine', kind: CharacterKind.pj, playerUid: 'u2', playerName: 'Max', status: CharacterStatus.active)
    ..backgrounds = [Trait('Contacts', 3)];

  Future<(FakeAlliesRepository, FakeCharacterRepository)> pump(WidgetTester tester, {AppUser user = lea, List<AllyFile> files = const [], List<XpRequest> requests = const [], Stream<List<AllyFile>>? filesStream}) async {
    tester.view.physicalSize = const Size(1440, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final allies = FakeAlliesRepository();
    final characters = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulebookProvider.overrideWith((ref) => rb),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()..allies = [castan()], victor()])),
        allAllyFilesProvider.overrideWith((ref) => filesStream ?? Stream.value(files)),
        openRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        alliesRepositoryProvider.overrideWith((ref) => allies),
        characterRepositoryProvider.overrideWith((ref) => characters),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: AlliesAdminScreen())),
    ));
    await tester.pumpAndSettle();
    return (allies, characters);
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('noter un usage : date de retour calculée, suivi créé pour le joueur', (tester) async {
    final (allies, _) = await pump(tester);
    expect(find.text('Me Hervé Castan, notaire'), findsOneWidget);
    await tester.tap(find.byKey(const Key('al-row-x-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('al-used')), '20/09/2026');
    await tester.enterText(find.byKey(const Key('al-what')), 'Classer une plainte.');
    await tester.pump();
    expect(find.widgetWithText(TextField, '20/01/2027'), findsOneWidget);
    await tester.tap(find.byKey(const Key('al-save')));
    await tester.pumpAndSettle();
    final f = allies.lastSaved!;
    expect((f.id, f.name, f.characterId, f.usedAt, f.returnAt, f.lastUse), ('x-a1', 'Me Hervé Castan, notaire', 'x', DateTime(2026, 9, 20), DateTime(2027, 1, 20), 'Classer une plainte.'));
    expect(f.holderPlayers, ['u1']);
    expect(allies.lastBefore!.version, 0);
  });

  testWidgets('indisponible : filtre, puis rendre disponible', (tester) async {
    final (allies, _) = await pump(tester, files: [
      AllyFile(id: 'x-a1', name: 'Me Hervé Castan, notaire', characterId: 'x', usedAt: DateTime(2026, 9, 20), returnAt: DateTime.now().add(const Duration(days: 30)), version: 1),
    ]);
    await tester.tap(find.byKey(const Key('al-filter-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('al-row-x-a1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('al-row-x-a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('al-free')));
    await tester.pumpAndSettle();
    expect((allies.lastSaved!.usedAt, allies.lastSaved!.returnAt, allies.lastReason), (null, null, 'Rendu disponible'));
  });

  testWidgets('conversion : allié créé, historique diminué, motif tracé (Review Focus 4)', (tester) async {
    final (_, characters) = await pump(tester);
    await tester.tap(find.byKey(const Key('al-filter-convert')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('al-convert-y-Contacts')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cv-name')), 'Dédé « la Fouine »');
    await choose(tester, 'cv-type', 'Pègre');
    await choose(tester, 'cv-domain', 'Crime');
    await choose(tester, 'cv-level', '2');
    await choose(tester, 'cv-spec0', 'Contact');
    await choose(tester, 'cv-spec1', 'Nocturne');
    await tester.tap(find.byKey(const Key('cv-save')));
    await tester.pumpAndSettle();
    expect(characters.calls, ['saveEdit:Conversion des anciens historiques']);
    final after = characters.lastAfter!;
    expect(after.allies.single.name, 'Dédé « la Fouine »');
    expect(after.backgrounds.single.level, 1);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien);
    await tester.tap(find.byKey(const Key('al-row-x-a1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('al-save')), findsNothing);
  });

  testWidgets('après un enregistrement, le fichier reçu sert de base : rendre disponible passe', (tester) async {
    final ctl = StreamController<List<AllyFile>>();
    addTearDown(ctl.close);
    ctl.add(const []);
    final (allies, _) = await pump(tester, filesStream: ctl.stream);
    await tester.tap(find.byKey(const Key('al-row-x-a1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('al-used')), '20/09/2026');
    await tester.pump();
    await tester.tap(find.byKey(const Key('al-save')));
    await tester.pumpAndSettle();
    ctl.add([AllyFile(id: 'x-a1', name: 'Me Hervé Castan, notaire', characterId: 'x', usedAt: DateTime(2026, 9, 20), returnAt: DateTime(2027, 1, 20), version: 1)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('al-free')));
    await tester.pumpAndSettle();
    expect(allies.lastBefore!.version, 1);
  });

  testWidgets('conversion refusée sans conflit : message de refus, pas de conflit', (tester) async {
    final (_, characters) = await pump(tester);
    characters.error = Exception('refusé');
    await tester.tap(find.byKey(const Key('al-filter-convert')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('al-convert-y-Contacts')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cv-name')), 'Dédé « la Fouine »');
    await choose(tester, 'cv-type', 'Pègre');
    await choose(tester, 'cv-domain', 'Crime');
    await choose(tester, 'cv-level', '2');
    await choose(tester, 'cv-spec0', 'Contact');
    await choose(tester, 'cv-spec1', 'Nocturne');
    await tester.tap(find.byKey(const Key('cv-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.text('Modifié entre-temps : rechargez la page.'), findsNothing);
  });

  testWidgets('filtre « Demandes » : une demande à compléter compte aussi', (tester) async {
    await pump(tester, requests: [
      XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.changes,
        items: [const XpItem(XpKind.ally, 'Me Castan', 0, 1, 2, ally: {'type': 'Gotha', 'domain': 'Police', 'influence': 0, 'specialties': ['Contact']})],
      ),
    ]);
    expect(find.text('Demandes · 1'), findsOneWidget);
  });
}
