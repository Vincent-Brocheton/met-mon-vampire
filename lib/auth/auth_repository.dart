import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.doc('users/$uid');

  Future<void> signIn(String email, String password, {bool remember = true}) async {
    if (kIsWeb) await _auth.setPersistence(remember ? Persistence.LOCAL : Persistence.SESSION);
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    await _touchLogin(cred.user!);
  }

  /// Met à jour la dernière connexion et recopie l'e-mail (il a pu changer). Ignoré sans profil.
  Future<void> _touchLogin(User user) async {
    final ref = _userDoc(user.uid);
    if ((await ref.get()).exists) {
      await ref.update({'lastLoginAt': FieldValue.serverTimestamp(), 'email': user.email});
    }
  }

  /// Même comportement que le compte existe ou non (MotDePasse.dc.html).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' && e.code != 'invalid-email') rethrow;
    }
  }

  Future<void> requestAccess({
    required String displayName,
    required String email,
    required String password,
    String? message,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user!.updateDisplayName(displayName.trim());
    await cred.user!.sendEmailVerification();
    await ensureProfile(message: message);
  }

  /// Crée `users/{uid}` s'il manque. Premier compte de la chronique : principal,
  /// avec création de `chronicle/config` dans le même batch (règle isFirstPrincipal).
  Future<void> ensureProfile({String? message}) async {
    final user = _auth.currentUser!;
    final ref = _userDoc(user.uid);
    if ((await ref.get()).exists) return;
    final config = _db.doc('chronicle/config');
    final first = !(await config.get()).exists;
    final now = FieldValue.serverTimestamp();
    final name = user.displayName?.trim() ?? '';
    final batch = _db.batch()
      ..set(ref, {
        'displayName': name.isEmpty ? user.email!.split('@').first : name,
        'email': user.email,
        'role': first ? 'principal' : 'pending',
        if (message != null && message.trim().isNotEmpty) 'accessMessage': message.trim(),
        'createdAt': now,
        'lastLoginAt': now,
      });
    if (first) {
      batch.set(config, {
        'name': '',
        'associationName': '',
        'defaultSect': 'Camarilla',
        'ownerUid': user.uid,
        'createdAt': now,
      });
    }
    await batch.commit();
  }

  /// Applique l'invitation de cet e-mail au compte en attente. `true` si un rôle a été attribué.
  Future<bool> applyInvitation() async {
    await _auth.currentUser!.reload();
    final user = _auth.currentUser!;
    if (!user.emailVerified) return false;
    await user.getIdToken(true); // le jeton doit porter email_verified
    final invitation = await _db.doc('invitations/${user.email!.toLowerCase()}').get();
    final role = invitation.data()?['role'];
    if (role is! String) return false;
    await _userDoc(user.uid).update({'role': role});
    return true;
  }

  Future<void> resendVerification() => _auth.currentUser!.sendEmailVerification();

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser!;
    await user.updateDisplayName(name.trim());
    await _userDoc(user.uid).update({'displayName': name.trim()});
  }

  /// Le changement n'est effectif qu'après le clic sur le lien envoyé à [newEmail].
  Future<void> changeEmail(String newEmail) => _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());

  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser!;
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: current));
    await user.updatePassword(next);
  }
}
