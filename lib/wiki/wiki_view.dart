import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'wiki_markdown.dart';
import 'wiki_repository.dart';
import 'wiki_rules.dart';

/// Adresses de lecture : espace joueur (`/joueur/wiki`) ou conte (`/conteur/wiki/…`), aperçu joueur compris.
class WikiNav {
  const WikiNav({required this.staff, this.preview = false});
  final bool staff;

  /// Aperçu joueur du conte : pages ouvertes à tous et entrées proposées seulement.
  final bool preview;

  String get _base => staff ? '/conteur/wiki' : '/joueur/wiki';
  String _q(String path) => preview ? '$path${path.contains('?') ? '&' : '?'}apercu=1' : path;
  String get home => _q(staff ? '$_base/accueil' : _base);
  String rubric(String id) => _q('$_base/rubrique/$id');
  String page(String id) => _q('$_base/page/$id');
  String search(String query) => _q('$_base/recherche?q=${Uri.encodeQueryComponent(query)}');
}

/// Charge le référentiel et les pages, puis construit avec les éléments lisibles.
class WikiLoader extends ConsumerWidget {
  const WikiLoader({super.key, required this.nav, required this.builder});
  final WikiNav nav;
  final Widget Function(BuildContext context, List<WikiItem> items, Rulebook rb) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rb = ref.watch(rulebookProvider);
    final staff = ref.watch(currentUserProvider.select((u) => u.value?.role.isStaff ?? false));
    if (rb == null) return const Center(child: CircularProgressIndicator());
    return asyncView(ref.watch(wikiPagesProvider), (pages) => builder(context, readerItems(rb, pages, staff: staff, preview: nav.preview), rb),
        onRetry: () => ref.invalidate(wikiPagesProvider));
  }
}

/// Fil d'Ariane : liens, puis la page courante.
class WikiCrumbs extends StatelessWidget {
  const WikiCrumbs(this.links, this.current, {super.key});
  final List<(String, String)> links;
  final String current;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final (label, path) in links) ...[
        InkWell(onTap: () => context.go(path), child: Text(label, style: style?.copyWith(color: AppColors.link))),
        Text(' / ', style: style),
      ],
      Text(current, style: style),
    ]);
  }
}

/// Pastille « Visible par ».
class AudiencePill extends StatelessWidget {
  const AudiencePill(this.audience, this.label, {super.key});
  final String audience;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (audience) {
      audienceAll => (AppColors.activeBg, AppColors.success),
      audienceStaff => (AppColors.deadBg, AppColors.linkHover),
      _ => (const Color(0xFF2A2240), AppColors.narrator),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Texte d'une page. [target] donne l'identifiant d'une page visible de ce titre ;
/// sans page visible, le lien reste du texte simple (il ne trahit pas une page cachée).
class WikiBody extends StatelessWidget {
  const WikiBody(this.source, {super.key, required this.target, required this.onOpen, this.headingKeys = const []});
  final String source;
  final String? Function(String title) target;
  final void Function(String id) onOpen;

  /// Clés des titres `##`, dans l'ordre (sommaire).
  final List<GlobalKey> headingKeys;

  InlineSpan _span(WikiSpan s, TextStyle? style, {required bool links}) {
    final id = s.link && links ? target(s.text) : null;
    if (id == null) {
      return TextSpan(text: s.text, style: TextStyle(fontWeight: s.bold ? FontWeight.w700 : null, fontStyle: s.italic ? FontStyle.italic : null));
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: InkWell(onTap: () => onOpen(id), child: Text(s.text, style: style?.copyWith(color: AppColors.link))),
    );
  }

  Widget _rich(String text, TextStyle? style, {bool links = true}) =>
      Text.rich(TextSpan(style: style, children: [for (final s in parseInline(text)) _span(s, style, links: links)]));

  /// Pas de lien dans un tableau : les colonnes se mesurent sur du texte simple.
  Widget _table(List<List<String>> rows, TextStyle? head, TextStyle? body) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final width = rows.fold<int>(0, (m, r) => max(m, r.length));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: AppColors.border),
        children: [
          for (final (n, r) in rows.indexed)
            TableRow(children: [
              for (var c = 0; c < width; c++)
                Padding(padding: const EdgeInsets.all(8), child: _rich(c < r.length ? r[c] : '', n == 0 ? head : body, links: false)),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final body = t.bodyLarge?.copyWith(color: AppColors.textSoft, height: 1.6);
    var heading = 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final b in parseWiki(source))
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: switch (b) {
            WikiHeading(:final text) => Padding(
                key: heading < headingKeys.length ? headingKeys[heading++] : null,
                padding: const EdgeInsets.only(top: 8),
                child: _rich(text, t.titleMedium),
              ),
            WikiPara(:final text) => _rich(text, body),
            WikiRuleBox(:final text) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(color: AppColors.surface, border: Border(left: BorderSide(color: AppColors.gold, width: 3))),
                child: _rich(text, body),
              ),
            WikiList(:final items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final i in items)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('•  ', style: body), Expanded(child: _rich(i, body))]),
              ]),
            WikiTable(:final rows) => _table(rows, t.titleSmall, body),
          },
        ),
    ]);
  }
}

/// Données de l'entrée du référentiel, en tête d'une page de règle ; les pouvoirs d'une discipline niveau par niveau.
class RuleDataView extends StatelessWidget {
  const RuleDataView({super.key, required this.cat, required this.entry});
  final String cat;
  final RuleEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lines = dataLines(cat, entry);
    final powers = disciplinePowers(entry);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (entry.description.isNotEmpty) ...[
        Text(entry.description, style: t.bodyLarge?.copyWith(color: AppColors.textSoft)),
        const SizedBox(height: 12),
      ],
      if (lines.isNotEmpty)
        Wrap(spacing: 18, runSpacing: 6, children: [
          for (final (label, value) in lines)
            Text.rich(
              TextSpan(children: [TextSpan(text: '$label : ', style: const TextStyle(color: AppColors.textMuted)), TextSpan(text: value)]),
              style: t.bodyMedium,
            ),
        ]),
      if (powers.isNotEmpty) ...[
        const SizedBox(height: 18),
        const SectionTitle('Pouvoirs'),
        for (final p in powers)
          Padding(
            key: Key('wk-power-${p.level}-${p.name}'),
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(p.elder ? 'Ancien' : '●' * p.level, style: t.titleSmall?.copyWith(color: AppColors.gold)),
                Text(p.name, style: t.titleSmall),
                if (p.vo.isNotEmpty) Text(p.vo, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: AppColors.textMuted)),
              ]),
              if (p.effect.isNotEmpty) Text(p.effect, style: t.bodyMedium?.copyWith(color: AppColors.textSoft)),
            ]),
          ),
      ],
    ]);
  }
}
