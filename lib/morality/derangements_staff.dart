import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_edit_screen.dart' show askReason;
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../offline/offline.dart';
import '../rulebook/rulebook.dart';
import 'derangement_form.dart';
import 'derangement_rules.dart';

/// Bloc « Dérangements » du conte (C-Moralite) : liste, à détailler, compteur de traits en jeu.
class StaffDerangements extends ConsumerStatefulWidget {
  const StaffDerangements({super.key, required this.character, required this.rb, required this.canEdit});

  final Character character;
  final Rulebook rb;
  final bool canEdit;

  @override
  ConsumerState<StaffDerangements> createState() => _StaffDerangementsState();
}

class _StaffDerangementsState extends ConsumerState<StaffDerangements> {
  /// Dérangement ouvert dans le formulaire ; null : formulaire fermé.
  Derangement? _editing;
  int _form = 0;
  bool _busy = false;

  Character get c => widget.character;

  void _open(Derangement? d) => setState(() {
        _editing = d;
        _form++;
      });

  Future<bool> _write(Character after, String reason) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return false;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(characterRepositoryProvider).saveEdit(c, after, reason, by);
      messenger.showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      return true;
    } catch (e) {
      final latest = ref.read(characterProvider(c.id)).value;
      final moved = latest != null && latest.version != c.version;
      messenger.showSnackBar(SnackBar(content: Text(refusalText(e, moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.'))));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ajout, modification ou retrait : modification tracée, avec motif.
  Future<void> _saveList(Character after) async {
    final changes = describeChanges(c, after);
    if (changes.isEmpty) return;
    final reason = await askReason(context, changes);
    if (reason == null || !mounted) return;
    if (await _write(after, reason) && mounted) _open(null);
  }

  Future<void> _submit(Derangement d) async {
    final after = c.clone();
    final i = after.derangements.indexWhere((x) => x.id == d.id);
    if (i < 0) {
      after.derangements.add(d);
    } else {
      after.derangements[i] = d;
    }
    await _saveList(after);
  }

  Future<void> _setTraits(int n) async {
    final after = c.clone()..derangementTraits = clampTraits(c, n);
    if (after.derangementTraits == c.derangementTraits) return;
    await _write(after, 'Traits de dérangement');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserProvider); // garde le flux de l'acteur abonné pour _write
    final t = Theme.of(context).textTheme;
    // Une fiche en création ou en validation se modifie dans le parcours de création, pas ici.
    final ro = !widget.canEdit || !(c.kind == CharacterKind.pnj || c.status.settled);
    final floor = traitsFloor(c);
    final traits = clampTraits(c, c.derangementTraits);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Dérangements'),
        const SizedBox(height: 8),
        if (c.derangements.isEmpty) Text('Aucun dérangement.', style: t.bodyMedium),
        for (final d in c.derangements)
          DerangementTile(
            d,
            trailing: ro
                ? null
                : Wrap(spacing: 4, children: [
                    TextButton(key: Key('de-edit-${d.id}'), onPressed: _busy ? null : () => _open(d.copy()), child: const Text('Modifier')),
                    TextButton(
                      key: Key('de-remove-${d.id}'),
                      onPressed: _busy ? null : () => _saveList(c.clone()..derangements.removeWhere((x) => x.id == d.id)),
                      child: const Text('Retirer', style: TextStyle(color: AppColors.linkHover)),
                    ),
                  ]),
          ),
        if (!ro)
          for (final f in toDetail(c, widget.rb))
            Row(children: [
              Expanded(child: Text('${f.name} · handicap ${f.level} pts', style: t.bodyMedium)),
              TextButton(
                key: Key('de-detail-${f.name}'),
                onPressed: _busy ? null : () => _open(fromModel(widget.rb, f.name, id: newDerangementId(c.id))..severe = f.level >= 3),
                child: const Text('Détailler'),
              ),
            ]),
        if (!ro && _editing == null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('de-add'),
              onPressed: _busy ? null : () => _open(Derangement(newDerangementId(c.id), '')),
              child: const Text('+ Ajouter'),
            ),
          ),
        if (!ro && _editing != null) ...[
          const SizedBox(height: 12),
          DerangementForm(
            key: ValueKey('de-form-$_form'),
            rb: widget.rb,
            initial: _editing!,
            existing: c.derangements,
            busy: _busy,
            actionLabel: c.derangements.any((x) => x.id == _editing!.id) ? 'Enregistrer' : 'Ajouter',
            onSubmit: (d, _) => _submit(d),
            onCancel: () => _open(null),
          ),
        ],
        const SizedBox(height: 16),
        Text('Traits de dérangement en jeu', style: t.labelMedium),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!ro)
            IconButton(
              key: const Key('de-minus'),
              tooltip: 'Retirer un trait',
              onPressed: _busy || traits <= floor ? null : () => _setTraits(traits - 1),
              icon: const Icon(Icons.remove),
            ),
          Text('●' * traits + '○' * (3 - traits), key: const Key('de-traits'), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
          if (!ro)
            IconButton(
              key: const Key('de-plus'),
              tooltip: 'Ajouter un trait',
              onPressed: _busy || traits >= 3 ? null : () => _setTraits(traits + 1),
              icon: const Icon(Icons.add),
            ),
          if (floor == 1) Text('min. 1 (Malkavien)', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
        if (traits >= 3) ...[
          Text('Réaction extrême, puis retour à 0.', style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
          if (!ro)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(key: const Key('de-reset'), onPressed: _busy ? null : () => _setTraits(floor), child: const Text('Revenir au plancher')),
            ),
        ],
      ]),
    );
  }
}
