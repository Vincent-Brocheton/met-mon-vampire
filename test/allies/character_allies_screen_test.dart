import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/allies/allies_repository.dart';
import 'package:portail_met/allies/ally_file.dart';
import 'package:portail_met/allies/character_allies_screen.dart';
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
import 'ally_rules_test.dart' show rb;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);

  Ally maelle() => Ally('x-a0', 'Maëlle Garnier, critique', type: 'Gotha', domain: 'Média', specialties: ['Contact']);

  Character isaure({int xp = 100}) => sample()
    ..allies = [maelle()]
    ..xpInitial = xp
    ..xpEarned = 0
    ..xpSpent = 0;

  Future<FakeXpRepository> pump(WidgetTester tester, {Character? c, List<XpRequest> requests = const [], List<AllyFile> files = const []}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeXpRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        rulebookProvider.overrideWith((ref) => rb),
        characterProvider('x').overrideWith((ref) => Stream.value(c ?? isaure())),
        myRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        characterAllyFilesProvider('x').overrideWith((ref) => Stream.value(files)),
        xpRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterAlliesScreen(characterId: 'x'))),
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

  testWidgets('nouvel allié : demande d’XP au coût cumulé, avec l’état demandé', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byKey(const Key('al-name')), 'Me Hervé Castan, notaire');
    await choose(tester, 'al-type', 'Gotha');
    await choose(tester, 'al-domain', 'Finance & Industrie');
    await choose(tester, 'al-level', '4');
    await choose(tester, 'al-influence', 'Influence 4 · prend 2 spécialisations');
    await choose(tester, 'al-spec0', 'Expert · si Influent');
    await choose(tester, 'al-spec1', 'Sécurité · si Influent');
    expect(find.text('Influence 4 prend 2 spécialisations sur 4 : il en reste 2. Retour après usage : 4 mois.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('al-why')), 'Rencontré au cercle.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('al-send')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:submit:20']);
    final r = repo.lastSaved!;
    final i = r.items.single;
    expect((i.kind, i.name, i.fromLevel, i.toLevel, i.cost), (XpKind.ally, 'Me Hervé Castan, notaire', 0, 4, 20));
    expect(i.ally, {'type': 'Gotha', 'domain': 'Finance & Industrie', 'influence': 4, 'specialties': ['Expert', 'Sécurité']});
    expect((r.justification, r.characterId, r.playerUid), ('Rencontré au cercle.', 'x', 'u1'));
  });

  testWidgets('demande incomplète ou trop chère : pas d’envoi', (tester) async {
    final repo = await pump(tester, c: isaure(xp: 0));
    await tester.tap(find.byKey(const Key('al-send')));
    await tester.pumpAndSettle();
    expect(find.text('Nom obligatoire'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('al-name')), 'Dédé');
    await choose(tester, 'al-type', 'Pègre');
    await choose(tester, 'al-domain', 'Crime');
    await choose(tester, 'al-spec0', 'Contact');
    await tester.enterText(find.byKey(const Key('al-why')), 'Un vieux copain.');
    await tester.tap(find.byKey(const Key('al-send')));
    await tester.pumpAndSettle();
    expect(find.text('XP libre insuffisante : 2 requis, 0 disponible.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('montée de niveau : nom figé, un niveau, état « De retour le … »', (tester) async {
    final repo = await pump(tester, files: [AllyFile(id: 'x-a0', returnAt: DateTime.now().add(const Duration(days: 40)), version: 1)]);
    expect(find.textContaining('De retour le'), findsOneWidget);
    await tester.tap(find.byKey(const Key('al-up-x-a0')));
    await tester.pumpAndSettle();
    await choose(tester, 'al-spec1', 'Nocturne');
    await tester.enterText(find.byKey(const Key('al-why')), 'Elle me doit un service.');
    await tester.tap(find.byKey(const Key('al-send')));
    await tester.pumpAndSettle();
    final i = repo.lastSaved!.items.single;
    expect((i.name, i.fromLevel, i.toLevel, i.cost), ('Maëlle Garnier, critique', 1, 2, 4));
    expect(i.ally!['specialties'], ['Contact', 'Nocturne']);
  });

  testWidgets('demande ouverte : carte « En attente du conte »', (tester) async {
    await pump(tester, requests: [
      XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.ally, 'Me Castan', 0, 1, 2, ally: {'type': 'Gotha', 'domain': 'Police', 'influence': 0, 'specialties': ['Contact']})],
      ),
    ]);
    expect(find.text('Me Castan'), findsOneWidget);
    expect(find.text('En attente du conte'), findsOneWidget);
  });
}
