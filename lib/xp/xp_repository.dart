import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import 'xp_request.dart';
import 'xp_rules.dart';

part 'xp_repository.g.dart';

int _newestFirst(XpRequest a, XpRequest b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
int _oldestFirst(XpRequest a, XpRequest b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0));

/// Demandes d'XP (`requests`). Un seul filtre par requête : pas d'index composite, tri dans l'application.
class XpRepository {
  XpRepository(this._db, this._characters);

  final FirebaseFirestore _db;
  final CharacterRepository _characters;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('requests');

  List<XpRequest> Function(QuerySnapshot<Map<String, dynamic>>) _sorted(int Function(XpRequest, XpRequest) by) =>
      (q) => q.docs.map(XpRequest.fromDoc).toList()..sort(by);

  Stream<List<XpRequest>> watchMine(String uid) =>
      _col.where('playerUid', isEqualTo: uid).snapshots().map(_sorted(_newestFirst));

  Stream<List<XpRequest>> watchPending() =>
      _col.where('status', isEqualTo: RequestStatus.pending.name).snapshots().map(_sorted(_oldestFirst));

  Stream<List<XpRequest>> watchForCharacter(String characterId) =>
      _col.where('characterId', isEqualTo: characterId).snapshots().map(_sorted(_newestFirst));

  /// Nouvelle demande (id vide) ou modification. [submit] : envoi au conte (statut « en attente »).
  Future<String> save(XpRequest r, {required bool submit}) async {
    final status = submit ? RequestStatus.pending : (r.id.isEmpty ? RequestStatus.draft : r.status);
    final now = FieldValue.serverTimestamp();
    if (r.id.isEmpty) {
      final ref = _col.doc();
      await ref.set({
        ...r.toMap(),
        'status': status.name,
        'version': 1,
        'createdAt': now,
        'updatedAt': now,
        'submittedAt': submit ? now : null,
      });
      return ref.id;
    }
    await _col.doc(r.id).update({
      ...r.toMap(),
      'status': status.name,
      'version': r.version + 1,
      'updatedAt': now,
      if (submit) 'submittedAt': now,
    });
    return r.id;
  }

  /// Réponse du joueur à une demande « à compléter » : elle repart au conte.
  Future<void> reply(XpRequest r, String text, Actor by) => _col.doc(r.id).update({
        'thread': [for (final m in [...r.thread, XpMessage(by.uid, by.name, nowMs(), text.trim())]) m.toMap()],
        'status': RequestStatus.pending.name,
        'version': r.version + 1,
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancel(XpRequest r) => _col.doc(r.id).update({
        'status': RequestStatus.cancelled.name,
        'version': r.version + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Décision du conte. Validée : la fiche [c] reçoit les achats dans le même lot (règle staffRequestDecision).
  Future<void> decide(XpRequest r, Character c, RequestStatus to, String comment, Actor by) {
    final text = comment.trim();
    final message = text.isEmpty ? null : XpMessage(by.uid, by.name, nowMs(), text);
    final batch = _db.batch()..update(_col.doc(r.id), decisionUpdate(r, to, message, by.uid, FieldValue.serverTimestamp()));
    if (to == RequestStatus.accepted) {
      final after = applyRequest(c, r.items);
      _characters.stageEdit(
        batch,
        after,
        fromVersion: c.version,
        by: by,
        kind: 'xp',
        summary: describeChanges(c, after),
        reason: text.isEmpty ? 'Demande validée' : 'Demande validée : $text',
        delta: xpDelta(c, after),
      );
    }
    return batch.commit();
  }
}

/// Écriture de la demande lors d'une décision : seulement les clés permises par la règle staffRequestDecision.
Map<String, dynamic> decisionUpdate(XpRequest r, RequestStatus to, XpMessage? message, String byUid, Object now) => {
      'status': to.name,
      'thread': [for (final m in [...r.thread, ?message]) m.toMap()],
      'version': r.version + 1,
      'updatedAt': now,
      if (to != RequestStatus.changes) 'decidedAt': now,
      if (to != RequestStatus.changes) 'decidedByUid': byUid,
    };

@Riverpod(keepAlive: true)
XpRepository xpRepository(Ref ref) =>
    XpRepository(ref.watch(firestoreProvider), ref.watch(characterRepositoryProvider));

@riverpod
Stream<List<XpRequest>> myRequests(Ref ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(xpRepositoryProvider).watchMine(uid);
}

@riverpod
Stream<List<XpRequest>> pendingRequests(Ref ref) => ref.watch(xpRepositoryProvider).watchPending();

@riverpod
Stream<List<XpRequest>> characterRequests(Ref ref, String characterId) =>
    ref.watch(xpRepositoryProvider).watchForCharacter(characterId);
