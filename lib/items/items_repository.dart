import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/trace.dart';
import 'item.dart';
import 'item_rules.dart';

part 'items_repository.g.dart';

/// `items/{id}`, `items/{id}/private/note`, `items/{id}/history/{h}`.
class ItemsRepository {
  ItemsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('items');

  List<Item> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) Item.fromMap(d.id, d.data())]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Équipe : tous les objets.
  Stream<List<Item>> watchAll() => _col.snapshots().map(_sorted);

  /// Équipe : les objets d'un personnage.
  Stream<List<Item>> watchForCharacter(String characterId) => _col.where('characterId', isEqualTo: characterId).snapshots().map(_sorted);

  /// Joueur : les objets de ses personnages (requête permise par les règles).
  Stream<List<Item>> watchForPlayer(String uid) => _col.where('playerUid', isEqualTo: uid).snapshots().map(_sorted);

  Stream<String> watchNote(String id) =>
      _col.doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Stream<List<TraceEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) TraceEntry.fromMap(d.data())]);

  /// Conte : crée (id vide) ou modifie [i] dans un lot : objet (version + 1), historique, note secrète. Renvoie l'id.
  Future<String> save(Item before, Item i, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    final creating = i.id.isEmpty;
    final ref = creating ? _col.doc() : _col.doc(i.id);
    final noteChanged = note != null && note.trim() != noteBefore.trim();
    final batch = _db.batch();
    stageTraced(
      batch,
      ref,
      i.toMap(),
      creating: creating,
      fromVersion: before.version,
      byUid: by.uid,
      byName: by.name,
      summary: creating ? ['Objet créé'] : [...itemChanges(before, i), if (noteChanged) 'Note secrète modifiée'],
      reason: reason,
      note: noteChanged ? note : null,
    );
    await batch.commit();
    return ref.id;
  }

  /// Joueur : demande d'objet (état « Demande à valider », sans qualité hors limite). Renvoie l'id.
  Future<String> request(Item i, Actor by) async {
    final ref = _col.doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      ...i.toMap(),
      'state': ItemState.requested.name,
      'extraQuality': null,
      'refusal': '',
      'version': 1,
      'createdAt': now,
      'updatedAt': now,
      'updatedByName': by.name,
    });
    return ref.id;
  }

  /// Joueur du porteur changé (C3) : l'accès à ses objets suit, chaque objet étant réenregistré et tracé.
  Future<void> setPlayer(String characterId, String playerUid, Actor by) async {
    final q = await _col.where('characterId', isEqualTo: characterId).get();
    for (final d in q.docs) {
      final before = Item.fromMap(d.id, d.data());
      if (before.playerUid == playerUid) continue;
      await save(before, before.copy()..playerUid = playerUid, by, reason: 'Joueur du porteur changé');
    }
  }

  /// Conte : supprime l'objet, sa note et son historique.
  Future<void> delete(String id) => deleteTraced(_db, _col.doc(id));

  /// Joueur : supprime sa demande (en attente ou refusée).
  Future<void> deleteRequest(String id) => _col.doc(id).delete();
}

@Riverpod(keepAlive: true)
ItemsRepository itemsRepository(Ref ref) => ItemsRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Item>> allItems(Ref ref) => ref.watch(itemsRepositoryProvider).watchAll();

/// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.
@riverpod
Stream<List<Item>> characterItems(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final repo = ref.watch(itemsRepositoryProvider);
  if (me.role.isStaff) return repo.watchForCharacter(characterId);
  return repo.watchForPlayer(me.uid).map((l) => [for (final i in l) if (i.characterId == characterId) i]);
}

@riverpod
Stream<String> itemNote(Ref ref, String id) => ref.watch(itemsRepositoryProvider).watchNote(id);

@riverpod
Stream<List<TraceEntry>> itemHistory(Ref ref, String id) => ref.watch(itemsRepositoryProvider).watchHistory(id);
