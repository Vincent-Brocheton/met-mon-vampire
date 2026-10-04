import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'loan_rules.dart';
import 'npc_loan.dart';
import 'npc_loans_repository.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// « Confier un PNJ » (C-PNJ) : formulaire et liste des prêts.
class NpcLoansScreen extends ConsumerStatefulWidget {
  const NpcLoansScreen({super.key});

  @override
  ConsumerState<NpcLoansScreen> createState() => _NpcLoansScreenState();
}

class _NpcLoansScreenState extends ConsumerState<NpcLoansScreen> {
  String? _npcId;
  String? _playerUid;
  final _from = TextEditingController(text: _day(DateTime.now()));
  final _until = TextEditingController();
  LoanMode _mode = LoanMode.full;
  bool _allowNotes = true;
  final _personality = TextEditingController();
  final _goals = TextEditingController();
  final _limits = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_from, _until, _personality, _goals, _limits]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _write(NpcLoan before, NpcLoan l, {Map<String, dynamic>? sheet, String done = 'Prêt enregistré.'}) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return false;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(npcLoansRepositoryProvider).save(before, l, by, sheet: sheet);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      return true;
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.code == 'permission-denied' && before.version > 0 ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
      return false;
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create(List<Character> npcs, List<AppUser> players) async {
    final npc = npcs.where((c) => c.id == _npcId).firstOrNull;
    final player = players.where((u) => u.uid == _playerUid).firstOrNull;
    final from = parseDay(_from.text);
    final until = parseDay(_until.text);
    String? error;
    if (npc == null || player == null) {
      error = 'Choisissez le PNJ et le joueur.';
    } else if (from == null || until == null) {
      error = 'Dates attendues au format JJ/MM/AAAA.';
    } else if (until.isBefore(from)) {
      error = 'La fin précède le début';
    }
    setState(() => _error = error);
    if (error != null) return;
    final l = NpcLoan(
      characterId: npc!.id,
      characterName: npc.name,
      playerUid: player!.uid,
      playerName: player.displayName,
      from: startOfDay(from!),
      until: endOfDay(until!),
      mode: _mode,
      allowNotes: _allowNotes,
      personality: _personality.text.trim(),
      goals: _goals.text.trim(),
      limits: _limits.text.trim(),
    );
    final ok = await _write(NpcLoan(from: l.from, until: l.until), l, sheet: sheetCopy(npc, _mode), done: 'PNJ confié à ${player.displayName}.');
    if (ok && mounted) {
      setState(() {
        _npcId = null;
        _playerUid = null;
        _until.clear();
        for (final c in [_personality, _goals, _limits]) {
          c.clear();
        }
      });
    }
  }

  Future<void> _extend(NpcLoan l) async {
    final field = TextEditingController(text: _day(l.until));
    final day = await showDialog<DateTime>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Prolonger le prêt de ${l.characterName}'),
        content: TextField(key: const Key('extend-until'), controller: field, decoration: const InputDecoration(labelText: 'Jusqu’au (JJ/MM/AAAA)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(key: const Key('extend-ok'), onPressed: () => Navigator.pop(d, parseDay(field.text)), child: const Text('Prolonger')),
        ],
      ),
    );
    if (day == null || !mounted) return;
    if (day.isBefore(startOfDay(l.from))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fin précède le début')));
      return;
    }
    await _write(l, l.copy()..until = endOfDay(day), done: 'Prêt prolongé.');
  }

  Future<void> _revoke(NpcLoan l) async {
    if (!await confirm(context, title: 'Révoquer le prêt ?', body: '${l.playerName} ne verra plus la fiche de ${l.characterName}.', action: 'Révoquer')) {
      return;
    }
    await _write(l, l.copy()..revokedAt = DateTime.now(), done: 'Prêt révoqué.');
  }

  Future<void> _refresh(NpcLoan l, Character? npc) async {
    if (npc == null) return;
    await _write(l, l.copy(), sheet: sheetCopy(npc, l.mode), done: 'Copie mise à jour.');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les PNJ sont confiés par le conte.');
    }
    return asyncView(
      ref.watch(allNpcLoansProvider),
      (loans) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, !me.role.managesAccounts, loans, chars, ref.watch(allUsersProvider).value ?? const []),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allNpcLoansProvider),
    );
  }

  Widget _body(BuildContext context, bool readOnly, List<NpcLoan> loans, List<Character> chars, List<AppUser> users) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final npcs = [for (final c in chars) if (c.kind == CharacterKind.pnj && c.status != CharacterStatus.draft) c];
    final players = [for (final u in users) if (u.role != Role.pending && u.role != Role.disabled) u];
    final active = loans.where((l) => loanState(l, now) == LoanState.active).length;
    final playerName = players.where((u) => u.uid == _playerUid).firstOrNull?.displayName;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    final form = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        gap(DropdownButtonFormField<String>(
          key: const Key('loan-npc'),
          initialValue: npcs.any((c) => c.id == _npcId) ? _npcId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'PNJ'),
          items: [for (final c in npcs) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (id) => setState(() => _npcId = id),
        )),
        gap(DropdownButtonFormField<String>(
          key: const Key('loan-player'),
          initialValue: players.any((u) => u.uid == _playerUid) ? _playerUid : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Joueur'),
          items: [for (final u in players) DropdownMenuItem(value: u.uid, child: Text(u.displayName))],
          onChanged: (uid) => setState(() => _playerUid = uid),
        )),
        gap(Row(children: [
          Expanded(child: TextField(key: const Key('loan-from'), controller: _from, decoration: const InputDecoration(labelText: 'Accès à partir du'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(key: const Key('loan-until'), controller: _until, decoration: const InputDecoration(labelText: 'Jusqu’au (inclus)'))),
        ])),
        gap(SegmentedButton<LoanMode>(
          key: const Key('loan-mode'),
          segments: [for (final m in LoanMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        )),
        CheckboxListTile(
          key: const Key('loan-allow-notes'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Autoriser les notes d’interprétation du joueur'),
          value: _allowNotes,
          onChanged: (v) => setState(() => _allowNotes = v == true),
        ),
        for (final (key, label, c) in [
          ('loan-personality', 'Personnalité', _personality),
          ('loan-goals', 'Objectifs', _goals),
          ('loan-limits', 'Limites', _limits),
        ])
          gap(TextField(key: Key(key), controller: c, maxLines: 2, decoration: InputDecoration(labelText: label))),
        if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const Key('loan-save'),
            onPressed: _busy ? null : () => _create(npcs, players),
            child: Text(playerName == null ? 'Confier' : 'Confier à $playerName'),
          ),
        ),
      ]),
    );

    final list = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [const Expanded(child: SectionTitle('PNJ confiés')), Text('$active en cours', style: t.bodySmall)]),
        ),
        if (loans.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: Text('Aucun prêt.', style: t.bodySmall)),
        for (final l in loans) _row(context, readOnly, l, loans, chars, now),
      ]),
    );

    final title = PageTitle('Confier un PNJ',
        subtitle: 'Le joueur voit la fiche en lecture seule pendant la période choisie. Les notes privées du conte ne sont jamais partagées.');
    if (!isWide(context)) {
      return PageBody(children: [title, const SizedBox(height: 20), if (!readOnly) ...[form, const SizedBox(height: 20)], list]);
    }
    return PageBody(children: [
      title,
      const SizedBox(height: 24),
      if (readOnly)
        list
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: form),
          const SizedBox(width: 24),
          SizedBox(width: 520, child: list),
        ]),
    ]);
  }

  Widget _row(BuildContext context, bool readOnly, NpcLoan l, List<NpcLoan> loans, List<Character> chars, DateTime now) {
    final t = Theme.of(context).textTheme;
    final state = loanState(l, now);
    final open = state == LoanState.active || state == LoanState.upcoming;
    final npc = chars.where((c) => c.id == l.characterId).firstOrNull;
    final warnings = open ? loanWarnings(l, loans: loans, npc: npc, now: now) : const <String>[];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.characterName, style: t.titleSmall?.copyWith(color: open ? null : AppColors.textMuted)),
        Text(
          '${l.playerName} · ${state == LoanState.upcoming ? 'à partir du ${formatDay(l.from)}' : 'jusqu’au ${formatDay(l.until)}'} · ${l.mode.label}',
          style: t.bodySmall,
        ),
        if (!open) Text('Terminé${state == LoanState.revoked ? ' (révoqué)' : ''}', style: t.bodySmall),
        if (open && !readOnly)
          Wrap(spacing: 4, children: [
            TextButton(key: Key('loan-extend-${l.id}'), onPressed: _busy ? null : () => _extend(l), child: const Text('Prolonger')),
            TextButton(key: Key('loan-refresh-${l.id}'), onPressed: _busy || npc == null ? null : () => _refresh(l, npc), child: const Text('Mettre à jour la copie')),
            TextButton(key: Key('loan-revoke-${l.id}'), onPressed: _busy ? null : () => _revoke(l), child: const Text('Révoquer')),
          ]),
        for (final w in warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        if (l.personality.isNotEmpty || l.goals.isNotEmpty || l.limits.isNotEmpty)
          Text('Consignes : ${[l.personality, l.goals, l.limits].where((s) => s.isNotEmpty).join(' · ')}', style: t.bodySmall),
        if (l.playerNotes.isNotEmpty) Text('Notes du joueur : ${l.playerNotes}', style: t.bodySmall),
      ]),
    );
  }
}
