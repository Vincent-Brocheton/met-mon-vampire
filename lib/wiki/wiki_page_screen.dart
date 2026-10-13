import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'wiki_chronology.dart';
import 'wiki_markdown.dart';
import 'wiki_page.dart';
import 'wiki_personal.dart';
import 'wiki_rules.dart';
import 'wiki_view.dart';

/// « Source : … · mis à jour le 25 sept. par Léa ».
String pageFooter(WikiPage p) => [
      if (p.source.isNotEmpty) 'Source : ${p.source}',
      'mis à jour le ${formatDay(p.updatedAt)}${p.updatedByName == null ? '' : ' par ${p.updatedByName}'}',
    ].join(' · ');

/// Page du wiki (J-WikiPage, J-WikiLore) : données du référentiel, texte, sommaire ; pour une discipline,
/// un encadré par fiche active du joueur. Une page inexistante ou cachée affiche le même message.
class WikiPageScreen extends ConsumerStatefulWidget {
  const WikiPageScreen({super.key, required this.nav, required this.pageId});
  final WikiNav nav;
  final String pageId;

  @override
  ConsumerState<WikiPageScreen> createState() => _WikiPageScreenState();
}

class _WikiPageScreenState extends ConsumerState<WikiPageScreen> {
  final _keys = <GlobalKey>[];

  List<GlobalKey> _keysFor(int n) {
    while (_keys.length < n) {
      _keys.add(GlobalKey());
    }
    return _keys.sublist(0, n);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nav = widget.nav;
    final manages = ref.watch(currentUserProvider.select((u) => u.value?.role.managesAccounts ?? false));
    final mine = mineFor(ref, nav);
    return WikiLoader(
      nav: nav,
      builder: (context, items, rb) {
        final item = items.where((i) => i.id == widget.pageId).firstOrNull;
        if (item == null) {
          return const EmptyState(kind: EmptyKind.notFound, title: 'Page introuvable', message: 'Cette page n’existe pas ou ne vous est pas ouverte.');
        }
        final page = item.page;
        final body = page?.body ?? '';
        final heads = headingsOf(body);
        final keys = _keysFor(heads.length);
        final r = rubricById(item.rubric);
        final banner = page == null ? null : reservedBanner(page.audience, rb);
        final discipline = item.cat == 'disciplines' ? item.entry : null;
        final article = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WikiCrumbs([('Wiki', nav.home), (r.label, nav.rubric(r.id))], item.title),
          const SizedBox(height: 8),
          Wrap(spacing: 14, crossAxisAlignment: WrapCrossAlignment.end, children: [
            Text(item.title, style: isWide(context) ? t.displaySmall : t.headlineMedium),
            if ((item.vo ?? '').isNotEmpty) Text(item.vo!, style: t.bodyMedium?.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic)),
          ]),
          if (banner != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('wk-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF2A2240), borderRadius: BorderRadius.circular(6)),
              child: Text(banner, style: t.bodyMedium?.copyWith(color: AppColors.narrator)),
            ),
          ],
          if (discipline != null)
            for (final c in mine)
              if (nextStep(c, discipline, rb) case final step) ...[
                const SizedBox(height: 14),
                Panel(
                  key: Key('wk-next-${c.id}'),
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(step.heading, style: t.titleSmall),
                    if (step.next case final next?) ...[
                      const SizedBox(height: 4),
                      Text(next, style: t.bodyMedium?.copyWith(color: AppColors.textSoft)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: Key('wk-buy-${c.id}'),
                        onPressed: () => context.go('/joueur/personnages/${c.id}/xp'),
                        child: const Text('Préparer l’achat'),
                      ),
                    ],
                  ]),
                ),
              ],
          if (item.entry case final e?) ...[
            const SizedBox(height: 18),
            RuleDataView(cat: item.cat!, entry: e, focus: mine.firstOrNull, rb: rb),
          ],
          const SizedBox(height: 18),
          if (item.id == chronologyId)
            const ChronologyView()
          else if (body.trim().isEmpty)
            Text(item.isRule ? 'Le conte n’a pas encore rédigé cette page.' : 'Page vide.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted))
          else
            WikiBody(body, headingKeys: keys, target: (title) => resolveLink(title, items)?.id, onOpen: (id) => context.go(nav.page(id))),
          if (page != null) ...[
            const SizedBox(height: 24),
            Text(pageFooter(page), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
        ]);
        final toc = heads.length < 2
            ? null
            : Panel(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('Sur cette page'),
                  const SizedBox(height: 6),
                  for (final (n, h) in heads.indexed)
                    InkWell(
                      onTap: () {
                        final at = keys[n].currentContext;
                        if (at != null) Scrollable.ensureVisible(at, duration: const Duration(milliseconds: 300));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(h, style: t.bodyMedium?.copyWith(color: AppColors.link)),
                      ),
                    ),
                ]),
              );
        return PageBody(children: [
          if (manages && nav.staff && !nav.preview)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(key: const Key('wk-edit'), onPressed: () => context.go('/conteur/wiki/edition/${item.id}'), child: const Text('Modifier')),
            ),
          if (toc != null && isWide(context))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 220, child: toc),
              const SizedBox(width: 32),
              Expanded(child: article),
            ])
          else
            article,
        ]);
      },
    );
  }
}
