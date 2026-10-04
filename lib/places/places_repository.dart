import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/trace.dart';
import 'place.dart';
import 'place_rules.dart';

part 'places_repository.g.dart';

/// `places/{id}` (privé), `places/{id}/private/note`, `places/{id}/history/{h}`, `publicPlaces/{id}`.
class PlacesRepository {
  PlacesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('places');
  CollectionReference<Map<String, dynamic>> get _public => _db.collection('publicPlaces');

  List<Place> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) Place.fromMap(d.id, d.data())]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Équipe : tous les lieux.
  Stream<List<Place>> watchAll() => _col.snapshots().map(_sorted);

  /// Joueur : les lieux de ses personnages (requête permise par les règles).
  Stream<List<Place>> watchForPlayer(String uid) => _col.where('holderPlayers', arrayContains: uid).snapshots().map(_sorted);

  /// Équipe : les lieux d'un personnage.
  Stream<List<Place>> watchForCharacter(String characterId) =>
      _col.where('holderIds', arrayContains: characterId).snapshots().map(_sorted);

  /// Résumés publics (nom, type, ce qui s'en sait).
  Stream<List<Place>> watchPublic() => _public.snapshots().map(_sorted);

  Stream<String> watchNote(String id) =>
      _col.doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Stream<List<TraceEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) TraceEntry.fromMap(d.data())]);

  /// Crée (id vide) ou modifie [p] dans un lot : lieu (version + 1), entrée d'historique, résumé public
  /// (écrit si connu de tous, supprimé sinon) et note secrète. Renvoie l'id.
  Future<String> save(Place before, Place p, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    final creating = p.id.isEmpty;
    final ref = creating ? _col.doc() : _col.doc(p.id);
    final noteChanged = note != null && note.trim() != noteBefore.trim();
    final batch = _db.batch();
    stageTraced(
      batch,
      ref,
      p.toMap(),
      creating: creating,
      fromVersion: before.version,
      byUid: by.uid,
      byName: by.name,
      summary: creating ? ['Lieu créé'] : [...placeChanges(before, p), if (noteChanged) 'Note secrète modifiée'],
      reason: reason,
      note: noteChanged ? note : null,
    );
    if (p.public) {
      batch.set(_public.doc(ref.id), p.publicMap());
    } else if (!creating) {
      batch.delete(_public.doc(ref.id));
    }
    await batch.commit();
    return ref.id;
  }

  /// Supprime le lieu, son résumé public, sa note et son historique.
  Future<void> delete(String id) => deleteTraced(_db, _col.doc(id), also: [_public.doc(id)]);
}

@Riverpod(keepAlive: true)
PlacesRepository placesRepository(Ref ref) => PlacesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Place>> allPlaces(Ref ref) => ref.watch(placesRepositoryProvider).watchAll();

@riverpod
Stream<List<Place>> publicPlaces(Ref ref) => ref.watch(placesRepositoryProvider).watchPublic();

/// Lieux d'un personnage : requête de l'équipe, ou lieux du joueur filtrés par personnage.
@riverpod
Stream<List<Place>> characterPlaces(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const Stream.empty();
  final repo = ref.watch(placesRepositoryProvider);
  if (me.role.isStaff) return repo.watchForCharacter(characterId);
  return repo.watchForPlayer(me.uid).map((l) => [for (final p in l) if (p.holderIds.contains(characterId)) p]);
}

@riverpod
Stream<String> placeNote(Ref ref, String id) => ref.watch(placesRepositoryProvider).watchNote(id);

@riverpod
Stream<List<TraceEntry>> placeHistory(Ref ref, String id) => ref.watch(placesRepositoryProvider).watchHistory(id);
