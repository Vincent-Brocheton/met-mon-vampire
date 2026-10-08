import 'package:flutter/material.dart';

import '../characters/character.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/theme.dart';
import '../rulebook/rulebook.dart';
import 'ally_fields.dart';
import 'ally_rules.dart';

/// Alliés de la fiche dans C3 : ajout, modification, retrait. Les contrôles sont des avertissements.
class AllyListEditor extends StatelessWidget {
  const AllyListEditor({super.key, required this.characterId, required this.items, required this.rb, required this.onChanged});

  final String characterId;
  final List<Ally> items;
  final Rulebook rb;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final a in items)
        Container(
          key: ObjectKey(a),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('${a.name} ${dots(a.level)}', style: t.titleSmall)),
              IconButton(
                tooltip: 'Retirer ${a.name}',
                onPressed: () {
                  items.remove(a);
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ]),
            AllyFields(ally: a, rb: rb, prefix: 'c3-ally-${a.id}', onChanged: onChanged),
            for (final w in allyChecks(a, rb)) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
          ]),
        ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: () {
            items.add(Ally(newAllyId(characterId), 'Nouvel allié', type: allyTypes(rb).first, domain: allyDomains(rb).first));
            onChanged();
          },
          child: const Text('+ Allié'),
        ),
      ),
    ]);
  }
}
