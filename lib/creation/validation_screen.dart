import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rules/creation_rules.dart';

/// C4 : file des fiches soumises, contrôles, décision du conte.
class ValidationScreen extends ConsumerStatefulWidget {
  const ValidationScreen({super.key});

  @override
  ConsumerState<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends ConsumerState<ValidationScreen> {
  String? _selectedId;
  final _comment = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide(Character c, CharacterStatus to) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    if (to != CharacterStatus.active && _comment.text.trim().isEmpty) {
      setState(() => _error = 'Expliquez les corrections attendues.');
      return;
    }
    if (to == CharacterStatus.rejected) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Refuser la fiche'),
          content: const Text('La fiche sera archivée en lecture seule.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Refuser')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(characterRepositoryProvider).decide(c, to, _comment.text, by);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(switch (to) {
          CharacterStatus.active => '${c.name} est validé et actif.',
          CharacterStatus.draft => 'Corrections demandées à ${c.playerName ?? 'son joueur'}.',
          _ => '${c.name} est refusé.',
        })));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Décision impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    return asyncView(ref.watch(reviewQueueProvider), (queue) {
      if (queue.isEmpty) {
        return const EmptyState(kind: EmptyKind.empty, title: 'Aucune fiche en attente', message: 'Les fiches soumises par les joueurs apparaîtront ici.');
      }
      final selected = queue.firstWhere((c) => c.id == _selectedId, orElse: () => queue.first);
      final list = Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.all(16), child: SectionTitle('En attente · ${queue.length}')),
          for (final c in queue)
            InkWell(
              onTap: () => setState(() {
                _selectedId = c.id;
                _comment.clear();
                _error = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: c.id == selected.id ? AppColors.navActive : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Création · ${formatDay(c.submittedAt)}', style: t.bodySmall?.copyWith(color: AppColors.narrator)),
                  Text(c.name, style: t.titleMedium),
                  Text('${c.playerName ?? '—'} · nouvelle fiche', style: t.bodySmall),
                ]),
              ),
            ),
        ]),
      );
      final checks = creationChecks(selected);
      final own = selected.playerUid == me?.uid;
      final detail = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Création · soumise le ${formatDay(selected.submittedAt)} par ${selected.playerName ?? '—'}', style: t.bodySmall),
        const SizedBox(height: 6),
        Text(selected.name, style: isWide(context) ? t.displaySmall : t.headlineMedium),
        Text(identityLine(selected), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Contrôles automatiques'),
            const SizedBox(height: 10),
            for (final k in checks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(
                    switch (k.level) {
                      CheckLevel.ok => Icons.check_circle_outline,
                      CheckLevel.warn => Icons.info_outline,
                      _ => Icons.error_outline,
                    },
                    size: 18,
                    color: switch (k.level) {
                      CheckLevel.ok => AppColors.success,
                      CheckLevel.warn => AppColors.goldLight,
                      _ => AppColors.linkHover,
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(k.text, style: t.bodyMedium)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        CharacterSheetView(selected),
        if ((selected.story ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Récit'),
            const SizedBox(height: 8),
            Text(selected.story!, style: t.bodyMedium),
          ])),
        ],
        const SizedBox(height: 20),
        if (own)
          Text('C’est votre propre fiche : un autre conteur doit la valider.', style: t.bodyMedium?.copyWith(color: AppColors.goldLight))
        else
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                key: const Key('decision-comment'),
                controller: _comment,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Commentaire au joueur'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton(onPressed: () => _decide(selected, CharacterStatus.active), child: const Text('Valider et activer la fiche')),
                OutlinedButton(onPressed: () => _decide(selected, CharacterStatus.draft), child: const Text('Demander des corrections')),
                TextButton(onPressed: () => _decide(selected, CharacterStatus.rejected), child: const Text('Refuser')),
              ]),
            ]),
          ),
      ]);
      return PageBody(children: [
        if (isWide(context))
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 300, child: list),
            const SizedBox(width: 24),
            Expanded(child: detail),
          ])
        else ...[list, const SizedBox(height: 20), detail],
      ]);
    }, onRetry: () => ref.invalidate(reviewQueueProvider));
  }
}
