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
import 'characters/character_edit_screen.dart';
import 'characters/character_screen.dart';
import 'characters/characters_list_screen.dart';
import 'characters/my_characters_screen.dart';
import 'chronicle/accounts_screen.dart';
import 'chronicle/startup_screen.dart';
import 'chronicle/team_screen.dart';
import 'core/empty_state.dart';
import 'creation/creation_screen.dart';
import 'creation/submitted_screen.dart';
import 'creation/validation_screen.dart';
import 'redirect.dart';
import 'shell/app_shell.dart';
import 'xp/corrections_screen.dart';
import 'xp/my_requests_screen.dart';
import 'xp/spend_screen.dart';
import 'xp/xp_admin_screen.dart';
import 'xp/xp_settings_screen.dart';

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
          page('/joueur', const PlayerHome()),
          page('/joueur/personnages', const MyCharactersScreen()),
          GoRoute(
            path: '/joueur/personnages/:id',
            builder: (_, s) => CharacterScreen(id: s.pathParameters['id']!, basePath: '/joueur/personnages/${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/joueur/personnages/:id/creation',
            builder: (_, s) => CreationScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/joueur/personnages/:id/soumise',
            builder: (_, s) => SubmittedScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/joueur/personnages/:id/xp',
            builder: (_, s) => SpendScreen(
              characterId: s.pathParameters['id']!,
              requestId: s.uri.queryParameters['demande'],
            ),
          ),
          GoRoute(
            path: '/joueur/personnages/:id/historique',
            builder: (_, s) => CharacterScreen(
              id: s.pathParameters['id']!,
              basePath: '/joueur/personnages/${s.pathParameters['id']}',
              history: true,
            ),
          ),
          page('/joueur/pnj', soon('PNJ confiés')),
          GoRoute(
            path: '/joueur/demandes',
            builder: (_, s) => MyRequestsScreen(selectedId: s.uri.queryParameters['d']),
          ),
          page('/joueur/wiki', soon('Wiki')),
          page('/joueur/notifications', soon('Notifications')),
          page('/conteur', const StorytellerHome()),
          page('/conteur/demarrage', const StartupScreen()),
          page('/conteur/comptes', const AccountsScreen()),
          page('/conteur/equipe', const TeamScreen()),
          page('/conteur/fiches', const CharactersListScreen()),
          GoRoute(
            path: '/conteur/fiches/:id',
            builder: (_, s) => CharacterEditScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/conteur/fiches/:id/historique',
            builder: (_, s) => CharacterScreen(
              id: s.pathParameters['id']!,
              basePath: '/conteur/fiches/${s.pathParameters['id']}',
              history: true,
            ),
          ),
          page('/conteur/demandes', const ValidationScreen()),
          page('/conteur/pnj', soon('PNJ confiés')),
          page('/conteur/xp', const XpAdminScreen()),
          page('/conteur/xp/corrections', const CorrectionsScreen()),
          page('/conteur/wiki', soon('Wiki')),
          page('/conteur/referentiel', soon('Référentiel des règles')),
          page('/conteur/parametres', const ParametersScreen()),
          page('/conteur/parametres/xp', const XpSettingsScreen()),
          page('/conteur/notifications', soon('Notifications')),
        ],
      ),
    ],
  );
}
