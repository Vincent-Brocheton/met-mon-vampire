import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../morality/derangement_rules.dart' show derangementOfItem, derangementSummary;
import '../offline/offline.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import '../rules/creation_rules.dart' show Check, CheckLevel;
import 'xp_repository.dart';
import 'xp_request.dart';
import 'xp_rules.dart';
import 'xp_widgets.dart';

/// Ligne de contrôle (icône et couleur selon le niveau).
class CheckLine extends StatelessWidget {
  const CheckLine(this.k, {super.key});
  final Check k;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            switch (k.level) {
              CheckLevel.ok => Icons.check_circle_outline,
              CheckLevel.warn => Icons.info_outline,
              _ => Icons.error_outline,
            },
            size: 18,
            color: switch (k.level) {
              CheckLevel.ok => AppColors.success,
              CheckLevel.warn => AppColors.goldLight,
              _ => AppColors.linkHover,
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(k.text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

/// Détail d'une dépense d'XP dans « Demandes » (C-Validation) : solde, contrôles, décision.
class RequestReview extends ConsumerStatefulWidget {
  const RequestReview(this.r, {super.key, required this.onDecided});
  final XpRequest r;
  final VoidCallback onDecided;

  @override
  ConsumerState<RequestReview> createState() => _RequestReviewState();
}

class _RequestReviewState extends ConsumerState<RequestReview> {
  final _comment = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide(Character c, RequestStatus to, Rulebook rb) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    if (to != RequestStatus.accepted && _comment.text.trim().isEmpty) {
      setState(() => _error = 'Expliquez ce qu’il faut compléter.');
      return;
    }
    if (to == RequestStatus.rejected) {
      final ok = await confirm(context, title: 'Refuser la demande', body: 'L’XP réservée sera libérée.', action: 'Refuser');
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(xpRepositoryProvider).decide(widget.r, c, to, _comment.text, by, rb: rb);
      _comment.clear();
      messenger.showSnackBar(SnackBar(content: Text(switch (to) {
        RequestStatus.accepted => 'Dépense validée : ${widget.r.characterName}.',
        RequestStatus.changes => 'Compléments demandés à ${widget.r.playerName}.',
        _ => 'Demande refusée.',
      })));
      widget.onDecided();
    } catch (e) {
      if (mounted) setState(() => _error = refusalText(e, 'Décision impossible : la demande ou la fiche a changé. Réessayez.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.r;
    final me = ref.watch(currentUserProvider).value;
    final canDecide = me?.role.managesAccounts ?? false;
    return asyncView(ref.watch(characterProvider(r.characterId)), (c) {
      if (c == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Fiche introuvable', message: 'Elle a pu être retirée.');
      }
      return asyncView(ref.watch(characterRequestsProvider(r.characterId)), (all) {
        final rb = ref.watch(rulebookProvider);
        if (rb == null) return const Center(child: CircularProgressIndicator());
        final reservedOthers = reservedBy(all, c.id, exceptId: r.id);
        final checks = requestChecks(c, r, reservedOthers: reservedOthers, rb: rb);
        final blocked = checks.any((k) => k.level == CheckLevel.error);
        final total = recomputedTotal(c, r.items, rb: rb);
        final after = c.xpAvailable - reservedOthers - total;
        // Pendant le gel, une dépense ne se valide pas (règle staffEdit) ; une demande à 0 XP, si.
        final frozen = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], c.id, DateTime.now());
        final xpLocked = frozen != null && total > 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const XpTypePill(),
            Text('Envoyée le ${formatDay(r.submittedAt)} par ${r.playerName}', style: t.bodySmall),
          ]),
          const SizedBox(height: 6),
          Text(r.characterName, style: isWide(context) ? t.displaySmall : t.headlineMedium),
          Text(identityLine(c), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Text(
            'Disponible ${c.xpAvailable} · Réservé par d’autres demandes $reservedOthers · Cette demande $total · Après validation $after',
            style: t.titleSmall?.copyWith(color: after < 0 ? AppColors.linkHover : AppColors.text),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Achats'),
              const SizedBox(height: 10),
              for (final i in r.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(width: 260, child: Text(i.note == null ? i.label : '${i.label} (${i.note})', style: t.bodyMedium)),
                    SizedBox(
                      width: 110,
                      child: Text('${levelText(i.kind, i.fromLevel)} → ${levelText(i.kind, i.toLevel)}', style: const TextStyle(color: AppColors.gold)),
                    ),
                    SizedBox(width: 60, child: Text('${costOf(c, i, rb: rb)} XP', textAlign: TextAlign.right, style: t.titleSmall)),
                    Text(ruleText(c, i, rb: rb), style: t.bodySmall),
                    if (i.derangement != null) Text(derangementSummary(derangementOfItem(i)), style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Contrôles automatiques'),
              const SizedBox(height: 10),
              for (final k in checks) CheckLine(k),
            ]),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Justification et échanges'),
              const SizedBox(height: 10),
              Text(r.justification.isEmpty ? '—' : r.justification, style: t.bodyMedium),
              for (final m in r.thread) ...[
                const SizedBox(height: 10),
                Text('${m.byName} · ${formatDay(m.at)}', style: t.bodySmall),
                Text(m.text, style: t.bodyMedium),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          if (r.playerUid == me?.uid)
            Text('C’est votre propre fiche : un autre conteur doit la valider.', style: t.bodyMedium?.copyWith(color: AppColors.goldLight))
          else if (!canDecide)
            Text('Lecture seule : les conteurs décident.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted))
          else
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  key: const Key('decision-comment'),
                  controller: _comment,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Commentaire au joueur'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
                ],
                const SizedBox(height: 12),
                if (xpLocked) ...[
                  Text(frozenUntilText(frozen), style: t.bodyMedium?.copyWith(color: AppColors.frozen)),
                  const SizedBox(height: 8),
                ],
                Wrap(spacing: 12, runSpacing: 12, children: [
                  FilledButton(
                    onPressed: blocked || xpLocked || _busy ? null : () => _decide(c, RequestStatus.accepted, rb),
                    child: const Text('Valider la dépense'),
                  ),
                  OutlinedButton(onPressed: _busy ? null : () => _decide(c, RequestStatus.changes, rb), child: const Text('Demander des compléments')),
                  TextButton(onPressed: _busy ? null : () => _decide(c, RequestStatus.rejected, rb), child: const Text('Refuser')),
                ]),
              ]),
            ),
        ]);
      }, onRetry: () => ref.invalidate(characterRequestsProvider(r.characterId)));
    }, onRetry: () => ref.invalidate(characterProvider(r.characterId)));
  }
}
