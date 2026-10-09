import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import 'game.dart';

part 'games_repository.g.dart';

/// Parties (`games`), pointeur `chronicle/freeze` et versions figées `characters/{id}/frozen/{gameId}`.
class GamesRepository {
  GamesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('games');

  DocumentReference<Map<String, dynamic>> _snapshot(String characterId, String gameId) => _db.doc('characters/$characterId/frozen/$gameId');

  /// Toutes les parties, la plus récemment figée d'abord.
  Stream<List<Game>> watchAll() => _col.snapshots().map(
        (q) => [for (final d in q.docs) Game.fromMap(d.id, d.data())]..sort((a, b) => b.frozenAt.compareTo(a.frozenAt)),
      );

  /// Versions figées d'une partie, sur toutes les fiches (index `frozen.gameDate`, firestore.indexes.json).
  /// Deux parties peuvent tomber le même jour : on garde celles de [gameId].
  Stream<List<FrozenSheet>> watchSnapshots(String gameId, DateTime gameDate) => _db
      .collectionGroup('frozen')
      .where('gameDate', isEqualTo: Timestamp.fromDate(gameDate))
      .snapshots()
      .map((q) => [
            for (final d in q.docs)
              if (d.id == gameId) FrozenSheet.fromMap(d.reference.parent.parent!.id, d.id, d.data()),
          ]);

  /// Version figée d'une fiche pour une partie ; null si elle manque (fiche validée pendant le gel).
  Stream<FrozenSheet?> watchSnapshot(String characterId, String gameId) => _snapshot(characterId, gameId)
      .snapshots()
      .map((d) => d.exists ? FrozenSheet.fromMap(characterId, gameId, d.data()!) : null);

  /// Fige [sheets] en un lot : la partie, le pointeur et une version figée par fiche.
  // ponytail: un seul lot, plafond de 500 écritures (environ 497 fiches) ; découper le lot si la chronique grossit à ce point.
  Future<void> freeze(DateTime date, DateTime until, List<Character> sheets, Actor by) {
    final ref = _col.doc();
    final batch = _db.batch()
      ..set(ref, {
        'date': Timestamp.fromDate(date),
        'frozenAt': FieldValue.serverTimestamp(),
        'until': Timestamp.fromDate(until),
        'liftedAt': null,
        'liftedByUid': null,
        'byUid': by.uid,
        'sheetIds': [for (final c in sheets) c.id],
      })
      ..set(_db.doc('chronicle/freeze'), {'gameId': ref.id});
    for (final c in sheets) {
      batch.set(_snapshot(c.id, ref.id), snapshotData(c, date, by, null));
    }
    return batch.commit();
  }

  /// Levée anticipée (les règles exigent l'heure du serveur).
  Future<void> lift(Game g, Actor by) => _col.doc(g.id).update({'liftedAt': FieldValue.serverTimestamp(), 'liftedByUid': by.uid});

  /// Correction urgente : la fiche actuelle remplace la version figée, avec un motif.
  Future<void> correct(Game g, Character c, String reason, Actor by) => _snapshot(c.id, g.id).set(snapshotData(c, g.date, by, reason.trim()));
}

/// Données d'une version figée. Règles : clés fermées, heure du serveur, motif nul à la création et obligatoire ensuite.
Map<String, dynamic> snapshotData(Character c, DateTime gameDate, Actor by, String? reason) => {
      'sheet': c.toMap(),
      'version': c.version,
      'gameDate': Timestamp.fromDate(gameDate),
      'at': FieldValue.serverTimestamp(),
      'byUid': by.uid,
      'reason': reason,
    };

@Riverpod(keepAlive: true)
GamesRepository gamesRepository(Ref ref) => GamesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Game>> games(Ref ref) => ref.watch(gamesRepositoryProvider).watchAll();

@riverpod
Stream<List<FrozenSheet>> gameSnapshots(Ref ref, String gameId, DateTime gameDate) =>
    ref.watch(gamesRepositoryProvider).watchSnapshots(gameId, gameDate);

@riverpod
Stream<FrozenSheet?> frozenSheet(Ref ref, String characterId, String gameId) =>
    ref.watch(gamesRepositoryProvider).watchSnapshot(characterId, gameId);
