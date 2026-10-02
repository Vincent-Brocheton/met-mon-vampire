import 'auth/session.dart';

const publicPaths = {'/connexion', '/mot-de-passe', '/demande-acces'};

String homeFor(Role role) => role == Role.joueur ? '/joueur' : '/conteur';

/// Où envoyer l'utilisateur ; `null` = rester sur [uri]. Fonction pure (spec, « Redirection par rôle »).
String? redirectFor(Uri uri, Session s) {
  final path = uri.path;
  if (s.loading) {
    return path == '/chargement'
        ? null
        : Uri(path: '/chargement', queryParameters: {'de': uri.toString()}).toString();
  }
  if (path == '/chargement') {
    final target = uri.queryParameters['de'] ?? '/';
    return redirectFor(Uri.parse(target), s) ?? target;
  }
  if (s.uid == null) return publicPaths.contains(path) ? null : '/connexion';

  final role = s.role;
  if (role == null || role == Role.pending) return path == '/attente' ? null : '/attente';
  if (role == Role.disabled) return path == '/connexion' ? null : '/connexion?desactive=1';
  if (role == Role.principal && !s.chronicleNamed) {
    return path == '/conteur/demarrage' ? null : '/conteur/demarrage';
  }
  if (path == '/compte') return null;

  final home = homeFor(role);
  if (!path.startsWith(home)) return home;
  if (path.startsWith('/conteur/comptes') && !role.managesAccounts) return home;
  if (path.startsWith('/conteur/equipe') && role != Role.principal) return home;
  return null;
}
