import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import 'item.dart';

/// Catégorie du référentiel qui porte les qualités d'objets.
const equipmentCat = 'equipment';

/// Règles de base d'une catégorie (paramètres du référentiel) ; 2 et 1 qualités par défaut.
class CategoryRules {
  const CategoryRules({this.damage = '', this.hands, this.normal = 2, this.cheap = 1});
  final String damage;
  final int? hands;
  final int normal;
  final int cheap;

  int max(ItemGrade g) => g == ItemGrade.normal ? normal : cheap;
}

int? _n(Object? v) => v is num && v >= 0 ? v.toInt() : null;

CategoryRules categoryRules(Rulebook rb, ItemCategory c) {
  final rows = rb.settings[equipmentCat]?['rules'];
  final row = rows is List ? rows.whereType<Map>().where((r) => r['category'] == c.name).firstOrNull : null;
  if (row == null) return const CategoryRules();
  return CategoryRules(
    damage: '${row['damage'] ?? ''}'.trim(),
    hands: _n(row['hands']),
    normal: _n(row['qualitiesNormal']) ?? 2,
    cheap: _n(row['qualitiesCheap']) ?? 1,
  );
}

/// « Arme de mêlée : dégâts 1 normal · 1 main » ; vide sans règle de base.
String rulesText(Rulebook rb, ItemCategory c) {
  final r = categoryRules(rb, c);
  final parts = [
    if (r.damage.isNotEmpty) 'dégâts ${r.damage}',
    if (r.hands case final h?) '$h main${h > 1 ? 's' : ''}',
  ];
  return parts.isEmpty ? '' : '${c.label} : ${parts.join(' · ')}';
}

bool _inCategory(RuleEntry e, ItemCategory c) => ((e.data['categories'] as List?) ?? const []).contains(c.name);
bool _outside(RuleEntry e) => e.data['outsideLimit'] == true;

/// Qualités de la gamme pour [c] : disponibles ou sur accord du conte, hors limite exclues.
List<String> qualityOptions(Rulebook rb, ItemCategory c) =>
    [for (final e in rb.all(equipmentCat)) if (e.state.offered && _inCategory(e, c) && !_outside(e)) e.name];

/// Qualités hors limite pour [c] (posées par le conte).
List<String> extraOptions(Rulebook rb, ItemCategory c) =>
    [for (final e in rb.all(equipmentCat)) if (e.state.offered && _inCategory(e, c) && _outside(e)) e.name];

/// Qualité [i] remplacée par [name] ; null la retire ; au-delà de la liste, ajoutée.
List<String> setQuality(List<String> qualities, int i, String? name) {
  final l = [...qualities];
  if (i < l.length) {
    if (name == null) {
      l.removeAt(i);
    } else {
      l[i] = name;
    }
  } else if (name != null) {
    l.add(name);
  }
  return l;
}

bool _incompatible(Rulebook rb, String a, String b) {
  List<String> of(String x) => [for (final n in (rb.find(equipmentCat, x)?.data['incompatible'] as List?) ?? const []) nameKey('$n')];
  return of(a).contains(nameKey(b)) || of(b).contains(nameKey(a));
}

/// Contrôles d'un objet : les erreurs bloquent l'enregistrement, les avertissements sont signalés au conte.
({List<String> errors, List<String> warnings}) itemChecks(Item i, Rulebook rb, {bool byPlayer = false}) {
  final errors = <String>[];
  final warnings = <String>[];
  if (i.name.trim().isEmpty) errors.add('Nom obligatoire');
  final max = categoryRules(rb, i.category).max(i.grade);
  if (i.qualities.length > max) {
    errors.add('$max qualité${max > 1 ? 's' : ''} au plus pour un objet ${i.grade == ItemGrade.normal ? 'courant' : 'bon marché'}');
  }
  final extra = i.extraQuality;
  if (byPlayer && extra != null) errors.add('Les qualités hors limite sont posées par le conte');
  final all = [...i.qualities, ?extra];
  final seen = <String>{};
  for (final (k, q) in all.indexed) {
    if (!seen.add(nameKey(q))) {
      errors.add('$q en double');
      continue;
    }
    final e = rb.find(equipmentCat, q);
    if (e == null || !_inCategory(e, i.category)) {
      errors.add('$q : pas une qualité de cette catégorie');
      continue;
    }
    if (!e.state.offered) {
      errors.add('$q est interdite');
      continue;
    }
    if (e.state == RuleState.approval) warnings.add('$q demande l’accord du conte');
    final isExtra = extra != null && k == all.length - 1;
    if (!isExtra && _outside(e)) errors.add('$q ne compte pas dans la limite : à poser comme qualité hors limite');
    if (isExtra && !_outside(e)) errors.add('$q compte dans la limite : à choisir parmi les qualités de la gamme');
  }
  for (var a = 0; a < all.length; a++) {
    for (var b = a + 1; b < all.length; b++) {
      if (nameKey(all[a]) != nameKey(all[b]) && _incompatible(rb, all[a], all[b])) errors.add('${all[a]} et ${all[b]} sont incompatibles');
    }
  }
  return (errors: errors, warnings: warnings);
}

/// « Dissimulable · Précise · Chef-d’œuvre (hors limite) » ; « — » sans qualité.
String itemQualitiesText(Item i) {
  final all = [...i.qualities, if (i.extraQuality case final x?) '$x (hors limite)'];
  return all.isEmpty ? '—' : all.join(' · ');
}

String holderText(Item i) => i.characterId.isEmpty ? 'Personne (réserve du conte)' : i.characterName;

/// Résumé des changements pour l'historique.
List<String> itemChanges(Item a, Item b) => [
      if (a.name != b.name) 'Nom : ${a.name} → ${b.name}',
      if (a.category != b.category) 'Catégorie : ${a.category.label} → ${b.category.label}',
      if (a.grade != b.grade) 'Gamme : ${a.grade.label} → ${b.grade.label}',
      if (itemQualitiesText(a) != itemQualitiesText(b)) 'Qualités : ${itemQualitiesText(a)} → ${itemQualitiesText(b)}',
      if (a.characterId != b.characterId) 'Porté par : ${holderText(a)} → ${holderText(b)}',
      if (a.state != b.state) 'État : ${a.state.label} → ${b.state.label}',
      if (a.description != b.description) 'Description modifiée',
      if (a.refusal != b.refusal && b.refusal.isNotEmpty) 'Motif du refus : ${b.refusal}',
    ];
