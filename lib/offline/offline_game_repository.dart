import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../events/story_event.dart';
import '../games/game.dart';
import '../morality/sin.dart';
import 'sync_queue.dart';
import 'wipe.dart';

part 'offline_game_repository.g.dart';

/// Lectures de « Partie hors ligne » (sous-projet 8d) : saisies suivies avec leur état d'envoi, préparation, synchronisation.
class OfflineGameRepository {
  OfflineGameRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _sub(String characterId, String name) =>
      _db.collection('characters').doc(characterId).collection(name);

  /// Avec les changements de métadonnées : une saisie passe de « En attente » à « Envoyé » sans changer de contenu.
  Stream<List<Tracked<Sin>>> watchSins(String characterId) => _sub(characterId, 'sins').snapshots(includeMetadataChanges: true).map((q) => [
        for (final d in q.docs) (doc: Sin.fromMap(d.id, d.data()), pending: d.metadata.hasPendingWrites),
      ]);

  /// Équipe : tous les événements de la fiche.
  Stream<List<Tracked<StoryEvent>>> watchEvents(String characterId) =>
      _sub(characterId, 'events').snapshots(includeMetadataChanges: true).map((q) => [
            for (final d in q.docs) (doc: StoryEvent.fromMap(d.id, d.data()), pending: d.metadata.hasPendingWrites),
          ]);

  /// Lit une fois ce dont la partie a besoin : le cache persistant le garde pour la suite.
  /// Les notes du conte ne sont lisibles que par le conte, hors de sa propre fiche : un refus est ignoré.
  /// Il l'est aussi pour les événements : sur sa propre fiche, le conte compte comme un joueur et la lecture non filtrée est refusée.
  Future<void> prepare(Game g, OfflinePrefs p) async {
    final chars = _db.collection('characters');
    Future<void> quiet(Future<Object?> f) => f.then((_) {}, onError: (Object _) {});
    await Future.wait<Object?>([
      _db.collection('games').get(),
      chars.get(),
      if (p.rulebook) ...[
        // Réglages `rules/{cat}`, puis les entrées (même requête que `RulesRepository.watchAll`).
        _db.collection('rules').get(),
        _db.collectionGroup('ruleEntries').get(),
      ],
      if (p.bonds) _db.collection('bonds').get(),
      for (final id in g.sheetIds) ...[
        chars.doc(id).collection('frozen').doc(g.id).get(),
        _sub(id, 'sins').get(),
        if (p.bonds) quiet(_sub(id, 'events').get()),
        if (p.notes) quiet(_sub(id, 'private').doc('notes').get()),
      ],
    ]);
  }

  /// « Synchroniser maintenant » : réseau rétabli s'il était coupé, puis attente de l'envoi des saisies.
  Future<void> sync() async {
    await _db.enableNetwork();
    await _db.waitForPendingWrites();
  }
}

@Riverpod(keepAlive: true)
OfflineGameRepository offlineGameRepository(Ref ref) => OfflineGameRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Tracked<Sin>>> trackedSins(Ref ref, String characterId) => ref.watch(offlineGameRepositoryProvider).watchSins(characterId);

@riverpod
Stream<List<Tracked<StoryEvent>>> trackedEvents(Ref ref, String characterId) =>
    ref.watch(offlineGameRepositoryProvider).watchEvents(characterId);
