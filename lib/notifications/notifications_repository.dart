import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart' hide reviewQueue;
import '../chronicle/chronicle_repository.dart';
import '../games/games_repository.dart';
import '../npcs/npc_loans_repository.dart';
import '../wiki/wiki_repository.dart';
import '../xp/xp_repository.dart';
import 'notification_rules.dart';

part 'notifications_repository.g.dart';

/// Seule écriture des notifications : la date de dernière visite (`users/{uid}.notifSeenAt`, heure du serveur).
class NotificationsRepository {
  NotificationsRepository(this._db);

  final FirebaseFirestore _db;

  Future<void> markAllRead(String uid) => _db.collection('users').doc(uid).update({'notifSeenAt': FieldValue.serverTimestamp()});
}

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) => NotificationsRepository(ref.watch(firestoreProvider));

/// Une source qui charge ou qui échoue ne donne rien : elle n'empêche pas les autres.
List<T> _v<T>(AsyncValue<List<T>> a) => a.value ?? const [];

/// Fil du lecteur, calculé à partir des données que l'application lit déjà (conte ou joueur selon le rôle).
@riverpod
List<AppNotification> notifications(Ref ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final now = DateTime.now();
  if (me.role.isStaff) {
    return feed([
      // Le narrateur ne lit pas les comptes.
      if (me.role.managesAccounts) ...accessRequests(_v(ref.watch(pendingUsersProvider))),
      ...pendingSummary(_v(ref.watch(pendingRequestsProvider))),
      ...reviewQueue(_v(ref.watch(reviewQueueProvider))),
      ...wikiByOthers(_v(ref.watch(wikiPagesProvider)), me.uid),
    ], now: now);
  }
  return feed([
    ...decidedRequests(_v(ref.watch(myRequestsProvider))),
    for (final c in _v(ref.watch(myCharactersProvider))) ...xpReceived(c, _v(ref.watch(characterHistoryProvider(c.id)))),
    ...freeze(_v(ref.watch(gamesProvider)), now),
    ...npcLoans(_v(ref.watch(myNpcLoansProvider))),
    ...wikiForPlayer(_v(ref.watch(wikiPagesProvider))),
  ], now: now);
}

/// Nombre de notifications non lues (point rouge de la cloche).
@riverpod
int unreadNotifications(Ref ref) =>
    unreadCount(ref.watch(notificationsProvider), ref.watch(currentUserProvider.select((u) => u.value?.notifSeenAt)));
