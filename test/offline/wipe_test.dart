import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/device_session.dart';
import 'package:portail_met/offline/wipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/game_rules_test.dart' show frozenGame;

DeviceSession session(List<String> calls, {WipePolicy policy = WipePolicy.week, bool pending = false}) => DeviceSession(
      removeDevice: (_, _) async {},
      pendingWrites: () async => pending,
      wipeCache: () async => calls.add('wipe'),
      forgetDevice: () async => calls.add('forget'),
      signOutAccount: () async => calls.add('signOut'),
      restart: (location) async => calls.add('restart:$location'),
      clearPrepared: (uid, id) async => calls.add('clear:$uid/$id'),
      policy: () async => policy,
      removeTimeout: const Duration(milliseconds: 20),
    );

void main() {
  // Partie du 3 oct., levée prévue le 4 à 6h.
  final running = frozenGame();
  final lifted = frozenGame(liftedAt: DateTime(2026, 10, 4, 1));
  const device = Device(id: 'd1', name: 'Navigateur · Windows', gameId: 'g2');

  test('politique : libellés et lecture, « 7 jours » par défaut', () {
    expect([for (final p in WipePolicy.values) p.label], ['7 jours après la partie', 'Au dégel', 'Jamais']);
    expect(WipePolicy.parse('lift'), WipePolicy.lift);
    expect(WipePolicy.parse(null), WipePolicy.week);
    expect(WipePolicy.parse('autre'), WipePolicy.week);
  });

  test('fin du gel : levée, ou levée prévue passée ; rien tant qu’il court', () {
    expect(gameEnd(running, DateTime(2026, 10, 3, 22)), isNull);
    expect(gameEnd(running, DateTime(2026, 10, 4, 7)), DateTime(2026, 10, 4, 6));
    expect(gameEnd(lifted, DateTime(2026, 10, 4, 2)), DateTime(2026, 10, 4, 1));
  });

  test('faut-il effacer ?', () {
    expect(shouldWipe(WipePolicy.lift, running, DateTime(2026, 10, 3, 22)), isFalse);
    expect(shouldWipe(WipePolicy.lift, running, DateTime(2026, 10, 4, 7)), isTrue);
    expect(shouldWipe(WipePolicy.week, running, DateTime(2026, 10, 11, 5)), isFalse);
    expect(shouldWipe(WipePolicy.week, running, DateTime(2026, 10, 11, 6)), isTrue);
    expect(shouldWipe(WipePolicy.week, lifted, DateTime(2026, 10, 11, 1)), isTrue);
    expect(shouldWipe(WipePolicy.never, lifted, DateTime(2027)), isFalse);
    expect(shouldWipe(WipePolicy.lift, null, DateTime(2027)), isFalse);
  });

  test('réglages de l’appareil : défauts, puis gardés', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await OfflinePrefs.load();
    expect(p.rulebook, isTrue);
    expect(p.bonds, isTrue);
    expect(p.notes, isFalse);
    expect(p.policy, WipePolicy.week);
    await p.copyWith(rulebook: false, notes: true, policy: WipePolicy.never).save();
    final again = await OfflinePrefs.load();
    expect(again.rulebook, isFalse);
    expect(again.bonds, isTrue);
    expect(again.notes, isTrue);
    expect(again.policy, WipePolicy.never);
    expect((await SharedPreferences.getInstance()).getString('wipePolicy'), 'never');
  });

  test('« Effacer maintenant » : partie oubliée, cache vidé, l’app repart ; le compte reste connecté', () async {
    final calls = <String>[];
    await session(calls).wipe('u1', 'd1', '/conteur/gel/hors-ligne');
    expect(calls, ['clear:u1/d1', 'wipe', 'restart:/conteur/gel/hors-ligne']);
  });

  test('effacement programmé : une semaine après la levée', () async {
    final calls = <String>[];
    await session(calls).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 12), '/');
    expect(calls, ['clear:u1/d1', 'wipe', 'restart:/']);
  });

  test('effacement programmé : trop tôt, jamais, partie inconnue, rien de préparé', () async {
    final calls = <String>[];
    await session(calls).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 8), '/');
    await session(calls, policy: WipePolicy.never).wipeIfDue('u1', device, [lifted], DateTime(2027), '/');
    await session(calls).wipeIfDue('u1', device, const [], DateTime(2027), '/');
    await session(calls).wipeIfDue('u1', const Device(id: 'd1', name: 'x'), [lifted], DateTime(2027), '/');
    await session(calls).wipeIfDue('u1', null, [lifted], DateTime(2027), '/');
    expect(calls, isEmpty);
  });

  test('effacement programmé : retardé tant que des saisies attendent le réseau (Review Focus 3)', () async {
    final calls = <String>[];
    await session(calls, pending: true).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 12), '/');
    expect(calls, isEmpty);
  });

  test('« Au dégel » : dès la levée', () async {
    final calls = <String>[];
    await session(calls, policy: WipePolicy.lift).wipeIfDue('u1', device, [lifted], DateTime(2026, 10, 4, 2), '/');
    expect(calls, contains('wipe'));
  });

  test('partie préparée impossible à oublier, cache impossible à vider : l’app repart quand même', () async {
    final calls = <String>[];
    final s = DeviceSession(
      removeDevice: (_, _) async {},
      pendingWrites: () async => false,
      wipeCache: () async => throw Exception('échec'),
      forgetDevice: () async {},
      signOutAccount: () async {},
      restart: (location) async => calls.add('restart:$location'),
      clearPrepared: (_, _) async => throw Exception('refus'),
    );
    await s.wipe('u1', 'd1', '/');
    expect(calls, ['restart:/']);
  });
}
