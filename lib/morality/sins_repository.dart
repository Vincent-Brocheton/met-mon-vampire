import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import 'morality_rules.dart';
import 'sin.dart';

part 'sins_repository.g.dart';

/// `characters/{id}/sins/{s}` : péchés de la fiche, écrits par le conte.
class SinsRepository {
  SinsRepository(this._db, this._chars);

  final FirebaseFirestore _db;
  final CharacterRepository _chars;

  CollectionReference<Map<String, dynamic>> _col(String characterId) =>
      _db.collection('characters').doc(characterId).collection('sins');

  /// Du plus récent au plus ancien.
  Stream<List<Sin>> watch(String characterId) => _col(characterId)
      .snapshots()
      .map((q) => [for (final d in q.docs) Sin.fromMap(d.id, d.data())]..sort((a, b) => b.date.compareTo(a.date)));

  /// Crée ([s] sans identifiant) ou modifie le péché ; refusé par les règles une fois la perte appliquée.
  Future<void> save(String characterId, Sin s, Actor by) {
    if (s.id.isEmpty) return _col(characterId).doc().set(newSinData(s, by.uid, by.name));
    return _col(characterId).doc(s.id).update({
      ...s.toMap(),
      'byUid': by.uid,
      'byName': by.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String characterId, String id) => _col(characterId).doc(id).delete();

  /// Perte de la soirée, en un lot : fiche (moralité − 1, tracée), péchés verrouillés, événement « Moralité ».
  /// Une seconde application échoue en entier : les péchés déjà verrouillés refusent la modification.
  Future<void> applyEveningLoss(Character before, List<Sin> evening, Actor by) {
    final after = loseOne(before);
    final day = dayOf(evening.first.date);
    final batch = _db.batch();
    _chars.stageEdit(
      batch,
      after,
      fromVersion: before.version,
      by: by,
      kind: 'edit',
      summary: describeChanges(before, after),
      reason: lossReason(day),
      extra: after.laterKeys(),
      events: [lossEvent(before, after, day)],
    );
    for (final s in evening) {
      batch.update(_col(before.id).doc(s.id), {
        'lossApplied': true,
        'byUid': by.uid,
        'byName': by.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }
}

@Riverpod(keepAlive: true)
SinsRepository sinsRepository(Ref ref) => SinsRepository(ref.watch(firestoreProvider), ref.watch(characterRepositoryProvider));

@riverpod
Stream<List<Sin>> characterSins(Ref ref, String characterId) => ref.watch(sinsRepositoryProvider).watch(characterId);
