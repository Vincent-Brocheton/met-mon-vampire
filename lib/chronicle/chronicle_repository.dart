import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';

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

  Future<void> setRole(String uid, Role role) => _users.doc(uid).update({'role': role.name});

  Future<void> updateConfig({required String name, required String associationName, required String defaultSect}) =>
      _db.doc('chronicle/config').update({
        'name': name.trim(),
        'associationName': associationName.trim(),
        'defaultSect': defaultSect,
      });

  Stream<List<Invitation>> watchInvitations() => _db.collection('invitations').snapshots().map((q) => q.docs
      .map((d) => Invitation(email: d.id, role: Role.parse(d.data()['role']) ?? Role.joueur))
      .toList());

  Future<void> invite(String email, Role role, String invitedBy) =>
      _db.doc('invitations/${email.trim().toLowerCase()}').set({
        'role': role.name,
        'invitedBy': invitedBy,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancelInvitation(String email) => _db.doc('invitations/$email').delete();
}

@Riverpod(keepAlive: true)
ChronicleRepository chronicleRepository(Ref ref) => ChronicleRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<AppUser>> pendingUsers(Ref ref) => ref.watch(chronicleRepositoryProvider).watchPending();

@riverpod
Stream<List<AppUser>> allUsers(Ref ref) => ref.watch(chronicleRepositoryProvider).watchUsers();

@riverpod
Stream<List<Invitation>> invitations(Ref ref) => ref.watch(chronicleRepositoryProvider).watchInvitations();
