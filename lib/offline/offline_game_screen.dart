import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../events/story_event.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../morality/morality_rules.dart';
import '../morality/sin.dart';
import '../morality/sins_repository.dart';
import 'device_session.dart';
import 'devices_repository.dart';
import 'night.dart' show webTabText;
import 'offline.dart';
import 'offline_game_repository.dart';
import 'sync_queue.dart';
import 'wipe.dart';

const _route = '/conteur/gel/hors-ligne';

/// « Partie hors ligne » (C-HorsLigne, sous-projet 8d) : préparer l'appareil, suivre la file, trancher les conflits de péchés.
class OfflineGameScreen extends ConsumerStatefulWidget {
  const OfflineGameScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<OfflineGameScreen> createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends ConsumerState<OfflineGameScreen> {
  OfflinePrefs? _prefs;
  bool _busy = false;
  String? _message;
  String? _conflictError;

  /// Heure où la file est revenue à zéro en ligne, gardée en mémoire.
  DateTime? _lastSync;
  bool _hadPending = false;

  @override
  void initState() {
    super.initState();
    OfflinePrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  void _setPrefs(OfflinePrefs p) {
    setState(() => _prefs = p);
    p.save();
  }

  Future<void> _prepare(Game g, String uid, String? deviceId) async {
    final p = _prefs;
    if (p == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(offlineGameRepositoryProvider).prepare(g, p);
      if (deviceId != null) await ref.read(devicesRepositoryProvider).prepared(uid, deviceId, g.id);
      if (mounted) setState(() => _message = preparedText);
    } catch (_) {
      if (mounted) setState(() => _message = prepareFailedText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Sans réseau, l'attente ne finirait qu'à son retour : on rend la main.
      await ref.read(offlineGameRepositoryProvider).sync().timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _lastSync = widget.now();
          _message = allSentText;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = syncLaterText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipeNow(String uid, String? deviceId) async {
    final session = ref.read(deviceSessionProvider);
    final pending = await session.pendingWrites();
    if (!mounted) return;
    final ok = await confirm(context, title: 'Effacer cet appareil', body: wipeConfirmText(pending: pending), action: 'Effacer');
    if (!ok) return;
    await session.wipe(uid, deviceId, _route);
  }

  /// Hors ligne, l'écriture reste en file et son futur ne finit qu'au retour du réseau : on ne l'attend pas.
  void _resolve(Future<void> Function(Actor by) write) {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    setState(() => _conflictError = null);
    write(by).catchError((Object _) {
      if (mounted) setState(() => _conflictError = resolveRefusedText);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'La partie hors ligne est l’affaire du conte.');
    }
    return asyncView(ref.watch(gamesProvider), (games) {
      final g = runningGame(games, widget.now());
      if (g == null) {
        return EmptyState(
          kind: EmptyKind.empty,
          title: noGameText,
          message: 'Le bouton « Partie hors ligne » apparaît sur l’écran du gel pendant une partie.',
          actionLabel: 'Gel des fiches',
          onAction: () => context.go('/conteur/gel'),
        );
      }
      return _page(context, me, g);
    }, onRetry: () => ref.invalidate(gamesProvider));
  }

  Widget _page(BuildContext context, AppUser me, Game g) {
    final t = Theme.of(context).textTheme;
    final wide = isWide(context);
    final offline = ref.watch(offlineProvider).value ?? false;
    final device = ref.watch(thisDeviceProvider).value;
    final sheets = {for (final c in ref.watch(allCharactersProvider).value ?? const <Character>[]) c.id: c};
    final sins = {for (final id in g.sheetIds) id: ref.watch(trackedSinsProvider(id)).value ?? const <Tracked<Sin>>[]};
    final events = {for (final id in g.sheetIds) id: ref.watch(trackedEventsProvider(id)).value ?? const <Tracked<StoryEvent>>[]};
    final day = dayOf(g.date);
    final pairs = [
      for (final id in g.sheetIds)
        for (final p in conflicts([for (final s in sins[id]!) if (dayOf(s.doc.date) == day) s.doc])) (id: id, a: p.$1, b: p.$2),
    ];
    final inConflict = {for (final p in pairs) ...[p.a.id, p.b.id]};
    final lines = queueLines(g, sheets, sins, events, inConflict);
    final pending = pendingCount(lines);
    if (pending > 0) _hadPending = true;
    if (!offline && pending == 0 && _hadPending) {
      _hadPending = false;
      _lastSync = widget.now();
    }
    final preparedAt = device?.gameId == g.id ? device?.preparedAt : null;
    final p = _prefs;

    Widget kpi(String value, String label, String key) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, key: Key(key), style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(label, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        );

    Widget conflictBlock(String id, Sin a, Sin b) {
      Widget card(Sin s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.background, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(conflictHead(s), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(s.what.isEmpty ? '—' : s.what, style: t.bodyLarge),
              const SizedBox(height: 4),
              Text(traitsText(sinTraits(s)), style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
          );
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.accent), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Conflit · ${sheets[id]?.name ?? '—'}'),
          const SizedBox(height: 12),
          Text(conflictText(a, b), style: t.bodyLarge?.copyWith(color: AppColors.textSoft)),
          const SizedBox(height: 12),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: card(a)), const SizedBox(width: 12), Expanded(child: card(b))])
          else ...[
            card(a),
            const SizedBox(height: 12),
            card(b),
          ],
          if (me.role.managesAccounts) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(onPressed: () => _resolve((_) => ref.read(sinsRepositoryProvider).delete(id, b.id)), child: Text(keepText(a))),
              OutlinedButton(onPressed: () => _resolve((_) => ref.read(sinsRepositoryProvider).delete(id, a.id)), child: Text(keepText(b))),
              OutlinedButton(
                onPressed: () => _resolve((by) => ref.read(sinsRepositoryProvider).markDistinct(id, [a, b], by)),
                child: const Text('Deux péchés distincts'),
              ),
            ]),
          ],
          if (_conflictError != null) ...[
            const SizedBox(height: 8),
            Text(_conflictError!, style: const TextStyle(color: AppColors.linkHover)),
          ],
        ]),
      );
    }

    Widget chip(QueueState s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: switch (s) {
              QueueState.pending => AppColors.reviewBg,
              QueueState.sent => AppColors.activeBg,
              QueueState.conflict => AppColors.deadBg,
            },
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            s.label,
            style: TextStyle(
              color: switch (s) {
                QueueState.pending => AppColors.goldLight,
                QueueState.sent => AppColors.success,
                QueueState.conflict => AppColors.linkHover,
              },
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    Widget lineTile(QueueLine l) {
      final hour = Text(lineHour(l.at), style: t.bodyMedium?.copyWith(color: AppColors.textMuted));
      final what = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.label, style: t.bodyMedium),
        Text(l.sheetName, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]);
      return InkWell(
        onTap: () => context.go(l.path),
        child: Container(
          color: l.state == QueueState.conflict ? AppColors.deadBg.withValues(alpha: 0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: wide
              ? Row(children: [
                  SizedBox(width: 70, child: hour),
                  SizedBox(width: 130, child: Text(l.byName, style: t.bodyMedium)),
                  Expanded(child: what),
                  chip(l.state),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    hour,
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.byName, style: t.bodyMedium)),
                    chip(l.state),
                  ]),
                  const SizedBox(height: 4),
                  what,
                ]),
        ),
      );
    }

    final queue = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 14), child: SectionTitle('File de synchronisation')),
        const Divider(height: 1, color: AppColors.border),
        if (lines.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(emptyQueueText, style: t.bodyMedium))
        else
          for (final l in lines) ...[lineTile(l), const Divider(height: 1, color: AppColors.border)],
      ]),
    );

    Widget box(String label, String detail, bool value, OfflinePrefs Function(bool) next) => CheckboxListTile(
          value: value,
          onChanged: p == null ? null : (v) => _setPrefs(next(v ?? false)),
          title: Text(label),
          subtitle: Text(detail),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        );

    final devicePanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Sur cet appareil'),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: true,
          onChanged: null,
          title: const Text('Fiches figées'),
          subtitle: Text(sheetCountText(g.sheetIds.length)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        box('Référentiel', 'Atouts, disciplines, titres', p?.rulebook ?? true, (v) => p!.copyWith(rulebook: v)),
        box('Liens de sang et événements', 'Y compris les secrets', p?.bonds ?? true, (v) => p!.copyWith(bonds: v)),
        box('Notes du conte', 'Lecture seule', p?.notes ?? false, (v) => p!.copyWith(notes: v)),
        const SizedBox(height: 6),
        Text(cacheNote, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: offline || _busy || p == null ? null : () => _prepare(g, me.uid, device?.id),
            child: const Text('Préparer la partie'),
          ),
        ),
      ]),
    );

    final canDoPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Hors ligne, on peut'),
        const SizedBox(height: 8),
        for (final x in canDo) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x, style: t.bodyLarge)),
        Text(cannotDo, style: t.bodyLarge?.copyWith(color: AppColors.textSecondary)),
      ]),
    );

    final securityPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Sécurité'),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('wipe-policy'),
          child: DropdownButtonFormField<WipePolicy>(
            // Les réglages arrivent après le premier affichage : le menu repart avec eux.
            key: ValueKey(p?.policy),
            initialValue: p?.policy ?? WipePolicy.week,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Effacer les données de l’appareil'),
            items: [for (final w in WipePolicy.values) DropdownMenuItem(value: w, child: Text(w.label))],
            onChanged: p == null ? null : (w) => _setPrefs(p.copyWith(policy: w)),
          ),
        ),
        const SizedBox(height: 12),
        Text(playersNote, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: () => _wipeNow(me.uid, device?.id), child: const Text('Effacer maintenant de cet appareil')),
        ),
      ]),
    );

    final main = [
      for (final c in pairs) ...[conflictBlock(c.id, c.a, c.b), const SizedBox(height: 20)],
      queue,
    ];
    final side = [devicePanel, const SizedBox(height: 20), canDoPanel, const SizedBox(height: 20), securityPanel];

    return PageBody(children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(onPressed: () => context.go('/conteur/gel'), child: const Text('Gel des fiches')),
        Text('/ Hors ligne', style: t.bodySmall),
      ]),
      Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Partie hors ligne', style: wide ? t.displaySmall : t.headlineMedium),
        if (offline) const _OfflineBadge(),
      ]),
      const SizedBox(height: 6),
      Text(headerLine(g, preparedAt, _lastSync), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton(onPressed: _busy ? null : _sync, child: const Text('Synchroniser maintenant')),
        if (_message != null) Text(_message!, style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
      ]),
      const SizedBox(height: 16),
      if (offline && preparedAt == null) ...[const _Notice(notPreparedGameText), const SizedBox(height: 12)],
      if (kIsWeb) ...[const _Notice(webTabText), const SizedBox(height: 12)],
      Row(children: [
        kpi('${g.sheetIds.length}', 'fiches figées', 'kpi-sheets'),
        const SizedBox(width: 14),
        kpi('$pending', 'saisies en attente', 'kpi-pending'),
        const SizedBox(width: 14),
        kpi('${pairs.length}', conflictLabel(pairs.length), 'kpi-conflicts'),
      ]),
      const SizedBox(height: 20),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main)),
          const SizedBox(width: 24),
          SizedBox(width: 420, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side)),
        ])
      else ...[
        ...main,
        const SizedBox(height: 20),
        ...side,
      ],
    ]);
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.reviewBg, borderRadius: BorderRadius.circular(999)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off, size: 16, color: AppColors.goldLight),
          SizedBox(width: 6),
          Text('Hors ligne', style: TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.reviewBg, border: Border.all(color: AppColors.gold), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(color: AppColors.textSoft, fontSize: 15)),
      );
}
