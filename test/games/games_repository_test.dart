import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/games/games_repository.dart';

import '../characters/character_test.dart' show sample;

void main() {
  test('version figée : clés des règles, fiche complète, sans motif à la création', () {
    final m = snapshotData(sample(), DateTime(2026, 10, 3), const Actor('lea', 'Léa G.'), null);
    expect(m.keys.toSet(), {'sheet', 'version', 'gameDate', 'at', 'byUid', 'reason'});
    expect(m['version'], 4);
    expect(m['gameDate'], Timestamp.fromDate(DateTime(2026, 10, 3)));
    expect(m['byUid'], 'lea');
    expect(m['reason'], isNull);
    expect((m['sheet'] as Map)['name'], 'Isaure de Valcourt');
  });

  test('correction urgente : le motif est enregistré', () {
    final m = snapshotData(sample(), DateTime(2026, 10, 3), const Actor('lea', 'Léa G.'), 'Erreur de saisie');
    expect(m['reason'], 'Erreur de saisie');
  });
}
