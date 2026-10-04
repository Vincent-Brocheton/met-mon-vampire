import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'character.dart';
import 'describe_changes.dart';

const _other = '\u0000autre';

/// Valeur chiffrée avec − / +.
class PointsField extends StatelessWidget {
  const PointsField({super.key, required this.label, required this.value, required this.onChanged, this.max = 10, this.asDots = true});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int max;
  final bool asDots;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        IconButton(
          tooltip: 'Retirer un point : $label',
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 90,
          child: Text(
            asDots ? dots(value) : '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gold, letterSpacing: 2),
          ),
        ),
        IconButton(
          tooltip: 'Ajouter un point : $label',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ]);
}

/// Texte libre, aligné sur les autres champs.
class TextFieldRow extends StatelessWidget {
  const TextFieldRow({super.key, required this.label, required this.value, required this.onChanged, this.maxLines = 1});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: Key('field-$label'),
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => onChanged(v.trim().isEmpty ? null : v),
      );
}

Future<String?> _askOther(BuildContext context, String label) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(label),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Valeur')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: const Text('Valider'),
        ),
      ],
    ),
  );
}

/// Menu sur une liste de règles, plus « Autre… ». Une valeur hors liste reste proposée.
class ChoiceField extends StatelessWidget {
  const ChoiceField({super.key, required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final all = [...options, if (v != null && !options.contains(v)) v];
    return DropdownButtonFormField<String?>(
      key: ValueKey('$label-$v'),
      initialValue: v,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        for (final o in all) DropdownMenuItem<String?>(value: o, child: Text(o)),
        const DropdownMenuItem<String?>(value: _other, child: Text('Autre…')),
      ],
      onChanged: (o) async {
        if (o == _other) {
          final custom = await _askOther(context, label);
          if (custom != null) onChanged(custom);
        } else {
          onChanged(o);
        }
      },
    );
  }
}

/// Compétences, historiques, atouts, handicaps : nom, points, note.
class TraitListEditor extends StatelessWidget {
  const TraitListEditor({
    super.key,
    required this.items,
    required this.options,
    required this.onChanged,
    this.noteLabel,
    this.max = 5,
    this.asDots = true,
  });

  final List<Trait> items;
  final List<String> options;
  final VoidCallback onChanged;
  final String? noteLabel;
  final int max;
  final bool asDots;

  @override
  Widget build(BuildContext context) {
    final remaining = options.where((o) => !items.any((t) => t.name == o)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final t in items)
        Container(
          key: ObjectKey(t), // l'état des champs suit la ligne, pas sa position
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: PointsField(
                  label: t.name,
                  value: t.level,
                  max: max,
                  asDots: asDots,
                  onChanged: (v) {
                    t.level = v;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Retirer ${t.name}',
                onPressed: () {
                  items.remove(t);
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ]),
            if (noteLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  initialValue: t.note,
                  decoration: InputDecoration(labelText: noteLabel, isDense: true),
                  onChanged: (v) {
                    t.note = v.trim().isEmpty ? null : v;
                    onChanged();
                  },
                ),
              ),
          ]),
        ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: ValueKey('add-${items.length}'),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ajouter…'),
        items: [
          for (final o in remaining) DropdownMenuItem(value: o, child: Text(o)),
          const DropdownMenuItem(value: _other, child: Text('Autre…')),
        ],
        onChanged: (o) async {
          final name = o == _other ? await _askOther(context, 'Ajouter') : o;
          if (name == null) return;
          items.add(Trait(name, 1));
          onChanged();
        },
      ),
    ]);
  }
}

/// Disciplines : niveau, en clan, pouvoirs.
class DisciplineListEditor extends StatelessWidget {
  const DisciplineListEditor({super.key, required this.items, required this.options, required this.onChanged});

  final List<Discipline> items;
  final List<String> options;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final remaining = options.where((o) => !items.any((d) => d.name == o)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final d in items)
        Container(
          key: ObjectKey(d),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: PointsField(
                  label: d.name,
                  value: d.level,
                  max: 5,
                  onChanged: (v) {
                    d.level = v;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Retirer ${d.name}',
                onPressed: () {
                  items.remove(d);
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ]),
            SwitchListTile(
              value: d.inClan,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('En clan'),
              onChanged: (v) {
                d.inClan = v;
                onChanged();
              },
            ),
            TextFormField(
              initialValue: d.powers.join(', '),
              decoration: const InputDecoration(labelText: 'Pouvoirs (séparés par des virgules)', isDense: true),
              onChanged: (v) {
                d.powers = [for (final p in v.split(',')) if (p.trim().isNotEmpty) p.trim()];
                onChanged();
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: ValueKey('add-discipline-${items.length}'),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ajouter une discipline…'),
        items: [
          for (final o in remaining) DropdownMenuItem(value: o, child: Text(o)),
          const DropdownMenuItem(value: _other, child: Text('Autre…')),
        ],
        onChanged: (o) async {
          final name = o == _other ? await _askOther(context, 'Discipline') : o;
          if (name == null) return;
          items.add(Discipline(name, 1));
          onChanged();
        },
      ),
    ]);
  }
}

/// Rituels, techniques, pouvoirs d'anciens : des noms, ajoutés depuis le référentiel ou saisis.
class NameListEditor extends StatelessWidget {
  const NameListEditor({super.key, required this.label, required this.items, required this.options, required this.onAdd, required this.onRemove});

  final String label;
  final List<String> items;
  final List<String> options;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final remaining = options.where((o) => !items.contains(o)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (items.isEmpty) Text('Aucun.', style: Theme.of(context).textTheme.bodySmall),
      for (final n in items)
        Row(children: [
          Expanded(child: Text(n)),
          IconButton(tooltip: 'Retirer $n', onPressed: () => onRemove(n), icon: const Icon(Icons.close, size: 18)),
        ]),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: ValueKey('add-$label-${items.length}'),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ajouter…'),
        items: [
          for (final o in remaining) DropdownMenuItem(value: o, child: Text(o)),
          const DropdownMenuItem(value: _other, child: Text('Autre…')),
        ],
        onChanged: (o) async {
          final name = o == _other ? await _askOther(context, label) : o;
          // « Autre… » peut redonner un nom déjà présent.
          if (name != null && !items.contains(name)) onAdd(name);
        },
      ),
    ]);
  }
}

/// Serviteurs (C3) : nom, type, rang ; l'identifiant reste celui de la fiche détaillée.
class ServantListEditor extends StatelessWidget {
  const ServantListEditor({super.key, required this.characterId, required this.items, required this.onChanged});

  final String characterId;
  final List<Servant> items;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final s in items)
        Container(
          key: ObjectKey(s),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('servant-name-${s.id}'),
                  initialValue: s.name,
                  decoration: const InputDecoration(labelText: 'Nom', isDense: true),
                  onChanged: (v) {
                    s.name = v.trim();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<ServantKind>(
                  initialValue: s.kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true),
                  items: [for (final k in ServantKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
                  onChanged: (k) {
                    s.kind = k ?? s.kind;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Retirer ${s.name}',
                onPressed: () {
                  items.remove(s);
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ]),
            PointsField(
              label: 'Rang',
              value: s.rank,
              max: 5,
              onChanged: (v) {
                s.rank = v.clamp(1, 5);
                onChanged();
              },
            ),
          ]),
        ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () {
            items.add(Servant(newServantId(characterId), 'Nouveau serviteur', ServantKind.human, 1));
            onChanged();
          },
          child: const Text('+ Serviteur'),
        ),
      ),
    ]);
  }
}
