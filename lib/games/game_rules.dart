import '../characters/character.dart';
import '../characters/describe_changes.dart';
import '../core/dates.dart';
import '../npcs/loan_rules.dart';
import '../npcs/npc_loan.dart';
import 'game.dart';

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// Gel en cours : ni levé, ni dépassé (les règles Firestore font le même calcul avec `request.time`).
bool isRunning(Game g, DateTime now) => g.liftedAt == null && now.isBefore(g.until);

Game? runningGame(List<Game> games, DateTime now) => games.where((g) => isRunning(g, now)).firstOrNull;

/// Gel en cours qui fige [characterId], ou null.
Game? frozenBy(List<Game> games, String characterId, DateTime now) =>
    games.where((g) => isRunning(g, now) && g.sheetIds.contains(characterId)).firstOrNull;

/// Dernier gel figé avant [g] : la référence de la comparaison.
Game? previousGame(List<Game> games, Game g) {
  Game? best;
  for (final x in games) {
    if (x.frozenAt.isBefore(g.frozenAt) && (best == null || x.frozenAt.isAfter(best.frozenAt))) best = x;
  }
  return best;
}

/// Fiches jouées à la partie : PJ actifs, et PNJ actifs dont un prêt est en cours.
List<Character> sheetsToFreeze(List<Character> sheets, List<NpcLoan> loans, DateTime now) {
  final lent = {for (final l in loans) if (loanState(l, now) == LoanState.active) l.characterId};
  return [
    for (final c in sheets)
      if (c.status == CharacterStatus.active && (c.kind == CharacterKind.pj || lent.contains(c.id))) c,
  ];
}

/// Levée par défaut : le lendemain de la partie à 6h.
DateTime defaultUntil(DateTime date) => DateTime(date.year, date.month, date.day + 1, 6);

/// « 6 », « 06:00 », « 20h », « 20h30 » ; null sinon.
(int, int)? parseTime(String text) {
  final m = RegExp(r'^(\d{1,2})(?:[:h](\d{2})?)?$').firstMatch(text.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2] ?? '0');
  return h < 24 && min < 60 ? (h, min) : null;
}

/// Levée choisie. Jour vide : le lendemain de la partie ; heure vide : 6h. Null si la saisie est invalide.
DateTime? untilOf(DateTime date, String day, String time) {
  final d = day.trim().isEmpty ? DateTime(date.year, date.month, date.day + 1) : parseDay(day);
  final t = time.trim().isEmpty ? (6, 0) : parseTime(time);
  if (d == null || t == null) return null;
  return DateTime(d.year, d.month, d.day, t.$1, t.$2);
}

typedef FreezePlan = ({DateTime? date, DateTime? until, String? error});

/// Contrôles du formulaire « Nouveau gel ».
FreezePlan freezePlan(String dateText, String untilDay, String untilTime, DateTime now) {
  final date = parseDay(dateText);
  if (date == null) return (date: null, until: null, error: 'Date de partie invalide');
  final until = untilOf(date, untilDay, untilTime);
  if (until == null) return (date: date, until: null, error: 'Levée invalide');
  if (!until.isAfter(now)) return (date: date, until: until, error: 'La levée doit être dans le futur.');
  return (date: date, until: until, error: null);
}

/// Nombre de changements entre deux versions figées ; null sans version précédente.
int? changeCount(Character? before, Character after) => before == null ? null : describeChanges(before, after).length;

String changeLabel(int? n) => switch (n) {
      null => 'Première version figée',
      0 => 'Aucun',
      1 => '1 changement',
      _ => '$n changements',
    };

String _two(int n) => n.toString().padLeft(2, '0');

String _weekday(DateTime d) => _weekdays[d.weekday - 1];

/// Termine une phrase : « 4 oct. » garde son point, « 3 mai » en reçoit un.
String _sentence(String s) => s.endsWith('.') ? s : '$s.';

/// « 6h », « 20h05 ».
String hourText(DateTime d) => d.minute == 0 ? '${d.hour}h' : '${d.hour}h${_two(d.minute)}';

/// « samedi 3 oct. ».
String shortDay(DateTime d) => '${_weekday(d)} ${formatDay(d)}';

/// « dimanche 4 oct. à 6h ».
String dayAndHour(DateTime d) => '${shortDay(d)} à ${hourText(d)}';

/// « 04/10/2026 ».
String slashDay(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String gameTitle(Game g) => 'Gel en cours · partie du ${_weekday(g.date)} ${g.date.day} ${_months[g.date.month - 1]}';

String gameSpanText(Game g) => 'Depuis le ${dayAndHour(g.frozenAt)}, jusqu’au ${dayAndHour(g.until)}';

/// Bandeau du joueur (J-Fiche, « Dépenser de l'XP »).
String playerFreezeText(Game g) =>
    'Fiche figée pour la partie du ${_sentence(shortDay(g.date))} Vos demandes restent en file et seront traitées à partir du ${_sentence(formatDay(g.until))}';

/// Bandeau du conte (C3).
String staffFreezeText(Game g) => 'Figée pour la partie du ${shortDay(g.date)}, jusqu’au ${dayAndHour(g.until)} : son XP ne peut pas changer.';

/// Raison d'un bouton ou d'une case désactivés.
String frozenUntilText(Game g) => 'Fiche figée jusqu’au ${formatDay(g.until)}';

String freezeCountText(List<Character> sheets) {
  final n = sheets.length;
  final pj = sheets.where((c) => c.kind == CharacterKind.pj).length;
  final npc = n - pj;
  return '${n == 1 ? '1 fiche sera figée' : '$n fiches seront figées'} : '
      '$pj ${pj > 1 ? 'PJ actifs' : 'PJ actif'} et $npc ${npc > 1 ? 'PNJ confiés' : 'PNJ confié'}.';
}

String frozenGainText(int n) =>
    n == 1 ? '1 fiche figée : son gain sera versé après le gel.' : '$n fiches figées : leur gain sera versé après le gel.';
