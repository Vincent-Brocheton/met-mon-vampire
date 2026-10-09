import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/offline/device.dart';

import '../games/game_rules_test.dart' show frozenGame;

void main() {
  final now = DateTime(2099, 10, 3, 21);
  final game = frozenGame(year: 2099);

  test('nom d’après la plateforme', () {
    expect(deviceName(web: true, platform: TargetPlatform.windows), 'Navigateur · Windows');
    expect(deviceName(web: true, platform: TargetPlatform.android), 'Navigateur · Android');
    expect(deviceName(web: false, platform: TargetPlatform.android), 'Android');
  });

  test('dernière visite', () {
    expect(lastSeenText(DateTime(2099, 10, 3, 8), now), 'aujourd’hui');
    expect(lastSeenText(DateTime(2099, 10, 2, 23), now), 'hier');
    expect(lastSeenText(DateTime(2099, 9, 30, 23), DateTime(2099, 10, 1, 1)), 'hier');
    expect(lastSeenText(DateTime(2099, 9, 29), now), '29 sept.');
    expect(lastSeenText(null, now), '—');
  });

  test('copie hors ligne tant que le gel de la partie court', () {
    const web = Device(id: 'd1', name: 'Navigateur · Windows', web: true);
    const android = Device(id: 'd2', name: 'Android', gameId: 'g2');
    expect(deviceKindText(web, [game], now), 'Connexion web');
    expect(deviceKindText(android, [game], now), 'Copie hors ligne · partie du 3 oct.');
    expect(deviceKindText(android, [game], DateTime(2099, 10, 4, 7)), 'Application Android');
    expect(deviceKindText(android, const [], now), 'Application Android');
  });

  test('ligne de l’appareil', () {
    expect(deviceLine(Device(id: 'd1', name: 'x', web: true, lastSeen: DateTime(2099, 10, 3, 8)), [game], now), 'Connexion web · aujourd’hui');
    expect(deviceLine(Device(id: 'd1', name: 'x', revokedAt: DateTime(2099, 10, 3, 20)), [game], now), 'Déconnexion en attente');
  });

  test('lu depuis Firestore', () {
    final d = Device.fromMap('d1', {
      'name': 'Android',
      'web': false,
      'lastSeen': Timestamp.fromDate(DateTime(2099, 10, 3, 8)),
      'gameId': 'g2',
      'preparedAt': null,
      'revokedAt': null,
    });
    expect(d.id, 'd1');
    expect(d.name, 'Android');
    expect(d.web, isFalse);
    expect(d.lastSeen, DateTime(2099, 10, 3, 8));
    expect(d.gameId, 'g2');
    expect(d.preparedAt, isNull);
    expect(d.revokedAt, isNull);
  });
}
