import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show parseDay;
import '../npcs/npc_loans_repository.dart';
import '../offline/night.dart';
import '../offline/night_repository.dart';
import '../offline/offline.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'game.dart';
import 'game_rules.dart';
import 'games_repository.dart';

const _during = [
  'Dépenses et gains d’XP bloqués ; les demandes restent en file.',
  'Une nouvelle fiche peut être validée, pour la partie suivante.',
  'Saisies de jeu permises : péchés, événements, liens de sang, titres.',
  'Correction urgente : avec motif, elle met à jour la version figée.',
];

int? _count(FrozenSheet? snap, FrozenSheet? old) => snap == null || old == null ? null : changeCount(old.character, snap.character);

/// Ligne du tableau : la fiche actuelle, sa version figée, celle du gel précédent et ses demandes ouvertes.
class _Row {
  _Row(this.live, this.snap, this.old, this.requests) : changes = _count(snap, old);
  final Character live;
  final FrozenSheet? snap;
  final FrozenSheet? old;
  final List<XpRequest> requests;
  final int? changes;

  String get diffLabel => snap == null ? '—' : changeLabel(changes);

  /// « Modifiées » : changée depuis le gel précédent, ou figée pour la première fois.
  bool get modified => snap != null && (old == null || changes! > 0);
}

/// « Gel des fiches » (C-Figer) : figer les fiches avant une partie, suivre le gel, corriger une version figée.
class FreezeScreen extends ConsumerStatefulWidget {
  const FreezeScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<FreezeScreen> createState() => _FreezeScreenState();
}

class _FreezeScreenState extends ConsumerState<FreezeScreen> {
  final _date = TextEditingController();
  final _untilDay = TextEditingController();
  final _untilTime = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _selectedId;
  bool _onlyChanged = false;

  // La levée prévue est vérifiée chaque minute : passé l'heure, l'écran revient au formulaire.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _date.dispose();
    _untilDay.dispose();
    _untilTime.dispose();
    super.dispose();
  }

  Future<void> _freeze(List<Character> sheets) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final plan = freezePlan(_date.text, _untilDay.text, _untilTime.text, widget.now());
    if (plan.error != null) {
      setState(() => _error = plan.error);
      return;
    }
    final ok = await confirm(
      context,
      title: 'Figer les fiches',
      body: '${freezeCountText(sheets)} Leur XP ne pourra plus changer jusqu’à la levée, ${dayAndHour(plan.until!)}.',
      action: 'Figer',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).freeze(plan.date!, plan.until!, sheets, by);
      if (!mounted) return;
      _date.clear();
      _untilDay.clear();
      _untilTime.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Fiches figées.')));
    } catch (e) {
      if (!mounted) return;
      // Un autre membre du conte a pu figer entre-temps : les règles refusent un second gel.
      final other = runningGame(ref.read(gamesProvider).value ?? const <Game>[], widget.now());
      setState(() => _error = refusalText(e, other != null ? 'Un gel est déjà en cours.' : 'Enregistrement refusé : réessayez.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lift(Game g) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final ok = await confirm(
      context,
      title: 'Lever le gel',
      body: 'L’XP des fiches figées redevient modifiable. Les versions figées sont conservées.',
      action: 'Lever',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(gamesRepositoryProvider).lift(g, by);
      if (mounted) setState(() => _error = null);
      messenger.showSnackBar(const SnackBar(content: Text('Gel levé.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(refusalText(e, 'Enregistrement refusé : réessayez.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _correct(Game g, Character live, FrozenSheet snap) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CorrectionDialog(name: live.name, changes: describeChanges(snap.character, live)),
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(gamesRepositoryProvider).correct(g, live, reason, by);
      messenger.showSnackBar(SnackBar(content: Text('Version figée mise à jour : ${live.name}.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(refusalText(e, 'Enregistrement refusé : réessayez.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Le gel des fiches est l’affaire du conte.');
    }
    return asyncView(
      ref.watch(gamesProvider),
      (games) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _page(context, me, games, chars),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(gamesProvider),
    );
  }

  Widget _page(BuildContext context, AppUser me, List<Game> games, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final running = runningGame(games, widget.now());
    return PageBody(children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(onPressed: () => context.go('/conteur/fiches'), child: const Text('Fiches')),
        Text('/ Gel des fiches', style: t.bodySmall),
      ]),
      PageTitle(
        'Gel des fiches',
        subtitle: 'Une version figée par fiche fait foi pendant la partie. C’est elle qu’on imprimera.',
        action: running == null
            ? null
            : Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton(onPressed: () => context.go('/conteur/gel/hors-ligne'), child: const Text('Partie hors ligne')),
                if (me.role.managesAccounts) OutlinedButton(onPressed: _busy ? null : () => _lift(running), child: const Text('Lever le gel')),
              ]),
      ),
      const SizedBox(height: 22),
      if (running == null) _newFreeze(context, me, chars) else _running(context, me, running, games, chars),
    ]);
  }

  Widget _newFreeze(BuildContext context, AppUser me, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    if (!me.role.managesAccounts) return Panel(child: Text('Aucun gel en cours.', style: t.titleMedium));
    return asyncView(ref.watch(allNpcLoansProvider), (loans) {
      final sheets = sheetsToFreeze(chars, loans, widget.now());
      final date = parseDay(_date.text);
      final until = date == null ? null : untilOf(date, _untilDay.text, _untilTime.text);
      void edited(String _) => setState(() => _error = null);
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Nouveau gel'),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 200,
              child: TextField(
                key: const Key('freeze-date'),
                controller: _date,
                decoration: const InputDecoration(labelText: 'Partie du', hintText: 'JJ/MM/AAAA'),
                onChanged: edited,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                key: const Key('freeze-until-day'),
                controller: _untilDay,
                decoration: InputDecoration(labelText: 'Lever le', hintText: date == null ? 'JJ/MM/AAAA' : slashDay(defaultUntil(date))),
                onChanged: edited,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                key: const Key('freeze-until-time'),
                controller: _untilTime,
                decoration: const InputDecoration(labelText: 'à', hintText: '06:00'),
                onChanged: edited,
              ),
            ),
          ]),
          if (until != null) ...[
            const SizedBox(height: 10),
            Text('Levée prévue : ${dayAndHour(until)}', style: t.bodyMedium),
          ],
          const SizedBox(height: 12),
          Text(freezeCountText(sheets), style: t.titleSmall),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: sheets.isEmpty || _busy ? null : () => _freeze(sheets), child: const Text('Figer maintenant')),
          ),
        ]),
      );
    }, onRetry: () => ref.invalidate(allNpcLoansProvider));
  }

  Widget _running(BuildContext context, AppUser me, Game g, List<Game> games, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final prev = previousGame(games, g);
    final currentAsync = ref.watch(gameSnapshotsProvider(g.id, g.date));
    final beforeAsync = prev == null ? null : ref.watch(gameSnapshotsProvider(prev.id, prev.date));
    final requestsAsync = ref.watch(openRequestsProvider);
    final readError = currentAsync.hasError || (beforeAsync?.hasError ?? false) || requestsAsync.hasError;
    final current = currentAsync.value ?? const <FrozenSheet>[];
    final before = beforeAsync?.value ?? const <FrozenSheet>[];
    final requests = requestsAsync.value ?? const <XpRequest>[];
    final live = {for (final c in chars) c.id: c};
    final snaps = {for (final s in current) s.characterId: s};
    final olds = {for (final s in before) s.characterId: s};
    final rows = [
      for (final id in g.sheetIds)
        if (live[id] case final c?) _Row(c, snaps[id], olds[id], [for (final r in requests) if (r.characterId == id) r]),
    ];
    final shown = _onlyChanged ? [for (final r in rows) if (r.modified) r] : rows;
    final selected = rows.where((r) => r.live.id == _selectedId).firstOrNull ?? shown.firstOrNull;
    final pending = rows.fold<int>(0, (s, r) => s + r.requests.length);

    Widget kpi(String value, String label, String key) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, key: Key(key), style: t.headlineSmall),
          Text(label, style: t.bodySmall?.copyWith(color: AppColors.frozenText)),
        ]);

    final banner = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.frozenBg,
        border: Border.all(color: AppColors.frozenBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(spacing: 24, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Icon(Icons.lock_outline, color: AppColors.frozen),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gameTitle(g), style: t.titleMedium),
          Text(gameSpanText(g), style: t.bodyMedium?.copyWith(color: AppColors.frozenText)),
        ]),
        kpi('${g.sheetIds.length}', 'fiches figées', 'kpi-sheets'),
        kpi('$pending', 'demandes en file', 'kpi-requests'),
      ]),
    );

    Widget cells(List<Widget> children) => Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: children);
    final table = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (readError)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Text('Lecture des versions figées impossible : réessayez plus tard.', style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
          ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const SectionTitle('Fiches figées pour cette partie'),
            ChoiceChip(label: const Text('Toutes'), selected: !_onlyChanged, onSelected: (_) => setState(() => _onlyChanged = false)),
            ChoiceChip(label: const Text('Modifiées'), selected: _onlyChanged, onSelected: (_) => setState(() => _onlyChanged = true)),
          ]),
        ),
        if (isWide(context))
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: cells([
              SizedBox(width: 230, child: Text('Fiche', style: t.bodySmall)),
              SizedBox(width: 140, child: Text('Joueur', style: t.bodySmall)),
              SizedBox(width: 170, child: Text(prev == null ? 'Depuis le gel précédent' : 'Depuis le gel du ${formatDay(prev.frozenAt)}', style: t.bodySmall)),
              Text('En attente', style: t.bodySmall),
            ]),
          ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text('Aucune fiche modifiée depuis le gel précédent.', style: t.bodySmall),
          ),
        for (final r in shown)
          InkWell(
            key: Key('freeze-row-${r.live.id}'),
            onTap: () => setState(() => _selectedId = r.live.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: r == selected ? AppColors.navActive : null,
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: cells([
                SizedBox(width: 230, child: Text('${r.live.name} · ${r.live.kind.label}', style: t.bodyMedium)),
                SizedBox(width: 140, child: Text(r.live.playerName ?? '—', style: t.bodySmall)),
                SizedBox(width: 170, child: Text(r.diffLabel, style: t.bodyMedium)),
                Text(
                  r.requests.isEmpty ? '—' : [for (final x in r.requests) x.summary].join(', '),
                  style: t.bodySmall?.copyWith(color: r.requests.isEmpty ? null : AppColors.goldLight),
                ),
              ]),
            ),
          ),
      ]),
    );

    final aside = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (selected != null) ...[_detail(context, me, g, prev, selected), const SizedBox(height: 20)],
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Pendant le gel'),
          const SizedBox(height: 10),
          for (final s in _during) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(s, style: t.bodyMedium)),
        ]),
      ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      banner,
      const SizedBox(height: 20),
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: table),
          const SizedBox(width: 24),
          SizedBox(width: 440, child: aside),
        ])
      else ...[table, const SizedBox(height: 20), aside],
    ]);
  }

  /// Panneau de la fiche choisie : changements depuis le gel précédent, correction urgente.
  Widget _detail(BuildContext context, AppUser me, Game g, Game? prev, _Row r) {
    final t = Theme.of(context).textTheme;
    final snap = r.snap;
    final old = r.old;
    final lines = snap == null || old == null ? const <String>[] : describeChanges(old.character, snap.character);
    final toReport = snap != null && snap.version != r.live.version;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(r.live.name),
        const SizedBox(height: 6),
        Text(
          prev == null ? 'Gel du ${formatDay(g.frozenAt)}' : 'Gel du ${formatDay(prev.frozenAt)} → gel du ${formatDay(g.frozenAt)}',
          style: t.bodySmall,
        ),
        const SizedBox(height: 10),
        if (snap == null)
          Text('Version figée en cours de chargement.', style: t.bodySmall)
        else if (old == null)
          Text('Première version figée.', style: t.bodyMedium)
        else if (lines.isEmpty)
          Text('Aucun changement depuis le gel précédent.', style: t.bodyMedium)
        else
          for (final l in lines) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(l, style: t.bodyMedium)),
        if (snap?.reason case final reason?) ...[
          const SizedBox(height: 10),
          Text('Corrigée le ${formatDay(snap!.at)} : $reason', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        ],
        const SizedBox(height: 16),
        _NightBlock(characterId: r.live.id, gameId: g.id, sheet: snap?.character ?? r.live),
        if (me.role.managesAccounts) ...[
          const SizedBox(height: 16),
          if (r.live.playerUid == me.uid)
            Text('Votre propre fiche : un autre conteur doit la corriger.', style: t.bodyMedium?.copyWith(color: AppColors.goldLight))
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: toReport && !_busy ? () => _correct(g, r.live, snap) : null,
                child: const Text('Correction urgente…'),
              ),
            ),
            if (snap != null && !toReport) ...[
              const SizedBox(height: 6),
              Text('Aucun changement à reporter', style: t.bodySmall),
            ],
          ],
        ],
      ]),
    );
  }
}

/// Motif obligatoire de la correction urgente ; renvoie null si annulée.
class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.name, required this.changes});
  final String name;
  final List<String> changes;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Correction urgente'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('La version figée de ${widget.name} sera remplacée par la fiche actuelle :'),
              const SizedBox(height: 8),
              for (final c in widget.changes) Text('· $c', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                key: const Key('freeze-reason'),
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _reason.text.trim()),
            child: const Text('Mettre à jour la version figée'),
          ),
        ],
      );
}

/// Suivi de la soirée saisi par le joueur (sous-projet 8c), en lecture pour tout le conte.
class _NightBlock extends ConsumerWidget {
  const _NightBlock({required this.characterId, required this.gameId, required this.sheet});
  final String characterId;
  final String gameId;

  /// Version figée : elle donne les maxima.
  final Character sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final view = ref.watch(nightProvider(characterId, gameId)).value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Suivi de la soirée'),
      const SizedBox(height: 8),
      if (view == null)
        Text('Chargement du suivi…', style: t.bodySmall)
      else if (!view.exists)
        Text('Aucun suivi pour cette partie', style: t.bodyMedium)
      else ...[
        Text(nightSummary(view.night, NightLimits.of(sheet)), style: t.bodyMedium),
        for (final n in view.night.notes.reversed) Padding(padding: const EdgeInsets.only(top: 6), child: Text(noteLine(n), style: t.bodySmall)),
      ],
    ]);
  }
}
