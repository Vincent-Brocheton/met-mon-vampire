import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/device_session.dart';
import 'package:portail_met/offline/devices_repository.dart';
import 'package:portail_met/offline/offline.dart';
import 'package:portail_met/offline/offline_game_repository.dart';
import 'package:portail_met/offline/offline_game_screen.dart';
import 'package:portail_met/offline/sync_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;

/// Hors ligne, la suppression reste en file : son futur ne se termine pas.
class _HangingSins extends FakeSinsRepository {
  @override
  Future<void> delete(String characterId, String id) {
    calls.add('delete:$characterId:$id');
    return Completer<void>().future;
  }
}

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);
  final now = DateTime(2026, 10, 3, 23);
  final g2 = frozenGame(sheetIds: const ['x', 'y']);
  Character bastien() => Character.fromMap('y', {...sample().toMap(), 'name': 'Bastien Roche', 'playerUid': 'u2'});
  Sin sin(String id, String uid, String name, {int level = 2, DateTime? at}) => Sin(
        id: id,
        date: DateTime(2026, 10, 3),
        level: level,
        what: 'Témoin rendu fou',
        remorse: Remorse.success,
        byUid: uid,
        byName: name,
        createdAt: at,
      );
  // Isaure : Marc et Léa ont saisi le même péché ; un troisième péché attend le réseau.
  final sinsX = <Tracked<Sin>>[
    (doc: sin('m1', 'marc', 'Marc', at: DateTime(2026, 10, 3, 22, 47)), pending: false),
    (doc: sin('l1', 'lea', 'Léa G.', at: DateTime(2026, 10, 3, 22, 44)), pending: false),
    (doc: sin('p1', 'lea', 'Léa G.', level: 1), pending: true),
  ];
  // Bastien : un événement de la soirée, un autre bien plus ancien.
  final eventsY = <Tracked<StoryEvent>>[
    (doc: StoryEvent(id: 'e1', title: 'Titre obtenu : Gardien', year: 2026, byName: 'Marc', createdAt: DateTime(2026, 10, 3, 22, 12)), pending: false),
    (doc: StoryEvent(id: 'e0', title: 'Étreinte', year: 1890, byName: 'Marc', createdAt: DateTime(2026, 9, 1)), pending: false),
  ];
  final prepared = Device(id: 'd1', name: 'Navigateur · Windows', web: true, gameId: 'g2', preparedAt: DateTime(2026, 10, 3, 17, 30));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<({FakeOfflineGameRepository repo, FakeSinsRepository sins, FakeDevicesRepository devices, List<String> session})> pump(
    WidgetTester tester, {
    AppUser me = lea,
    List<Game>? games,
    bool offline = false,
    Device? device,
    FakeSinsRepository? sins,
    FakeOfflineGameRepository? repo,
    Size size = const Size(1440, 2600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = repo ?? FakeOfflineGameRepository();
    final sinsRepo = sins ?? FakeSinsRepository();
    final devices = FakeDevicesRepository();
    final session = <String>[];
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(me)),
        gamesProvider.overrideWith((ref) => Stream.value(games ?? [g2])),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample(), bastien()])),
        offlineProvider.overrideWith((ref) => Stream.value(offline)),
        thisDeviceProvider.overrideWith((ref) => Stream.value(device ?? prepared)),
        trackedSinsProvider('x').overrideWith((ref) => Stream.value(sinsX)),
        trackedSinsProvider('y').overrideWith((ref) => Stream.value(const <Tracked<Sin>>[])),
        trackedEventsProvider('x').overrideWith((ref) => Stream.value(const <Tracked<StoryEvent>>[])),
        trackedEventsProvider('y').overrideWith((ref) => Stream.value(eventsY)),
        offlineGameRepositoryProvider.overrideWith((ref) => r),
        sinsRepositoryProvider.overrideWith((ref) => sinsRepo),
        devicesRepositoryProvider.overrideWith((ref) => devices),
        deviceSessionProvider.overrideWith((ref) => DeviceSession(
              removeDevice: (_, _) async {},
              pendingWrites: () async => false,
              wipeCache: () async => session.add('wipe'),
              forgetDevice: () async => session.add('forget'),
              signOutAccount: () async => session.add('signOut'),
              restart: (location) async => session.add('restart:$location'),
              clearPrepared: (uid, id) async => session.add('clear:$uid/$id'),
            )),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: OfflineGameScreen(now: () => now))),
    ));
    await tester.pumpAndSettle();
    return (repo: r, sins: sinsRepo, devices: devices, session: session);
  }

  String kpi(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('en ligne : en-tête, compteurs, conflit et file', (tester) async {
    await pump(tester);
    expect(find.text('Partie hors ligne'), findsOneWidget);
    expect(find.text('Hors ligne'), findsNothing);
    expect(find.text('Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30'), findsOneWidget);
    expect(kpi(tester, 'kpi-sheets'), '2');
    expect(kpi(tester, 'kpi-pending'), '1');
    expect(kpi(tester, 'kpi-conflicts'), '1');
    expect(find.text('conflit'), findsOneWidget);
    expect(find.text('CONFLIT · ISAURE DE VALCOURT'), findsOneWidget);
    expect(find.text('Léa G. et Marc ont saisi chacun un péché de niveau 2 le 3 oct. S’agit-il du même péché ?'), findsOneWidget);
    expect(find.text('Léa G. · 22h44'), findsOneWidget);
    expect(find.text('Marc · 22h47'), findsOneWidget);
    expect(find.text('+1 trait de Bête'), findsNWidgets(2));
    expect(find.text('Péché niveau 1 · remords réussi'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Événement · Titre obtenu : Gardien'), findsOneWidget);
    expect(find.text('Envoyé'), findsOneWidget);
    expect(find.text('Événement · Étreinte'), findsNothing);
    expect(find.text('Conflit'), findsNWidgets(2));
    expect(find.text(cannotDo), findsOneWidget);
    expect(find.text(playersNote), findsOneWidget);
  });

  testWidgets('conflit : garder l’un, garder l’autre, ou deux péchés distincts', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Même péché : garder celui de Léa G.'));
    await tester.pump();
    await tester.tap(find.text('Même péché : garder celui de Marc'));
    await tester.pump();
    await tester.tap(find.text('Deux péchés distincts'));
    await tester.pump();
    expect(r.sins.calls, ['delete:x:m1', 'delete:x:l1', 'distinct:x:l1,m1']);
  });

  testWidgets('conflit tranché hors ligne : l’écran ne reste pas bloqué (Review Focus 1)', (tester) async {
    final r = await pump(tester, offline: true, sins: _HangingSins());
    await tester.tap(find.text('Même péché : garder celui de Léa G.'));
    await tester.pump();
    await tester.tap(find.text('Deux péchés distincts'));
    await tester.pump();
    expect(r.sins.calls, ['delete:x:m1', 'distinct:x:l1,m1']);
  });

  testWidgets('conflit refusé : message sous le bloc', (tester) async {
    await pump(tester, sins: FakeSinsRepository()..error = Exception('refus'));
    await tester.tap(find.text('Deux péchés distincts'));
    await tester.pumpAndSettle();
    expect(find.text(resolveRefusedText), findsOneWidget);
  });

  testWidgets('narrateur : il prépare son appareil, il ne tranche pas', (tester) async {
    await pump(tester, me: julien);
    expect(find.text('CONFLIT · ISAURE DE VALCOURT'), findsOneWidget);
    expect(find.text('Deux péchés distincts'), findsNothing);
    expect(find.text('Préparer la partie'), findsOneWidget);
  });

  testWidgets('hors ligne : badge, préparation impossible', (tester) async {
    await pump(tester, offline: true);
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Préparer la partie')).onPressed, isNull);
    expect(find.text(notPreparedGameText), findsNothing);
  });

  testWidgets('hors ligne sans préparation : bandeau', (tester) async {
    await pump(tester, offline: true, device: const Device(id: 'd1', name: 'Navigateur · Windows', web: true));
    expect(find.text(notPreparedGameText), findsOneWidget);
    expect(find.text('Partie du samedi 3 oct.'), findsOneWidget);
  });

  testWidgets('aucune partie en cours', (tester) async {
    await pump(tester, games: const []);
    expect(find.text(noGameText), findsOneWidget);
  });

  testWidgets('préparer : lectures selon les cases, appareil noté, cases gardées', (tester) async {
    final r = await pump(tester);
    expect(find.text('2 fiches'), findsOneWidget);
    await tester.tap(find.text('Référentiel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Préparer la partie'));
    await tester.pumpAndSettle();
    expect(r.repo.calls, ['prepare:g2:false/true/false']);
    expect(r.devices.calls, ['prepared:lea/d1/g2']);
    expect(find.text(preparedText), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('prepare.rulebook'), isFalse);
  });

  testWidgets('préparation refusée : message', (tester) async {
    await pump(tester, repo: FakeOfflineGameRepository()..error = Exception('refus'));
    await tester.tap(find.text('Préparer la partie'));
    await tester.pumpAndSettle();
    expect(find.text(prepareFailedText), findsOneWidget);
  });

  testWidgets('synchroniser : envoi attendu, heure de la synchronisation', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Synchroniser maintenant'));
    await tester.pumpAndSettle();
    expect(r.repo.calls, ['sync']);
    expect(find.text(allSentText), findsOneWidget);
    expect(find.text('Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 23h'), findsOneWidget);
  });

  testWidgets('synchroniser sans réseau : message, le bouton revient (Review Focus 5)', (tester) async {
    await pump(tester, repo: FakeOfflineGameRepository()..error = TimeoutException('réseau'));
    await tester.tap(find.text('Synchroniser maintenant'));
    await tester.pumpAndSettle();
    expect(find.text(syncLaterText), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Synchroniser maintenant')).onPressed, isNotNull);
  });

  testWidgets('politique d’effacement : gardée sur l’appareil', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('wipe-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jamais').last);
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('wipePolicy'), 'never');
  });

  testWidgets('effacer maintenant : confirmation, puis effacement de l’appareil', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Effacer maintenant de cet appareil'));
    await tester.pumpAndSettle();
    expect(find.text('Effacer les données de cet appareil ? Vous restez connecté.'), findsOneWidget);
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();
    expect(r.session, ['clear:lea/d1', 'wipe', 'restart:/conteur/gel/hors-ligne']);
  });

  testWidgets('390 px : une colonne, sans débordement', (tester) async {
    await pump(tester, size: const Size(390, 4200));
    expect(tester.takeException(), isNull);
    expect(find.text('Deux péchés distincts'), findsOneWidget);
    expect(find.text('Péché niveau 1 · remords réussi'), findsOneWidget);
  });
}
