import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../places/place.dart' show PlaceEntry;
import 'servant_file.dart';
import 'servant_rules.dart';

part 'servants_repository.g.dart';

/// `servants/{id}` : fiches détaillées des serviteurs et des mortels, avec note secrète et historique.
class ServantsRepository {
  ServantsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('servants');

  List<ServantFile> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) ServantFile.fromMap(d.id, d.data())]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Équipe : toutes les fiches.
  Stream<List<ServantFile>> watchAll() => _col.snapshots().map(_sorted);

  /// Équipe : les serviteurs d'un personnage.
  Stream<List<ServantFile>> watchForDomitor(String characterId) => _col.where('domitorId', isEqualTo: characterId).snapshots().map(_sorted);

  /// Joueur : les serviteurs de ses personnages (requête permise par les règles).
  Stream<List<ServantFile>> watchForPlayer(String uid) => _col.where('holderPlayers', arrayContains: uid).snapshots().map(_sorted);

  Stream<String> watchNote(String id) =>
      _col.doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Stream<List<PlaceEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) PlaceEntry.fromMap(d.data())]);

  /// Crée ([before] en version 0) ou modifie [f] dans un lot : fiche (version + 1), historique, note. Renvoie l'id.
  /// Un mortel neuf a un id vide : Firestore en génère un.
  Future<String> save(ServantFile before, ServantFile f, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    final creating = before.version == 0;
    final ref = f.id.isEmpty ? _col.doc() : _col.doc(f.id);
    final h = ref.collection('history').doc();
    final now = FieldValue.serverTimestamp();
    final noteChanged = note != null && note.trim() != noteBefore.trim();
    final summary = creating ? ['Fiche créée'] : [...servantChanges(before, f), if (noteChanged) 'Note secrète modifiée'];
    final batch = _db.batch()
      ..set(
        ref,
        {
          ...f.toMap(),
          'version': creating ? 1 : before.version + 1,
          'lastHistoryId': h.id,
          'updatedAt': now,
          'updatedByName': by.name,
          if (creating) 'createdAt': now,
        },
        SetOptions(merge: !creating), // fusion : garde createdAt ; toutes les autres clés sont réécrites
      )
      ..set(h, {
        'at': now,
        'byUid': by.uid,
        'byName': by.name,
        'summary': summary.isEmpty ? ['Enregistré sans changement'] : summary,
        'reason': reason.trim(),
      });
    if (note != null && noteChanged) batch.set(ref.collection('private').doc('note'), {'text': note.trim()});
    await batch.commit();
    return ref.id;
  }

  /// Serviteur retiré de la fiche de son domitor : la fiche détaillée, si elle existe, est marquée libérée.
  Future<void> release(String id, Actor by, {int rank = 1}) async {
    final d = await _col.doc(id).get();
    final data = d.data();
    if (data == null || data['releasedAt'] != null) return;
    final before = ServantFile.fromMap(id, data);
    await save(
      before,
      before.copy()
        ..releasedAt = DateTime.now()
        ..releasedRank = rank,
      by,
      reason: 'Retiré de la fiche du domitor',
    );
  }

  /// Joueur du domitor changé : l'accès à la fiche détaillée, si elle existe, suit.
  Future<void> setPlayers(String id, List<String> players, Actor by) async {
    final d = await _col.doc(id).get();
    final data = d.data();
    if (data == null) return;
    final before = ServantFile.fromMap(id, data);
    if (before.holderPlayers.join(',') == players.join(',')) return;
    await save(before, before.copy()..holderPlayers = players, by, reason: 'Joueur du domitor changé');
  }

  /// Supprime la fiche, sa note et son historique.
  Future<void> delete(String id) async {
    // ponytail: un seul lot, limité à 500 écritures ; découper si une fiche a plus de 498 entrées d'historique.
    final history = await _col.doc(id).collection('history').get();
    final batch = _db.batch()
      ..delete(_col.doc(id).collection('private').doc('note'))
      ..delete(_col.doc(id));
    for (final d in history.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}

@Riverpod(keepAlive: true)
ServantsRepository servantsRepository(Ref ref) => ServantsRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<ServantFile>> allServantFiles(Ref ref) => ref.watch(servantsRepositoryProvider).watchAll();

/// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.
@riverpod
Stream<List<ServantFile>> characterServantFiles(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const Stream.empty();
  final repo = ref.watch(servantsRepositoryProvider);
  if (me.role.isStaff) return repo.watchForDomitor(characterId);
  return repo.watchForPlayer(me.uid).map((l) => [for (final f in l) if (f.domitorId == characterId) f]);
}

@riverpod
Stream<String> servantNote(Ref ref, String id) => ref.watch(servantsRepositoryProvider).watchNote(id);

@riverpod
Stream<List<PlaceEntry>> servantHistory(Ref ref, String id) => ref.watch(servantsRepositoryProvider).watchHistory(id);
