import '../characters/character.dart';
import 'rule_entry.dart';

/// Fiches qui portent ce nom ; null si la catégorie n'apparaît pas encore sur les fiches.
int? usageCount(String cat, String name, List<Character> chars) {
  final k = nameKey(name);
  bool has(Iterable<String> names) => names.any((n) => nameKey(n) == k);
  final bool Function(Character)? test = switch (cat) {
    'merits' => (c) => has(c.merits.map((t) => t.name)),
    'flaws' => (c) => has(c.flaws.map((t) => t.name)),
    'clans' => (c) => has([?c.clan]),
    'disciplines' => (c) => has(c.disciplines.map((d) => d.name)),
    'skills' => (c) => has(c.skills.map((t) => t.name)),
    'backgrounds' => (c) => has(c.backgrounds.map((t) => t.name)),
    'archetypes' => (c) => has([?c.archetype]),
    'sects' => (c) => has([?c.sect]),
    _ => null,
  };
  return test == null ? null : chars.where(test).length;
}
