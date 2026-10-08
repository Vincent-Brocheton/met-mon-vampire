import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show formatLoanDay;
import 'bond.dart';
import 'bond_rules.dart';
import 'bonds_repository.dart';
import 'drink_form.dart';

String _lowerFirst(String s) => s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

/// Page « Liens de sang de la chronique » (C-Liens) : liens actifs, filtres, panneau « Enregistrer une gorgée ».
class BondsScreen extends ConsumerStatefulWidget {
  const BondsScreen({super.key, this.today});

  /// Date du jour (tests) ; aujourd'hui par défaut.
  final DateTime? today;

  @override
  ConsumerState<BondsScreen> createState() => _BondsScreenState();
}

class _BondsScreenState extends ConsumerState<BondsScreen> {
  BondFilter _filter = BondFilter.all;
  String _query = '';
  String? _regnantId;
  String? _thrallId;

  /// Mobile : panneau ouvert en pleine page.
  bool _panel = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function(Actor by) write) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await write(by);
      if (mounted) setState(() => _panel = false);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value; // l'auteur est relu à l'enregistrement
    final canEdit = me != null && me.role.managesAccounts;
    final today = widget.today ?? DateTime.now();
    return asyncView(ref.watch(allBondsProvider), (all) {
      final t = Theme.of(context).textTheme;
      final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
      final chars = ref.watch(allCharactersProvider).value ?? const <Character>[];
      Character? byId(String? id) => id == null ? null : chars.where((x) => x.id == id).firstOrNull;
      final wide = isWide(context);
      final active = activeBonds(all, today);
      final shown = [for (final b in active) if (bondMatches(b, _filter, _query, today)) b];
      final s = bondStats(active, today);
      final repo = ref.read(bondsRepositoryProvider);

      Widget panel() {
        final pickable = [
          for (final x in chars)
            if (bondable(x) && (x.playerUid == null || x.playerUid != me?.uid)) x,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        Widget pick(String key, String label, String? value, ValueChanged<String?> onChanged) => KeyedSubtree(
              key: ValueKey('$key-$value'),
              child: DropdownButtonFormField<String>(
                key: Key(key),
                initialValue: pickable.any((x) => x.id == value) ? value : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final x in pickable)
                    DropdownMenuItem(value: x.id, child: Text('${x.name} · ${partyTag(x)}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: onChanged,
              ),
            );
        final r = byId(_regnantId);
        final th = byId(_thrallId);
        final errors = bondChecks(regnantId: r?.id, thrallId: th?.id, day: today);
        Bond? base;
        if (r != null && th != null && errors.isEmpty) {
          final existing = all.where((b) => b.id == bondId(r.id, th.id)).firstOrNull;
          base = existing == null ? bondBetween(r, th, today) : refreshed(existing, r, th);
        }
        return Container(
          key: const Key('bo-panel'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(type: MaterialType.transparency, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Enregistrer une gorgée'),
            const SizedBox(height: 12),
            pick('bo-regnant', 'Qui donne son sang', _regnantId, (v) => setState(() => _regnantId = v)),
            const SizedBox(height: 10),
            pick('bo-thrall', 'Qui boit', _thrallId, (v) => setState(() => _thrallId = v)),
            if (base == null) ...[
              const SizedBox(height: 10),
              for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
            ] else
              DrinkForm(
                key: ValueKey('dr-${base.id}'),
                base: base,
                all: all,
                today: today,
                busy: _busy,
                touchesOwn: (e) => me != null && (byId(e.regnantId)?.playerUid == me.uid || byId(e.thrallId)?.playerUid == me.uid),
                onDrink: (w) => _run((by) => repo.drink(withCurrentPlayers(w, byId), by)),
                onContact: base.stored ? (b) => _run((by) => repo.save(b, by)) : null,
              ),
            const SizedBox(height: 16),
            Text('Règles appliquées', style: t.labelMedium),
            const SizedBox(height: 4),
            Text('●○○ s’efface après un an sans contact.', style: muted),
            Text('●●○ s’efface après six mois sans contact ; résister coûte 1 Volonté par heure.', style: muted),
            Text('●●● redescend à ●●○ après trois mois sans boire et efface les liens moindres.', style: muted),
          ])),
        );
      }

      Widget stat(String key, int v, String label, Color color) => Container(
            key: Key(key),
            width: 170,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$v', style: t.headlineMedium?.copyWith(color: color)),
              Text(label, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
          );

      Widget party(String name, Character? c) => SizedBox(
            width: 200,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: t.titleSmall),
              if (c != null) Text(partyTag(c), style: muted),
            ]),
          );

      Widget row(Bond b) {
        final selected = _regnantId == b.regnantId && _thrallId == b.thrallId;
        return InkWell(
          key: Key('bo-row-${b.id}'),
          onTap: () => setState(() {
            _regnantId = b.regnantId;
            _thrallId = b.thrallId;
            _panel = true;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.deadBg : null,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(spacing: 18, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              party(b.regnantName, byId(b.regnantId)),
              party(b.thrallName, byId(b.thrallId)),
              Text(bondDots(effectiveLevel(b, today)), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
              Text(
                'Gorgée ${formatLoanDay(b.lastDrink, now: today)} · contact ${formatLoanDay(b.lastContact, now: today)}',
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Text(dueText(b, today), style: t.bodySmall?.copyWith(color: dueSoon(b, today) ? AppColors.goldLight : AppColors.textSecondary)),
              Text(
                b.known ? 'Connu du lié : oui' : 'Connu du lié : non',
                style: t.bodySmall?.copyWith(color: b.known ? AppColors.success : AppColors.linkHover),
              ),
            ]),
          ),
        );
      }

      final soonest = active.where((b) => dueSoon(b, today)).firstOrNull;
      final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton(onPressed: () => context.go('/conteur/fiches'), child: const Text('Fiches')),
          Text('/ Liens de sang', style: muted),
        ]),
        const PageTitle(
          'Liens de sang de la chronique',
          subtitle: 'Chaque gorgée et chaque contact mettent à jour les deux fiches. Les échéances se calculent seules.',
        ),
        const SizedBox(height: 18),
        if (!wide && soonest != null) ...[
          Container(
            key: const Key('bo-alert'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.reviewBg,
              border: Border.all(color: AppColors.gold),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                'Échéance dans ${daysUntil(today, nextChange(soonest, today)!.at)} jours',
                style: t.titleSmall?.copyWith(color: AppColors.goldLight),
              ),
              Text(
                'Le lien de ${soonest.thrallName} envers ${soonest.regnantName} : ${_lowerFirst(dueText(soonest, today))}.',
                style: t.bodyMedium,
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        Wrap(spacing: 14, runSpacing: 14, children: [
          stat('bo-stat-active', s.active, 'liens actifs', AppColors.text),
          stat('bo-stat-full', s.full, 'liens complets', AppColors.accentIcon),
          stat('bo-stat-soon', s.soon, 'échéance sous 30 jours', AppColors.goldLight),
          stat('bo-stat-unknown', s.unknown, 'ignorés du lié', AppColors.linkHover),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final f in BondFilter.values)
            ChoiceChip(
              key: Key('bo-filter-${f.name}'),
              label: Text(f.label),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            ),
          SizedBox(
            width: 240,
            child: TextField(
              key: const Key('bo-search'),
              decoration: const InputDecoration(hintText: 'Rechercher un personnage…'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (shown.isEmpty) Padding(padding: const EdgeInsets.all(18), child: Text('Aucun lien.', style: t.bodyMedium)),
            for (final b in shown) row(b),
          ]),
        ),
        if (!wide && canEdit) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('bo-m-contact'),
                onPressed: () => setState(() => _panel = true),
                child: const Text('Contact'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const Key('bo-m-drink'),
                onPressed: () => setState(() => _panel = true),
                child: const Text('+ Gorgée'),
              ),
            ),
          ]),
        ],
      ]);

      if (!wide && _panel && canEdit) {
        return PageBody(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('bo-back'),
              onPressed: () => setState(() => _panel = false),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Retour'),
            ),
          ),
          const SizedBox(height: 8),
          panel(),
        ]);
      }
      if (wide) {
        return PageBody(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: list),
            if (canEdit) ...[const SizedBox(width: 24), SizedBox(width: 420, child: panel())],
          ]),
        ]);
      }
      return PageBody(children: [list]);
    }, onRetry: () => ref.invalidate(allBondsProvider));
  }
}
