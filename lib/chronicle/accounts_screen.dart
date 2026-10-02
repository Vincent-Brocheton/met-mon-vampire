import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'chronicle_repository.dart';

enum AccountFilter {
  all('Tous'),
  players('Joueurs'),
  staff('Conteurs'),
  disabled('Désactivés');

  const AccountFilter(this.label);
  final String label;
}

bool matchesFilter(AppUser u, AccountFilter f) => switch (f) {
      AccountFilter.all => u.role != Role.pending,
      AccountFilter.players => u.role == Role.joueur,
      AccountFilter.staff => u.role.isStaff,
      AccountFilter.disabled => u.role == Role.disabled,
    };

/// C7 : demandes d’accès et liste des comptes (conteur et principal).
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  AccountFilter _filter = AccountFilter.all;

  Future<void> _setRole(AppUser u, Role role) async {
    try {
      await ref.read(chronicleRepositoryProvider).setRole(u.uid, role);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action refusée ou impossible. Réessayez.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final pending = ref.watch(pendingUsersProvider);
    final users = ref.watch(allUsersProvider);
    final t = Theme.of(context).textTheme;

    return PageBody(children: [
      PageTitle(
        'Comptes',
        subtitle: 'Qui peut se connecter, et avec quel rôle.',
        action: me?.role == Role.principal
            ? OutlinedButton(onPressed: () => context.go('/conteur/equipe'), child: const Text('Équipe de conteurs et rôles'))
            : null,
      ),
      const SizedBox(height: 22),
      asyncView(pending, (list) => list.isEmpty ? const SizedBox.shrink() : _pendingPanel(list),
          onRetry: () => ref.invalidate(pendingUsersProvider)),
      const SizedBox(height: 22),
      asyncView(users, (list) {
        final shown = list.where((u) => matchesFilter(u, _filter)).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in AccountFilter.values)
              ChoiceChip(
                label: Text('${f.label} · ${list.where((u) => matchesFilter(u, f)).length}'),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: AppColors.navActive,
              ),
          ]),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            const EmptyState(kind: EmptyKind.empty, title: 'Aucun compte', message: 'Aucun compte ne correspond à ce filtre.')
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (i, u) in shown.indexed) _UserRow(u, first: i == 0, isMe: u.uid == me?.uid, onSetRole: _setRole),
              ]),
            ),
        ]);
      }, onRetry: () => ref.invalidate(allUsersProvider)),
      const SizedBox(height: 16),
      Text(
        'Seul le conteur principal nomme les conteurs. Désactiver un compte conserve ses fiches ; elles restent consultables par le conte.',
        style: t.bodySmall,
      ),
    ]);
  }

  Widget _pendingPanel(List<AppUser> list) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Demandes d’accès · ${list.length}'),
        for (final u in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${u.displayName}  ·  ${formatDay(u.createdAt)}', style: t.titleMedium),
                    Text(u.email, style: t.bodySmall),
                    if (u.accessMessage != null) ...[
                      const SizedBox(height: 4),
                      Text('« ${u.accessMessage} »', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: AppColors.textSoft)),
                    ],
                  ]),
                ),
                Wrap(spacing: 8, children: [
                  FilledButton(onPressed: () => _setRole(u, Role.joueur), child: const Text('Accepter comme joueur')),
                  OutlinedButton(onPressed: () => _setRole(u, Role.disabled), child: const Text('Refuser')),
                ]),
              ],
            ),
          ),
      ]),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow(this.u, {required this.first, required this.isMe, required this.onSetRole});
  final AppUser u;
  final bool first;
  final bool isMe;
  final Future<void> Function(AppUser, Role) onSetRole;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Désactivation / réactivation des joueurs seulement : l’équipe se gère sur C33.
    final action = isMe
        ? null
        : switch (u.role) {
            Role.joueur => OutlinedButton(onPressed: () => onSetRole(u, Role.disabled), child: const Text('Désactiver')),
            Role.disabled => OutlinedButton(onPressed: () => onSetRole(u, Role.joueur), child: const Text('Réactiver')),
            _ => null,
          };
    final name = Text(u.displayName, style: t.titleMedium?.copyWith(fontSize: 15));
    final role = Text(u.role.label, style: TextStyle(fontSize: 15, color: roleColor(u.role)));
    final last = Text(formatDay(u.lastLoginAt), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
      child: isWide(context)
          ? Row(children: [
              Expanded(flex: 3, child: name),
              Expanded(flex: 4, child: Text(u.email, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
              Expanded(flex: 2, child: role),
              Expanded(flex: 2, child: last),
              SizedBox(width: 130, child: Align(alignment: Alignment.centerRight, child: action)),
            ])
          : Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  name,
                  Text(u.email, style: t.bodySmall),
                  const SizedBox(height: 4),
                  Row(children: [role, const SizedBox(width: 12), last]),
                ]),
              ),
              ?action,
            ]),
    );
  }
}
