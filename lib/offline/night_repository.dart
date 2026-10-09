import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import 'night.dart';

part 'night_repository.g.dart';

/// Ce que l'écran sait du suivi : le document, s'il existe, et d'où il vient.
class NightView {
  const NightView(this.night, {this.exists = false, this.fromCache = false, this.pending = false});

  final Night night;
  final bool exists;

  /// Lu dans le cache de l'appareil : pas de réseau, ou pas encore de réponse du serveur.
  final bool fromCache;

  /// Des saisies attendent d'être envoyées.
  final bool pending;
}

/// `characters/{id}/night/{gameId}` : suivi de la soirée, écrit par le joueur seul.
class NightRepository {
  NightRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String characterId, String gameId) => _db.doc('characters/$characterId/night/$gameId');

  /// Avec les changements de métadonnées : passage hors ligne, envoi des saisies en attente.
  Stream<NightView> watch(String characterId, String gameId) => _doc(characterId, gameId).snapshots(includeMetadataChanges: true).map((d) => NightView(
        d.exists ? Night.fromMap(d.data()!) : const Night(),
        exists: d.exists,
        fromCache: d.metadata.isFromCache,
        pending: d.metadata.hasPendingWrites,
      ));

  /// Réécrit tout le suivi. Hors ligne, le futur ne se termine qu'au retour du réseau ; il échoue si le serveur refuse.
  Future<void> save(String characterId, String gameId, Night n, String uid) =>
      _doc(characterId, gameId).set({...n.toMap(), 'byUid': uid, 'at': FieldValue.serverTimestamp()});
}

@Riverpod(keepAlive: true)
NightRepository nightRepository(Ref ref) => NightRepository(ref.watch(firestoreProvider));

@riverpod
Stream<NightView> night(Ref ref, String characterId, String gameId) => ref.watch(nightRepositoryProvider).watch(characterId, gameId);
