import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character_repository.dart' show Actor;
import '../journal/journal_rules.dart';

part 'chronicle_repository.g.dart';

class Invitation {
  const Invitation({required this.email, required this.role});
  final String email;
  final Role role;
}

class ChronicleRepository {
  ChronicleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<List<AppUser>> watchUsers() =>
      _users.orderBy('displayName').snapshots().map((q) => q.docs.map(AppUser.fromDoc).toList());

  /// Tri côté client : pas d'index composite (Global Constraints).
  Stream<List<AppUser>> watchPending() => _users
      .where('role', isEqualTo: Role.pending.name)
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList()
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0))));

  DocumentReference<Map<String, dynamic>> get _journal => _db.collection('journal').doc();

  /// Rôle de [u] et sa ligne de journal, dans un lot.
  Future<void> setRole(AppUser u, Role role, Actor by) => (_db.batch()
        ..update(_users.doc(u.uid), {'role': role.name})
        ..set(_journal, journalData(roleNote(u, role), by)))
      .commit();

  Future<void> updateConfig({required String name, required String associationName, required String defaultSect}) =>
      _db.doc('chronicle/config').update({
        'name': name.trim(),
        'associationName': associationName.trim(),
        'defaultSect': defaultSect,
      });

  Stream<List<Invitation>> watchInvitations() => _db.collection('invitations').snapshots().map((q) => q.docs
      .map((d) => Invitation(email: d.id, role: Role.parse(d.data()['role']) ?? Role.joueur))
      .toList());

  Future<void> invite(String email, Role role, Actor by) {
    final id = email.trim().toLowerCase();
    return (_db.batch()
          ..set(_db.doc('invitations/$id'), {
            'role': role.name,
            'invitedBy': by.uid,
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(_journal, journalData(inviteNote(id, role), by)))
        .commit();
  }

  Future<void> cancelInvitation(String email, Actor by) => (_db.batch()
        ..delete(_db.doc('invitations/$email'))
        ..set(_journal, journalData(inviteCancelNote(email), by)))
      .commit();
}

@Riverpod(keepAlive: true)
ChronicleRepository chronicleRepository(Ref ref) => ChronicleRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<AppUser>> pendingUsers(Ref ref) => ref.watch(chronicleRepositoryProvider).watchPending();

@riverpod
Stream<List<AppUser>> allUsers(Ref ref) => ref.watch(chronicleRepositoryProvider).watchUsers();

@riverpod
Stream<List<Invitation>> invitations(Ref ref) => ref.watch(chronicleRepositoryProvider).watchInvitations();
