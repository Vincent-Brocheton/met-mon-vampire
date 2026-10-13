import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'notification_rules.dart';
import 'notifications_repository.dart';

/// Notifications (C-Notifications, J-Notifications) : le fil des 60 derniers jours, les non lues signalées.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _busy = false;

  Future<void> _markRead(String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead(uid);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    final items = ref.watch(notificationsProvider);
    final seen = me?.notifSeenAt;
    final unread = unreadCount(items, seen);
    return PageBody(children: [
      PageTitle(
        'Notifications',
        subtitle: unread == 0 ? 'Aucune notification non lue.' : '$unread non lue${unread > 1 ? 's' : ''}. La cloche en haut de l’écran les signale.',
        action: OutlinedButton(
          key: const Key('nt-read'),
          onPressed: unread == 0 || _busy || me == null ? null : () => _markRead(me.uid),
          child: const Text('Tout marquer comme lu'),
        ),
      ),
      const SizedBox(height: 20),
      if (items.isEmpty)
        Text('Rien de nouveau pour l’instant.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
      else
        Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, n) in items.indexed)
              if (isUnread(n, seen) case final fresh)
                InkWell(
                  key: Key('nt-$i'),
                  onTap: () => context.go(n.link),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: fresh ? const Color(0xFF211719) : null,
                      border: const Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: fresh ? AppColors.accentIcon : Colors.transparent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: t.bodyLarge?.copyWith(fontWeight: fresh ? FontWeight.w600 : FontWeight.w400)),
                          if (n.detail.isNotEmpty) Text(n.detail, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(formatDay(n.at), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ]),
                  ),
                ),
          ]),
        ),
    ]);
  }
}
