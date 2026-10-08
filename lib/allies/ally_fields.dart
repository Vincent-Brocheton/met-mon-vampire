import 'package:flutter/material.dart';

import '../characters/character.dart';
import '../rulebook/rulebook.dart';
import 'ally_rules.dart';

/// Spécialisations ramenées au nombre de places (niveau − Influence) ; Influence remise à zéro si trop haute.
void fitAlly(Ally a) {
  if (a.influence > a.level) a.influence = 0;
  final slots = a.level - influenceSlots(a.influence);
  if (a.specialties.length > slots) a.specialties = a.specialties.sublist(0, slots);
}

/// Champs d'un allié (nom, type, domaine, niveau, Influence, spécialisations), modifiés en place.
class AllyFields extends StatelessWidget {
  const AllyFields({
    super.key,
    required this.ally,
    required this.rb,
    required this.onChanged,
    required this.prefix,
    this.maxLevel,
    this.minLevel = 1,
    this.nameEditable = true,
  });

  final Ally ally;
  final Rulebook rb;
  final VoidCallback onChanged;
  final String prefix;
  final int? maxLevel;
  final int minLevel;
  final bool nameEditable;

  @override
  Widget build(BuildContext context) {
    final a = ally;
    final top = maxLevel ?? allyMaxLevel(rb);
    final slots = (a.level - influenceSlots(a.influence)).clamp(0, 99);
    final options = allySpecialtyOptions(rb);
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    Widget pick<T>(String key, String label, T? value, List<(T, String)> items, void Function(T? v) set) => KeyedSubtree(
          key: ValueKey('$prefix-$key/$value/${a.level}/${a.influence}'),
          child: DropdownButtonFormField<T>(
            key: Key('$prefix-$key'),
            isExpanded: true,
            initialValue: items.any((x) => x.$1 == value) ? value : null,
            decoration: InputDecoration(labelText: label),
            items: [for (final (v, l) in items) DropdownMenuItem<T>(value: v, child: Text(l))],
            onChanged: (v) {
              set(v);
              onChanged();
            },
          ),
        );
    String slotsText(int i) => 'Influence $i · prend ${influenceSlots(i)} spécialisation${influenceSlots(i) > 1 ? 's' : ''}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      gap(TextFormField(
        key: Key('$prefix-name'),
        initialValue: a.name,
        enabled: nameEditable,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nom et fonction'),
        onChanged: (v) {
          a.name = v.trim();
          onChanged();
        },
      )),
      gap(Row(children: [
        Expanded(child: pick<String>('type', 'Type', a.type, [for (final t in allyTypes(rb)) (t, t)], (v) => a.type = v ?? a.type)),
        const SizedBox(width: 10),
        Expanded(child: pick<String>('domain', 'Domaine', a.domain, [for (final d in allyDomains(rb)) (d, d)], (v) => a.domain = v ?? a.domain)),
      ])),
      gap(Row(children: [
        Expanded(
          child: pick<int>('level', 'Niveau', a.level, [for (var n = minLevel; n <= top; n++) (n, '$n')], (v) {
            a.level = v ?? a.level;
            fitAlly(a);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: pick<int>('influence', 'Influence', a.influence, [
            (0, 'Aucune'),
            for (final i in influenceLevels)
              if (i <= a.level) (i, slotsText(i)),
          ], (v) {
            a.influence = v ?? 0;
            fitAlly(a);
          }),
        ),
      ])),
      for (var i = 0; i < slots; i++)
        gap(pick<String>(
          'spec$i',
          'Spécialisation ${i + 1 + influenceSlots(a.influence)}',
          i < a.specialties.length ? a.specialties[i] : null,
          [
            for (final o in [...options, if (i < a.specialties.length && !options.contains(a.specialties[i])) a.specialties[i]])
              (o, needsInfluence(rb, o) ? '$o · si Influent' : o),
          ],
          (v) {
            if (v == null) return;
            if (i < a.specialties.length) {
              a.specialties[i] = v;
            } else {
              a.specialties.add(v);
            }
          },
        )),
      Text(allySummary(a, rb), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
