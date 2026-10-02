import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_repository.dart';
import 'session.dart';

part 'session_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider));

/// `userChanges` : émet aussi après `reload()` (e-mail vérifié, nom changé).
@Riverpod(keepAlive: true)
Stream<User?> authState(Ref ref) => ref.watch(firebaseAuthProvider).userChanges();

@Riverpod(keepAlive: true)
Stream<AppUser?> currentUser(Ref ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('users/$uid')
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);
}

/// Lecture publique (règles) : affichée dès l'écran de connexion.
@Riverpod(keepAlive: true)
Stream<ChronicleConfig?> chronicle(Ref ref) => ref
    .watch(firestoreProvider)
    .doc('chronicle/config')
    .snapshots()
    .map((d) => d.exists ? ChronicleConfig.fromDoc(d) : null);

@Riverpod(keepAlive: true)
Session session(Ref ref) {
  final auth = ref.watch(authStateProvider);
  final user = ref.watch(currentUserProvider);
  final chronicle = ref.watch(chronicleProvider);
  bool pending(AsyncValue<Object?> v) => v.isLoading && !v.hasValue;

  final uid = auth.value?.uid;
  if (pending(auth)) return Session.loadingState;
  if (uid != null && (pending(user) || pending(chronicle))) return Session.loadingState;
  return Session(
    uid: uid,
    role: user.value?.role,
    chronicleNamed: (chronicle.value?.name ?? '').isNotEmpty,
  );
}
