import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import 'event_rules.dart';
import 'story_event.dart';

part 'events_repository.g.dart';

/// `characters/{id}/events/{e}` : événements de la fiche, écrits par le conte.
class EventsRepository {
  EventsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String characterId) =>
      _db.collection('characters').doc(characterId).collection('events');

  List<StoryEvent> _list(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) StoryEvent.fromMap(d.id, d.data())]..sort(compareEvents);

  /// Équipe : tous les événements.
  Stream<List<StoryEvent>> watchAll(String characterId) => _col(characterId).snapshots().map(_list);

  /// Joueur : la requête doit filtrer la visibilité, sinon les règles la refusent.
  Stream<List<StoryEvent>> watchVisible(String characterId) => _col(characterId)
      .where('visibility', whereIn: [EventVisibility.public.name, EventVisibility.player.name])
      .snapshots()
      .map(_list);

  /// Crée ([e] sans identifiant) ou modifie l'événement. Pas de version : la dernière écriture l'emporte.
  Future<void> save(String characterId, StoryEvent e, Actor by) {
    if (e.id.isEmpty) return _col(characterId).doc().set(newEventData(e, by.uid, by.name));
    return _col(characterId).doc(e.id).update({
      ...e.toMap(),
      'byUid': by.uid,
      'byName': by.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String characterId, String id) => _col(characterId).doc(id).delete();
}

@Riverpod(keepAlive: true)
EventsRepository eventsRepository(Ref ref) => EventsRepository(ref.watch(firestoreProvider));

/// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.
@riverpod
Stream<List<StoryEvent>> characterEvents(Ref ref, String characterId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final repo = ref.watch(eventsRepositoryProvider);
  // « Conte seul » jamais pour le joueur de la fiche, même membre de l'équipe ; propriétaire inconnu = filtré.
  final c = ref.watch(characterProvider(characterId)).value;
  final all = me.role.isStaff && c != null && c.playerUid != me.uid;
  return all ? repo.watchAll(characterId) : repo.watchVisible(characterId);
}
