import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../npcs/loan_rules.dart' show parseDay;
import 'bond.dart';
import 'bond_rules.dart';

/// Formulaire d'une gorgée (fiche et page de la chronique) : date, nombre, « sait de qui vient ce sang », aperçu.
class DrinkForm extends StatefulWidget {
  const DrinkForm({
    super.key,
    required this.base,
    required this.all,
    required this.today,
    required this.onDrink,
    this.onContact,
    this.errors = const [],
    this.busy = false,
  });

  /// Le lien tel qu'il est (ou nouveau, au niveau 0), noms à jour.
  final Bond base;

  /// Tous les liens connus : liens moindres effacés et refus.
  final List<Bond> all;
  final DateTime today;
  final Future<void> Function(DrinkWrite w) onDrink;

  /// « Noter un simple contact » ; absent pour un lien qui n'existe pas encore.
  final Future<void> Function(Bond contacted)? onContact;

  /// Contrôles du choix des fiches.
  final List<String> errors;
  final bool busy;

  @override
  State<DrinkForm> createState() => _DrinkFormState();
}

class _DrinkFormState extends State<DrinkForm> {
  late final _date = TextEditingController(text: _input(widget.today));
  int _count = 1;
  late bool _known = widget.base.known;

  static String _input(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final day = parseDay(_date.text);
    final validDay = validDrinkDay(day, widget.today);
    final errors = [...widget.errors, if (!validDay) 'Date invalide'];
    final base = widget.base.copy()..known = _known;
    final preview = day == null || !validDay || widget.errors.isNotEmpty ? const <String>[] : drinkPreview(base, widget.all, day, _count);
    final write = day == null || !validDay || widget.errors.isNotEmpty ? null : drinkWrite(base, widget.all, day, _count, _known);
    final canContact = widget.onContact != null && day != null && validDay && effectiveLevel(widget.base, day) > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 160,
            child: TextField(
              key: const Key('dr-date'),
              controller: _date,
              decoration: const InputDecoration(labelText: 'Date (JJ/MM/AAAA)'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int>(
              key: const Key('dr-count'),
              initialValue: _count,
              decoration: const InputDecoration(labelText: 'Gorgées'),
              items: [for (var n = 1; n <= 3; n++) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: (v) => setState(() => _count = v ?? 1),
            ),
          ),
        ]),
        CheckboxListTile(
          key: const Key('dr-known'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _known,
          onChanged: (v) => setState(() => _known = v ?? true),
          title: Text('${widget.base.thrallName} sait de qui vient ce sang'),
        ),
        for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        if (preview.isNotEmpty)
          Container(
            key: const Key('dr-preview'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.deadBg,
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, p) in preview.indexed)
                Text(p, style: i == 0 ? t.titleSmall : t.bodySmall?.copyWith(color: AppColors.linkHover)),
            ]),
          ),
        const SizedBox(height: 8),
        Text(
          'La gorgée s’ajoute aussi aux événements de ${widget.base.thrallName}, visible par le joueur si le lien lui est connu.',
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(
            key: const Key('dr-save'),
            onPressed: write == null || widget.busy ? null : () => widget.onDrink(write),
            child: const Text('Enregistrer la gorgée'),
          ),
          if (canContact)
            OutlinedButton(
              key: const Key('dr-contact'),
              onPressed: widget.busy ? null : () => widget.onContact!(contacted(widget.base, day)),
              child: const Text('Noter un simple contact'),
            ),
        ]),
      ]),
    );
  }
}
