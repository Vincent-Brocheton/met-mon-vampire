import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/forms.dart';
import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'chronicle_repository.dart';

const _staffRoles = [Role.principal, Role.conteur, Role.narrateur];

// Tableau des droits de C33 : (droit, principal, conteur, narrateur).
const _rights = [
  ('Paramètres de la chronique, comptes, rôles', 'Oui', 'Non', 'Non'),
  ('Référentiel et wiki', 'Oui', 'Oui', 'Lecture'),
  ('Valider les créations et dépenses', 'Oui', 'Oui', 'Non'),
  ('Saisies de jeu : péchés, liens, événements', 'Oui', 'Oui', 'Oui'),
  ('Secrets : notes du conte, événements cachés', 'Oui', 'Oui', 'Non'),
  ('Journal de la chronique', 'Oui', 'Oui', 'Non'),
  ('Corrections et remboursements d’XP', 'Oui', 'Oui', 'Non'),
  ('Gel, impression, hors ligne', 'Oui', 'Oui', 'Oui'),
];

/// C33 : équipe, rôles, invitations. Réservé au conteur principal.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _inviteForm = GlobalKey<FormState>();
  final _inviteEmail = TextEditingController();
  Role _inviteRole = Role.conteur;
  String? _promoteUid;
  Role _promoteRole = Role.conteur;

  @override
  void dispose() {
    _inviteEmail.dispose();
    super.dispose();
  }

  /// Exécute [action] ; true si elle a réussi. Le résultat s'affiche dans un SnackBar.
  Future<bool> _guard(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
      return true;
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Action refusée ou impossible. Réessayez.')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(chronicleRepositoryProvider);
    final me = ref.watch(currentUserProvider).value;
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textSecondary);

    final team = asyncView(ref.watch(allUsersProvider), (users) {
      final staff = users.where((u) => u.role.isStaff).toList()
        ..sort((a, b) => _staffRoles.indexOf(a.role).compareTo(_staffRoles.indexOf(b.role)));
      final players = users.where((u) => u.role == Role.joueur).toList();
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('L’équipe'),
          for (final u in staff)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: u.role == Role.principal ? AppColors.staffAvatar : AppColors.border,
                  child: Text(initialsOf(u.displayName), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(u.displayName, style: t.titleMedium)),
                if (u.uid == me?.uid)
                  Text(u.role.label, style: TextStyle(color: roleColor(u.role)))
                else
                  DropdownButton<Role>(
                    value: u.role,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final r in [..._staffRoles, Role.joueur])
                        DropdownMenuItem(
                          value: r,
                          child: Text(r == Role.joueur ? 'Retirer de l’équipe' : r.label, style: TextStyle(color: roleColor(r))),
                        ),
                    ],
                    onChanged: (r) {
                      if (r != null && r != u.role) _guard(() => repo.setRole(u.uid, r), '${u.displayName} : ${r.label}.');
                    },
                  ),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Vous ne pouvez pas modifier votre propre rôle. Pour quitter le rôle de conteur principal, '
              'nommez d’abord un autre conteur principal : c’est lui qui pourra changer votre rôle.', style: t.bodySmall),
          const SizedBox(height: 18),
          const SectionTitle('Nommer un joueur dans l’équipe'),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: _promoteUid,
                hint: const Text('Choisir un joueur'),
                items: [for (final p in players) DropdownMenuItem(value: p.uid, child: Text(p.displayName))],
                onChanged: (v) => setState(() => _promoteUid = v),
              ),
            ),
            DropdownButton<Role>(
              value: _promoteRole,
              items: [for (final r in _staffRoles) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: (r) => setState(() => _promoteRole = r ?? _promoteRole),
            ),
            FilledButton(
              onPressed: _promoteUid == null
                  ? null
                  : () async {
                      if (await _guard(() => repo.setRole(_promoteUid!, _promoteRole), 'Rôle attribué.') && mounted) {
                        setState(() => _promoteUid = null);
                      }
                    },
              child: const Text('Nommer'),
            ),
          ]),
        ]),
      );
    }, onRetry: () => ref.invalidate(allUsersProvider));

    final invitations = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Inviter par e-mail'),
        const SizedBox(height: 10),
        Text('L’application n’envoie pas d’e-mail : partagez vous-même le lien de l’application. '
            'Le rôle est attribué dès que la personne a demandé un accès avec cette adresse et l’a confirmée.', style: muted),
        const SizedBox(height: 14),
        Form(
          key: _inviteForm,
          child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(
              width: 300,
              child: LabeledField(label: 'Adresse e-mail', controller: _inviteEmail, keyboardType: TextInputType.emailAddress, validator: validateEmail),
            ),
            DropdownButton<Role>(
              value: _inviteRole,
              items: [
                for (final r in [Role.conteur, Role.narrateur, Role.joueur]) DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (r) => setState(() => _inviteRole = r ?? _inviteRole),
            ),
            FilledButton(
              onPressed: () async {
                if (!_inviteForm.currentState!.validate()) return;
                if (await _guard(() => repo.invite(_inviteEmail.text, _inviteRole, me!.uid), 'Invitation enregistrée.')) {
                  _inviteEmail.clear();
                }
              },
              child: const Text('Enregistrer l’invitation'),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        asyncView(ref.watch(invitationsProvider), (list) => Column(children: [
              for (final inv in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(inv.email),
                  subtitle: Text(inv.role.label, style: TextStyle(color: roleColor(inv.role))),
                  trailing: TextButton(
                    onPressed: () => _guard(() => repo.cancelInvitation(inv.email), 'Invitation annulée.'),
                    child: const Text('Annuler'),
                  ),
                ),
            ]), onRetry: () => ref.invalidate(invitationsProvider)),
      ]),
    );

    final rights = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Droits par rôle'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: t.labelMedium,
            columns: [
              const DataColumn(label: Text('Droit')),
              for (final r in _staffRoles) DataColumn(label: Text(r.label, style: TextStyle(color: roleColor(r)))),
            ],
            rows: [
              for (final (right, a, b, c) in _rights)
                DataRow(cells: [
                  DataCell(Text(right)),
                  for (final v in [a, b, c])
                    DataCell(Text(v, style: TextStyle(
                      color: switch (v) { 'Oui' => AppColors.success, 'Lecture' => AppColors.goldLight, _ => AppColors.textMuted },
                    ))),
                ]),
            ],
          ),
        ),
      ]),
    );

    return PageBody(children: [
      const PageTitle('Équipe de conteurs', subtitle: 'Chaque rôle se modifie ici. Seul le conteur principal y a accès.'),
      const SizedBox(height: 22),
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [team, const SizedBox(height: 20), invitations])),
          const SizedBox(width: 20),
          Expanded(child: rights),
        ])
      else ...[
        team,
        const SizedBox(height: 20),
        invitations,
        const SizedBox(height: 20),
        rights,
      ],
    ]);
  }
}
