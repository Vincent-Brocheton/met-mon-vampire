import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../allies/allies_repository.dart';
import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../chronicle/chronicle_repository.dart';
import '../games/games_repository.dart';
import '../items/items_repository.dart';
import '../places/places_repository.dart';
import '../servants/servants_repository.dart';
import '../wiki/wiki_repository.dart';
import 'journal_rules.dart';

part 'journal_repository.g.dart';

/// Lectures du journal : historiques et versions du wiki (groupes de collections, index `at` dans firestore.indexes.json)
/// et lignes stockées `journal/{id}`. Les écritures se font dans les dépôts du référentiel et des comptes.
class JournalRepository {
  JournalRepository(this._db);

  final FirebaseFirestore _db;

  // ponytail: 500 documents par source au plus ; paginer si une période en dépasse.
  static const cap = 500;

  Query<Map<String, dynamic>> _since(Query<Map<String, dynamic>> q, DateTime? since) =>
      (since == null ? q : q.where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))).orderBy('at', descending: true).limit(cap);

  /// L'heure est celle du serveur : absente de l'écho local de l'écriture, on prend celle de l'appareil.
  static DateTime _at(Object? v) => (v as Timestamp?)?.toDate() ?? DateTime.now();

  Stream<List<RawHistory>> watchHistory(DateTime? since) => _since(_db.collectionGroup('history'), since).snapshots().map((q) => [
        for (final d in q.docs)
          if (d.data() case final m)
            RawHistory(
              col: d.reference.parent.parent!.parent.id,
              parentId: d.reference.parent.parent!.id,
              at: _at(m['at']),
              byName: m['byName'] as String? ?? '',
              kind: m['kind'] as String? ?? 'edit',
              summary: [for (final s in (m['summary'] as List?) ?? const []) '$s'],
              reason: m['reason'] as String? ?? '',
            ),
      ]);

  Stream<List<RawVersion>> watchVersions(DateTime? since) => _since(_db.collectionGroup('versions'), since).snapshots().map((q) => [
        for (final d in q.docs)
          if (d.data() case final m)
            RawVersion(
              pageId: d.reference.parent.parent!.id,
              n: int.tryParse(d.id) ?? 0,
              title: m['title'] as String? ?? '',
              note: m['note'] as String? ?? '',
              byName: m['byName'] as String? ?? '',
              at: _at(m['at']),
            ),
      ]);

  Stream<List<JournalLine>> watchStored(DateTime? since) =>
      _since(_db.collection('journal'), since).snapshots().map((q) => [for (final d in q.docs) JournalLine.fromMap(d.data())]);
}

@Riverpod(keepAlive: true)
JournalRepository journalRepository(Ref ref) => JournalRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<RawHistory>> journalHistory(Ref ref, DateTime? since) => ref.watch(journalRepositoryProvider).watchHistory(since);

@riverpod
Stream<List<RawVersion>> journalVersions(Ref ref, DateTime? since) => ref.watch(journalRepositoryProvider).watchVersions(since);

@riverpod
Stream<List<JournalLine>> journalStored(Ref ref, DateTime? since) => ref.watch(journalRepositoryProvider).watchStored(since);

/// Le fil d'une période. [partial] : une source a échoué (elle est absente) ; [loading] : une source charge encore.
class JournalFeed {
  const JournalFeed(this.lines, {this.partial = false, this.loading = false});
  final List<JournalLine> lines;
  final bool partial;
  final bool loading;
}

/// Une source qui charge ou qui échoue ne donne rien : elle n'empêche pas les autres.
List<T> _v<T>(AsyncValue<List<T>> a) => a.value ?? const [];

/// Journal depuis [since] (tout si null) : historiques, versions du wiki, parties et lignes stockées, avec les noms.
@riverpod
JournalFeed journal(Ref ref, DateTime? since) {
  final history = ref.watch(journalHistoryProvider(since));
  final versions = ref.watch(journalVersionsProvider(since));
  final stored = ref.watch(journalStoredProvider(since));
  final games = ref.watch(gamesProvider);
  final names = {
    for (final c in _v(ref.watch(allCharactersProvider))) 'characters/${c.id}': c.name,
    for (final p in _v(ref.watch(allPlacesProvider))) 'places/${p.id}': p.name,
    for (final i in _v(ref.watch(allItemsProvider))) 'items/${i.id}': i.name,
    for (final a in _v(ref.watch(allAllyFilesProvider))) 'allies/${a.id}': a.name,
    for (final s in _v(ref.watch(allServantFilesProvider))) 'servants/${s.id}': s.name,
  };
  final users = {for (final u in _v(ref.watch(allUsersProvider))) u.uid: u.displayName};
  final pages = {for (final p in _v(ref.watch(wikiPagesProvider))) p.id};
  final sources = <AsyncValue<Object>>[history, versions, stored, games];
  return JournalFeed(
    mergeLines([historyLines(_v(history), names), versionLines(_v(versions), pages), _v(stored), gameLines(_v(games), users)], since),
    partial: sources.any((s) => s.hasError),
    loading: sources.any((s) => s.isLoading),
  );
}
