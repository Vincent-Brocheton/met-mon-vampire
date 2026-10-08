import '../characters/character.dart';
import '../npcs/loan_rules.dart' show formatLoanDay;
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';

/// Catégorie du référentiel : spécialisations des alliés, réglages (niveau maximum, types, domaines).
const alliesCat = 'allies';

const influenceLevels = [2, 4, 5];
const defaultAllyTypes = ['Gotha', 'Pègre'];
const defaultAllyDomains = [
  'Bureaucratie',
  'Crime',
  'Arts & Éducation',
  'Finance & Industrie',
  'Haute Société & Politique',
  'Média',
  'Occulte & Religion',
  'Police',
  'Rue & Transport',
  'Santé & Social',
];

/// Spécialisations occupées par l'Influence : 2 → 1, 4 → 2, 5 → 3.
int influenceSlots(int influence) => switch (influence) {
      2 => 1,
      4 => 2,
      5 => 3,
      _ => 0,
    };

List<String> _list(Object? v) => [for (final x in (v as List?) ?? const []) if ('$x'.trim().isNotEmpty) '$x'.trim()];

int allyMaxLevel(Rulebook rb) => switch (rb.settings[alliesCat]?['maxLevel']) {
      final num n when n >= 1 => n.toInt(),
      _ => 5,
    };

List<String> allyTypes(Rulebook rb) {
  final l = _list(rb.settings[alliesCat]?['types']);
  return l.isEmpty ? defaultAllyTypes : l;
}

List<String> allyDomains(Rulebook rb) {
  final l = _list(rb.settings[alliesCat]?['domains']);
  return l.isEmpty ? defaultAllyDomains : l;
}

bool _isInfluent(String name) => name.trim().toLowerCase().startsWith('influent');

/// Spécialisations proposées : disponibles ou sur accord, sans « Influent » (l'Influence a son propre choix).
List<String> allySpecialtyOptions(Rulebook rb) =>
    [for (final e in rb.all(alliesCat)) if (e.state.offered && !_isInfluent(e.name)) e.name];

/// La spécialisation exige un allié influent (condition « Si Influent » du référentiel).
bool needsInfluence(Rulebook rb, String name) => '${rb.find(alliesCat, name)?.data['condition'] ?? ''}'.toLowerCase().contains('influent');

String _plural(int n, String word) => '$n $word${n > 1 ? 's' : ''}';

/// Erreurs d'un allié (demande du joueur, validation, conversion) ; avertissements dans C3.
List<String> allyChecks(Ally a, Rulebook rb) {
  final out = <String>[];
  final max = allyMaxLevel(rb);
  if (a.name.trim().isEmpty) out.add('Nom obligatoire');
  if (a.level < 1 || a.level > max) out.add('Niveau de 1 à $max');
  if (a.influence != 0 && !influenceLevels.contains(a.influence)) {
    out.add('Influence : 2, 4 ou 5');
  } else if (a.influence > a.level) {
    out.add('Influence ${a.influence} au-delà du niveau de l’allié');
  }
  final expected = a.level - influenceSlots(a.influence);
  if (expected >= 0 && a.specialties.length != expected) {
    final n = a.specialties.length;
    out.add('${_plural(expected, 'spécialisation')} attendue${expected > 1 ? 's' : ''} pour un allié de niveau ${a.level}, '
        '$n choisie${n > 1 ? 's' : ''}');
  }
  final seen = <String>{};
  for (final s in a.specialties) {
    if (!seen.add(nameKey(s))) {
      out.add('$s en double');
      continue;
    }
    final e = rb.find(alliesCat, s);
    if (e == null || !e.state.offered || _isInfluent(s)) {
      out.add('$s : pas une spécialisation d’allié');
      continue;
    }
    if (needsInfluence(rb, s) && a.influence == 0) out.add('$s demande un allié influent');
  }
  if (!allyTypes(rb).contains(a.type)) out.add('Type hors liste');
  if (!allyDomains(rb).contains(a.domain)) out.add('Domaine hors liste');
  return out;
}

int returnMonths(Ally a) => a.specialties.any((s) => nameKey(s) == nameKey('Remplaçable')) ? 2 : a.level;

/// Date de retour après un usage le [usedAt] : N mois (N = niveau), 2 si Remplaçable.
DateTime returnDate(Ally a, DateTime usedAt) => DateTime(usedAt.year, usedAt.month + returnMonths(a), usedAt.day);

/// « Influence 4 prend 2 spécialisations sur 4 : il en reste 2. Retour après usage : 4 mois. »
String allySummary(Ally a, Rulebook rb) {
  final slots = influenceSlots(a.influence);
  final left = a.level - slots;
  final head = a.influence == 0
      ? 'Sans Influence : ${_plural(a.level, 'spécialisation')} à choisir.'
      : 'Influence ${a.influence} prend ${_plural(slots, 'spécialisation')} sur ${a.level} : il en reste $left.';
  return '$head Retour après usage : ${returnMonths(a)} mois.';
}

/// « En attente du conte », « De retour le … » ou « Disponible ».
String allyStatus({required bool pending, required DateTime? returnAt, required DateTime now}) {
  if (pending) return 'En attente du conte';
  if (returnAt != null && now.isBefore(returnAt)) return 'De retour le ${formatLoanDay(returnAt, now: now)}';
  return 'Disponible';
}

/// Anciens historiques encore sur la fiche (à convertir).
List<Trait> legacyAllies(Character c) => [for (final t in c.backgrounds) if (legacyAllyBackgrounds.contains(t.name) && t.level > 0) t];

/// Message si [a] dépasse ce qui reste de l'historique [background] ; null sinon.
String? conversionError(Character c, String background, Ally a) {
  final t = c.backgrounds.where((t) => t.name == background).firstOrNull;
  if (t == null) return 'Historique $background absent de la fiche';
  if (a.level > t.level) return 'Niveau ${a.level} au-delà de l’historique $background (${t.level})';
  return null;
}

/// La fiche après conversion : l'allié ajouté, l'historique diminué d'autant (retiré à 0). Sans mouvement d'XP.
Character convertLegacy(Character c, String background, Ally a) {
  final n = c.clone();
  final t = n.backgrounds.firstWhere((t) => t.name == background);
  t.level -= a.level;
  if (t.level <= 0) n.backgrounds.remove(t);
  n.allies.add(a.copy());
  return n;
}
