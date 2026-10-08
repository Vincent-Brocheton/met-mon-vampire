import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../characters/character.dart';
import '../characters/describe_changes.dart' show dots;
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook_provider.dart';
import '../titles/title_rules.dart' show playerView;
import 'loan_rules.dart';
import 'npc_loan.dart';
import 'npc_loans_repository.dart';

/// « PNJ confiés » du joueur : ses prêts en cours ; un seul s'ouvre directement.
class MyNpcLoansScreen extends ConsumerWidget {
  const MyNpcLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(myNpcLoansProvider), (loans) {
      final now = DateTime.now();
      final open = [for (final l in loans) if (loanState(l, now) == LoanState.active) l];
      if (open.isEmpty) {
        return const EmptyState(kind: EmptyKind.empty, title: 'Aucun PNJ confié', message: 'Le conte ne vous a confié aucun PNJ en ce moment.');
      }
      if (open.length == 1) return NpcLoanScreen(loanId: open.single.id);
      return PageBody(children: [
        const PageTitle('PNJ confiés'),
        const SizedBox(height: 20),
        for (final l in open)
          Card(
            child: ListTile(
              title: Text(l.characterName, style: t.titleMedium),
              subtitle: Text('Jusqu’au ${formatLoanDay(l.until)} · ${l.mode.label}'),
              onTap: () => context.go('/joueur/pnj/${l.id}'),
            ),
          ),
      ]);
    }, onRetry: () => ref.invalidate(myNpcLoansProvider));
  }
}

/// Un PNJ confié (J-PNJ) : bandeau, consignes, fiche selon le mode, notes d'interprétation.
class NpcLoanScreen extends ConsumerStatefulWidget {
  const NpcLoanScreen({super.key, required this.loanId});
  final String loanId;

  @override
  ConsumerState<NpcLoanScreen> createState() => _NpcLoanScreenState();
}

class _NpcLoanScreenState extends ConsumerState<NpcLoanScreen> {
  final _notes = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  // La fin du prêt est vérifiée à chaque minute : la page se ferme d'elle-même une fois le prêt terminé.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(npcLoansRepositoryProvider).saveNotes(widget.loanId, _notes.text);
      messenger.showSnackBar(const SnackBar(content: Text('Notes enregistrées.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : le prêt est peut-être terminé.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(myNpcLoansProvider), (loans) {
      final l = loans.where((x) => x.id == widget.loanId).firstOrNull;
      final now = DateTime.now();
      if (l == null || loanState(l, now) != LoanState.active) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Prêt terminé', message: 'Ce PNJ ne vous est plus confié.');
      }
      if (!_loaded) {
        _notes.text = l.playerNotes;
        _loaded = true;
      }
      final left = daysLeft(l, now);
      return PageBody(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.navActive, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
              child: Text(
                'PNJ confié par ${l.updatedByName ?? 'le conte'} — lecture seule, accès jusqu’au ${formatLoanDay(l.until)} 23h59. '
                'Les notes privées du conte ne sont pas visibles.',
                style: t.bodyMedium?.copyWith(color: AppColors.goldLight),
              ),
            ),
            const SizedBox(width: 12),
            Text(left == 0 ? 'Dernier jour' : 'Encore $left jour${left > 1 ? 's' : ''}', style: t.bodySmall),
          ]),
        ),
        const SizedBox(height: 20),
        PageTitle(l.characterName, subtitle: l.mode.label),
        const SizedBox(height: 20),
        if (l.personality.isNotEmpty || l.goals.isNotEmpty || l.limits.isNotEmpty) ...[
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Consignes du conte'),
              const SizedBox(height: 10),
              for (final (label, text) in [('Personnalité', l.personality), ('Objectifs', l.goals), ('Limites', l.limits)])
                if (text.isNotEmpty) ...[
                  Text(label, style: t.bodySmall),
                  Text(text, style: t.bodyMedium),
                  const SizedBox(height: 8),
                ],
            ]),
          ),
          const SizedBox(height: 20),
        ],
        asyncView(ref.watch(npcLoanSheetProvider(l.id)), (sheet) {
          if (sheet == null) return Text('La fiche n’est pas encore disponible.', style: t.bodySmall);
          final c = Character.fromMap(l.characterId, sheet);
          final seen = playerView(c, ref.watch(rulebookProvider));
          return l.mode == LoanMode.full ? CharacterSheetView(seen) : _Summary(seen);
        }, onRetry: () => ref.invalidate(npcLoanSheetProvider(l.id))),
        if (l.allowNotes) ...[
          const SizedBox(height: 20),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Mes notes d’interprétation'),
              if (l.notesAt != null) Text('Partagées avec le conte · enregistré le ${formatLoanDay(l.notesAt)}', style: t.bodySmall),
              const SizedBox(height: 10),
              TextField(
                key: const Key('loan-player-notes'),
                controller: _notes,
                maxLines: 4,
                maxLength: 5000,
                decoration: const InputDecoration(hintText: 'Ce que le PNJ a dit, promis ou appris pendant la partie…'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const Key('loan-notes-save'), onPressed: _busy ? null : _saveNotes, child: const Text('Enregistrer')),
              ),
            ]),
          ),
        ],
      ]);
    }, onRetry: () => ref.invalidate(myNpcLoansProvider));
  }
}

/// Fiche résumée : identité, attributs, Sang et Volonté, compétences principales, disciplines.
class _Summary extends StatelessWidget {
  const _Summary(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(identityLine(c), style: t.bodyMedium),
        const SizedBox(height: 12),
        for (final cat in AttrCategory.values)
          InfoRow(cat.label, '${c.attributes[cat]!.value}${c.attributes[cat]!.focus == null ? '' : ' · ${c.attributes[cat]!.focus}'}'),
        InfoRow('Sang · Volonté', '${c.blood} (${c.bloodPerTurn} par tour) · ${c.willpower}'),
        if ((c.title ?? '').isNotEmpty) InfoRow('Titre', c.title!),
        const SizedBox(height: 12),
        const SectionTitle('Compétences principales'),
        for (final s in c.skills) InfoRow(s.name, dots(s.level)),
        const SizedBox(height: 12),
        const SectionTitle('Disciplines'),
        for (final d in c.disciplines) InfoRow(d.name, dots(d.level)),
      ]),
    );
  }
}

/// Section « Prêts » d'une fiche de PNJ (C3) : joueurs, périodes, notes.
class NpcLoansSection extends ConsumerWidget {
  const NpcLoansSection({super.key, required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(characterNpcLoansProvider(characterId));
    final loans = async.value ?? const <NpcLoan>[];
    final now = DateTime.now();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Prêts'),
        const SizedBox(height: 8),
        if (async.hasError)
          Text('Prêts indisponibles.', style: t.bodySmall)
        else if (!async.hasValue)
          const LinearProgressIndicator()
        else if (loans.isEmpty)
          Text('Jamais confié.', style: t.bodySmall),
        for (final l in loans) ...[
          Text(
            '${l.playerName} · du ${formatLoanDay(l.from)} au ${formatLoanDay(l.until)} · ${switch (loanState(l, now)) {
              LoanState.active => 'en cours',
              LoanState.upcoming => 'à venir',
              LoanState.ended => 'terminé',
              LoanState.revoked => 'révoqué',
            }}',
            style: t.bodyMedium,
          ),
          if (l.playerNotes.isNotEmpty) Text('Notes : ${l.playerNotes}', style: t.bodySmall),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}
