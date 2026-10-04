import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook_provider.dart';
import '../rules/creation_rules.dart';
import '../xp/request_review.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';

enum _Filter {
  all('Tous les types'),
  creation('Créations'),
  xp('Dépenses d’XP');

  const _Filter(this.label);
  final String label;
}

typedef _Entry = ({String key, DateTime? date, Character? c, XpRequest? r});

/// « Demandes » (C-Validation) : créations soumises et dépenses d'XP en attente, la plus ancienne d'abord.
class ValidationScreen extends ConsumerStatefulWidget {
  const ValidationScreen({super.key});

  @override
  ConsumerState<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends ConsumerState<ValidationScreen> {
  String? _selectedKey;
  _Filter _filter = _Filter.all;
  final _comment = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide(Character c, CharacterStatus to) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    if (to != CharacterStatus.active && _comment.text.trim().isEmpty) {
      setState(() => _error = 'Expliquez les corrections attendues.');
      return;
    }
    if (to == CharacterStatus.rejected) {
      final ok = await confirm(context, title: 'Refuser la fiche', body: 'La fiche sera archivée en lecture seule.', action: 'Refuser');
      if (!ok) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(characterRepositoryProvider).decide(c, to, _comment.text, by);
      // La fiche quitte la file : le commentaire ne doit pas suivre sur la suivante.
      _comment.clear();
      _selectedKey = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(switch (to) {
          CharacterStatus.active => '${c.name} est validé et actif.',
          CharacterStatus.draft => 'Corrections demandées à ${c.playerName ?? 'son joueur'}.',
          _ => '${c.name} est refusé.',
        })));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Décision impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => asyncView(
        ref.watch(reviewQueueProvider),
        (creations) => asyncView(
          ref.watch(pendingRequestsProvider),
          (requests) => _body(context, creations, requests),
          onRetry: () => ref.invalidate(pendingRequestsProvider),
        ),
        onRetry: () => ref.invalidate(reviewQueueProvider),
      );

  Widget _body(BuildContext context, List<Character> creations, List<XpRequest> requests) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    final all = <_Entry>[
      for (final c in creations) (key: 'c:${c.id}', date: c.submittedAt, c: c, r: null),
      for (final r in requests) (key: 'r:${r.id}', date: r.submittedAt, c: null, r: r),
    ]..sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    if (all.isEmpty) {
      return const EmptyState(
        kind: EmptyKind.empty,
        title: 'Aucune demande en attente',
        message: 'Les créations et les dépenses d’XP envoyées par les joueurs apparaîtront ici.',
      );
    }
    final shown = switch (_filter) {
      _Filter.creation => all.where((e) => e.c != null).toList(),
      _Filter.xp => all.where((e) => e.r != null).toList(),
      _Filter.all => all,
    };
    final selected = shown.where((e) => e.key == _selectedKey).firstOrNull ?? shown.firstOrNull;

    final list = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('En attente · ${all.length}'),
            const SizedBox(height: 10),
            DropdownButtonFormField<_Filter>(
              key: const Key('queue-filter'),
              initialValue: _filter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filtrer par type'),
              items: [for (final f in _Filter.values) DropdownMenuItem(value: f, child: Text(f.label))],
              onChanged: (f) => setState(() => _filter = f ?? _filter),
            ),
          ]),
        ),
        if (shown.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Rien de ce type.', style: t.bodySmall)),
        for (final e in shown)
          InkWell(
            onTap: () => setState(() {
              _selectedKey = e.key;
              _comment.clear();
              _error = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: e.key == selected?.key ? AppColors.navActive : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${e.c != null ? 'Création' : 'Dépense XP'} · ${formatDay(e.date)}',
                  style: t.bodySmall?.copyWith(color: e.c != null ? AppColors.narrator : AppColors.goldLight),
                ),
                Text(e.c?.name ?? e.r!.characterName, style: t.titleMedium),
                Text(e.c != null ? '${e.c!.playerName ?? '—'} · nouvelle fiche' : e.r!.summary, style: t.bodySmall),
              ]),
            ),
          ),
      ]),
    );

    final Widget? detail = selected == null
        ? null
        : selected.r != null
            ? RequestReview(selected.r!, key: ValueKey(selected.key), onDecided: () => setState(() => _selectedKey = null))
            : _creationDetail(context, selected.c!, me);

    return PageBody(children: [
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 300, child: list),
          if (detail != null) ...[const SizedBox(width: 24), Expanded(child: detail)],
        ])
      else ...[list, if (detail != null) ...[const SizedBox(height: 20), detail]],
    ]);
  }

  Widget _creationDetail(BuildContext context, Character selected, AppUser? me) {
    final t = Theme.of(context).textTheme;
    final rb = ref.watch(rulebookProvider);
    if (rb == null) return const Center(child: CircularProgressIndicator());
    final checks = creationChecks(selected, rb: rb);
    final own = selected.playerUid == me?.uid;
    final canDecide = me?.role.managesAccounts ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Création · soumise le ${formatDay(selected.submittedAt)} par ${selected.playerName ?? '—'}', style: t.bodySmall),
      const SizedBox(height: 6),
      Text(selected.name, style: isWide(context) ? t.displaySmall : t.headlineMedium),
      Text(identityLine(selected), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Contrôles automatiques'),
          const SizedBox(height: 10),
          for (final k in checks) CheckLine(k),
        ]),
      ),
      const SizedBox(height: 20),
      CharacterSheetView(selected),
      if ((selected.story ?? '').isNotEmpty) ...[
        const SizedBox(height: 20),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Récit'),
            const SizedBox(height: 8),
            Text(selected.story!, style: t.bodyMedium),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      if (own)
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
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton(onPressed: () => _decide(selected, CharacterStatus.active), child: const Text('Valider et activer la fiche')),
              OutlinedButton(onPressed: () => _decide(selected, CharacterStatus.draft), child: const Text('Demander des corrections')),
              TextButton(onPressed: () => _decide(selected, CharacterStatus.rejected), child: const Text('Refuser')),
            ]),
          ]),
        ),
    ]);
  }
}
