import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../events/event_rules.dart';
import '../events/story_event.dart';
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
    GhoulState? ghoul,
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
      ..lastHistoryId = h.id
      ..ghoul = kind == CharacterKind.pj ? ghoul : null;
    final now = FieldValue.serverTimestamp();
    await (_db.batch()
          ..set(ref, {...c.toMap(), 'createdAt': now, 'updatedAt': now})
          ..set(h, _entry(by, 'creation', [c.ghoul != null ? 'Fiche de goule créée' : 'Fiche créée'], '')))
        .commit();
    return ref.id;
  }

  /// Fiche complète créée d'un coup (étreinte d'un mortel ou d'un serviteur) ; renvoie l'id.
  /// [id] imposé : une seconde création sous le même identifiant est refusée par les règles (pas de doublon).
  Future<String> createSheet(Character c, Actor by, String summary, {String? id, List<StoryEvent> events = const []}) async {
    final ref = _col.doc(id);
    final h = ref.collection('history').doc();
    final sheet = Character.fromMap(ref.id, c.toMap())
      ..version = 1
      ..lastHistoryId = h.id;
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch()
      ..set(ref, {...sheet.toMap(), 'createdAt': now, 'updatedAt': now})
      ..set(h, _entry(by, 'creation', [summary], ''));
    for (final e in events) {
      batch.set(ref.collection('events').doc(), newEventData(e, by.uid, by.name));
    }
    await batch.commit();
    return ref.id;
  }

  /// Modification tracée (C3, transformations). Refusée par les règles si la fiche a changé entre-temps (version).
  /// [extra] : clés écrites en plus, par exemple la suppression de `ghoul` à l'étreinte.
  Future<void> saveEdit(Character before, Character after, String reason, Actor by, {String? kind, Map<String, Object?> extra = const {}, List<StoryEvent> events = const []}) =>
      _commit(
        after,
        fromVersion: before.version,
        by: by,
        kind: kind ?? (before.status != after.status ? 'status' : 'edit'),
        summary: describeChanges(before, after),
        reason: reason,
        delta: xpDelta(before, after),
        // Un rituel retiré après un premier enregistrement doit être effacé (revue du plan C).
        extra: {...after.laterKeys(), ...extra},
        events: events,
      );

  /// Brouillon du joueur : version +1, pas d'historique (règle playerDraftSave).
  Future<void> saveDraft(Character c) => _col.doc(c.id).update({
        ...draftData(c),
        'version': c.version + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Character>> watchReview() => _col.where('status', isEqualTo: CharacterStatus.review.name).snapshots().map(
        (q) => q.docs.map(Character.fromDoc).toList()
          ..sort((a, b) => (a.submittedAt ?? DateTime(0)).compareTo(b.submittedAt ?? DateTime(0))),
      );

  Future<void> submit(Character c, Actor by) => _commit(
        c.clone()
          ..status = CharacterStatus.review
          ..submittedAt = nowMs(),
        fromVersion: c.version,
        by: by,
        kind: 'submission',
        summary: ['Fiche soumise au conte'],
        reason: '',
      );

  Future<void> withdraw(Character c, Actor by) => _commit(
        c.clone()
          ..status = CharacterStatus.draft
          ..submittedAt = null,
        fromVersion: c.version,
        by: by,
        kind: 'withdrawal',
        summary: ['Soumission retirée'],
        reason: '',
      );

  Future<void> setBonus(Character c, int bonus, Actor by) => _commit(
        c.clone()..xpBonus = bonus,
        fromVersion: c.version,
        by: by,
        kind: 'bonus',
        summary: ['Bonus du conte : ${c.xpBonus} → $bonus'],
        reason: '',
      );

  /// Validation (active), corrections (draft) ou refus (rejected) d'une fiche soumise.
  Future<void> decide(Character c, CharacterStatus to, String comment, Actor by) => _commit(
        c.clone()
          ..status = to
          ..decidedAt = nowMs()
          ..decidedByUid = by.uid
          ..comment = comment.trim().isEmpty ? null : comment.trim(),
        fromVersion: c.version,
        by: by,
        kind: switch (to) {
          CharacterStatus.active => 'validation',
          CharacterStatus.draft => 'corrections',
          _ => 'rejection',
        },
        summary: [
          switch (to) {
            CharacterStatus.active => 'Fiche validée et activée',
            CharacterStatus.draft => 'Corrections demandées',
            _ => 'Fiche refusée',
          },
        ],
        reason: comment,
        events: to == CharacterStatus.active ? [validatedEvent(c, DateTime.now())] : const [],
      );

  /// Ajoute à [batch] une modification tracée de la fiche (version + 1, entrée d'historique).
  void stageEdit(
    WriteBatch batch,
    Character c, {
    required int fromVersion,
    required Actor by,
    required String kind,
    required List<String> summary,
    required String reason,
    Map<String, int> delta = const {'initial': 0, 'earned': 0, 'spent': 0},
    Map<String, Object?> extra = const {},
    List<StoryEvent> events = const [],
  }) {
    final ref = _col.doc(c.id);
    final h = ref.collection('history').doc();
    batch
      ..update(ref, {
        ...c.toMap(),
        'version': fromVersion + 1,
        'lastHistoryId': h.id,
        'updatedAt': FieldValue.serverTimestamp(),
        ...extra,
      })
      ..set(h, _entry(by, kind, withConversion(c, summary), reason, delta));
    c.legacyServants = false;
    for (final e in events) {
      batch.set(ref.collection('events').doc(), newEventData(e, by.uid, by.name));
    }
  }

  Future<void> _commit(
    Character c, {
    required int fromVersion,
    required Actor by,
    required String kind,
    required List<String> summary,
    required String reason,
    Map<String, int> delta = const {'initial': 0, 'earned': 0, 'spent': 0},
    Map<String, Object?> extra = const {},
    List<StoryEvent> events = const [],
  }) {
    final batch = _db.batch();
    stageEdit(batch, c, fromVersion: fromVersion, by: by, kind: kind, summary: summary, reason: reason, delta: delta, extra: extra, events: events);
    return batch.commit();
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

@riverpod
Stream<List<Character>> reviewQueue(Ref ref) => ref.watch(characterRepositoryProvider).watchReview();

/// Écriture du brouillon par le joueur : les clés tardives toujours, vides comprises (règle playerDraftSave).
/// Sinon, un rituel acheté puis retiré dans la même séance resterait dans le document.
/// Sans `allies`, `path`, `derangements` ni `derangementTraits` : clés protégées, que seul le conte écrit (règle playerDraftSave).
Map<String, dynamic> draftData(Character c) {
  const protected = ['allies', 'path', 'derangements', 'derangementTraits'];
  return {
    ...c.toMap()..removeWhere((k, _) => protected.contains(k)),
    ...c.laterKeys()..removeWhere((k, _) => protected.contains(k)),
  };
}
