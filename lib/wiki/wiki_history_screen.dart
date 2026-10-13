import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'wiki_page.dart';
import 'wiki_repository.dart';
import 'wiki_view.dart';
import 'word_diff.dart';

/// Historique d'une page (C-WikiHistorique) : versions, comparaison avec la précédente, restauration.
class WikiHistoryScreen extends ConsumerStatefulWidget {
  const WikiHistoryScreen({super.key, required this.pageId});
  final String pageId;

  @override
  ConsumerState<WikiHistoryScreen> createState() => _WikiHistoryScreenState();
}

class _WikiHistoryScreenState extends ConsumerState<WikiHistoryScreen> {
  int? _selected;
  var _busy = false;

  /// Restaurer republie le contenu de [v] comme version suivante ; aucune version n'est effacée.
  Future<void> _restore(WikiVersion v, WikiPage current, bool hasDraft) async {
    if (hasDraft && !await confirm(context, title: 'Restaurer la version ${v.n}', body: 'Le brouillon en cours sera abandonné.', action: 'Restaurer')) {
      return;
    }
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(wikiRepositoryProvider).publish(restoredPage(v, current.version), by, note: 'Restauration de la version ${v.n}');
      messenger.showSnackBar(SnackBar(content: Text('Version ${v.n} restaurée.')));
      if (mounted) setState(() => _selected = null);
    } catch (e) {
      final denied = e is FirebaseException && e.code == 'permission-denied';
      messenger.showSnackBar(SnackBar(
          content: Text(denied ? 'Cette page a été publiée entre-temps. Rechargez-la avant de publier.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manages = ref.watch(currentUserProvider.select((u) => u.value?.role.managesAccounts ?? false));
    final drafts = ref.watch(wikiDraftsProvider).value ?? const <WikiPage>[];
    final versions = ref.watch(wikiVersionsProvider(widget.pageId));
    return asyncView(ref.watch(wikiPagesProvider), (pages) {
      final page = pages.where((p) => p.id == widget.pageId).firstOrNull;
      if (page == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Page introuvable', message: 'Cette page n’a pas de version publiée.');
      }
      return asyncView(versions, (list) {
        if (list.isEmpty) {
          return const EmptyState(kind: EmptyKind.empty, title: 'Aucune version', message: 'Les versions apparaissent à chaque publication.');
        }
        return _body(context, page, list, manages: manages, hasDraft: drafts.any((d) => d.id == widget.pageId));
      }, onRetry: () => ref.invalidate(wikiVersionsProvider(widget.pageId)));
    }, onRetry: () => ref.invalidate(wikiPagesProvider));
  }

  Widget _body(BuildContext context, WikiPage page, List<WikiVersion> list, {required bool manages, required bool hasDraft}) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final sel = list.where((v) => v.n == _selected).firstOrNull ?? list.first;
    final prev = list.where((v) => v.n == sel.n - 1).firstOrNull;
    final versionList = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final v in list)
          InkWell(
            key: Key('wk-version-${v.n}'),
            onTap: () => setState(() => _selected = v.n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: v.n == sel.n ? const Color(0xFF2A1A1D) : null,
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Version ${v.n}', style: t.titleSmall)),
                  if (v.n == page.version) Text('En ligne', style: t.bodySmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
                if (v.note.isNotEmpty) Text(v.note, style: t.bodyMedium),
                Text('${v.byName} · ${formatDay(v.at)}', style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ]),
            ),
          ),
      ]),
    );
    final body = t.bodyLarge?.copyWith(color: AppColors.textSoft, height: 1.6);
    final compare = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.spaceBetween, children: [
          SectionTitle(prev == null ? 'Version ${sel.n} : création' : 'Version ${sel.n} comparée à la version ${prev.n}'),
          Wrap(spacing: 14, children: [
            Text('■ ajouté', style: t.bodySmall?.copyWith(color: AppColors.success)),
            Text('■ retiré', style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
          ]),
        ]),
        const SizedBox(height: 14),
        Text.rich(
          key: const Key('wk-diff'),
          TextSpan(style: body, children: [
            for (final p in wordDiff(prev?.page.body ?? '', sel.page.body))
              TextSpan(
                text: p.text,
                style: switch (p.kind) {
                  DiffKind.same => null,
                  DiffKind.added => const TextStyle(color: AppColors.success, backgroundColor: AppColors.activeBg),
                  DiffKind.removed => const TextStyle(color: AppColors.linkHover, backgroundColor: AppColors.deadBg, decoration: TextDecoration.lineThrough),
                },
              ),
          ]),
        ),
        if (manages && sel.n != page.version) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton(
              key: const Key('wk-restore'),
              onPressed: _busy ? null : () => _restore(sel, page, hasDraft),
              child: Text('Restaurer la version ${sel.n}'),
            ),
            Text('Restaurer crée une version ${page.version + 1} identique à la ${sel.n}. Aucune version n’est effacée.', style: muted),
          ]),
        ],
      ]),
    );
    return PageBody(children: [
      WikiCrumbs([('Wiki', '/conteur/wiki'), (page.title, '/conteur/wiki/edition/${page.id}')], 'Historique'),
      const SizedBox(height: 8),
      PageTitle(
        'Historique de « ${page.title} »',
        action: OutlinedButton(onPressed: () => context.go('/conteur/wiki/edition/${page.id}'), child: const Text('Retour à l’édition')),
      ),
      const SizedBox(height: 20),
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 380, child: versionList),
          const SizedBox(width: 24),
          Expanded(child: compare),
        ])
      else ...[
        versionList,
        const SizedBox(height: 20),
        compare,
      ],
    ]);
  }
}
