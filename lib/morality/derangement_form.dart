import 'package:flutter/material.dart';

import '../characters/character.dart';
import '../core/theme.dart';
import '../rulebook/rulebook.dart';
import 'derangement_rules.dart';

/// Un dérangement en lecture : nom, type et points, déclencheur, mention « incurable » pour celui du clan.
class DerangementTile extends StatelessWidget {
  const DerangementTile(this.d, {super.key, this.trailing});
  final Derangement d;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.name, style: t.titleSmall),
        Text('${derangementTypes[d.type] ?? d.type} · ${derangementLine(d)}', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        if (d.trigger.isNotEmpty) Text('Déclencheur : ${d.trigger}', style: t.bodyMedium),
        if (d.clan) Text('Incurable · ne rapporte pas d’XP', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ?trailing,
      ]),
    );
  }
}

/// Formulaire d'un dérangement (conte : ajout ou modification ; joueur : demande).
class DerangementForm extends StatefulWidget {
  const DerangementForm({
    super.key,
    required this.rb,
    required this.initial,
    required this.existing,
    required this.onSubmit,
    required this.actionLabel,
    this.showClan = true,
    this.askWhy = false,
    this.busy = false,
    this.onCancel,
  });

  final Rulebook rb;
  final Derangement initial;

  /// Dérangements déjà portés (ou demandés), pour le contrôle du doublon.
  final List<Derangement> existing;
  final Future<void> Function(Derangement d, String why) onSubmit;
  final String actionLabel;
  final bool showClan;
  final bool askWhy;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  State<DerangementForm> createState() => _DerangementFormState();
}

class _DerangementFormState extends State<DerangementForm> {
  late final Derangement _d = widget.initial.copy();
  late final _name = TextEditingController(text: _d.name);
  late final _trigger = TextEditingController(text: _d.trigger);
  final _why = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _trigger.dispose();
    _why.dispose();
    super.dispose();
  }

  void _model(String? name) {
    if (name == null) return;
    final m = fromModel(widget.rb, name, id: _d.id);
    setState(() {
      _d
        ..name = m.name
        ..type = m.type;
      _name.text = m.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    _d
      ..name = _name.text.trim()
      ..trigger = _trigger.text.trim();
    final errors = [
      ...derangementChecks(_d, widget.existing),
      if (widget.askWhy && _why.text.trim().isEmpty) 'Indiquez pourquoi.',
    ];
    final models = widget.rb.offeredNames(derangementsCat);
    void touch(String _) => setState(() {});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (models.isNotEmpty)
        DropdownButtonFormField<String>(
          key: const Key('de-model'),
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Modèle (facultatif)'),
          items: [for (final m in models) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: _model,
        ),
      const SizedBox(height: 12),
      TextField(key: const Key('de-name'), controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Nom'), onChanged: touch),
      KeyedSubtree(
        key: ValueKey('de-type-${_d.type}'),
        child: DropdownButtonFormField<String>(
          key: const Key('de-type'),
          initialValue: derangementTypes.containsKey(_d.type) ? _d.type : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final e in derangementTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _d.type = v ?? _d.type),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('de-trigger'),
        controller: _trigger,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Déclencheur'),
        onChanged: touch,
      ),
      CheckboxListTile(
        key: const Key('de-severe'),
        value: _d.severe,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Sévère (3 points)'),
        onChanged: (v) => setState(() => _d.severe = v ?? false),
      ),
      if (widget.showClan)
        CheckboxListTile(
          key: const Key('de-clan'),
          value: _d.clan,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Dérangement de clan'),
          onChanged: (v) => setState(() => _d.clan = v ?? false),
        ),
      if (widget.askWhy)
        TextField(key: const Key('de-why'), controller: _why, maxLines: 2, decoration: const InputDecoration(labelText: 'Pourquoi ?'), onChanged: touch),
      for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton(
          key: const Key('de-save'),
          onPressed: widget.busy || errors.isNotEmpty ? null : () => widget.onSubmit(_d.copy(), _why.text.trim()),
          child: Text(widget.actionLabel),
        ),
        if (widget.onCancel != null) TextButton(onPressed: widget.onCancel, child: const Text('Annuler')),
      ]),
    ]);
  }
}
