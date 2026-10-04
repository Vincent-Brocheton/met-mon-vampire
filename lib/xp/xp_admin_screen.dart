import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/edit_widgets.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'xp_gain.dart';
import 'xp_repository.dart';
import 'xp_settings.dart';

String _sheets(int n) => n == 1 ? '1 fiche' : '$n fiches';

/// « XP » (C-XP) : gain mensuel préparé puis versé, bonus ponctuels sur une sélection.
class XpAdminScreen extends ConsumerStatefulWidget {
  const XpAdminScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<XpAdminScreen> createState() => _XpAdminScreenState();
}

class _XpAdminScreenState extends ConsumerState<XpAdminScreen> {
  bool _detail = false;
  bool _busy = false;
  final _reason = TextEditingController();
  final _search = TextEditingController();
  int _amount = 1;

  /// Fiches sélectionnées pour le bonus → montant.
  final Map<String, int> _selected = {};

  @override
  void dispose() {
    _reason.dispose();
    _search.dispose();
    super.dispose();
  }


  void _report(ScaffoldMessengerState messenger, String done, List<String> refused) => messenger.showSnackBar(SnackBar(
        content: Text(refused.isEmpty ? done : '$done Refusé pour : ${refused.join(', ')} (modifiées entre-temps, réessayez).'),
      ));

  Future<void> _pay(List<GainDue> dues, int total) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    if (!await confirm(context, title: 'Verser le gain mensuel', body: '$total XP sur ${_sheets(dues.length)}. Chaque versement apparaît dans l’historique de la fiche.', action: 'Verser')) {
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final refused = await ref.read(xpRepositoryProvider).payGain(dues, by);
      _report(messenger, 'Gain versé.', refused);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _award(List<Character> chosen) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final total = chosen.fold<int>(0, (s, c) => s + _selected[c.id]!);
    if (!await confirm(context, title: 'Attribuer le bonus', body: '$total XP sur ${_sheets(chosen.length)}, motif « ${_reason.text.trim()} ».', action: 'Attribuer')) {
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final refused = await ref.read(xpRepositoryProvider).award([for (final c in chosen) (c, _selected[c.id]!)], _reason.text, by);
      _report(messenger, 'Bonus attribué.', refused);
      if (mounted) {
        // Les fiches refusées restent sélectionnées, avec le motif, pour réessayer.
        setState(() {
          _selected.removeWhere((id, _) => !refused.contains(chosen.firstWhere((c) => c.id == id).name));
          if (refused.isEmpty) _reason.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.managesAccounts) {
      return const EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Réservé aux conteurs',
        message: 'Le gain mensuel, les bonus et les corrections sont l’affaire des conteurs.',
      );
    }
    return asyncView(
      ref.watch(allCharactersProvider),
      (chars) => asyncView(
        ref.watch(xpSettingsProvider),
        (settings) => _body(context, me, chars, settings),
        onRetry: () => ref.invalidate(xpSettingsProvider),
      ),
      onRetry: () => ref.invalidate(allCharactersProvider),
    );
  }

  Widget _body(BuildContext context, AppUser me, List<Character> chars, XpSettings settings) {
    final t = Theme.of(context).textTheme;
    final current = monthKey(widget.now());
    final dues = monthlyGain(chars, settings, widget.now());
    final payable = [for (final d in dues) if (d.c.playerUid != me.uid) d];
    final mine = [for (final d in dues) if (d.c.playerUid == me.uid) d.c.name];
    final total = payable.fold<int>(0, (s, d) => s + d.xp);

    final gainCard = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Gain mensuel'),
        const SizedBox(height: 10),
        if (!settings.monthlyEnabled)
          Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Gain mensuel désactivé', style: t.titleMedium),
            TextButton(onPressed: () => context.go('/conteur/parametres/xp'), child: const Text('Régler le gain mensuel')),
          ])
        else if (payable.isEmpty)
          Text('À jour pour ${monthLabel(current)}.', style: t.titleMedium)
        else ...[
          Text('${monthLabel(current)} : ${_sheets(payable.length)}, $total XP à verser', style: t.titleMedium),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _detail = !_detail),
              child: Text(_detail ? 'Masquer le détail' : 'Voir le détail'),
            ),
          ),
          if (_detail)
            for (final d in payable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Wrap(spacing: 16, children: [
                  SizedBox(width: 200, child: Text(d.c.name, style: t.bodyMedium)),
                  SizedBox(width: 140, child: Text(d.c.playerName ?? '—', style: t.bodySmall)),
                  SizedBox(width: 220, child: Text('${d.months.length} mois (${monthRange(d.months)})', style: t.bodySmall)),
                  SizedBox(width: 80, child: Text('Palier ${d.tier + 1}', style: t.bodySmall)),
                  Text('${d.xp} XP', style: t.titleSmall),
                ]),
              ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: _busy ? null : () => _pay(payable, total), child: Text('Verser $total XP')),
          ),
        ],
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('À verser par un autre conteur : ${mine.join(', ')}', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        ],
      ]),
    );

    final actives = [for (final c in chars) if (c.kind == CharacterKind.pj && c.status == CharacterStatus.active) c];
    final selectable = [for (final c in actives) if (c.playerUid != me.uid) c];
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final c in actives)
        if (query.isEmpty || c.name.toLowerCase().contains(query) || (c.playerName ?? '').toLowerCase().contains(query)) c,
    ];
    final chosen = [for (final c in selectable) if (_selected.containsKey(c.id)) c];
    final awardTotal = chosen.fold<int>(0, (s, c) => s + _selected[c.id]!);
    final adjusted = chosen.where((c) => _selected[c.id] != _amount).length;
    final reason = _reason.text.trim();
    final allSelected = selectable.isNotEmpty && chosen.length == selectable.length;

    final bonus = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Attribuer un bonus d’XP'),
        const SizedBox(height: 6),
        Text('Bonus ponctuels, en plus du gain mensuel. Le motif apparaît dans l’historique de chaque fiche.', style: t.bodySmall),
        const SizedBox(height: 14),
        Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 380,
            child: TextField(
              key: const Key('award-reason'),
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Motif', hintText: 'Bonus — scène de la Cour du 17 octobre'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 280,
            child: PointsField(
              label: 'XP par fiche',
              value: _amount,
              max: 100,
              asDots: false,
              onChanged: (v) => setState(() => _amount = max(1, v)),
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              for (final id in _selected.keys) {
                _selected[id] = _amount;
              }
            }),
            child: const Text('Appliquer à la sélection'),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          decoration: const InputDecoration(labelText: 'Rechercher un personnage ou un joueur', prefixIcon: Icon(Icons.search)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Checkbox(
            key: const Key('award-all'),
            value: allSelected,
            onChanged: (on) => setState(() {
              _selected.clear();
              if (on == true) {
                for (final c in selectable) {
                  _selected[c.id] = _amount;
                }
              }
            }),
          ),
          Text('Tout sélectionner · PJ actifs (${actives.length})', style: t.bodyMedium),
        ]),
        for (final c in shown)
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Tooltip(
                message: c.playerUid == me.uid ? 'Votre propre fiche' : '',
                child: Checkbox(
                  key: Key('award-${c.id}'),
                  value: _selected.containsKey(c.id),
                  onChanged: c.playerUid == me.uid
                      ? null
                      : (on) => setState(() => on == true ? _selected[c.id] = _amount : _selected.remove(c.id)),
                ),
              ),
              SizedBox(width: 200, child: Text(c.name, style: t.bodyMedium?.copyWith(color: c.playerUid == me.uid ? AppColors.textMuted : null))),
              SizedBox(width: 140, child: Text(c.playerName ?? '—', style: t.bodySmall)),
              SizedBox(width: 90, child: Text('${c.xpAvailable} XP', style: t.bodySmall)),
              if (_selected.containsKey(c.id)) ...[
                IconButton(
                  tooltip: 'Moins : ${c.name}',
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => setState(() => _selected[c.id] = max(1, _selected[c.id]! - 1)),
                ),
                Text('+ ${_selected[c.id]}', style: t.titleSmall?.copyWith(color: AppColors.gold)),
                IconButton(
                  tooltip: 'Plus : ${c.name}',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => setState(() => _selected[c.id] = min(100, _selected[c.id]! + 1)),
                ),
                Text('→ ${c.xpAvailable + _selected[c.id]!} XP', style: t.bodySmall),
              ],
            ]),
          ),
        const SizedBox(height: 14),
        Text(
          'Fiches sélectionnées ${chosen.length} · dont montant ajusté $adjusted · XP distribuée $awardTotal',
          style: t.bodyMedium,
        ),
        if (reason.isNotEmpty) Text('Motif : « $reason »', style: t.bodySmall),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: reason.isEmpty || chosen.isEmpty || _busy ? null : () => _award(chosen),
            child: Text('Attribuer à ${_sheets(chosen.length)}'),
          ),
        ),
      ]),
    );

    return PageBody(children: [
      PageTitle(
        'Expérience',
        action: TextButton(
          onPressed: () => context.go('/conteur/xp/corrections'),
          child: const Text('Corrections et remboursements'),
        ),
      ),
      const SizedBox(height: 22),
      gainCard,
      const SizedBox(height: 20),
      bonus,
    ]);
  }
}
