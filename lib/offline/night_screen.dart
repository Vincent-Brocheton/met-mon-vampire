import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../items/items_repository.dart';
import '../morality/morality_rules.dart' show eveningTraits, lossThreshold;
import '../morality/sin.dart' show Sin, dayOf;
import '../morality/sins_repository.dart';
import '../places/places_repository.dart';
import '../print/print_sheet.dart';
import '../rulebook/rulebook_provider.dart';
import 'device.dart';
import 'devices_repository.dart';
import 'night.dart';
import 'night_repository.dart';

/// « En partie » (J-HorsLigne) : suivi de la soirée sur la version figée, utilisable sans réseau.
class NightScreen extends ConsumerStatefulWidget {
  const NightScreen({super.key, required this.characterId, this.now});
  final String characterId;

  /// Heure de l'appareil ; remplacée dans les tests.
  final DateTime Function()? now;

  @override
  ConsumerState<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends ConsumerState<NightScreen> {
  /// États précédents des cases, pour « Annuler le dernier coup ».
  final _undo = <Night>[];
  final _note = TextEditingController();
  bool _preparing = false;

  String get _base => '/joueur/personnages/${widget.characterId}';
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Hors ligne, l'écriture attend le réseau : on ne l'attend pas ; un refus du serveur est signalé.
  void _save(String uid, String gameId, Night next) {
    ref.read(nightRepositoryProvider).save(widget.characterId, gameId, next, uid).catchError((Object _) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(refusedText)));
    });
  }

  void _play(String uid, String gameId, Night before, Night after) {
    setState(() => _undo.add(before));
    _save(uid, gameId, after);
  }

  void _cancel(String uid, String gameId, Night current) {
    final previous = _undo.removeLast();
    setState(() {});
    _save(uid, gameId, undoTo(current, previous));
  }

  void _addNote(String uid, String gameId, Night current) {
    final next = addNote(current, _note.text, _now);
    if (next == null) return;
    _note.clear();
    _save(uid, gameId, next);
  }

  /// Première ouverture avec réseau : l'appareil note la partie préparée (« Copie hors ligne » dans Mon compte).
  void _markPrepared(String uid, Device? device, String gameId, bool fromCache) {
    if (_preparing || fromCache || device == null || device.gameId == gameId) return;
    _preparing = true;
    ref.read(devicesRepositoryProvider).prepared(uid, device.id, gameId).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider).value?.uid;
    final value = ref.watch(characterProvider(widget.characterId));
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
    return asyncView(value, (live) {
      if (live == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      final now = _now;
      final game = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], live.id, now);
      if (game == null) {
        return EmptyState(
          kind: EmptyKind.empty,
          title: notFrozenText,
          message: 'Le bouton « En partie » apparaît sur la fiche pendant le gel.',
          actionLabel: 'Retour à la fiche',
          onAction: () => context.go(_base),
        );
      }
      final snap = ref.watch(frozenSheetProvider(live.id, game.id)).value;
      final view = ref.watch(nightProvider(live.id, game.id)).value;
      final rb = ref.watch(rulebookProvider);
      if (snap == null || view == null || rb == null) {
        return const EmptyState(kind: EmptyKind.offline, title: 'Chargement de la version figée…', message: notPreparedText);
      }
      final device = ref.watch(thisDeviceProvider).value;
      if (uid != null) _markPrepared(uid, device, game.id, view.fromCache);

      final c = snap.character;
      final limits = NightLimits.of(c);
      final night = view.night;
      final sheet = printSheet(
        c,
        version: PrintVersion.frozen,
        game: game,
        now: now,
        rb: rb,
        items: ref.watch(characterItemsProvider(live.id)).value ?? const [],
        places: ref.watch(characterPlacesProvider(live.id)).value ?? const [],
      );
      final evening = [
        for (final s in ref.watch(characterSinsProvider(live.id)).value ?? const <Sin>[])
          if (dayOf(s.date) == dayOf(game.date)) s,
      ];
      final traits = eveningTraits(evening).clamp(0, lossThreshold);
      final preparedAt = device?.gameId == game.id ? device?.preparedAt : null;
      final t = Theme.of(context).textTheme;
      final wide = isWide(context);

      Widget boxes(NightTrack track, String label) {
        final max = limits.of(track);
        final v = nightValue(night, track).clamp(0, max);
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 1; i <= max; i++)
            _Box(
              key: Key('${track.name}-$i'),
              label: '$label $i',
              filled: i <= v,
              onTap: uid == null ? null : () => _play(uid, game.id, night, toggle(night, track, i, limits)),
            ),
        ]);
      }

      Widget gauge(String title, String? count, Widget body) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: t.titleSmall)),
              if (count != null) Text(count, style: t.bodySmall),
            ]),
            const SizedBox(height: 8),
            body,
          ]);

      Widget rows(List<PrintRow> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.dots > 0 ? '${r.label} ${'●' * r.dots}' : r.label, style: t.titleSmall),
                  if (r.detail.isNotEmpty) Text(r.detail, style: t.bodySmall),
                ]),
              ),
          ]);

      final bloodLabel = limits.vitae ? 'Vitae dépensée' : 'Sang dépensé';
      final tracker = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
            const SectionTitle('Suivi de la soirée'),
            OutlinedButton(
              onPressed: _undo.isEmpty || uid == null ? null : () => _cancel(uid, game.id, night),
              child: const Text('Annuler le dernier coup'),
            ),
          ]),
          const SizedBox(height: 18),
          gauge(bloodLabel, spentText(nightValue(night, NightTrack.blood).clamp(0, limits.blood), limits.blood), boxes(NightTrack.blood, bloodLabel)),
          const SizedBox(height: 20),
          gauge('Volonté dépensée', spentText(nightValue(night, NightTrack.willpower).clamp(0, limits.willpower), limits.willpower),
              boxes(NightTrack.willpower, 'Volonté dépensée')),
          const SizedBox(height: 20),
          gauge(
            'Santé',
            null,
            Wrap(spacing: 16, runSpacing: 12, children: [
              for (final (track, name) in [(NightTrack.healthy, 'Sain'), (NightTrack.hurt, 'Blessé'), (NightTrack.incapacitated, 'Incapacité')])
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  boxes(track, name),
                  const SizedBox(height: 4),
                  Text(name, style: t.bodySmall),
                ]),
            ]),
          ),
          const SizedBox(height: 20),
          gauge(
            'Traits de Bête ce soir',
            '$traits / $lossThreshold',
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 1; i <= lossThreshold; i++) _Box(key: Key('beast-$i'), label: 'Traits de Bête ce soir $i', filled: i <= traits, round: true),
            ]),
          ),
          const SizedBox(height: 12),
          Text(beastNote, style: t.bodySmall),
        ]),
      );

      // `printSheet` met « Aucun » dans une liste vide : on le retire pour regrouper les trois listes.
      bool real(PrintRow r) => r.label != 'Aucun';
      final gear = [
        ...sheet.items.where(real),
        for (final a in c.allies) PrintRow(a.name, detail: 'allié', dots: a.level),
        ...sheet.places.where(real),
      ];

      final side = [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Pouvoirs'),
            const SizedBox(height: 8),
            rows(sheet.disciplines),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Note de partie'),
            const SizedBox(height: 10),
            TextField(
              key: const Key('night-note'),
              controller: _note,
              maxLines: 3,
              maxLength: noteMaxLength,
              decoration: const InputDecoration(hintText: 'Ce qui s’est passé, qui vous avez rencontré…'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton(onPressed: uid == null ? null : () => _addNote(uid, game.id, night), child: const Text('Ajouter la note')),
              OutlinedButton(onPressed: () => context.go('$_base/xp'), child: const Text('Brouillon de demande')),
            ]),
            for (final n in night.notes.reversed) Padding(padding: const EdgeInsets.only(top: 8), child: Text(noteLine(n), style: t.bodyMedium)),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Équipement, alliés et lieux'),
            const SizedBox(height: 8),
            if (gear.isEmpty) Text('Aucun', style: t.bodyMedium) else rows(gear),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Envoi'),
            const SizedBox(height: 8),
            Text(sentText(view.pending), style: t.bodyMedium?.copyWith(color: view.pending ? AppColors.goldLight : AppColors.success)),
          ]),
        ),
      ];

      return PageBody(children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton(onPressed: () => context.go(_base), child: Text(live.name)),
          Text('/ En partie', style: t.bodySmall),
        ]),
        Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${firstName(live.name)} en partie', style: wide ? t.displaySmall : t.headlineMedium),
          if (view.fromCache) const _OfflineBadge(),
        ]),
        const SizedBox(height: 6),
        Text(versionLine(game, preparedAt), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: () => context.go(_base), child: const Text('Fiche complète (lecture)')),
        ),
        const SizedBox(height: 20),
        if (view.fromCache) ...[const _Notice(offlineText), const SizedBox(height: 12)],
        if (kIsWeb) ...[const _Notice(webTabText), const SizedBox(height: 12)],
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: tracker),
            const SizedBox(width: 24),
            SizedBox(
              width: 460,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final p in side) ...[p, const SizedBox(height: 20)],
              ]),
            ),
          ])
        else ...[
          tracker,
          const SizedBox(height: 20),
          for (final p in side) ...[p, const SizedBox(height: 20)],
        ],
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }
}

/// Case du suivi ; ronde pour les traits de Bête, sans action quand elle est en lecture.
class _Box extends StatelessWidget {
  const _Box({super.key, required this.label, required this.filled, this.onTap, this.round = false});
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool round;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        toggled: filled,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: round ? const CircleBorder() : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: filled ? AppColors.accent : Colors.transparent,
              border: Border.all(color: filled ? AppColors.accentIcon : AppColors.fieldBorder, width: 1.5),
              borderRadius: round ? null : BorderRadius.circular(5),
              shape: round ? BoxShape.circle : BoxShape.rectangle,
            ),
          ),
        ),
      );
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

/// Bandeau d'avertissement (hors ligne, onglet à garder ouvert).
class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.reviewBg,
          border: Border.all(color: AppColors.gold),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textSoft, fontSize: 15)),
      );
}
