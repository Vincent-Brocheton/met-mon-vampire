import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/forms.dart';

void main() {
  test('validateEmail', () {
    expect(validateEmail(''), 'Indiquez votre adresse e-mail.');
    expect(validateEmail('camille'), 'Cette adresse e-mail n’est pas valide.');
    expect(validateEmail(' camille.r@exemple.fr '), isNull);
  });

  test('validateNewPassword : 12 caractères minimum', () {
    expect(validateNewPassword('a' * 11), 'Au moins 12 caractères.');
    expect(validateNewPassword('a' * 12), isNull);
  });

  test('validateDisplayName', () {
    expect(validateDisplayName('  '), 'Indiquez un nom.');
    expect(validateDisplayName('a' * 61), '60 caractères maximum.');
    expect(validateDisplayName('Camille R.'), isNull);
  });

  test('authErrorMessage : ne révèle pas qui est inscrit', () {
    for (final code in ['wrong-password', 'invalid-credential', 'user-not-found']) {
      expect(authErrorMessage(FirebaseAuthException(code: code)), 'E-mail ou mot de passe incorrect.');
    }
    expect(authErrorMessage(FirebaseAuthException(code: 'too-many-requests')),
        'Trop de tentatives. Réessayez dans quelques minutes.');
    expect(authErrorMessage(StateError('x')), 'Quelque chose s’est mal passé. Réessayez.');
  });
}
