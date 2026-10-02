import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import 'character.dart';
import 'describe_changes.dart';

part 'character_repository.g.dart';

/// Auteur d'une écriture, recopié dans l'historique.
class Actor {
  const Actor(this.uid, this.name);
  final String uid;
  final String name;
}

Actor? actorOf(AppUser? u) => u == null ? null : Actor(u.uid, u.displayName);

int _byName(Character a, Character b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

class CharacterRepository {
  CharacterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('characters');

  Stream<List<Character>> watchMine(String uid) => _col
      .where('playerUid', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs.map(Character.fromDoc).toList()..sort(_byName));

  Stream<List<Character>> watchAll() =>
      _col.orderBy('name').snapshots().map((q) => q.docs.map(Character.fromDoc).toList());

  Stream<Character?> watch(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? Character.fromDoc(d) : null);

  Stream<List<HistoryEntry>> watchHistory(String id) => _col
      .doc(id)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => q.docs.map(HistoryEntry.fromDoc).toList());

  Stream<String> watchNotes(String id) => _col
      .doc(id)
      .collection('private')
      .doc('notes')
      .snapshots()
      .map((d) => d.data()?['text'] as String? ?? '');

  Future<void> saveNotes(String id, String text, Actor by) => _col.doc(id).collection('private').doc('notes').set({
        'text': text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'byUid': by.uid,
      });

  /// PJ : amorce en brouillon, le joueur la remplira. PNJ : fiche active, remplie par le conte.
  Future<String> create({
    required String name,
    required CharacterKind kind,
    String? playerUid,
    String? playerName,
    required Actor by,
  }) async {
    final ref = _col.doc();
    final h = ref.collection('history').doc();
    final c = Character(
      id: ref.id,
      name: name.trim(),
      kind: kind,
      playerUid: kind == CharacterKind.pj ? playerUid : null,
      playerName: kind == CharacterKind.pj ? playerName : null,
      status: kind == CharacterKind.pj ? CharacterStatus.draft : CharacterStatus.active,
    )
      ..version = 1
      ..lastHistoryId = h.id;
    final now = FieldValue.serverTimestamp();
    await (_db.batch()
          ..set(ref, {...c.toMap(), 'createdAt': now, 'updatedAt': now})
          ..set(h, _entry(by, 'creation', ['Fiche créée'], '')))
        .commit();
    return ref.id;
  }

  /// Modification tracée (C3). Refusée par les règles si la fiche a changé entre-temps (version).
  Future<void> saveEdit(Character before, Character after, String reason, Actor by) => _commit(
        after,
        fromVersion: before.version,
        by: by,
        kind: before.status != after.status ? 'status' : 'edit',
        summary: describeChanges(before, after),
        reason: reason,
        delta: xpDelta(before, after),
      );

  Future<void> _commit(
    Character c, {
    required int fromVersion,
    required Actor by,
    required String kind,
    required List<String> summary,
    required String reason,
    Map<String, int> delta = const {'initial': 0, 'earned': 0, 'spent': 0},
  }) {
    final ref = _col.doc(c.id);
    final h = ref.collection('history').doc();
    final data = {
      ...c.toMap(),
      'version': fromVersion + 1,
      'lastHistoryId': h.id,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return (_db.batch()
          ..update(ref, data)
          ..set(h, _entry(by, kind, summary, reason, delta)))
        .commit();
  }

  Map<String, dynamic> _entry(
    Actor by,
    String kind,
    List<String> summary,
    String reason, [
    Map<String, int> delta = const {'initial': 0, 'earned': 0, 'spent': 0},
  ]) =>
      {
        'at': FieldValue.serverTimestamp(),
        'byUid': by.uid,
        'byName': by.name,
        'kind': kind,
        'summary': summary,
        'reason': reason.trim(),
        'xpDelta': delta,
      };
}

@Riverpod(keepAlive: true)
CharacterRepository characterRepository(Ref ref) => CharacterRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Character>> myCharacters(Ref ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(characterRepositoryProvider).watchMine(uid);
}

@riverpod
Stream<List<Character>> allCharacters(Ref ref) => ref.watch(characterRepositoryProvider).watchAll();

@riverpod
Stream<Character?> character(Ref ref, String id) => ref.watch(characterRepositoryProvider).watch(id);

@riverpod
Stream<List<HistoryEntry>> characterHistory(Ref ref, String id) =>
    ref.watch(characterRepositoryProvider).watchHistory(id);

@riverpod
Stream<String> characterNotes(Ref ref, String id) => ref.watch(characterRepositoryProvider).watchNotes(id);
