import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../chronicle/chronicle_repository.dart';
import 'wiki_page.dart';
import 'wiki_rules.dart';

part 'wiki_repository.g.dart';

/// `wiki/{id}` (publiée), `wiki/{id}/versions/{n}` (copies), `wikiDrafts/{id}` (brouillons), `users/{uid}.wikiAudiences`.
class WikiRepository {
  WikiRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _pages => _db.collection('wiki');
  CollectionReference<Map<String, dynamic>> get _drafts => _db.collection('wikiDrafts');

  static List<WikiPage> _list(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) WikiPage.fromMap(d.id, d.data())];

  /// Toutes les pages publiées (équipe).
  Stream<List<WikiPage>> watchAll() => _pages.snapshots().map(_list);

  /// Pages d'un joueur : le filtre que testent les règles.
  Stream<List<WikiPage>> watchVisible(List<String> audiences) =>
      _pages.where('audience', whereIn: [audienceAll, ...audiences]).snapshots().map(_list);

  Stream<List<WikiPage>> watchDrafts() => _drafts.snapshots().map(_list);

  /// Versions publiées de la page, la plus récente d'abord (équipe seulement).
  Stream<List<WikiVersion>> watchVersions(String id) => _pages.doc(id).collection('versions').snapshots().map(
      (q) => [for (final d in q.docs) WikiVersion.fromMap(id, d.id, d.data())]..sort((a, b) => b.n.compareTo(a.n)));

  String newId() => _pages.doc().id;

  Map<String, dynamic> _by(Actor by) => {'updatedAt': FieldValue.serverTimestamp(), 'updatedByUid': by.uid, 'updatedByName': by.name};

  /// [page].version : version publiée sur laquelle part le brouillon.
  Future<void> saveDraft(WikiPage page, Actor by) =>
      _drafts.doc(page.id).set({...page.contentMap(), 'baseVersion': page.version, ..._by(by)});

  Future<void> discardDraft(String id) => _drafts.doc(id).delete();

  /// Publie [page] en version [page].version + 1, en un lot : page, copie de version, brouillon supprimé.
  /// Refusé si un autre conteur a publié entre-temps.
  Future<void> publish(WikiPage page, Actor by, {String note = ''}) {
    final n = page.version + 1;
    final batch = _db.batch()
      ..set(_pages.doc(page.id), {...page.contentMap(), 'version': n, ..._by(by)})
      ..set(_pages.doc(page.id).collection('versions').doc('$n'),
          {...page.contentMap(), 'note': note.trim(), 'byUid': by.uid, 'byName': by.name, 'at': FieldValue.serverTimestamp()})
      ..delete(_drafts.doc(page.id));
    return batch.commit();
  }

  /// Supprime la page publiée et son brouillon ; les versions restent.
  Future<void> delete(String id) {
    final batch = _db.batch()
      ..delete(_pages.doc(id))
      ..delete(_drafts.doc(id));
    return batch.commit();
  }

  Future<void> setAudiences(Map<String, List<String>> changes) {
    final batch = _db.batch();
    for (final MapEntry(key: uid, value: list) in changes.entries) {
      batch.update(_db.collection('users').doc(uid), {'wikiAudiences': list});
    }
    return batch.commit();
  }
}

@Riverpod(keepAlive: true)
WikiRepository wikiRepository(Ref ref) => WikiRepository(ref.watch(firestoreProvider));

/// Pages publiées lisibles : toutes pour l'équipe, celles des audiences du joueur sinon.
@riverpod
Stream<List<WikiPage>> wikiPages(Ref ref) {
  final key = ref.watch(currentUserProvider.select((u) => switch (u.value) {
        null => null,
        final me => me.role.isStaff ? '*' : me.wikiAudiences.join('|'),
      }));
  if (key == null) return Stream.value(const []);
  final repo = ref.watch(wikiRepositoryProvider);
  return key == '*' ? repo.watchAll() : repo.watchVisible(key.isEmpty ? const [] : key.split('|'));
}

@riverpod
Stream<List<WikiPage>> wikiDrafts(Ref ref) => ref.watch(wikiRepositoryProvider).watchDrafts();

@riverpod
Stream<List<WikiVersion>> wikiVersions(Ref ref, String id) => ref.watch(wikiRepositoryProvider).watchVersions(id);

/// Recalcule `wikiAudiences` des comptes d'après les fiches et écrit les différences (conteur et principal).
/// Lancé par la liste des fiches et par le wiki du conte ; sans différence, rien n'est écrit.
@riverpod
Future<void> wikiAudienceSync(Ref ref) async {
  final manages = ref.watch(currentUserProvider.select((u) => u.value?.role.managesAccounts ?? false));
  if (!manages) return;
  final users = await ref.watch(allUsersProvider.future);
  final sheets = await ref.watch(allCharactersProvider.future);
  final changes = audienceChanges(users, sheets);
  if (changes.isEmpty) return;
  try {
    await ref.read(wikiRepositoryProvider).setAudiences(changes);
  } catch (e) {
    // Retentée à la prochaine ouverture d'un écran du conte.
    debugPrint('Accès du wiki non synchronisés : $e');
  }
}
