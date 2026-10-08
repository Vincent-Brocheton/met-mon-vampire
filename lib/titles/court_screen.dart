import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook_provider.dart';
import 'title_rules.dart';
import 'titles_repository.dart';

/// « La Cour » : les titres publics de la chronique et leurs détenteurs, par secte et par hiérarchie.
class CourtScreen extends ConsumerWidget {
  const CourtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final rb = ref.watch(rulebookProvider);
    if (rb == null) return const Center(child: CircularProgressIndicator());
    return asyncView(ref.watch(courtProvider), (entries) {
      final groups = courtGroups(entries, rb);
      return PageBody(children: [
        const PageTitle('La Cour', subtitle: 'Les titres publics de la chronique et ceux qui les portent.'),
        const SizedBox(height: 20),
        if (groups.isEmpty) Text('Aucun titre public pour l’instant.', style: t.bodyMedium),
        for (final g in groups) ...[
          Panel(
            key: Key('co-sect-${g.sect}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(g.sect),
              const SizedBox(height: 8),
              for (final ti in g.titles)
                Padding(
                  padding: EdgeInsets.only(left: 20.0 * ti.depth, top: 6, bottom: 6),
                  child: Column(key: Key('co-title-${ti.title}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ti.title, style: t.titleSmall?.copyWith(color: AppColors.gold)),
                    for (final h in ti.holders) Text(h.since == null ? h.name : '${h.name} · ${sinceText(h.since!)}', style: t.bodyMedium),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ]);
    }, onRetry: () => ref.invalidate(courtProvider));
  }
}
