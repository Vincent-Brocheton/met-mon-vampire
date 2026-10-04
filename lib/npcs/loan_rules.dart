import '../characters/character.dart';
import '../core/dates.dart';
import 'npc_loan.dart';

enum LoanState { upcoming, active, ended, revoked }

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dernière seconde du jour : la fin d'un prêt est incluse.
DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

/// Date d'un prêt affichée (« 17 oct. 2026 » selon `formatDay`).
String formatLoanDay(DateTime d) => formatDay(d);

/// « 17/10/2026 » ; null si la date n'existe pas.
DateTime? parseDay(String text) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text.trim());
  if (m == null) return null;
  final (d, mo, y) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final date = DateTime(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

LoanState loanState(NpcLoan l, DateTime now) {
  if (l.revokedAt != null) return LoanState.revoked;
  if (now.isBefore(l.from)) return LoanState.upcoming;
  if (now.isAfter(l.until)) return LoanState.ended;
  return LoanState.active;
}

/// Jours entiers jusqu'à la fin (0 le dernier jour), en jours de calendrier (indépendant de l'heure d'été).
int daysLeft(NpcLoan l, DateTime now) {
  final a = DateTime.utc(now.year, now.month, now.day);
  final b = DateTime.utc(l.until.year, l.until.month, l.until.day);
  return b.difference(a).inDays;
}

/// Copie de la fiche montrée au joueur. Résumée : identité, attributs, 7 meilleures compétences, disciplines, sang.
Map<String, dynamic> sheetCopy(Character c, LoanMode mode) {
  final all = c.toMap();
  if (mode == LoanMode.full) return all;
  final skills = [...c.skills]..sort((a, b) => b.level.compareTo(a.level));
  return {
    for (final k in ['name', 'kind', 'status', 'clan', 'lineage', 'sect', 'title', 'generation', 'attributes', 'disciplines', 'blood', 'bloodPerTurn', 'willpower'])
      k: all[k],
    'skills': [for (final t in skills.take(7)) t.toMap()],
  };
}

/// Avertissements (le conte peut quand même enregistrer, sauf « La fin précède le début »).
List<String> loanWarnings(NpcLoan l, {List<NpcLoan> loans = const [], Character? npc, required DateTime now}) {
  final out = <String>[];
  if (!l.until.isAfter(l.from)) out.add('La fin précède le début');
  for (final o in loans) {
    if (o.id == l.id || o.characterId != l.characterId) continue;
    final s = loanState(o, now);
    final open = s == LoanState.active || s == LoanState.upcoming;
    if (open && o.from.isBefore(l.until) && l.from.isBefore(o.until)) out.add('Déjà confié à ${o.playerName} jusqu’au ${formatDay(o.until)}');
  }
  if (npc != null) {
    final at = l.sheetAt;
    if (at != null && npc.updatedAt != null && npc.updatedAt!.isAfter(at)) out.add('Copie du ${formatDay(at)} : mettre à jour');
    if (npc.status == CharacterStatus.retired || npc.status == CharacterStatus.dead) out.add('Le PNJ est une fiche retirée ou morte');
  }
  return out;
}
