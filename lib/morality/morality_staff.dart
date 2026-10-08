import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_edit_screen.dart' show askReason;
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../events/story_event.dart';
import '../npcs/loan_rules.dart' show formatLoanDay, parseDay;
import '../rulebook/rulebook.dart';
import 'morality_rules.dart';
import 'sin.dart';
import 'sins_repository.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _traits(int n) => '$n trait${n > 1 ? 's' : ''}';

/// Vue du conte (C-Moralite) : voie et valeur, saisie des péchés, traits de Bête de la soirée et perte.
class StaffMorality extends ConsumerStatefulWidget {
  const StaffMorality({super.key, required this.character, required this.sins, required this.rb, required this.canEdit});

  final Character character;
  final List<Sin> sins;
  final Rulebook rb;
  final bool canEdit;

  @override
  ConsumerState<StaffMorality> createState() => _StaffMoralityState();
}

class _StaffMoralityState extends ConsumerState<StaffMorality> {
  /// Péché ouvert dans le formulaire ; null : nouveau péché.
  Sin? _editing;

  /// Soirée choisie ; null : la plus récente.
  DateTime? _evening;
  int _form = 0;
  bool _busy = false;

  Character get c => widget.character;

  void _edit(Sin? s) => setState(() {
        _editing = s?.copy();
        _form++;
      });

  Future<void> _write(Future<void> Function(Actor by) action, String done) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(by);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      final latest = ref.read(characterProvider(c.id)).value;
      final moved = latest != null && latest.version != c.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Modification tracée de la fiche (voie ou valeur), avec motif.
  Future<void> _saveSheet(Character after, {List<StoryEvent> events = const []}) async {
    final changes = describeChanges(c, after);
    if (changes.isEmpty) return;
    final reason = await askReason(context, changes);
    if (reason == null || !mounted) return;
    await _write((by) => ref.read(characterRepositoryProvider).saveEdit(c, after, reason, by, events: events), 'Fiche enregistrée.');
  }

  Future<void> _changePath(String? path) async {
    final after = changePath(c, widget.rb, path);
    if (after.path == c.path) return;
    await _saveSheet(after, events: [pathEvent(after, DateTime.now())]);
  }

  Future<void> _delete(Sin s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le péché ?'),
        content: Text('Niveau ${s.level} · ${s.what}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(key: const Key('sin-delete-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _write((by) => ref.read(sinsRepositoryProvider).delete(c.id, s.id), 'Péché supprimé.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ro = !widget.canEdit;
    final max = moralityMax(c, widget.rb);

    final paths = <String?>[null, for (final e in widget.rb.offered(pathsCat)) e.name];
    if (c.path != null && !paths.contains(c.path)) paths.add(c.path);
    final morality = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Moralité'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in paths)
            ChoiceChip(
              key: Key('mo-path-${p ?? humanityLabel}'),
              label: Text('${p ?? humanityLabel} (max. ${pathMax(widget.rb, p)})'),
              selected: (c.path ?? '') == (p ?? ''),
              onSelected: ro || _busy ? null : (_) => _changePath(p),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          if (!ro)
            IconButton(
              key: const Key('mo-minus'),
              tooltip: 'Retirer un point',
              onPressed: _busy || c.humanity <= 0 ? null : () => _saveSheet(c.clone()..humanity = c.humanity - 1),
              icon: const Icon(Icons.remove),
            ),
          Text('${c.humanity}', style: t.headlineMedium),
          if (!ro)
            IconButton(
              key: const Key('mo-plus'),
              tooltip: 'Ajouter un point',
              onPressed: _busy || c.humanity >= max ? null : () => _saveSheet(c.clone()..humanity = c.humanity + 1),
              icon: const Icon(Icons.add),
            ),
          const SizedBox(width: 12),
          Text(moralityLabel(c.humanity), style: t.titleMedium),
        ]),
        const SizedBox(height: 8),
        Text('Une voie s’obtient avec l’atout de voie. À 0, le personnage sombre dans le wassail et devient un PNJ.',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]),
    );

    final form = ro
        ? null
        : Panel(
            child: SinForm(
              key: ValueKey('sin-form-$_form'),
              character: c,
              rb: widget.rb,
              initial: _editing ?? Sin(id: '', date: dayOf(DateTime.now()), remorse: Remorse.failed),
              busy: _busy,
              onSave: (s) async {
                await _write((by) => ref.read(sinsRepositoryProvider).save(c.id, s, by), s.id.isEmpty ? 'Péché ajouté.' : 'Péché enregistré.');
                if (mounted) _edit(null);
              },
              onCancel: _editing == null ? null : () => _edit(null),
            ),
          );

    final evenings = eveningsOf(widget.sins);
    final current = evenings.where((x) => x.$1 == _evening).firstOrNull ?? evenings.firstOrNull;
    Widget eveningPanel;
    if (current == null) {
      eveningPanel = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Traits de Bête'),
          const SizedBox(height: 8),
          Text('Aucun péché.', style: t.bodyMedium),
        ]),
      );
    } else {
      final (day, list) = current;
      final total = eveningTraits(list);
      eveningPanel = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Traits de Bête · soirée du ${formatLoanDay(day)}'),
          const SizedBox(height: 8),
          if (evenings.length > 1)
            DropdownButtonFormField<DateTime>(
              key: const Key('sin-evening'),
              initialValue: day,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Soirée'),
              items: [for (final (d, _) in evenings) DropdownMenuItem(value: d, child: Text('Soirée du ${formatLoanDay(d)}'))],
              onChanged: (v) => setState(() => _evening = v),
            ),
          const SizedBox(height: 8),
          Text('$total / $lossThreshold', style: t.headlineSmall?.copyWith(color: total >= lossThreshold ? AppColors.accentIcon : AppColors.text)),
          const SizedBox(height: 8),
          for (final s in list)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Niveau ${s.level}', style: t.bodySmall?.copyWith(color: AppColors.goldLight, fontWeight: FontWeight.w600)),
                    Text(s.what, style: t.bodyMedium),
                    Text(s.remorse.label, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    if (!ro && !s.lossApplied)
                      Wrap(children: [
                        TextButton(key: Key('sin-edit-${s.id}'), onPressed: _busy ? null : () => _edit(s), child: const Text('Modifier')),
                        TextButton(
                          key: Key('sin-delete-${s.id}'),
                          onPressed: _busy ? null : () => _delete(s),
                          child: const Text('Supprimer', style: TextStyle(color: AppColors.linkHover)),
                        ),
                      ]),
                  ]),
                ),
                Text('+${sinTraits(s)}', style: t.titleSmall),
              ]),
            ),
          if (list.any((s) => s.lossApplied)) Text('Perte appliquée', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
          if (lossDue(list)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.deadBg, borderRadius: BorderRadius.circular(8)),
              child: Text(lossMessage(c, list), style: t.bodyMedium?.copyWith(color: AppColors.linkHover)),
            ),
            if (!ro) ...[
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('sin-loss'),
                onPressed: _busy ? null : () => _write((by) => ref.read(sinsRepositoryProvider).applyEveningLoss(c, list, by), 'Perte appliquée.'),
                child: const Text('Appliquer la perte'),
              ),
            ],
          ],
        ]),
      );
    }

    if (!isWide(context)) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        morality,
        if (form != null) ...[const SizedBox(height: 20), form],
        const SizedBox(height: 20),
        eveningPanel,
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          morality,
          if (form != null) ...[const SizedBox(height: 20), form],
        ]),
      ),
      const SizedBox(width: 24),
      SizedBox(width: 440, child: eveningPanel),
    ]);
  }
}

/// Formulaire « Enregistrer un péché » : ajout ([initial] sans identifiant) ou modification.
class SinForm extends StatefulWidget {
  const SinForm({
    super.key,
    required this.character,
    required this.rb,
    required this.initial,
    required this.busy,
    required this.onSave,
    this.onCancel,
  });

  final Character character;
  final Rulebook rb;
  final Sin initial;
  final bool busy;
  final Future<void> Function(Sin s) onSave;
  final VoidCallback? onCancel;

  @override
  State<SinForm> createState() => _SinFormState();
}

class _SinFormState extends State<SinForm> {
  late final Sin _s = widget.initial.copy();
  late final _date = TextEditingController(text: _day(_s.date));
  late final _what = TextEditingController(text: _s.what);

  bool get _isNew => _s.id.isEmpty;

  @override
  void dispose() {
    _date.dispose();
    _what.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final levels = sinLevels(widget.character, widget.rb);
    final parsed = parseDay(_date.text);
    _s
      ..date = parsed ?? DateTime(1800)
      ..what = _what.text.trim();
    final errors = sinChecks(_s, widget.character, widget.rb);
    final traits = sinTraits(_s);
    void touch(String _) => setState(() {});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_isNew ? 'Enregistrer un péché' : 'Modifier le péché'),
      const SizedBox(height: 12),
      TextField(
        key: const Key('sin-date'),
        controller: _date,
        decoration: const InputDecoration(labelText: 'Soirée (JJ/MM/AAAA)'),
        onChanged: touch,
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (i, label) in levels.indexed)
          ChoiceChip(
            key: Key('sin-level-${i + 1}'),
            label: Text('Niveau ${i + 1} · $label'),
            selected: _s.level == i + 1,
            onSelected: (_) => setState(() => _s.level = i + 1),
          ),
      ]),
      const SizedBox(height: 12),
      TextField(
        key: const Key('sin-what'),
        controller: _what,
        maxLines: 2,
        maxLength: 500,
        decoration: const InputDecoration(labelText: 'Ce qui s’est passé'),
        onChanged: touch,
      ),
      Text('Test de remords', style: t.labelMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in Remorse.values)
          ChoiceChip(
            key: Key('sin-remorse-${r.name}'),
            label: Text(r.choice),
            selected: _s.remorse == r,
            onSelected: (_) => setState(() => _s.remorse = r),
          ),
      ]),
      const SizedBox(height: 8),
      Text('Mental + Volonté contre 10 + niveau. Le conte peut baisser la difficulté de 5 au plus si c’était justifié.',
          style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      for (final e in [if (parsed == null) 'Date au format JJ/MM/AAAA', ...errors.where((e) => e != 'Date invalide')])
        Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton(
          key: const Key('sin-save'),
          onPressed: widget.busy || parsed == null || errors.isNotEmpty ? null : () => widget.onSave(_s.copy()),
          child: Text(_isNew ? 'Ajouter · ${_traits(traits)}' : 'Enregistrer · ${_traits(traits)}'),
        ),
        if (widget.onCancel != null) TextButton(onPressed: widget.onCancel, child: const Text('Annuler')),
      ]),
    ]);
  }
}
