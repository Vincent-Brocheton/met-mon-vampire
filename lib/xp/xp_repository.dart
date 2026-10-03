import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import 'xp_corrections.dart';
import 'xp_gain.dart';
import 'xp_request.dart';
import 'xp_rules.dart';
import 'xp_settings.dart';

part 'xp_repository.g.dart';

int _newestFirst(XpRequest a, XpRequest b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
int _oldestFirst(XpRequest a, XpRequest b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0));

/// Entrée `correction` d'un historique, avec sa fiche (requête sur les historiques de toutes les fiches).
class CorrectionEntry {
  const CorrectionEntry(this.characterId, this.entry);
  final String characterId;
  final HistoryEntry entry;
}

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

  DocumentReference<Map<String, dynamic>> get _settings => _db.doc('chronicle/xp');

  Stream<XpSettings> watchSettings() => _settings.snapshots().map((d) => XpSettings.fromMap(d.data()));

  Future<void> saveSettings(XpSettings s, Actor by) => _settings.set({
        ...s.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': by.uid,
        'updatedByName': by.name,
      });

  /// Une écriture par fiche : une fiche modifiée entre-temps est refusée seule. Renvoie les noms refusés.
  Future<List<String>> _eachSheet<T>(List<T> items, Character Function(T) sheetOf, void Function(WriteBatch, T) stage) async {
    final failed = <String>[];
    for (final item in items) {
      final batch = _db.batch();
      stage(batch, item);
      try {
        await batch.commit();
      } catch (_) {
        failed.add(sheetOf(item).name);
      }
    }
    return failed;
  }

  Future<List<String>> payGain(List<GainDue> dues, Actor by) => _eachSheet<GainDue>(dues, (d) => d.c, (batch, d) {
        final after = d.c.clone()..xpEarned += d.xp;
        final summary = describeChanges(d.c, after);
        _characters.stageEdit(
          batch,
          after,
          fromVersion: d.c.version,
          by: by,
          kind: 'gain',
          summary: summary.isEmpty ? ['Aucun gain ce mois-ci (palier)'] : summary,
          reason: 'Gain mensuel · ${monthRange(d.months)}',
          delta: xpDelta(d.c, after),
          extra: {'gainedThrough': d.through},
        );
      });

  Future<List<String>> award(List<(Character, int)> items, String reason, Actor by) =>
      _eachSheet<(Character, int)>(items, (x) => x.$1, (batch, x) {
        final (c, n) = x;
        final after = c.clone()..xpEarned += n;
        _characters.stageEdit(
          batch,
          after,
          fromVersion: c.version,
          by: by,
          kind: 'award',
          summary: describeChanges(c, after),
          reason: reason.trim(),
          delta: xpDelta(c, after),
        );
      });

  Future<void> correct(Character before, Character after, CorrectionKind k, String reason, Actor by) {
    final batch = _db.batch();
    _characters.stageEdit(
      batch,
      after,
      fromVersion: before.version,
      by: by,
      kind: 'correction',
      summary: [k.label, ...describeChanges(before, after)],
      reason: reason.trim(),
      delta: xpDelta(before, after),
    );
    return batch.commit();
  }

  /// Les 20 dernières corrections de la chronique (index history : kind + at, firestore.indexes.json).
  Stream<List<CorrectionEntry>> watchCorrections() => _db
      .collectionGroup('history')
      .where('kind', isEqualTo: 'correction')
      .orderBy('at', descending: true)
      .limit(20)
      .snapshots()
      .map((q) => [for (final d in q.docs) CorrectionEntry(d.reference.parent.parent!.id, HistoryEntry.fromDoc(d))]);

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

@riverpod
Stream<XpSettings> xpSettings(Ref ref) => ref.watch(xpRepositoryProvider).watchSettings();

@riverpod
Stream<List<CorrectionEntry>> corrections(Ref ref) => ref.watch(xpRepositoryProvider).watchCorrections();
