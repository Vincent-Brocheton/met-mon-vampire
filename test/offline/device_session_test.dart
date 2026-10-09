import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/offline/device_session.dart';

DeviceSession session(List<String> calls, {Future<void> Function(String uid, String id)? remove}) => DeviceSession(
      removeDevice: remove ?? (uid, id) async => calls.add('remove:$uid/$id'),
      pendingWrites: () async => false,
      wipeCache: () async => calls.add('wipe'),
      forgetDevice: () async => calls.add('forget'),
      signOutAccount: () async => calls.add('signOut'),
      restart: (location) async => calls.add('restart:$location'),
      removeTimeout: const Duration(milliseconds: 20),
    );

void main() {
  test('déconnexion à distance : appareil retiré, cache vidé, identifiant oublié, compte déconnecté, message', () async {
    final calls = <String>[];
    await session(calls).signOut('u1', 'd1', revoked: true);
    expect(calls, ['remove:u1/d1', 'wipe', 'forget', 'signOut', 'restart:/connexion?retire=1']);
  });

  test('« Se déconnecter » : même chemin, sans message', () async {
    final calls = <String>[];
    await session(calls).signOut('u1', 'd1');
    expect(calls.last, 'restart:/connexion');
  });

  test('sans réseau : la suppression qui n’aboutit pas ne bloque pas (Review Focus 5)', () async {
    final calls = <String>[];
    await session(calls, remove: (_, _) => Completer<void>().future).signOut('u1', 'd1');
    expect(calls, ['wipe', 'forget', 'signOut', 'restart:/connexion']);
  });

  test('suppression refusée : ignorée', () async {
    final calls = <String>[];
    await session(calls, remove: (_, _) async => throw Exception('refus')).signOut('u1', 'd1');
    expect(calls, ['wipe', 'forget', 'signOut', 'restart:/connexion']);
  });

  test('sans identifiant : rien à retirer', () async {
    final calls = <String>[];
    await session(calls).signOut('u1', null);
    expect(calls, ['wipe', 'forget', 'signOut', 'restart:/connexion']);
  });

  test('deux déclenchements rapprochés : un seul effet (Review Focus 5)', () async {
    final calls = <String>[];
    final s = session(calls);
    await Future.wait([s.signOut('u1', 'd1', revoked: true), s.signOut('u1', 'd1', revoked: true)]);
    expect(calls.where((c) => c == 'wipe'), hasLength(1));
  });
}
