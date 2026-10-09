import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../rulebook/rulebook.dart';
import 'court_entry.dart';
import 'title_rules.dart';

part 'titles_repository.g.dart';

/// Titres : la fiche porte le titre ; `court/{characterId}` en garde la copie publique.
class TitlesRepository {
  TitlesRepository(this._db, this._chars);

  final FirebaseFirestore _db;
  final CharacterRepository _chars;

  CollectionReference<Map<String, dynamic>> get _court => _db.collection('court');

  Stream<List<CourtEntry>> watchCourt() => _court.snapshots().map((q) => [for (final d in q.docs) CourtEntry.fromMap(d.id, d.data())]);

  /// Attribue [title] (null ou vide : retrait) depuis [since], en un lot : fiche tracée, événements, copie de la Cour.
  Future<void> assign(Character before, String? title, DateTime? since, String reason, Actor by, Rulebook rb) {
    final after = withTitle(before, title, since);
    final batch = _db.batch();
    _chars.stageEdit(
      batch,
      after,
      fromVersion: before.version,
      by: by,
      kind: 'edit',
      summary: titleSummary(before, after, rb),
      reason: reason,
      extra: after.laterKeys(),
      events: titleEvents(before, after, since ?? DateTime.now(), rb),
    );
    _stageCourt(batch, after, rb);
    return batch.commit();
  }

  /// Réécrit (ou supprime) la copie publique de la fiche.
  Future<void> refreshCourt(Character c, Rulebook rb) {
    final batch = _db.batch();
    _stageCourt(batch, c, rb);
    return batch.commit();
  }

  void _stageCourt(WriteBatch batch, Character c, Rulebook rb) {
    final e = courtEntry(c, rb);
    if (e == null) {
      batch.delete(_court.doc(c.id));
    } else {
      batch.set(_court.doc(c.id), e.toMap());
    }
  }
}

@Riverpod(keepAlive: true)
TitlesRepository titlesRepository(Ref ref) => TitlesRepository(ref.watch(firestoreProvider), ref.watch(characterRepositoryProvider));

@riverpod
Stream<List<CourtEntry>> court(Ref ref) => ref.watch(titlesRepositoryProvider).watchCourt();
