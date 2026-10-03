import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'xp_repository.dart';
import 'xp_request.dart';
import 'xp_widgets.dart';

typedef _Row = ({String key, DateTime? date, XpRequest? r, Character? c});

/// Ouverte (brouillon compris) côté joueur.
bool _ongoing(_Row row) => row.r != null
    ? row.r!.status == RequestStatus.draft || row.r!.status.open
    : row.c!.status != CharacterStatus.rejected;

void _noop() {}

/// « Mes demandes » (J-Demandes) : dépenses d'XP et créations, détail et échange avec le conte.
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key, this.selectedId});
  final String? selectedId;

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  int _tab = 0;
  late String? _selected = widget.selectedId;
  final _replyText = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _replyText.dispose();
    super.dispose();
  }

  Future<void> _reply(XpRequest r) async {
    final text = _replyText.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Écrivez votre réponse.');
      return;
    }
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(xpRepositoryProvider).reply(r, text, by);
      _replyText.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Envoi impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(XpRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text('L’XP réservée sera libérée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Garder')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Annuler la demande')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(xpRepositoryProvider).cancel(r);
    } catch (_) {
      if (mounted) setState(() => _error = 'Annulation impossible : la demande a peut-être été traitée.');
    }
  }

  @override
  Widget build(BuildContext context) => asyncView(
        ref.watch(myCharactersProvider),
        (chars) => asyncView(
          ref.watch(myRequestsProvider),
          (requests) => _body(context, chars, requests),
          onRetry: () => ref.invalidate(myRequestsProvider),
        ),
        onRetry: () => ref.invalidate(myCharactersProvider),
      );

  Widget _body(BuildContext context, List<Character> chars, List<XpRequest> requests) {
    final t = Theme.of(context).textTheme;
    final rows = <_Row>[
      for (final r in requests) (key: r.id, date: r.date, r: r, c: null),
      for (final c in chars)
        if (c.status == CharacterStatus.draft || c.status == CharacterStatus.review || c.status == CharacterStatus.rejected)
          (key: 'c-${c.id}', date: c.submittedAt ?? c.createdAt, r: null, c: c),
    ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    final ongoing = rows.where(_ongoing).length;
    final shown = switch (_tab) {
      1 => rows.where(_ongoing).toList(),
      2 => rows.where((x) => !_ongoing(x)).toList(),
      _ => rows,
    };
    final selected = shown.where((x) => x.key == _selected).firstOrNull ?? shown.firstOrNull;

    final actives = [for (final c in chars) if (c.status == CharacterStatus.active && c.kind == CharacterKind.pj) c];
    final Widget spend = switch (actives.length) {
      0 => const Tooltip(message: 'Aucun personnage actif', child: FilledButton(onPressed: null, child: Text('Dépenser de l’XP'))),
      1 => FilledButton(
          onPressed: () => context.go('/joueur/personnages/${actives.first.id}/xp'),
          child: const Text('Dépenser de l’XP'),
        ),
      _ => PopupMenuButton<String>(
          tooltip: 'Choisir le personnage',
          onSelected: (id) => context.go('/joueur/personnages/$id/xp'),
          itemBuilder: (_) => [for (final c in actives) PopupMenuItem(value: c.id, child: Text(c.name))],
          child: const IgnorePointer(child: FilledButton(onPressed: _noop, child: Text('Dépenser de l’XP ▾'))),
        ),
    };

    Widget tab(int i, String label) => TextButton(
          onPressed: () => setState(() => _tab = i),
          style: TextButton.styleFrom(
            foregroundColor: _tab == i ? AppColors.text : AppColors.textSecondary,
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(label, style: TextStyle(fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500)),
        );

    final table = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Wrap(children: [
            tab(0, 'Toutes · ${rows.length}'),
            tab(1, 'En cours · $ongoing'),
            tab(2, 'Traitées · ${rows.length - ongoing}'),
          ]),
        ),
        if (shown.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text('Aucune demande pour l’instant.', style: t.bodyMedium)),
        for (final x in shown)
          InkWell(
            onTap: () => setState(() {
              _selected = x.key;
              _error = null;
              _replyText.clear();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: x.key == selected?.key ? AppColors.navActive : null,
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                x.r != null ? const XpTypePill() : const Pill('Création', bg: Color(0xFF2A2240), fg: AppColors.narrator),
                SizedBox(width: 280, child: Text(x.r?.summary ?? 'Création de la fiche', style: t.titleSmall)),
                SizedBox(width: 160, child: Text(x.r?.characterName ?? x.c!.name, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
                SizedBox(width: 70, child: Text(formatDay(x.date), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
                x.r != null ? RequestStatusChip(x.r!.status) : StatusChip(x.c!.status),
              ]),
            ),
          ),
      ]),
    );

    final detail = selected == null
        ? null
        : selected.r != null
            ? _requestDetail(context, selected.r!)
            : _creationDetail(context, selected.c!);
    final header = PageTitle(
      'Mes demandes',
      subtitle: 'Toutes les évolutions de vos fiches passent par ici avant d’être validées par le conte.',
      action: spend,
    );
    if (!isWide(context)) {
      return PageBody(children: [header, const SizedBox(height: 22), table, if (detail != null) ...[const SizedBox(height: 20), detail]]);
    }
    return PageBody(children: [
      header,
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: table),
        if (detail != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: detail)],
      ]),
    ]);
  }

  Widget _creationDetail(BuildContext context, Character c) {
    final t = Theme.of(context).textTheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, children: [const Pill('Création', bg: Color(0xFF2A2240), fg: AppColors.narrator), StatusChip(c.status)]),
        const SizedBox(height: 10),
        Text(c.name, style: t.headlineSmall),
        if ((c.comment ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Le conte : « ${c.comment} »', style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: () => context.go('/joueur/personnages/${c.id}'), child: const Text('Ouvrir la fiche')),
        ),
      ]),
    );
  }

  Widget _requestDetail(BuildContext context, XpRequest r) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value;
    Widget message(String who, String text, {bool conte = false}) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: conte ? const Color(0xFF2A1A1D) : null, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(who, style: t.bodySmall?.copyWith(color: conte ? AppColors.linkHover : AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(text, style: t.bodyMedium),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, children: [const XpTypePill(), RequestStatusChip(r.status)]),
        const SizedBox(height: 10),
        Text(r.summary, style: t.headlineSmall),
        Text(
          '${r.characterName} · ${r.submittedAt == null ? 'brouillon' : 'envoyée le ${formatDay(r.submittedAt)}'}',
          style: t.bodySmall,
        ),
        const Divider(height: 24),
        for (final i in r.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text(i.label, style: t.bodyMedium)),
              Text('${levelText(i.kind, i.fromLevel)} → ${levelText(i.kind, i.toLevel)}', style: const TextStyle(color: AppColors.gold)),
              const SizedBox(width: 12),
              SizedBox(width: 50, child: Text('${i.cost} XP', textAlign: TextAlign.right, style: t.bodyMedium)),
            ]),
          ),
        Row(children: [
          Expanded(child: Text('Total', style: t.titleSmall)),
          Text('${r.total} XP', style: t.titleMedium?.copyWith(color: AppColors.gold)),
        ]),
        if (r.justification.isNotEmpty) message('Vous · ${formatDay(r.submittedAt ?? r.createdAt)}', r.justification),
        for (final m in r.thread)
          message(
            m.byUid == me?.uid ? 'Vous · ${formatDay(m.at)}' : '${m.byName} · ${formatDay(m.at)}',
            m.text,
            conte: m.byUid != me?.uid,
          ),
        const SizedBox(height: 14),
        if (r.status == RequestStatus.changes) ...[
          TextField(key: const Key('reply'), controller: _replyText, maxLines: 4, decoration: const InputDecoration(labelText: 'Votre réponse')),
          const SizedBox(height: 10),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
          const SizedBox(height: 10),
        ],
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (r.status == RequestStatus.changes)
            FilledButton(onPressed: _busy ? null : () => _reply(r), child: const Text('Renvoyer au conte')),
          if (r.status.editable)
            OutlinedButton(
              onPressed: () => context.go('/joueur/personnages/${r.characterId}/xp?demande=${r.id}'),
              child: const Text('Modifier'),
            ),
          if (r.status.editable) TextButton(onPressed: () => _cancel(r), child: const Text('Annuler la demande')),
        ]),
        if (r.status.open) ...[
          const SizedBox(height: 10),
          Text('Les ${r.total} XP restent réservés tant que la demande est ouverte.', style: t.bodySmall),
        ],
      ]),
    );
  }
}
