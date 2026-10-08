import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../events/story_event.dart';
import 'bond.dart';
import 'bond_rules.dart' show DrinkWrite;

part 'bonds_repository.g.dart';

/// `bonds/{regnantId}_{thrallId}` : liens de sang, écrits par le conte (sous-projet 7c).
class BondsRepository {
  BondsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('bonds');

  List<Bond> _list(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) Bond.fromMap(d.data())];

  /// Équipe : tous les liens.
  Stream<List<Bond>> watchAll() => _col.snapshots().map(_list);

  /// Joueur : liens subis par sa fiche et connus d'elle. Les règles exigent ces filtres.
  Stream<List<Bond>> watchSuffered(String characterId, String uid) => _col
      .where('thrallId', isEqualTo: characterId)
      .where('thrallPlayerUid', isEqualTo: uid)
      .where('known', isEqualTo: true)
      .snapshots()
      .map(_list);

  /// Joueur : liens exercés par sa fiche et connus d'elle. Les règles exigent ces filtres.
  Stream<List<Bond>> watchExerted(String characterId, String uid) => _col
      .where('regnantId', isEqualTo: characterId)
      .where('regnantPlayerUid', isEqualTo: uid)
      .where('regnantKnows', isEqualTo: true)
      .snapshots()
      .map(_list);

  /// Gorgée en un lot : le lien, les liens moindres effacés, l'événement du lié.
  Future<void> drink(DrinkWrite w, Actor by) {
    final batch = _db.batch()..set(_col.doc(w.after.id), bondData(w.after, by), SetOptions(merge: true));
    for (final e in w.erased) {
      batch.set(_col.doc(e.id), bondData(e, by), SetOptions(merge: true));
    }
    batch.set(_db.collection('characters').doc(w.after.thrallId).collection('events').doc(), newEventData(w.event, by.uid, by.name));
    return batch.commit();
  }

  /// Contact, ou lien de goule daté : une seule écriture.
  Future<void> save(Bond b, Actor by) => _col.doc(b.id).set(bondData(b, by), SetOptions(merge: true));
}

@Riverpod(keepAlive: true)
BondsRepository bondsRepository(Ref ref) => BondsRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Bond>> allBonds(Ref ref) => ref.watch(bondsRepositoryProvider).watchAll();

@riverpod
Stream<List<Bond>> sufferedBonds(Ref ref, String characterId, String uid) =>
    ref.watch(bondsRepositoryProvider).watchSuffered(characterId, uid);

@riverpod
Stream<List<Bond>> exertedBonds(Ref ref, String characterId, String uid) =>
    ref.watch(bondsRepositoryProvider).watchExerted(characterId, uid);

/// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.
@riverpod
Future<List<Bond>> characterBonds(Ref ref, String characterId) async {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final c = ref.watch(characterProvider(characterId)).value;
  if (me.role.isStaff && c != null && c.playerUid != me.uid) {
    final all = await ref.watch(allBondsProvider.future);
    return [for (final b in all) if (b.thrallId == characterId || b.regnantId == characterId) b];
  }
  final suffered = await ref.watch(sufferedBondsProvider(characterId, me.uid).future);
  final exerted = await ref.watch(exertedBondsProvider(characterId, me.uid).future);
  return [...suffered, ...exerted];
}
