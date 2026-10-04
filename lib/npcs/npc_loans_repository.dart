import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import 'npc_loan.dart';

part 'npc_loans_repository.g.dart';

/// `npcLoans/{id}` et la copie de la fiche `npcLoans/{id}/sheet/copy`.
class NpcLoansRepository {
  NpcLoansRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('npcLoans');

  List<NpcLoan> _sorted(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) NpcLoan.fromMap(d.id, d.data())]..sort((a, b) => b.until.compareTo(a.until));

  /// Équipe : tous les prêts, ceux qui finissent le plus tard d'abord.
  Stream<List<NpcLoan>> watchAll() => _col.snapshots().map(_sorted);

  /// Joueur : ses prêts (requête permise par les règles).
  Stream<List<NpcLoan>> watchForPlayer(String uid) => _col.where('playerUid', isEqualTo: uid).snapshots().map(_sorted);

  /// Équipe : les prêts d'un PNJ.
  Stream<List<NpcLoan>> watchForCharacter(String characterId) =>
      _col.where('characterId', isEqualTo: characterId).snapshots().map(_sorted);

  /// Copie de la fiche ; null si elle manque.
  Stream<Map<String, dynamic>?> watchSheet(String loanId) => _col.doc(loanId).collection('sheet').doc('copy').snapshots().map((d) {
        final s = d.data()?['sheet'];
        return s is Map ? Map<String, dynamic>.from(s) : null;
      });

  /// Crée ([before] en version 0) ou modifie le prêt ; [sheet] remplace la copie de la fiche. Renvoie l'id.
  /// Le conte n'écrit jamais les notes du joueur : une mise à jour ne les écrase pas.
  Future<String> save(NpcLoan before, NpcLoan l, Actor by, {Map<String, dynamic>? sheet}) async {
    final creating = before.version == 0;
    final ref = l.id.isEmpty ? _col.doc() : _col.doc(l.id);
    final now = FieldValue.serverTimestamp();
    final data = {
      ...l.toMap(),
      // Révocation à l'heure du serveur (exigé par les règles) ; ensuite la valeur stockée n'est plus réécrite.
      if (l.revokedAt != null && before.revokedAt == null) 'revokedAt': now,
      if (sheet != null) 'sheetAt': now,
      'version': creating ? 1 : before.version + 1,
      'updatedAt': now,
      'updatedByName': by.name,
    };
    final batch = _db.batch();
    if (!creating && l.revokedAt != null && before.revokedAt != null) data.remove('revokedAt');
    if (creating) {
      batch.set(ref, {...data, 'playerNotes': '', 'notesAt': null, 'createdAt': now});
    } else {
      batch.update(ref, data);
    }
    if (sheet != null) batch.set(ref.collection('sheet').doc('copy'), {'sheet': sheet});
    await batch.commit();
    return ref.id;
  }

  /// Notes du joueur (seules clés qu'il peut écrire).
  Future<void> saveNotes(String id, String text) =>
      _col.doc(id).update({'playerNotes': text.trim(), 'notesAt': FieldValue.serverTimestamp()});
}

@Riverpod(keepAlive: true)
NpcLoansRepository npcLoansRepository(Ref ref) => NpcLoansRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<NpcLoan>> allNpcLoans(Ref ref) => ref.watch(npcLoansRepositoryProvider).watchAll();

@riverpod
Stream<List<NpcLoan>> myNpcLoans(Ref ref) {
  final uid = ref.watch(currentUserProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(npcLoansRepositoryProvider).watchForPlayer(uid);
}

@riverpod
Stream<List<NpcLoan>> characterNpcLoans(Ref ref, String characterId) =>
    ref.watch(npcLoansRepositoryProvider).watchForCharacter(characterId);

@riverpod
Stream<Map<String, dynamic>?> npcLoanSheet(Ref ref, String loanId) => ref.watch(npcLoansRepositoryProvider).watchSheet(loanId);
