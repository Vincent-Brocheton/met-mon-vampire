import 'package:firebase_auth/firebase_auth.dart';

const minPasswordLength = 12;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final s = value?.trim() ?? '';
  if (s.isEmpty) return 'Indiquez votre adresse e-mail.';
  if (!_emailPattern.hasMatch(s)) return 'Cette adresse e-mail n’est pas valide.';
  return null;
}

String? validateNewPassword(String? value) =>
    (value ?? '').length < minPasswordLength ? 'Au moins $minPasswordLength caractères.' : null;

String? validateRequired(String? value) => (value ?? '').isEmpty ? 'Champ obligatoire.' : null;

String? validateDisplayName(String? value) {
  final s = value?.trim() ?? '';
  if (s.isEmpty) return 'Indiquez un nom.';
  if (s.length > 60) return '60 caractères maximum.';
  return null;
}

/// Message français pour une erreur Firebase Auth. Mauvais e-mail et mauvais
/// mot de passe donnent le même message : on ne révèle pas qui est inscrit.
String authErrorMessage(Object error) {
  final code = error is FirebaseAuthException ? error.code : '';
  return switch (code) {
    'wrong-password' || 'invalid-credential' || 'user-not-found' || 'invalid-email' =>
      'E-mail ou mot de passe incorrect.',
    'too-many-requests' => 'Trop de tentatives. Réessayez dans quelques minutes.',
    'network-request-failed' => 'Pas de connexion. Vérifiez votre réseau et réessayez.',
    'email-already-in-use' =>
      'Un compte existe déjà avec cette adresse : connectez-vous ou réinitialisez votre mot de passe.',
    'weak-password' => 'Mot de passe trop faible.',
    'requires-recent-login' => 'Par sécurité, reconnectez-vous puis recommencez.',
    'user-disabled' => 'Ce compte est désactivé.',
    'invalid-action-code' || 'expired-action-code' => 'Ce lien n’est plus valable. Demandez-en un nouveau.',
    _ => 'Quelque chose s’est mal passé. Réessayez.',
  };
}
