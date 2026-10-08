import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/trace.dart';
import 'ally_file.dart';

part 'allies_repository.g.dart';

/// `allies/{id}` (suivi d'usage) et `allies/{id}/history/{h}`.
class AlliesRepository {
  AlliesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('allies');

  List<AllyFile> _list(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) AllyFile.fromMap(d.id, d.data())];

  Stream<List<AllyFile>> watchAll() => _col.snapshots().map(_list);

  Stream<List<AllyFile>> watchForCharacter(String characterId) => _col.where('characterId', isEqualTo: characterId).snapshots().map(_list);

  /// Joueur : le suivi des alliés de ses personnages (requête permise par les règles).
  Stream<List<AllyFile>> watchForPlayer(String uid) => _col.where('holderPlayers', arrayContains: uid).snapshots().map(_list);

  Stream<List<TraceEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) TraceEntry.fromMap(d.data())]);

  /// Crée ([before] en version 0) ou modifie le suivi, avec une entrée d'historique.
  Future<void> save(AllyFile before, AllyFile f, Actor by, {String reason = ''}) async {
    final batch = _db.batch();
    stageTraced(
      batch,
      _col.doc(f.id),
      f.toMap(),
      creating: before.version == 0,
      fromVersion: before.version,
      byUid: by.uid,
      byName: by.name,
      summary: allyFileChanges(before, f),
      reason: reason,
    );
    await batch.commit();
  }

  /// Joueur du personnage changé (C3) : l'accès au suivi de ses alliés suit.
  Future<void> setPlayers(String characterId, List<String> players, Actor by) async {
    final q = await _col.where('characterId', isEqualTo: characterId).get();
    for (final d in q.docs) {
      final before = AllyFile.fromMap(d.id, d.data());
      if (before.holderPlayers.join(',') == players.join(',')) continue;
      await save(before, before.copy()..holderPlayers = players, by, reason: 'Joueur du personnage changé');
    }
  }
}

@Riverpod(keepAlive: true)
AlliesRepository alliesRepository(Ref ref) => AlliesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<AllyFile>> allAllyFiles(Ref ref) => ref.watch(alliesRepositoryProvider).watchAll();

/// Suivi des alliés d'un personnage : requête de l'équipe, ou suivis du joueur filtrés par personnage.
@riverpod
Stream<List<AllyFile>> characterAllyFiles(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final repo = ref.watch(alliesRepositoryProvider);
  if (me.role.isStaff) return repo.watchForCharacter(characterId);
  return repo.watchForPlayer(me.uid).map((l) => [for (final f in l) if (f.characterId == characterId) f]);
}

@riverpod
Stream<List<TraceEntry>> allyHistory(Ref ref, String id) => ref.watch(alliesRepositoryProvider).watchHistory(id);
