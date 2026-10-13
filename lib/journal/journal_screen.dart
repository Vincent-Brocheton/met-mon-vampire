import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/games_repository.dart';
import 'journal_repository.dart';
import 'journal_rules.dart';

/// Journal de la chronique (C-Journal) : ce que le conte et l'application ont modifié, toutes fiches confondues.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  JournalCat? _cat;
  String? _author;
  var _period = JournalPeriod.days30;

  Future<void> _export(List<JournalLine> lines) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: toCsv(lines)));
    messenger.showSnackBar(SnackBar(content: Text(lines.length == 1 ? 'CSV copié : 1 ligne.' : 'CSV copié : ${lines.length} lignes.')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final now = widget.now();
    final games = ref.watch(gamesProvider).value ?? const [];
    final hasGame = lastGameDay(games, now) != null;
    final period = _period == JournalPeriod.sinceGame && !hasGame ? JournalPeriod.days30 : _period;
    final feed = ref.watch(journalProvider(periodStart(period, now, games)));
    final authors = authorsOf(feed.lines);
    // Un auteur absent de la nouvelle période : retour à « Tous les auteurs ».
    final author = authors.contains(_author) ? _author : null;
    final lines = filterLines(feed.lines, cat: _cat, author: author);
    final wide = isWide(context);
    return PageBody(children: [
      Wrap(children: [
        InkWell(
          onTap: () => context.go('/conteur/parametres'),
          child: Text('Paramètres de la chronique', style: muted?.copyWith(decoration: TextDecoration.underline)),
        ),
        Text(' / Journal', style: muted),
      ]),
      const SizedBox(height: 6),
      PageTitle(
        'Journal de la chronique',
        subtitle: 'Tout ce que les conteurs et l’application ont modifié, toutes fiches confondues.',
        action: OutlinedButton(key: const Key('jn-csv'), onPressed: lines.isEmpty ? null : () => _export(lines), child: const Text('Exporter en CSV')),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in <JournalCat?>[null, ...JournalCat.values])
          ChoiceChip(label: Text(c?.label ?? 'Tout'), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 8, children: [
        DropdownButton<String?>(
          key: const Key('jn-author'),
          value: author,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Tous les auteurs')),
            for (final a in authors) DropdownMenuItem<String?>(value: a, child: Text(a)),
          ],
          onChanged: (v) => setState(() => _author = v),
        ),
        DropdownButton<JournalPeriod>(
          key: const Key('jn-period'),
          value: period,
          items: [
            for (final p in JournalPeriod.values)
              if (p != JournalPeriod.sinceGame || hasGame) DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (v) => setState(() => _period = v ?? _period),
        ),
      ]),
      const SizedBox(height: 16),
      if (feed.partial) ...[
        Text('Une partie du journal n’a pas pu être chargée.', style: t.bodyMedium?.copyWith(color: AppColors.accentIcon)),
        const SizedBox(height: 12),
      ],
      if (lines.isEmpty)
        feed.loading
            ? const Center(child: CircularProgressIndicator())
            : Text('Rien sur cette période.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
      else
        Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wide) const _Header(),
            for (final (i, l) in lines.indexed) wide ? _Row(l, key: Key('jn-$i')) : _Card(l, key: Key('jn-$i')),
          ]),
        ),
      const SizedBox(height: 16),
      Text('Le journal ne peut être ni modifié ni effacé. L’historique d’une seule fiche reste dans son onglet « Historique ».', style: muted),
    ]);
  }
}

/// Largeurs relatives des colonnes : Quand, Qui, Action, Sur, Détail.
const _flex = [2, 2, 2, 3, 5];

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        for (final (i, label) in ['Quand', 'Qui', 'Action', 'Sur', 'Détail'].indexed) Expanded(flex: _flex[i], child: Text(label, style: style)),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.l, {super.key});
  final JournalLine l;

  @override
  Widget build(BuildContext context) {
    final cell = Theme.of(context).textTheme.bodyMedium;
    final link = l.link;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: _flex[0], child: Text(journalStamp(l.at), style: cell?.copyWith(color: AppColors.textSecondary))),
        Expanded(flex: _flex[1], child: Text(l.who, style: cell)),
        Expanded(flex: _flex[2], child: Text(l.action, style: cell?.copyWith(fontWeight: FontWeight.w600))),
        Expanded(
          flex: _flex[3],
          child: link == null
              ? Text(l.target, style: cell)
              : InkWell(onTap: () => context.go(link), child: Text(l.target, style: cell?.copyWith(decoration: TextDecoration.underline))),
        ),
        Expanded(flex: _flex[4], child: Text(l.detail, style: cell?.copyWith(color: AppColors.textSecondary))),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.l, {super.key});
  final JournalLine l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final link = l.link;
    return InkWell(
      onTap: link == null ? null : () => context.go(link),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(l.action, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text(journalStamp(l.at), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 3),
          Text(l.detail.isEmpty ? l.target : '${l.target} · ${l.detail}', style: t.bodyMedium),
          const SizedBox(height: 3),
          Text(l.who, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
