import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../offline/offline.dart';
import '../rulebook/schema.dart';
import 'wiki_rules.dart';
import 'wiki_view.dart';

/// Carte cliquable des listes du wiki.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.title, this.trailing, this.subtitle = '', required this.onTap});
  final String title;
  final String? trailing;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text(title, style: t.titleMedium)),
              if (trailing != null) Text(trailing!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Grille de cartes : une colonne en mobile, [columns] à partir de 600 px.
Widget _grid(List<Widget> cards, {int columns = 2}) => LayoutBuilder(builder: (context, c) {
      final n = c.maxWidth >= 600 ? columns : 1;
      final w = (c.maxWidth - 14 * (n - 1)) / n;
      return Wrap(spacing: 14, runSpacing: 14, children: [for (final card in cards) SizedBox(width: w, child: card)]);
    });

/// Accueil du wiki (J-Wiki) : recherche, rubriques, pages mises à jour récemment.
class WikiHomeScreen extends ConsumerStatefulWidget {
  const WikiHomeScreen({super.key, required this.nav});
  final WikiNav nav;

  @override
  ConsumerState<WikiHomeScreen> createState() => _WikiHomeScreenState();
}

class _WikiHomeScreenState extends ConsumerState<WikiHomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nav = widget.nav;
    final offline = ref.watch(offlineProvider).value ?? false;
    return WikiLoader(
      nav: nav,
      builder: (context, items, rb) {
        final recent = recentlyUpdated(items);
        final cards = [
          for (final r in rubrics)
            if (items.where((i) => i.rubric == r.id).length case final n when n > 0)
              _Card(key: Key('wk-rub-${r.id}'), title: r.label, trailing: '$n', subtitle: r.blurb, onTap: () => context.go(nav.rubric(r.id))),
        ];
        final side = Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Mis à jour récemment'),
            const SizedBox(height: 8),
            if (recent.isEmpty) Text('Aucune page publiée pour l’instant.', style: t.bodyMedium),
            for (final i in recent)
              InkWell(
                key: Key('wk-recent-${i.id}'),
                onTap: () => context.go(nav.page(i.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: i.title),
                          TextSpan(text: ' · ${rubricById(i.rubric).label}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                        ]),
                        style: t.bodyMedium,
                      ),
                    ),
                    Text(formatDay(i.page?.updatedAt), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ]),
                ),
              ),
          ]),
        );
        return PageBody(children: [
          PageTitle(
            'Wiki de la chronique',
            subtitle: 'Les règles et le lore, au même endroit que vos fiches. Disponible hors ligne.',
            action: Text(offline ? 'Hors ligne · copie de l’appareil' : 'Copie hors ligne à jour',
                style: t.bodyMedium?.copyWith(color: offline ? AppColors.offline : AppColors.success)),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('wk-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Rechercher un pouvoir, un rituel, un clan…', prefixIcon: Icon(Icons.search)),
            onSubmitted: (q) {
              if (q.trim().isNotEmpty) context.go(nav.search(q.trim()));
            },
          ),
          const SizedBox(height: 20),
          if (isWide(context))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _grid(cards)),
              const SizedBox(width: 24),
              SizedBox(width: 360, child: side),
            ])
          else ...[
            _grid(cards),
            const SizedBox(height: 20),
            side,
          ],
        ]);
      },
    );
  }
}

/// Rubrique du wiki (J-WikiRubrique) : cartes groupées par catégorie, puces de filtre.
class WikiRubricScreen extends StatefulWidget {
  const WikiRubricScreen({super.key, required this.nav, required this.rubricId});
  final WikiNav nav;
  final String rubricId;

  @override
  State<WikiRubricScreen> createState() => _WikiRubricScreenState();
}

class _WikiRubricScreenState extends State<WikiRubricScreen> {
  var _filter = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nav = widget.nav;
    final r = findRubric(widget.rubricId);
    if (r == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Rubrique introuvable', message: 'Cette rubrique n’existe pas.');
    final filters = rubricFilters(r);
    return WikiLoader(
      nav: nav,
      builder: (context, items, rb) {
        final keep = filters[_filter].$2;
        final shown = [for (final i in items) if (i.rubric == r.id && keep(i)) i];
        final groups = [for (final c in r.cats) categoryById(c)?.label ?? c, 'Pages du conte'];
        return PageBody(children: [
          WikiCrumbs([('Wiki', nav.home)], r.label),
          const SizedBox(height: 8),
          PageTitle(r.label),
          if (filters.length > 1) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 8, children: [
              for (final (n, (label, _)) in filters.indexed)
                ChoiceChip(key: Key('wk-filter-$n'), label: Text(label), selected: n == _filter, onSelected: (_) => setState(() => _filter = n)),
            ]),
          ],
          const SizedBox(height: 20),
          if (shown.isEmpty) Text('Aucune page dans cette rubrique.', style: t.bodyMedium),
          for (final g in groups)
            if ([for (final i in shown) if (groupOf(i) == g) i] case final list when list.isNotEmpty) ...[
              SectionTitle(g),
              const SizedBox(height: 10),
              _grid([
                for (final i in list)
                  _Card(key: Key('wk-item-${i.id}'), title: i.title, subtitle: itemSubtitle(i, rb), onTap: () => context.go(nav.page(i.id))),
              ], columns: 3),
              const SizedBox(height: 24),
            ],
        ]);
      },
    );
  }
}

/// Recherche dans le wiki (J-WikiRecherche) : pages visibles seulement, hors ligne compris.
class WikiSearchScreen extends StatefulWidget {
  const WikiSearchScreen({super.key, required this.nav, required this.query});
  final WikiNav nav;
  final String query;

  @override
  State<WikiSearchScreen> createState() => _WikiSearchScreenState();
}

class _WikiSearchScreenState extends State<WikiSearchScreen> {
  late final _q = TextEditingController(text: widget.query);
  var _group = 0;

  static final _groups = <(String, bool Function(SearchHit))>[
    ('Tout', (SearchHit _) => true),
    ('Règles', (SearchHit h) => h.item.rubric != chronicleRubric),
    ('Chronique', (SearchHit h) => h.item.rubric == chronicleRubric),
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nav = widget.nav;
    return WikiLoader(
      nav: nav,
      builder: (context, items, rb) {
        final hits = search(items, _q.text);
        final shown = [for (final h in hits) if (_groups[_group].$2(h)) h];
        return PageBody(children: [
          WikiCrumbs([('Wiki', nav.home)], 'Recherche'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('wk-search'),
            controller: _q,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Rechercher un pouvoir, un rituel, un clan…', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            for (final (n, (label, keep)) in _groups.indexed)
              ChoiceChip(
                key: Key('wk-group-$n'),
                label: Text('$label · ${hits.where(keep).length}'),
                selected: n == _group,
                onSelected: (_) => setState(() => _group = n),
              ),
          ]),
          const SizedBox(height: 16),
          if (_q.text.trim().isNotEmpty && shown.isEmpty) Text('Aucun résultat.', style: t.bodyMedium),
          for (final h in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                child: InkWell(
                  key: Key('wk-hit-${h.item.id}'),
                  onTap: () => context.go(nav.page(h.item.id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.item.title, style: t.titleMedium),
                      Text(rubricById(h.item.rubric).label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                      if (h.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(h.excerpt, style: t.bodyMedium?.copyWith(color: AppColors.textSoft)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text('La recherche ne montre que les pages que vous pouvez voir. Elle fonctionne aussi hors ligne.',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]);
      },
    );
  }
}
