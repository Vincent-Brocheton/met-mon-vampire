import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'rule_entry.dart';
import 'schema.dart';

/// Un champ du schéma. [value] est la valeur JSON actuelle ; [onChanged] reçoit null pour « vide ».
class RuleFieldEditor extends StatelessWidget {
  const RuleFieldEditor(this.field, this.value, this.onChanged, {super.key, this.keyOptions = const {}, this.enabled = true, this.keyPrefix = 'rf'});

  final RuleField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final Map<String, List<String>> keyOptions;
  final bool enabled;
  final String keyPrefix;

  String get _k => '$keyPrefix-${field.key}';

  List<DropdownMenuItem<String?>> get _items => [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        for (final o in field.options) DropdownMenuItem<String?>(value: o.$1, child: Text(o.$2)),
      ];

  @override
  Widget build(BuildContext context) {
    final f = field;
    final t = Theme.of(context).textTheme;
    InputDecoration deco([String? label]) => InputDecoration(labelText: label ?? f.label, helperText: f.help);
    switch (f.type) {
      case FieldType.text || FieldType.longText:
        return TextFormField(
          key: Key(_k),
          initialValue: value as String? ?? '',
          enabled: enabled,
          maxLines: f.type == FieldType.longText ? 3 : 1,
          decoration: deco(),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
        );
      case FieldType.number:
        return TextFormField(
          key: Key(_k),
          initialValue: value == null ? '' : '$value',
          enabled: enabled,
          keyboardType: TextInputType.number,
          // Entier seulement : une saisie invalide est refusée au lieu d'effacer la valeur.
          inputFormatters: [TextInputFormatter.withFunction((old, next) => RegExp(r'^-?\d*$').hasMatch(next.text) ? next : old)],
          decoration: deco(),
          onChanged: (v) => onChanged(int.tryParse(v.trim())),
        );
      case FieldType.choice:
        return DropdownButtonFormField<String?>(
          key: Key(_k),
          initialValue: f.options.any((o) => o.$1 == value) ? value as String : null,
          isExpanded: true,
          decoration: deco(),
          items: _items,
          onChanged: enabled ? onChanged : null,
        );
      case FieldType.multi:
        final selected = [...(value as List?)?.cast<String>() ?? const <String>[]];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: t.labelMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in f.options)
              FilterChip(
                key: Key('$_k-${o.$1}'),
                label: Text(o.$2),
                selected: selected.contains(o.$1),
                onSelected: !enabled
                    ? null
                    : (on) {
                        final next = [for (final x in f.options) if (x.$1 == o.$1 ? on : selected.contains(x.$1)) x.$1];
                        onChanged(next.isEmpty ? null : next);
                      },
              ),
          ]),
        ]);
      case FieldType.flag:
        return CheckboxListTile(
          key: Key(_k),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(f.label),
          value: value == true,
          onChanged: enabled ? (v) => onChanged(v == true ? true : null) : null,
        );
      case FieldType.list:
        return TextFormField(
          key: Key(_k),
          initialValue: ((value as List?) ?? const []).join('\n'),
          enabled: enabled,
          minLines: 2,
          maxLines: null,
          decoration: deco('${f.label} — une valeur par ligne'),
          onChanged: (v) {
            final items = [for (final l in v.split('\n')) if (l.trim().isNotEmpty) l.trim()];
            onChanged(items.isEmpty ? null : items);
          },
        );
      case FieldType.keyed:
        final map = Map<String, dynamic>.from((value as Map?) ?? const {});
        final keys = keyOptions[f.keysFrom] ?? const <String>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(f.label, style: t.labelMedium),
          if (keys.isEmpty) Text('Aucune entrée dans « ${categoryById(f.keysFrom!)?.label ?? f.keysFrom} ».', style: t.bodySmall),
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: Text(k, style: t.bodyMedium)),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    key: Key('$_k-$k'),
                    initialValue: f.options.any((o) => o.$1 == map[k]) ? map[k] as String : null,
                    isExpanded: true,
                    items: _items,
                    onChanged: !enabled
                        ? null
                        : (v) {
                            final next = {...map};
                            if (v == null) {
                              next.remove(k);
                            } else {
                              next[k] = v;
                            }
                            onChanged(next.isEmpty ? null : next);
                          },
                  ),
                ),
              ]),
            ),
        ]);
      case FieldType.rows:
        final rows = [for (final r in (value as List?) ?? const []) Map<String, dynamic>.from(r as Map)];
        void set(List<Map<String, dynamic>> next) => onChanged(next.isEmpty ? null : next);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(f.label, style: t.labelMedium),
          for (final (i, row) in rows.indexed)
            Container(
              // La longueur dans la clé : retirer une ligne reconstruit les champs des suivantes.
              key: ValueKey('$_k-row-$i-${rows.length}'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final sub in f.rowFields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RuleFieldEditor(
                      sub,
                      row[sub.key],
                      (v) {
                        final next = [for (final r in rows) {...r}];
                        if (v == null) {
                          next[i].remove(sub.key);
                        } else {
                          next[i][sub.key] = v;
                        }
                        set(next);
                      },
                      enabled: enabled,
                      keyPrefix: '$_k-$i',
                    ),
                  ),
                if (enabled)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => set([for (final (j, r) in rows.indexed) if (j != i) r]),
                      child: const Text('Retirer la ligne'),
                    ),
                  ),
              ]),
            ),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(key: Key('$_k-add'), onPressed: () => set([...rows, <String, dynamic>{}]), child: const Text('+ Ajouter')),
            ),
        ]);
    }
  }
}

/// Panneau d'édition d'un élément, construit depuis le schéma de sa catégorie.
class RuleEntryForm extends StatefulWidget {
  const RuleEntryForm({
    super.key,
    required this.category,
    required this.entry,
    this.keyOptions = const {},
    this.existingNames = const {},
    this.readOnly = false,
    this.note = '',
    this.usage,
    required this.onSave,
    this.onDelete,
    this.onDirty,
  });

  final RuleCategory category;
  final RuleEntry entry;
  final Map<String, List<String>> keyOptions;

  /// Noms (nameKey) des autres éléments de la catégorie.
  final Set<String> existingNames;
  final bool readOnly;
  final String note;

  /// Fiches qui portent ce nom (null : non suivi).
  final int? usage;
  final Future<void> Function(RuleEntry entry, String note) onSave;
  final Future<void> Function()? onDelete;

  /// Première modification non enregistrée.
  final VoidCallback? onDirty;

  @override
  State<RuleEntryForm> createState() => _RuleEntryFormState();
}

class _RuleEntryFormState extends State<RuleEntryForm> {
  late final RuleEntry _e = widget.entry.copy();
  late final _note = TextEditingController(text: widget.note);
  String? _error;
  bool _busy = false;
  bool _dirty = false;

  void _touch() {
    if (_dirty) return;
    _dirty = true;
    widget.onDirty?.call();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _e.name.trim();
    final error = name.isEmpty
        ? 'Le nom est obligatoire.'
        : name.length > 80
            ? 'Le nom fait 80 caractères au plus.'
            : widget.existingNames.contains(nameKey(name))
                ? 'Un élément porte déjà ce nom.'
                : null;
    setState(() {
      _error = error;
      _busy = error == null;
    });
    if (error != null) return;
    try {
      await widget.onSave(_e..name = name, _note.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ro = widget.readOnly;
    final usage = widget.usage;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_e.id.isEmpty ? 'Nouvel élément' : 'Modifier l’élément'),
      const SizedBox(height: 12),
      gap(TextFormField(
        key: const Key('rf-name'),
        initialValue: _e.name,
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Nom'),
        onChanged: (v) {
          _e.name = v;
          _touch();
        },
      )),
      gap(TextFormField(
        key: const Key('rf-vo'),
        initialValue: _e.vo ?? '',
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Nom VO — pour retrouver la règle'),
        onChanged: (v) {
          _e.vo = v.trim().isEmpty ? null : v.trim();
          _touch();
        },
      )),
      gap(DropdownButtonFormField<RuleState>(
        key: const Key('rf-state'),
        initialValue: _e.state,
        decoration: const InputDecoration(labelText: 'État'),
        items: [for (final s in RuleState.values) DropdownMenuItem(value: s, child: Text(s.label))],
        onChanged: ro
            ? null
            : (s) {
                setState(() => _e.state = s ?? _e.state);
                _touch();
              },
      )),
      for (final f in widget.category.fields)
        gap(RuleFieldEditor(
          f,
          _e.data[f.key],
          (v) {
            setState(() {
              if (v == null) {
                _e.data.remove(f.key);
              } else {
                _e.data[f.key] = v;
              }
            });
            _touch();
          },
          keyOptions: widget.keyOptions,
          enabled: !ro,
        )),
      gap(TextFormField(
        key: const Key('rf-description'),
        initialValue: _e.description,
        enabled: !ro,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Règle affichée aux joueurs', hintText: 'Résumé de l’effet, rédigé par le conte'),
        onChanged: (v) {
          _e.description = v.trim();
          _touch();
        },
      )),
      gap(TextFormField(
        key: const Key('rf-source'),
        initialValue: _e.source ?? '',
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Source', hintText: 'Livre de base, p. …'),
        onChanged: (v) {
          _e.source = v.trim().isEmpty ? null : v.trim();
          _touch();
        },
      )),
      gap(TextFormField(
        key: const Key('rf-note'),
        controller: _note,
        onChanged: (_) => _touch(),
        enabled: !ro,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note réservée au conte'),
      )),
      if (usage != null)
        Text('Présent sur $usage fiche${usage == 1 ? '' : 's'}. Changer une valeur ne modifie pas les fiches existantes.', style: t.bodySmall),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      ],
      if (!ro) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(key: const Key('rf-save'), onPressed: _busy ? null : _save, child: const Text('Enregistrer'))),
          if (widget.onDelete != null) ...[
            const SizedBox(width: 10),
            TextButton(key: const Key('rf-delete'), onPressed: _busy ? null : widget.onDelete, child: const Text('Supprimer')),
          ],
        ]),
      ],
    ]);
  }
}
