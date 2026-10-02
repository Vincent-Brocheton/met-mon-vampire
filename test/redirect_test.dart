import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/redirect.dart';

void main() {
  String? go(String location, Session s) => redirectFor(Uri.parse(location), s);
  Session as(Role? role, {bool named = true}) => Session(uid: 'u', role: role, chronicleNamed: named);

  test('chargement : mémorise la destination (rafraîchissement Web)', () {
    final r = Uri.parse(go('/conteur/comptes', Session.loadingState)!);
    expect(r.path, '/chargement');
    expect(r.queryParameters['de'], '/conteur/comptes');
    expect(go('/chargement', Session.loadingState), isNull);
  });

  test('après chargement : retour à la destination mémorisée', () {
    expect(go('/chargement?de=%2Fconteur%2Fcomptes', as(Role.conteur)), '/conteur/comptes');
    expect(go('/chargement?de=%2Fconteur%2Fcomptes', as(Role.joueur)), '/joueur');
    expect(go('/chargement', as(Role.joueur)), '/joueur');
  });

  test('non connecté', () {
    const out = Session();
    expect(go('/joueur', out), '/connexion');
    expect(go('/connexion', out), isNull);
    expect(go('/mot-de-passe', out), isNull);
    expect(go('/demande-acces', out), isNull);
  });

  test('en attente ou sans profil', () {
    expect(go('/joueur', as(Role.pending)), '/attente');
    expect(go('/joueur', as(null)), '/attente');
    expect(go('/attente', as(Role.pending)), isNull);
  });

  test('désactivé : renvoyé vers la connexion avec le message', () {
    expect(go('/joueur', as(Role.disabled)), '/connexion?desactive=1');
    expect(go('/connexion?desactive=1', as(Role.disabled)), isNull);
  });

  test('joueur', () {
    expect(go('/', as(Role.joueur)), '/joueur');
    expect(go('/connexion', as(Role.joueur)), '/joueur');
    expect(go('/attente', as(Role.joueur)), '/joueur');
    expect(go('/conteur/comptes', as(Role.joueur)), '/joueur');
    expect(go('/joueur/pnj', as(Role.joueur)), isNull);
    expect(go('/compte', as(Role.joueur)), isNull);
  });

  test('équipe de conteurs : droits de C33', () {
    expect(go('/joueur', as(Role.conteur)), '/conteur');
    expect(go('/conteur/comptes', as(Role.narrateur)), '/conteur');
    expect(go('/conteur/comptes', as(Role.conteur)), isNull);
    expect(go('/conteur/equipe', as(Role.conteur)), '/conteur');
    expect(go('/conteur/equipe', as(Role.principal)), isNull);
  });

  test('principal, chronique sans nom : démarrage obligatoire', () {
    expect(go('/conteur', as(Role.principal, named: false)), '/conteur/demarrage');
    expect(go('/compte', as(Role.principal, named: false)), '/conteur/demarrage');
    expect(go('/conteur/demarrage', as(Role.principal, named: false)), isNull);
  });
}
