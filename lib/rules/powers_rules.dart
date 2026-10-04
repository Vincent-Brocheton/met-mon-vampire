import '../characters/character.dart';
import '../characters/describe_changes.dart' show dots;
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';

/// Écoles de magie du référentiel (champ `school`).
const schoolLabels = {'thaumaturgy': 'Thaumaturgie', 'necromancy': 'Nécromancie', 'abyss': 'Mysticisme de l’Abysse'};

String _school(String s) => schoolLabels[s] ?? s;

int _level(Character c, String discipline) =>
    c.disciplines.where((d) => nameKey(d.name) == nameKey(discipline)).fold(0, (s, d) => s + d.level);

bool _knows(Iterable<String> names, String name) => names.any((n) => nameKey(n) == nameKey(name));

String _limit(String school, int points, int count) =>
    '${_school(school)} ${dots(points)} : $points rituel${points > 1 ? 's' : ''} au plus, vous en avez $count';

/// Points des disciplines et voies de l'école sur la fiche.
int schoolDots(Character c, String school, Rulebook rb) => rb.schoolDisciplines(school).fold(0, (s, d) => s + _level(c, d));

/// Pourquoi la fiche ne peut pas apprendre le rituel ; null si elle le peut.
String? ritualError(Character c, String name, Rulebook rb) {
  if (_knows(c.rituals.map((r) => r.name), name)) return 'Rituel déjà connu.';
  final school = rb.ritualSchool(name);
  if (school == null) return 'Rituel sans école dans le référentiel : à demander au conte.';
  final points = schoolDots(c, school, rb);
  if (points == 0) return 'Il faut une discipline ou une voie de l’école ${_school(school)}.';
  final count = c.rituals.where((r) => r.school == school).length;
  if (count + 1 > points) return _limit(school, points, count);
  final level = rb.ritualLevel(name);
  for (var l = 1; l < level; l++) {
    if (!c.rituals.any((r) => r.school == school && r.level == l)) return 'Il manque un rituel de niveau $l';
  }
  return null;
}

/// Prérequis d'une technique : null si au moins une alternative est remplie.
String? prerequisiteError(Character c, String name, Rulebook rb) {
  final alternatives = rb.techniquePrerequisites(name);
  if (alternatives.isEmpty) return rb.hasPrerequisites(name) ? 'Prérequis de $name illisibles : à vérifier par le conte.' : null;
  List<(String, int)> missing(List<(String, int)> alt) => [for (final (d, l) in alt) if (_level(c, d) < l) (d, l)];
  var best = missing(alternatives.first);
  for (final alt in alternatives.skip(1)) {
    final m = missing(alt);
    if (m.length < best.length) best = m;
  }
  if (best.isEmpty) return null;
  return 'Prérequis manquant : ${[for (final (d, l) in best) '$d ${dots(l)}'].join(', ')}';
}

String? techniqueError(Character c, String name, Rulebook rb) {
  if (_knows(c.techniques, name)) return 'Technique déjà connue.';
  final rank = c.genRank ?? GenRank.neonate;
  if (rb.gen(rank).techniqueCost == 0) return 'Techniques interdites au rang ${rank.label}.';
  return prerequisiteError(c, name, rb);
}

String? elderError(Character c, String name, Rulebook rb) {
  if (_knows(c.elderPowers.map((e) => e.name), name)) return 'Pouvoir d’ancien déjà connu.';
  final rank = c.genRank ?? GenRank.neonate;
  final row = rb.gen(rank);
  if (!row.eldersAllowed) return 'Pouvoirs d’anciens interdits au rang ${rank.label}.';
  final discipline = rb.elderDiscipline(name);
  if (discipline == null) return 'Pouvoir d’ancien sans discipline dans le référentiel : à demander au conte.';
  if (_level(c, discipline) < 5) return 'Pouvoir d’ancien : 5 points de $discipline requis';
  if (c.elderPowers.length + 1 > row.eldersLimit) return 'Pouvoirs d’anciens : ${row.eldersLimit} au plus au rang ${rank.label}.';
  return null;
}

/// Ce qui ne tient plus sur la fiche (voie baissée, prérequis perdus, rang changé) : une ligne par problème.
List<String> powerProblems(Character c, Rulebook rb) {
  final out = <String>[];
  for (final school in {for (final r in c.rituals) r.school}) {
    final mine = [for (final r in c.rituals) if (r.school == school) r];
    final points = schoolDots(c, school, rb);
    if (mine.length > points) out.add(_limit(school, points, mine.length));
    final levels = {for (final r in mine) r.level};
    final gaps = {for (final l in levels) for (var k = 1; k < l; k++) if (!levels.contains(k)) k};
    for (final k in gaps.toList()..sort()) {
      out.add('Il manque un rituel de niveau $k (${_school(school)})');
    }
  }
  final rank = c.genRank ?? GenRank.neonate;
  final row = rb.gen(rank);
  if (c.techniques.isNotEmpty && row.techniqueCost == 0) out.add('Techniques interdites au rang ${rank.label}.');
  for (final t in c.techniques) {
    final e = prerequisiteError(c, t, rb);
    if (e != null) out.add('$t : ${e[0].toLowerCase()}${e.substring(1)}');
  }
  if (c.elderPowers.isNotEmpty && !row.eldersAllowed) out.add('Pouvoirs d’anciens interdits au rang ${rank.label}.');
  if (row.eldersAllowed && c.elderPowers.length > row.eldersLimit) {
    out.add('Pouvoirs d’anciens : ${row.eldersLimit} au plus au rang ${rank.label}.');
  }
  for (final e in c.elderPowers) {
    if (_level(c, e.discipline) < 5) out.add('${e.name} : 5 points de ${e.discipline} requis');
  }
  return out;
}

int ritualCost(String name, Rulebook rb) => rb.ritualLevel(name) * rb.ritualCostPerLevel;

int techniqueCost(Character c, Rulebook rb) => rb.gen(c.genRank ?? GenRank.neonate).techniqueCost;

/// La discipline du pouvoir est en clan pour la fiche (ou pour son clan, si elle ne l'a pas).
bool elderInClan(Character c, String name, Rulebook rb) {
  final d = rb.elderDiscipline(name);
  if (d == null) return false;
  return c.disciplines.where((x) => nameKey(x.name) == nameKey(d)).firstOrNull?.inClan ?? rb.clanDisciplines(c.clan).contains(d);
}

int elderCost(Character c, String name, Rulebook rb) => rb.elderCost(name, inClan: elderInClan(c, name, rb));
