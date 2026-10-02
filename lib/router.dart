import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'account/account_screen.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/login_screen.dart';
import 'auth/pending_screen.dart';
import 'auth/request_access_screen.dart';
import 'auth/session.dart';
import 'auth/session_providers.dart';
import 'chronicle/accounts_screen.dart';
import 'chronicle/startup_screen.dart';
import 'chronicle/team_screen.dart';
import 'core/empty_state.dart';
import 'player/welcome_screen.dart';
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
        builder: (_, state) => LoginScreen(
          disabled: state.uri.queryParameters['desactive'] == '1',
          emailLink: state.uri.queryParameters.containsKey('oobCode') ? Uri.base.toString() : null,
        ),
      ),
      page('/mot-de-passe', const ForgotPasswordScreen()),
      page('/demande-acces', const RequestAccessScreen()),
      page('/attente', const PendingScreen()),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          page('/compte', const AccountScreen()),
          page('/joueur', const WelcomeScreen()),
          page('/joueur/personnages', soon('Mes personnages')),
          page('/joueur/pnj', soon('PNJ confiés')),
          page('/joueur/demandes', soon('Mes demandes')),
          page('/joueur/wiki', soon('Wiki')),
          page('/joueur/notifications', soon('Notifications')),
          page('/conteur', const StorytellerHome()),
          page('/conteur/demarrage', const StartupScreen()),
          page('/conteur/comptes', const AccountsScreen()),
          page('/conteur/equipe', const TeamScreen()),
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
