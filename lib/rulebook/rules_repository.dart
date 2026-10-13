import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../journal/journal_rules.dart';
import 'rule_entry.dart';

part 'rules_repository.g.dart';

/// `rules/{cat}` (réglages), `rules/{cat}/ruleEntries/{id}`, `…/private/note`.
/// Nom de sous-collection propre au référentiel : la lecture groupée ne touche rien d'autre.
class RulesRepository {
  RulesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String cat) => _db.collection('rules').doc(cat).collection('ruleEntries');

  /// Journal de la chronique (sous-projet 10b) : une entrée dans le lot de chaque écriture.
  void _trace(WriteBatch batch, JournalNote note, Actor by) => batch.set(_db.collection('journal').doc(), journalData(note, by));

  /// Toutes les catégories, par une requête sur le groupe `ruleEntries`, triées par nom.
  Stream<Map<String, List<RuleEntry>>> watchAll() => _db.collectionGroup('ruleEntries').snapshots().map((q) {
        final out = <String, List<RuleEntry>>{};
        for (final d in q.docs) {
          (out[d.reference.parent.parent!.id] ??= []).add(RuleEntry.fromMap(d.id, d.data()));
        }
        for (final list in out.values) {
          list.sort((a, b) => nameKey(a.name).compareTo(nameKey(b.name)));
        }
        return out;
      });

  Stream<Map<String, Map<String, dynamic>>> watchSettings() =>
      _db.collection('rules').snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  Stream<String> watchNote(String cat, String id) =>
      _entries(cat).doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Map<String, dynamic> _write(RuleEntry e, Actor by) => {
        ...e.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': by.uid,
        'updatedByName': by.name,
      };

  /// Crée (id vide) ou remplace l'élément ; [note] : note du conte (null : inchangée) ; [before] : version remplacée (journal).
  Future<String> save(String cat, RuleEntry e, Actor by, {String? note, RuleEntry? before}) async {
    final ref = e.id.isEmpty ? _entries(cat).doc() : _entries(cat).doc(e.id);
    final batch = _db.batch()..set(ref, _write(e, by));
    if (note != null) batch.set(ref.collection('private').doc('note'), {'text': note.trim()});
    _trace(batch, ruleSaveNote(cat, e.id.isEmpty ? null : before, e), by);
    await batch.commit();
    return ref.id;
  }

  Future<void> delete(String cat, RuleEntry e, Actor by) {
    final batch = _db.batch()
      ..delete(_entries(cat).doc(e.id).collection('private').doc('note'))
      ..delete(_entries(cat).doc(e.id));
    _trace(batch, ruleDeleteNote(cat, e), by);
    return batch.commit();
  }

  /// Fusion : les clés hors du schéma restent ; une valeur null efface la clé.
  Future<void> saveSettings(String cat, Map<String, dynamic> values, Actor by) => _db.collection('rules').doc(cat).set({
        for (final e in values.entries) e.key: e.value ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByName': by.name,
      }, SetOptions(merge: true));

  /// Import ou valeurs de base : nouveaux (id vide) et modifiés, par lots de 400.
  Future<void> importEntries(String cat, List<RuleEntry> entries, Actor by) async {
    for (var i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      // Une seule ligne de journal pour tout l'import, dans le premier lot.
      if (i == 0) _trace(batch, ruleImportNote(cat, entries.length), by);
      for (final e in entries.skip(i).take(400)) {
        batch.set(e.id.isEmpty ? _entries(cat).doc() : _entries(cat).doc(e.id), _write(e, by));
      }
      await batch.commit();
    }
  }
}

@Riverpod(keepAlive: true)
RulesRepository rulesRepository(Ref ref) => RulesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<Map<String, List<RuleEntry>>> allRuleEntries(Ref ref) => ref.watch(rulesRepositoryProvider).watchAll();

@riverpod
Stream<Map<String, Map<String, dynamic>>> allRuleSettings(Ref ref) => ref.watch(rulesRepositoryProvider).watchSettings();
