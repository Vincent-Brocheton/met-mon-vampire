import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth/forgot_password_screen.dart';
import 'auth/login_screen.dart';
import 'auth/session.dart';
import 'auth/session_providers.dart';
import 'core/empty_state.dart';
import 'redirect.dart';
import 'shell/app_shell.dart';

part 'router.g.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  // Compte désactivé pendant qu’il est connecté (C7) : on coupe la session.
  ref.listen(currentUserProvider, (_, next) {
    if (next.value?.role == Role.disabled) ref.read(authRepositoryProvider).signOut();
  });

  GoRoute page(String path, Widget child) => GoRoute(path: path, builder: (_, _) => child);
  Widget soon(String feature) => EmptyState.comingSoon(feature);
  // Placeholder des écrans du socle, remplacé ligne par ligne aux tâches 8 à 14.
  Widget later(String screen) => Scaffold(body: EmptyState.comingSoon(screen));

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (_, state) => redirectFor(state.uri, ref.read(sessionProvider)),
    errorBuilder: (context, _) => Scaffold(
      body: EmptyState(
        kind: EmptyKind.notFound,
        title: 'Cette page n’existe pas',
        message: 'Elle a pu être renommée ou retirée.',
        actionLabel: 'Retour à l’accueil',
        onAction: () => context.go('/'),
      ),
    ),
    routes: [
      page('/', const LoadingScreen()),
      page('/chargement', const LoadingScreen()),
      GoRoute(
        path: '/connexion',
        builder: (_, state) => LoginScreen(disabled: state.uri.queryParameters['desactive'] == '1'),
      ),
      page('/mot-de-passe', const ForgotPasswordScreen()),
      GoRoute(path: '/demande-acces', builder: (_, _) => later('Demander un accès')),
      GoRoute(path: '/attente', builder: (_, _) => later('En attente')),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/compte', builder: (_, _) => soon('Mon compte')),
          GoRoute(path: '/joueur', builder: (_, _) => soon('Accueil')),
          page('/joueur/personnages', soon('Mes personnages')),
          page('/joueur/pnj', soon('PNJ confiés')),
          page('/joueur/demandes', soon('Mes demandes')),
          page('/joueur/wiki', soon('Wiki')),
          page('/joueur/notifications', soon('Notifications')),
          GoRoute(path: '/conteur', builder: (_, _) => soon('Tableau de bord')),
          GoRoute(path: '/conteur/demarrage', builder: (_, _) => soon('Démarrer la chronique')),
          GoRoute(path: '/conteur/comptes', builder: (_, _) => soon('Comptes')),
          GoRoute(path: '/conteur/equipe', builder: (_, _) => soon('Équipe de conteurs')),
          page('/conteur/fiches', soon('Fiches')),
          page('/conteur/demandes', soon('Demandes')),
          page('/conteur/pnj', soon('PNJ confiés')),
          page('/conteur/xp', soon('XP')),
          page('/conteur/wiki', soon('Wiki')),
          page('/conteur/referentiel', soon('Référentiel des règles')),
          page('/conteur/parametres', soon('Paramètres de la chronique')),
          page('/conteur/notifications', soon('Notifications')),
        ],
      ),
    ],
  );
}
