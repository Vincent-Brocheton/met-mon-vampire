import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show CharacterHeader, CharacterTab;
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show formatLoanDay;
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'morality_rules.dart';
import 'morality_staff.dart';
import 'sin.dart';
import 'sins_repository.dart';

/// Onglet « Moralité & liens » : vue du conte (C-Moralite) pour l'équipe sur la fiche d'un autre,
/// vue du joueur (J-Moralite) sinon.
class CharacterMoralityScreen extends ConsumerWidget {
  const CharacterMoralityScreen({super.key, required this.characterId, required this.basePath});

  final String characterId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final rb = ref.watch(rulebookProvider);
    final value = ref.watch(characterProvider(characterId));
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    if (rb == null) return const Center(child: CircularProgressIndicator());
    return asyncView(value, (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      final staffView = me != null && me.role.isStaff && c.playerUid != me.uid;
      final canEdit = staffView && me.role.managesAccounts;
      return asyncView(
        ref.watch(characterSinsProvider(c.id)),
        (sins) => PageBody(children: [
          CharacterHeader(c, basePath: basePath, tab: CharacterTab.morality),
          const SizedBox(height: 22),
          if (staffView) StaffMorality(character: c, sins: sins, rb: rb, canEdit: canEdit) else playerMorality(context, c, sins, rb, basePath),
        ]),
        onRetry: () => ref.invalidate(characterSinsProvider(c.id)),
      );
    }, onRetry: () => ref.invalidate(characterProvider(characterId)));
  }
}

/// Vue du joueur (J-Moralite) : carte Moralité et tableau des péchés, en lecture.
Widget playerMorality(BuildContext context, Character c, List<Sin> sins, Rulebook rb, String basePath) {
  final t = Theme.of(context).textTheme;
  final max = moralityMax(c, rb);
  final canBuy = basePath.startsWith('/joueur') && c.status == CharacterStatus.active && c.humanity < max;
  final card = Panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Moralité'),
          const SizedBox(height: 4),
          Text('${moralityName(c)} ${c.humanity} · ${moralityLabel(c.humanity)}', style: t.headlineSmall),
        ]),
        if (canBuy)
          OutlinedButton(key: const Key('mo-buy'), onPressed: () => context.go('$basePath/xp'), child: const Text('Acheter un point · 10 XP')),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var n = 1; n <= max; n++)
          Container(
            key: Key('mo-scale-$n'),
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: n == c.humanity ? AppColors.deadBg : null,
              border: Border.all(color: n == c.humanity ? AppColors.accent : AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n', style: t.titleMedium?.copyWith(color: n <= c.humanity ? AppColors.text : AppColors.textMuted)),
              Text(moralityLabel(n), style: t.bodySmall?.copyWith(color: n <= c.humanity ? AppColors.text : AppColors.textMuted)),
            ]),
          ),
      ]),
      const SizedBox(height: 12),
      Text(
        'Chaque péché donne des traits de Bête égaux à son niveau. À 5 traits dans une même soirée, vous perdez un point. '
        'Les traits s’effacent après une journée de sommeil.',
        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    ]),
  );
  final table = Panel(
    padding: EdgeInsets.zero,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
        child: Row(children: [
          const Expanded(child: SectionTitle('Péchés et traits de Bête')),
          Text('Saisis par le conte', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
      ),
      if (sins.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 18), child: Text('Aucun péché.', style: t.bodyMedium)),
      for (final s in sins)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 90, child: Text(formatLoanDay(s.date), style: t.bodySmall?.copyWith(color: AppColors.textSecondary))),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text('Niveau ${s.level} · ${s.what}', style: t.bodyMedium),
            ),
            Text(s.remorse.label, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            Text('${sinTraits(s)}', style: t.titleSmall),
          ]),
        ),
    ]),
  );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [card, const SizedBox(height: 20), table]);
}
