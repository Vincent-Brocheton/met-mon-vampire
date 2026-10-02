import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// J-Creation-Soumise : fiche verrouillée en attendant le conte.
class SubmittedScreen extends ConsumerWidget {
  const SubmittedScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(characterProvider(id)), (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: '');
      Future<void> withdraw() async {
        final by = actorOf(ref.read(currentUserProvider).value);
        if (by == null) return;
        try {
          await ref.read(characterRepositoryProvider).withdraw(c, by);
          if (context.mounted) context.go('/joueur/personnages/$id/creation');
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action impossible. Réessayez.')));
          }
        }
      }

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Panel(
              padding: const EdgeInsets.all(32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.name} est soumis au conte', style: t.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'La fiche est en validation et verrouillée. Le conte peut la valider, vous demander des corrections ou la refuser.',
                  style: t.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(c.status),
                  if (c.submittedAt != null) Text('Soumise le ${formatDay(c.submittedAt)} · ${c.xpEarned} XP mis de côté', style: t.bodySmall),
                ]),
                const SizedBox(height: 24),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  FilledButton(onPressed: () => context.go('/joueur'), child: const Text('Retour à l’accueil')),
                  if (c.status == CharacterStatus.review)
                    OutlinedButton(onPressed: withdraw, child: const Text('Retirer la soumission et repasser en brouillon')),
                ]),
                if (c.status != CharacterStatus.review) ...[
                  const SizedBox(height: 12),
                  Text('Le conte a déjà répondu : ouvrez la fiche pour voir sa décision.', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
                ],
              ]),
            ),
          ),
        ),
      );
    }, onRetry: () => ref.invalidate(characterProvider(id)));
  }
}
