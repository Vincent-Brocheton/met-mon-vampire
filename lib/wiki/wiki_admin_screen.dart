import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'wiki_repository.dart';
import 'wiki_rules.dart';
import 'wiki_view.dart';

enum _Filter { all, rules, chronicle, drafts, empty }

/// Wiki du conte (C-Wiki) : toutes les pages, avancement de la rédaction, accès aux éditions.
class WikiAdminScreen extends ConsumerStatefulWidget {
  const WikiAdminScreen({super.key});

  @override
  ConsumerState<WikiAdminScreen> createState() => _WikiAdminScreenState();
}

class _WikiAdminScreenState extends ConsumerState<WikiAdminScreen> {
  var _filter = _Filter.all;

  bool _keep(WikiItem i) => switch (_filter) {
        _Filter.all => true,
        _Filter.rules => i.rubric != chronicleRubric,
        _Filter.chronicle => i.rubric == chronicleRubric,
        _Filter.drafts => i.draft != null,
        _Filter.empty => stateOf(i) == WikiState.empty,
      };

  @override
  Widget build(BuildContext context) {
    // Accès du wiki recalculés d'après les fiches.
    ref.watch(wikiAudienceSyncProvider);
    final t = Theme.of(context).textTheme;
    final manages = ref.watch(currentUserProvider.select((u) => u.value?.role.managesAccounts ?? false));
    final rb = ref.watch(rulebookProvider);
    final drafts = ref.watch(wikiDraftsProvider);
    if (rb == null) return const Center(child: CircularProgressIndicator());
    return asyncView(
      ref.watch(wikiPagesProvider),
      (pages) => asyncView(drafts, (drafts) {
        final items = wikiIndex(rb, pages, drafts: drafts, staff: true);
        final shown = items.where(_keep).toList();
        final chips = [
          (_Filter.all, 'Toutes · ${items.length}'),
          (_Filter.rules, 'Règles'),
          (_Filter.chronicle, 'La chronique'),
          (_Filter.drafts, 'Brouillons · ${items.where((i) => i.draft != null).length}'),
          (_Filter.empty, 'À rédiger · ${items.where((i) => stateOf(i) == WikiState.empty).length}'),
        ];
        final table = Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucune page ne correspond.', style: t.bodyMedium)),
            for (final i in shown) _Row(i, rb, onTap: () => context.go('/conteur/wiki/edition/${i.id}')),
          ]),
        );
        final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Avancement de la rédaction'),
              const SizedBox(height: 8),
              Text('Chaque entrée du référentiel a sa page, vide tant que le conte ne l’a pas rédigée.',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSoft)),
              const SizedBox(height: 8),
              for (final p in progress(items))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Text(p.label, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
                    Text('${p.done} sur ${p.total}', style: t.bodyMedium),
                  ]),
                ),
              const SizedBox(height: 12),
              FilledButton(key: const Key('wk-empty'), onPressed: () => setState(() => _filter = _Filter.empty), child: const Text('Voir les pages vides')),
            ]),
          ),
          const SizedBox(height: 20),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Règles de visibilité'),
              const SizedBox(height: 8),
              for (final line in const [
                'Tous les joueurs, un clan, une secte, ou le conte seul.',
                'Un clan ou une secte : les joueurs dont une fiche active en fait partie.',
                'Les joueurs gardent une copie hors ligne des pages qu’ils peuvent voir.',
              ])
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: t.bodyMedium?.copyWith(color: AppColors.textSoft))),
            ]),
          ),
        ]);
        return PageBody(children: [
          PageTitle(
            'Wiki de la chronique',
            subtitle: 'Chaque entrée du référentiel a sa page. Les pages libres portent le lore et la chronique.',
            action: Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton(
                key: const Key('wk-preview'),
                onPressed: () => context.go(const WikiNav(staff: true, preview: true).home),
                child: const Text('Voir comme un joueur'),
              ),
              if (manages)
                FilledButton.icon(
                  key: const Key('wk-new'),
                  onPressed: () => context.go('/conteur/wiki/edition/nouvelle'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle page'),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 8, children: [
            for (final (f, label) in chips) ChoiceChip(label: Text(label), selected: f == _filter, onSelected: (_) => setState(() => _filter = f)),
          ]),
          const SizedBox(height: 14),
          if (isWide(context))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: table),
              const SizedBox(width: 24),
              SizedBox(width: 400, child: side),
            ])
          else ...[
            table,
            const SizedBox(height: 20),
            side,
          ],
        ]);
      }, onRetry: () => ref.invalidate(wikiDraftsProvider)),
      onRetry: () => ref.invalidate(wikiPagesProvider),
    );
  }
}

/// Ligne du tableau : page et rubrique, origine, visibilité, état, date.
class _Row extends StatelessWidget {
  const _Row(this.item, this.rb, {required this.onTap});
  final WikiItem item;
  final Rulebook rb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final state = stateOf(item);
    final color = switch (state) {
      WikiState.published => AppColors.success,
      WikiState.draft => AppColors.goldLight,
      WikiState.empty => AppColors.textMuted,
    };
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    return InkWell(
      key: Key('wk-row-${item.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 240,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: t.titleSmall),
              Text(rubricById(item.rubric).label, style: muted),
            ]),
          ),
          SizedBox(width: 150, child: Text(originLabel(item), style: t.bodySmall?.copyWith(color: AppColors.textSecondary))),
          AudiencePill(item.audience, audienceLabel(item.audience, rb)),
          SizedBox(width: 80, child: Text(state.label, style: t.bodySmall?.copyWith(color: color))),
          Text(formatDay(item.page?.updatedAt ?? item.draft?.updatedAt), style: muted),
        ]),
      ),
    );
  }
}
