import 'package:go_router/go_router.dart';

import 'wiki_admin_screen.dart';
import 'wiki_browse_screens.dart';
import 'wiki_edit_screen.dart';
import 'wiki_history_screen.dart';
import 'wiki_page_screen.dart';
import 'wiki_view.dart';

const _player = WikiNav(staff: false);

WikiNav _staff(GoRouterState s) => WikiNav(staff: true, preview: s.uri.queryParameters['apercu'] == '1');

/// Routes du wiki, dans la coquille : lecture du joueur ; wiki du conte, édition, historique, lecture et aperçu joueur du conte.
List<GoRoute> wikiRoutes() => [
      GoRoute(path: '/joueur/wiki', builder: (_, _) => const WikiHomeScreen(nav: _player)),
      GoRoute(path: '/joueur/wiki/rubrique/:rub', builder: (_, s) => WikiRubricScreen(nav: _player, rubricId: s.pathParameters['rub']!)),
      GoRoute(path: '/joueur/wiki/page/:id', builder: (_, s) => WikiPageScreen(nav: _player, pageId: s.pathParameters['id']!)),
      GoRoute(path: '/joueur/wiki/recherche', builder: (_, s) => WikiSearchScreen(nav: _player, query: s.uri.queryParameters['q'] ?? '')),
      GoRoute(path: '/conteur/wiki', builder: (_, _) => const WikiAdminScreen()),
      GoRoute(path: '/conteur/wiki/edition/:id', builder: (_, s) => WikiEditScreen(pageId: s.pathParameters['id']!)),
      GoRoute(path: '/conteur/wiki/edition/:id/historique', builder: (_, s) => WikiHistoryScreen(pageId: s.pathParameters['id']!)),
      GoRoute(path: '/conteur/wiki/accueil', builder: (_, s) => WikiHomeScreen(nav: _staff(s))),
      GoRoute(path: '/conteur/wiki/rubrique/:rub', builder: (_, s) => WikiRubricScreen(nav: _staff(s), rubricId: s.pathParameters['rub']!)),
      GoRoute(path: '/conteur/wiki/page/:id', builder: (_, s) => WikiPageScreen(nav: _staff(s), pageId: s.pathParameters['id']!)),
      GoRoute(path: '/conteur/wiki/recherche', builder: (_, s) => WikiSearchScreen(nav: _staff(s), query: s.uri.queryParameters['q'] ?? '')),
    ];
