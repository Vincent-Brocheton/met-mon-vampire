import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/transformations.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/theme.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';

/// Choix d'une étreinte : sire, génération, discipline à 2 points, joueur (amorce de PJ), motif.
class EmbraceChoice {
  const EmbraceChoice({required this.sire, required this.genNumber, this.first, this.player, required this.reason});
  final Character sire;
  final int genNumber;
  final String? first;
  final AppUser? player;
  final String reason;
}

/// Fiches de vampires actives (sires et domitors possibles).
List<Character> _vampires(WidgetRef ref) => [
      for (final c in ref.watch(allCharactersProvider).value ?? const <Character>[])
        if (c.isActiveVampire) c,
    ];

/// Joueurs possibles, sans le conteur lui-même (les règles lui refusent sa propre fiche).
List<AppUser> _players(WidgetRef ref) {
  final me = ref.watch(currentUserProvider).value?.uid;
  return [
    for (final u in ref.watch(allUsersProvider).value ?? const <AppUser>[])
      if (u.uid != me && u.role != Role.pending && u.role != Role.disabled) u,
  ];
}

/// « Étreindre… » : sire (proposé : [initialSireId]), génération (sire + 1), discipline à 2 points, PNJ ou PJ.
class EmbraceDialog extends ConsumerStatefulWidget {
  const EmbraceDialog({super.key, required this.name, this.initialSireId, this.allowPj = false, this.debt});
  final String name;
  final String? initialSireId;

  /// Mortel ou serviteur : PNJ actif, ou amorce de PJ pour un joueur.
  final bool allowPj;

  /// Dette que l'étreinte créerait (goule jouée) ; null si sans objet.
  final int Function(EmbraceChoice choice)? debt;

  @override
  ConsumerState<EmbraceDialog> createState() => _EmbraceDialogState();
}

class _EmbraceDialogState extends ConsumerState<EmbraceDialog> {
  String? _sireId;
  final _gen = TextEditingController();
  final _reason = TextEditingController();
  String? _first;
  bool _pj = false;
  bool _prefilled = false;
  String? _playerUid;

  @override
  void initState() {
    super.initState();
    _sireId = widget.initialSireId;
  }

  @override
  void dispose() {
    _gen.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _pickSire(Character? s) => setState(() {
        _prefilled = true;
        _sireId = s?.id;
        _first = null;
        if (s?.genNumber != null) _gen.text = '${s!.genNumber! + 1}';
      });

  @override
  Widget build(BuildContext context) {
    final rb = ref.watch(rulebookProvider) ?? const Rulebook();
    final t = Theme.of(context).textTheme;
    final sires = _vampires(ref);
    final sire = sires.where((s) => s.id == _sireId).firstOrNull;
    // Pré-remplie une seule fois, quand le sire proposé est connu : le conte peut ensuite vider le champ.
    if (!_prefilled && sire != null) {
      _prefilled = true;
      if (_gen.text.isEmpty && sire.genNumber != null) _gen.text = '${sire.genNumber! + 1}';
    }
    final number = int.tryParse(_gen.text.trim());
    final rank = number == null ? null : rankOfNumber(number, rb: rb);
    final clanDisciplines = rb.clanDisciplines(sire?.clan);
    final players = _players(ref);
    final player = players.where((u) => u.uid == _playerUid).firstOrNull;
    String? problem;
    if (sire == null) {
      problem = 'Choisissez le sire.';
    } else if ((sire.clan ?? '').isEmpty) {
      problem = 'Le sire n’a pas de clan';
    } else if (number == null) {
      problem = 'Indiquez la génération.';
    } else if (rank == null) {
      problem = 'Génération ${number}e absente du tableau des générations';
    } else if (_pj && player == null) {
      problem = 'Choisissez le joueur.';
    } else if (_reason.text.trim().isEmpty) {
      problem = 'Indiquez un motif.';
    }
    final choice = sire == null || number == null
        ? null
        : EmbraceChoice(sire: sire, genNumber: number, first: _first ?? clanDisciplines.firstOrNull, player: _pj ? player : null, reason: _reason.text.trim());
    final debt = choice == null || rank == null || widget.debt == null ? 0 : widget.debt!(choice);
    return AlertDialog(
      title: Text('Étreindre ${widget.name}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              key: const Key('em-sire'),
              initialValue: sire?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sire'),
              items: [for (final s in sires) DropdownMenuItem(value: s.id, child: Text(s.name))],
              onChanged: (id) => _pickSire(sires.where((s) => s.id == id).firstOrNull),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('em-gen'),
              controller: _gen,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Génération (celle du sire + 1)'),
              onChanged: (_) => setState(() {}),
            ),
            if (rank != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(rank.label, style: t.bodyMedium)),
            if (clanDisciplines.isNotEmpty && !_pj) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('em-first-${sire?.id}'),
                initialValue: clanDisciplines.contains(_first) ? _first : clanDisciplines.first,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Discipline à 2 points (les autres à 1)'),
                items: [for (final d in clanDisciplines) DropdownMenuItem(value: d, child: Text(d))],
                onChanged: (d) => setState(() => _first = d),
              ),
            ],
            if (widget.allowPj) ...[
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                key: const Key('em-pj'),
                segments: const [ButtonSegment(value: false, label: Text('PNJ')), ButtonSegment(value: true, label: Text('PJ'))],
                selected: {_pj},
                onSelectionChanged: (s) => setState(() => _pj = s.first),
              ),
              if (_pj)
                DropdownButtonFormField<String>(
                  key: const Key('em-player'),
                  initialValue: player?.uid,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Joueur'),
                  items: [for (final u in players) DropdownMenuItem(value: u.uid, child: Text(u.displayName))],
                  onChanged: (uid) => setState(() => _playerUid = uid),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('em-reason'),
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Motif'),
              onChanged: (_) => setState(() {}),
            ),
            if (sire != null && embraceNote(sire, rb: rb) != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(embraceNote(sire, rb: rb)!, style: const TextStyle(color: AppColors.goldLight))),
            if (debt > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Dette de $debt XP', style: const TextStyle(color: AppColors.goldLight))),
            if (problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(problem, style: t.bodySmall)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('em-confirm'),
          onPressed: problem != null || choice == null ? null : () => Navigator.pop(context, choice),
          child: const Text('Étreindre'),
        ),
      ],
    );
  }
}

/// « Devenir serviteur de… » : domitor, type, rang, coût et dette, motif.
class ServantOfDialog extends ConsumerStatefulWidget {
  const ServantOfDialog({super.key, required this.name});
  final String name;

  @override
  ConsumerState<ServantOfDialog> createState() => _ServantOfDialogState();
}

class _ServantOfDialogState extends ConsumerState<ServantOfDialog> {
  String? _domitorId;
  ServantKind _kind = ServantKind.human;
  int _rank = 1;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rb = ref.watch(rulebookProvider) ?? const Rulebook();
    final t = Theme.of(context).textTheme;
    final domitors = _vampires(ref);
    final d = domitors.where((c) => c.id == _domitorId).firstOrNull;
    final cost = d == null ? 0 : servantCost(d, _rank, rb: rb);
    final debt = d == null ? 0 : debtOf(withServant(d, '-', widget.name, _kind, _rank, rb: rb));
    final ready = d != null && _reason.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text('${widget.name} devient serviteur'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            key: const Key('so-domitor'),
            initialValue: d?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Domitor'),
            items: [for (final c in domitors) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (id) => setState(() => _domitorId = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ServantKind>(
            key: const Key('so-kind'),
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final k in ServantKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const Key('so-rank'),
            initialValue: _rank,
            decoration: const InputDecoration(labelText: 'Rang'),
            items: [for (var r = 1; r <= 5; r++) DropdownMenuItem(value: r, child: Text('$r'))],
            onChanged: (r) => setState(() => _rank = r ?? _rank),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('so-reason'),
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Motif'),
            onChanged: (_) => setState(() {}),
          ),
          if (d != null) ...[
            const SizedBox(height: 8),
            Text('Coût : $cost XP', style: t.bodyMedium),
            if (debt > 0) Text('Dette de $debt XP pour ${d.name}', style: const TextStyle(color: AppColors.goldLight)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('so-confirm'),
          onPressed: ready ? () => Navigator.pop(context, (d, _kind, _rank, _reason.text.trim())) : null,
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

/// « Devenir goule jouée… » : joueur et domitor.
class GhoulOfDialog extends ConsumerStatefulWidget {
  const GhoulOfDialog({super.key, required this.name});
  final String name;

  @override
  ConsumerState<GhoulOfDialog> createState() => _GhoulOfDialogState();
}

class _GhoulOfDialogState extends ConsumerState<GhoulOfDialog> {
  String? _playerUid;
  String? _domitorId;

  @override
  Widget build(BuildContext context) {
    final players = _players(ref);
    final domitors = _vampires(ref);
    final player = players.where((u) => u.uid == _playerUid).firstOrNull;
    final d = domitors.where((c) => c.id == _domitorId).firstOrNull;
    return AlertDialog(
      title: Text('${widget.name} devient goule jouée'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            key: const Key('gh-player'),
            initialValue: player?.uid,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Joueur'),
            items: [for (final u in players) DropdownMenuItem(value: u.uid, child: Text(u.displayName))],
            onChanged: (uid) => setState(() => _playerUid = uid),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('gh-domitor'),
            initialValue: d?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Domitor'),
            items: [for (final c in domitors) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (id) => setState(() => _domitorId = id),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          key: const Key('gh-confirm'),
          onPressed: player != null && d != null ? () => Navigator.pop(context, (player, d)) : null,
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
