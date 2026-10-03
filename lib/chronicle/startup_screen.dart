import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_card.dart';
import '../auth/forms.dart';
import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'chronicle_repository.dart';

const sects = ['Camarilla', 'Anarchs', 'Sabbat', 'Indépendants'];

/// `/conteur` : la liste de démarrage pour le principal ; le vrai tableau de bord viendra plus tard.
class StorytellerHome extends ConsumerWidget {
  const StorytellerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(currentUserProvider).value?.role == Role.principal
          ? const StartupScreen()
          : EmptyState.comingSoon('Tableau de bord');
}

enum _Status { done, now, later }

String _statusLabel(_Status s) => switch (s) { _Status.done => 'Fait', _Status.now => 'À faire', _Status.later => 'Plus tard' };

Color _statusColor(_Status s) =>
    switch (s) { _Status.done => AppColors.success, _Status.now => AppColors.goldLight, _Status.later => AppColors.textMuted };

/// C32 : ce que voit le conteur principal à sa première connexion.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(chronicleProvider).value;
    final principal = ref.watch(currentUserProvider).value?.role == Role.principal;
    final named = (config?.name ?? '').isNotEmpty;
    void open(String path) => context.go(path);
    final steps = <(String, String, String, _Status, String, VoidCallback?)>[
      ('1', 'Nommer la chronique', 'Nom, association, secte par défaut (${config?.defaultSect ?? 'Camarilla'}).',
          named ? _Status.done : _Status.now, named ? 'Modifier' : 'Nommer',
          principal ? () => showDialog<void>(context: context, builder: (_) => ChronicleNameDialog(config: config)) : null),
      ('2', 'Régler l’expérience', 'XP de création, gain mensuel par paliers, barème des PNJ.', _Status.later, 'Ouvrir',
          () => open('/conteur/parametres/xp')),
      ('3', 'Remplir le référentiel et le wiki', 'Partir des valeurs du livre de base, puis rédiger les pages.',
          _Status.later, 'Ouvrir', () => open('/conteur/wiki')),
      ('4', 'Inviter l’équipe de conteurs', 'Chaque conteur reçoit un rôle et des droits.', _Status.now, 'Inviter',
          principal ? () => open('/conteur/equipe') : null),
      ('5', 'Importer les fiches existantes', 'Excel ou CSV, avec vérification avant import.', _Status.later, 'Importer',
          () => open('/conteur/fiches')),
      ('6', 'Ouvrir aux joueurs', 'Partagez le lien de l’application ; chaque compte est validé par un conteur.',
          _Status.now, 'Ouvrir', () => open('/conteur/comptes')),
    ];
    final done = steps.where((s) => s.$4 == _Status.done).length;
    final plural = done > 1 ? 's' : '';
    final t = Theme.of(context).textTheme;

    return PageBody(children: [
      PageTitle('Démarrer la chronique', subtitle: '$done étape$plural terminée$plural sur 6.'),
      const SizedBox(height: 22),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: done / 6,
          minHeight: 8,
          backgroundColor: AppColors.navActive,
          color: AppColors.gold,
        ),
      ),
      const SizedBox(height: 22),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, (n, title, detail, status, button, onTap)) in steps.indexed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StepDot(n, status),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide(context) ? 560 : 260),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(detail, style: t.bodyMedium?.copyWith(fontSize: 14, color: AppColors.textSecondary)),
                      ]),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(_statusLabel(status),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _statusColor(status))),
                    ),
                    if (onTap != null) OutlinedButton(onPressed: onTap, child: Text(button)),
                  ],
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      Text('La liste reste sur le tableau de bord tant qu’elle n’est pas terminée.', style: t.bodySmall),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(this.n, this.status);
  final String n;
  final _Status status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: status == _Status.later ? AppColors.fieldBorder : color, width: 2),
      ),
      child: Text(n, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Étape 1 de C32 : nom, association, secte par défaut.
class ChronicleNameDialog extends ConsumerStatefulWidget {
  const ChronicleNameDialog({super.key, required this.config});
  final ChronicleConfig? config;

  @override
  ConsumerState<ChronicleNameDialog> createState() => _ChronicleNameDialogState();
}

class _ChronicleNameDialogState extends ConsumerState<ChronicleNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.config?.name);
  late final _association = TextEditingController(text: widget.config?.associationName);
  late String _sect = sects.contains(widget.config?.defaultSect) ? widget.config!.defaultSect : sects.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _association.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    return validateRequired(s) ?? (s.length > 80 ? '80 caractères maximum.' : null);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chronicleRepositoryProvider).updateConfig(
            name: _name.text,
            associationName: _association.text,
            defaultSect: _sect,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Enregistrement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nommer la chronique'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LabeledField(label: 'Nom de la chronique', controller: _name, hint: 'Paris by Night', validator: _validateName),
              const SizedBox(height: 16),
              LabeledField(label: 'Nom de l’association', controller: _association),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _sect,
                decoration: const InputDecoration(labelText: 'Secte par défaut'),
                items: [for (final s in sects) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setState(() => _sect = v ?? _sect),
              ),
              if (_error != null) ...[const SizedBox(height: 12), FormError(_error!)],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Enregistrer')),
        ],
      );
}
