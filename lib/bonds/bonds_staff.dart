import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'bond.dart';
import 'bond_rules.dart';
import 'bonds_repository.dart';
import 'drink_form.dart';

/// Bloc « Liens de sang » du conte (C-Moralite) : liens subis et exercés de la fiche, gorgées, contacts.
class StaffBonds extends ConsumerStatefulWidget {
  const StaffBonds({super.key, required this.character, required this.canEdit, this.today});

  final Character character;
  final bool canEdit;

  /// Date du jour (tests) ; aujourd'hui par défaut.
  final DateTime? today;

  @override
  ConsumerState<StaffBonds> createState() => _StaffBondsState();
}

class _StaffBondsState extends ConsumerState<StaffBonds> {
  /// Lien dont le formulaire est ouvert ; `new` pour un nouveau lien.
  String? _open;
  String? _partnerId;
  bool _suffered = true;
  bool _busy = false;

  Character get c => widget.character;

  Future<void> _run(Future<void> Function(Actor by) write) async {
    final messenger = ScaffoldMessenger.of(context);
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await write(by);
      if (mounted) {
        setState(() {
          _open = null;
          _partnerId = null;
        });
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value; // l'auteur est relu à l'enregistrement
    final today = widget.today ?? DateTime.now();
    final bondsAsync = ref.watch(allBondsProvider);
    // Tant que les liens ne sont pas lus : aucune action (une gorgée écraserait un lien existant).
    if (!bondsAsync.hasValue) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Liens de sang'),
          asyncView<List<Bond>>(bondsAsync, (_) => const SizedBox.shrink(), onRetry: () => ref.invalidate(allBondsProvider)),
        ]),
      );
    }
    final all = bondsAsync.requireValue;
    final chars = ref.watch(allCharactersProvider).value ?? const <Character>[];
    BondsRepository repo() => ref.read(bondsRepositoryProvider);
    Character? byId(String id) => chars.where((x) => x.id == id).firstOrNull;
    final ro = !widget.canEdit || !(c.kind == CharacterKind.pnj || c.status.settled);
    final suffered = activeBonds(all.where((b) => b.thrallId == c.id), today);
    final exerted = activeBonds(all.where((b) => b.regnantId == c.id), today);
    final toDate = ghoulBondToDate(c, all);
    final domitor = c.ghoul == null ? null : byId(c.ghoul!.domitorId);
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);

    Bond current(Bond b) {
      final r = byId(b.regnantId);
      final th = byId(b.thrallId);
      return r == null || th == null ? b : refreshed(b, r, th);
    }

    Widget form(Bond base) => DrinkForm(
          key: ValueKey('dr-${base.id}'),
          base: base,
          all: all,
          today: today,
          busy: _busy,
          touchesOwn: (e) => me != null && (byId(e.regnantId)?.playerUid == me.uid || byId(e.thrallId)?.playerUid == me.uid),
          onDrink: (w) => _run((by) => repo().drink(withCurrentPlayers(w, byId), by)),
          onContact: base.stored ? (b) => _run((by) => repo().save(b, by)) : null,
        );

    Widget tile(Bond b, {required bool isSuffered}) {
      final other = byId(isSuffered ? b.regnantId : b.thrallId);
      final open = _open == b.id;
      return Container(
        key: Key('bo-${b.id}'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(isSuffered ? b.regnantName : b.thrallName, style: t.titleSmall),
            if (other != null) Text(partyTag(other), style: muted),
            Text(
              bondDots(effectiveLevel(b, today)),
              key: Key('bo-dots-${b.id}'),
              style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3),
            ),
          ]),
          Text(staffLine(b, today), style: t.bodySmall?.copyWith(color: dueSoon(b, today) ? AppColors.goldLight : AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (!ro) ...[
              OutlinedButton(
                key: Key('bo-drink-${b.id}'),
                onPressed: _busy ? null : () => setState(() => _open = open ? null : b.id),
                child: const Text('+ Gorgée'),
              ),
              OutlinedButton(
                key: Key('bo-contact-${b.id}'),
                onPressed: _busy ? null : () => _run((by) => repo().save(contacted(current(b), today), by)),
                child: const Text('Contact'),
              ),
            ],
            Text(
              b.known ? 'Connu de ${b.thrallName}' : 'Ignoré de ${b.thrallName}',
              style: t.bodySmall?.copyWith(color: b.known ? AppColors.success : AppColors.linkHover),
            ),
          ]),
          if (open && !ro) form(current(b)),
        ]),
      );
    }

    Widget newLink() {
      final partners = [
        for (final x in chars)
          if (x.id != c.id && bondable(x) && (me == null || x.playerUid != me.uid)) x,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final p = _partnerId == null ? null : byId(_partnerId!);
      Bond? base;
      if (p != null) {
        final (r, th) = _suffered ? (p, c) : (c, p);
        final existing = all.where((b) => b.id == bondId(r.id, th.id)).firstOrNull;
        base = existing == null ? bondBetween(r, th, today) : refreshed(existing, r, th);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            key: const Key('bo-dir-suffered'),
            label: const Text('Subi'),
            selected: _suffered,
            onSelected: (_) => setState(() => _suffered = true),
          ),
          ChoiceChip(
            key: const Key('bo-dir-exerted'),
            label: const Text('Exercé'),
            selected: !_suffered,
            onSelected: (_) => setState(() => _suffered = false),
          ),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('bo-partner'),
          initialValue: _partnerId,
          isExpanded: true,
          decoration: InputDecoration(labelText: _suffered ? 'Qui donne son sang' : 'Qui boit'),
          items: [
            for (final x in partners)
              DropdownMenuItem(value: x.id, child: Text('${x.name} · ${partyTag(x)}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _partnerId = v),
        ),
        if (base != null) form(base),
      ]);
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SectionTitle('Liens de sang'),
            TextButton(
              key: const Key('bo-all'),
              onPressed: () => context.go('/conteur/liens'),
              child: const Text('Tous les liens de la chronique'),
            ),
          ],
        ),
        if (toDate > 0)
          Padding(
            key: const Key('bo-date'),
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Lien de ${domitor?.name ?? c.ghoul!.domitorName} ${bondDots(toDate)} à dater', style: t.bodyMedium),
              if (!ro && domitor != null)
                OutlinedButton(
                  key: const Key('bo-date-create'),
                  onPressed: _busy ? null : () => _run((by) => repo().save(datedGhoulBond(c, domitor, today), by)),
                  child: const Text('Créer le lien'),
                ),
            ]),
          ),
        if (suffered.isEmpty && exerted.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucun lien.', style: t.bodyMedium)),
        if (suffered.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Subis', style: t.labelMedium),
          for (final b in suffered) tile(b, isSuffered: true),
        ],
        if (exerted.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Exercés', style: t.labelMedium),
          for (final b in exerted) tile(b, isSuffered: false),
        ],
        if (!ro) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('bo-new'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _open = _open == 'new' ? null : 'new';
                        _partnerId = null;
                      }),
              child: const Text('+ Nouveau lien'),
            ),
          ),
          if (_open == 'new') newLink(),
        ],
      ]),
    );
  }
}
