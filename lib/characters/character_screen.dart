import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../allies/character_allies_screen.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/freeze_banner.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../items/character_items_screen.dart';
import '../places/character_places_screen.dart';
import '../rulebook/rulebook_provider.dart';
import '../servants/servants_section.dart';
import '../titles/title_rules.dart' show playerView;
import 'character.dart';
import 'character_repository.dart';
import 'sheet_widgets.dart';

/// J2 (fiche) et J6 (historique), côté joueur ; historique complet côté conteur.
class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key, required this.id, required this.basePath, this.history = false});

  final String id;
  final String basePath;
  final bool history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(characterProvider(id));
    // Riverpod 3 relance un provider en erreur : on lit l'erreur même pendant la relance.
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    return asyncView(value, (c) {
      if (c == null) {
        return const EmptyState(
          kind: EmptyKind.notFound,
          title: 'Cette fiche n’existe pas',
          message: 'Elle a pu être retirée.',
        );
      }
      // Fiche du joueur pendant un gel (J-Fiche) ; l'historique n'en a pas besoin.
      final frozen = basePath.startsWith('/joueur') && !history
          ? frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], c.id, DateTime.now())
          : null;
      return PageBody(children: [
        CharacterHeader(c, basePath: basePath, tab: history ? CharacterTab.history : CharacterTab.sheet),
        const SizedBox(height: 22),
        if (frozen != null) ...[
          FreezeBanner(
            playerFreezeText(frozen),
            action: TextButton(onPressed: () => context.go('$basePath/imprimer'), child: const Text('Imprimer')),
          ),
          const SizedBox(height: 22),
        ],
        if (!history && basePath.startsWith('/joueur') && c.kind == CharacterKind.pj && c.status == CharacterStatus.active) ...[
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton(onPressed: () => context.go('$basePath/xp'), child: const Text('Dépenser de l’XP')),
            OutlinedButton.icon(
              onPressed: () => context.go('$basePath/imprimer'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Imprimer'),
            ),
          ]),
          const SizedBox(height: 22),
        ],
        if (history) HistoryView(id: id, c: c) else ...[
          CharacterSheetView(basePath.startsWith('/joueur') ? playerView(c, ref.watch(rulebookProvider)) : c),
          const SizedBox(height: 20),
          PlacesSection(characterId: id, link: basePath.startsWith('/joueur') ? '$basePath/lieux' : '/conteur/lieux'),
          const SizedBox(height: 20),
          ItemsSection(characterId: id, link: basePath.startsWith('/joueur') ? '$basePath/equipement' : '/conteur/objets'),
          const SizedBox(height: 20),
          AlliesSection(character: c, link: basePath.startsWith('/joueur') ? '$basePath/allies' : '/conteur/allies'),
          const SizedBox(height: 20),
          ServantsSection(
            character: c,
            linkOf: (sid) => basePath.startsWith('/joueur') ? '$basePath/serviteurs/$sid' : '/conteur/goules',
          ),
        ],
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(id)));
  }
}

/// Onglet ouvert dans l'en-tête de la fiche.
enum CharacterTab { sheet, morality, events, history, story }

class CharacterHeader extends StatelessWidget {
  const CharacterHeader(this.c, {super.key, required this.basePath, this.tab = CharacterTab.sheet});

  final Character c;
  final String basePath;
  final CharacterTab tab;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget item(String label, String? path, bool selected) => InkWell(
          onTap: path == null ? null : () => context.go(path),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: selected ? AppColors.accentIcon : Colors.transparent, width: 2)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: path == null ? AppColors.textMuted : (selected ? AppColors.text : AppColors.textSecondary),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(c.name, style: isWide(context) ? t.displaySmall : t.headlineMedium),
        StatusChip(c.status),
        KindTag(c.kind),
      ]),
      if (identityLine(c).isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(identityLine(c), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 16),
      Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            item('Fiche', basePath, tab == CharacterTab.sheet),
            item('Moralité & liens', '$basePath/moralite', tab == CharacterTab.morality),
            if (basePath.startsWith('/conteur')) item('Événements', '$basePath/evenements', tab == CharacterTab.events),
            item('Historique', '$basePath/historique', tab == CharacterTab.history),
            item('Récit', '$basePath/recit', tab == CharacterTab.story),
          ]),
        ),
      ),
    ]);
  }
}

enum HistoryFilter {
  all('Tout'),
  xp('XP'),
  edits('Modifications'),
  status('Statut');

  const HistoryFilter(this.label);
  final String label;

  bool matches(HistoryEntry e) => switch (this) {
        HistoryFilter.all => true,
        HistoryFilter.xp => e.touchesXp,
        HistoryFilter.edits => e.kind == 'edit' || e.kind == 'creation',
        HistoryFilter.status => !{'edit', 'creation', 'bonus', 'xp', 'award', 'gain', 'correction'}.contains(e.kind),
      };
}

String xpText(HistoryEntry e) {
  if (!e.touchesXp) return '—';
  return [
    if (e.xpInitial != 0) '${e.xpInitial > 0 ? '+' : '−'} ${e.xpInitial.abs()} initiale',
    if (e.xpEarned != 0) '${e.xpEarned > 0 ? '+' : '−'} ${e.xpEarned.abs()}',
    if (e.xpSpent != 0) '${e.xpSpent > 0 ? '−' : '+'} ${e.xpSpent.abs()}',
  ].join(' · ');
}

/// J6 : historique filtrable et bilan d'expérience.
class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key, required this.id, required this.c});
  final String id;
  final Character c;

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = widget.c;
    final list = asyncView(ref.watch(characterHistoryProvider(widget.id)), (entries) {
      final shown = entries.where(_filter.matches).toList();
      return Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in HistoryFilter.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: AppColors.navActive,
                ),
            ]),
          ),
          if (shown.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('Aucune entrée.', style: t.bodySmall)),
          for (final e in shown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 80, child: Text(formatDay(e.at), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final line in e.summary) Text(line, style: t.bodyMedium),
                    if (e.reason.isNotEmpty) Text('« ${e.reason} »', style: t.bodySmall),
                    Text(e.byName, style: t.bodySmall),
                  ]),
                ),
                Text(
                  xpText(e),
                  style: t.labelLarge?.copyWith(color: e.xpEarned > 0 ? AppColors.success : AppColors.text),
                ),
              ]),
            ),
        ]),
      );
    }, onRetry: () => ref.invalidate(characterHistoryProvider(widget.id)));

    final summary = Panel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Bilan d’expérience'),
        const SizedBox(height: 10),
        InfoRow('XP initiale', '${c.xpInitial}'),
        InfoRow('XP gagnée', '+ ${c.xpEarned}'),
        InfoRow('Dépensée', '− ${c.xpSpent}'),
        const Divider(height: 20),
        Row(children: [
          Expanded(child: Text('Disponible', style: t.bodyMedium)),
          Text('${c.xpAvailable}', style: t.headlineMedium?.copyWith(color: AppColors.gold)),
        ]),
        const SizedBox(height: 8),
        Text('Chaque ligne indique qui a fait la modification et pourquoi.', style: t.bodySmall),
      ]),
    );

    if (!isWide(context)) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [summary, const SizedBox(height: 20), list]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: list),
      const SizedBox(width: 24),
      SizedBox(width: 320, child: summary),
    ]);
  }
}
