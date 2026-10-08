import 'dart:math' show min;

import '../characters/character.dart';
import '../core/dates.dart' show monthAbbr;
import '../events/story_event.dart';
import '../morality/sin.dart' show dayOf;
import '../npcs/loan_rules.dart' show formatLoanDay;
import 'bond.dart';

/// Délais des règles, en mois du calendrier (fixes pour l'instant ; réglage dans les paramètres plus tard).
const fullDropMonths = 3;
const twoFadeMonths = 6;
const oneFadeMonths = 12;

/// [d] + [n] mois du calendrier ; un jour qui n'existe pas devient le dernier du mois (31 janv. + 1 → 28 ou 29 févr.).
DateTime addMonths(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, min(d.day, last));
}

/// « ●●○ ».
String bondDots(int n) {
  final k = n.clamp(0, 3);
  return '●' * k + '○' * (3 - k);
}

/// Changement à venir d'un lien : sa date et le niveau après.
typedef BondChange = ({DateTime at, int to});

List<BondChange> _steps(Bond b) => switch (b.level) {
      >= 3 => [
          (at: addMonths(dayOf(b.lastDrink), fullDropMonths), to: 2),
          (at: addMonths(dayOf(b.lastContact), twoFadeMonths), to: 0),
        ],
      2 => [(at: addMonths(dayOf(b.lastContact), twoFadeMonths), to: 0)],
      1 => [(at: addMonths(dayOf(b.lastContact), oneFadeMonths), to: 0)],
      _ => const [],
    };

/// Niveau du lien à [day] : le jour même d'une échéance, le changement a eu lieu.
int effectiveLevel(Bond b, DateTime day) {
  var level = b.level.clamp(0, 3);
  for (final s in _steps(b)) {
    if (!dayOf(day).isBefore(s.at)) level = s.to;
  }
  return level;
}

/// Prochaine échéance après [day], ou null pour un lien effacé.
BondChange? nextChange(Bond b, DateTime day) => _steps(b).where((s) => dayOf(day).isBefore(s.at)).firstOrNull;

/// « 1er déc. », « 20 mars 2027 » (année si elle diffère de celle de [now]).
String _on(DateTime d, DateTime now) {
  final s = formatLoanDay(d, now: now);
  return d.day == 1 ? s.replaceFirst('1 ', '1er ') : s;
}

/// « 27 déc. 2026 ».
String _long(DateTime d) => '${d.day == 1 ? '1er' : d.day} ${monthAbbr(d.month)} ${d.year}';

/// « Redescend à ●● le 1er déc. », « S’efface le 20 mars 2027 sans contact » ; vide pour un lien effacé.
String dueText(Bond b, DateTime day) {
  final c = nextChange(b, day);
  if (c == null) return '';
  return c.to == 2 ? 'Redescend à ●● le ${_on(c.at, day)}' : 'S’efface le ${_on(c.at, day)} sans contact';
}

/// Jours de calendrier de [from] à [to].
int daysUntil(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Échéance dans 30 jours ou moins.
bool dueSoon(Bond b, DateTime day) {
  final c = nextChange(b, day);
  return c != null && daysUntil(day, c.at) <= 30;
}

/// Effet d'une gorgée : le refus, ou le nouveau niveau et les liens moindres effacés.
class DrinkOutcome {
  const DrinkOutcome(this.level, this.erased) : refusal = null;
  const DrinkOutcome.refused(this.refusal)
      : level = 0,
        erased = const <Bond>[];

  final String? refusal;
  final int level;

  /// Liens moindres du lié envers d'autres régnants, ramenés à 0 par un lien complet.
  final List<Bond> erased;
}

/// Gorgée de [count] (1 à 3) sur [b], à [day], parmi tous les liens connus [all].
DrinkOutcome drinkOutcome(Bond b, List<Bond> all, DateTime day, int count) {
  final others = [
    for (final o in all)
      if (o.thrallId == b.thrallId && o.regnantId != b.regnantId && effectiveLevel(o, day) > 0) o,
  ];
  final full = others.where((o) => effectiveLevel(o, day) >= 3).firstOrNull;
  if (full != null) return DrinkOutcome.refused('${b.thrallName} est déjà lié complètement à ${full.regnantName}.');
  final level = min(3, effectiveLevel(b, day) + count);
  return DrinkOutcome(level, level == 3 ? [for (final o in others) o.copy()..level = 0] : const <Bond>[]);
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Le lien après une gorgée : les dates ne reculent jamais.
Bond drunk(Bond b, DateTime day, int level, bool known) => b.copy()
  ..level = level
  ..lastDrink = b.stored ? _later(dayOf(b.lastDrink), dayOf(day)) : dayOf(day)
  ..lastContact = b.stored ? _later(dayOf(b.lastContact), dayOf(day)) : dayOf(day)
  ..known = known;

/// Le lien après un contact : niveau du jour enregistré ; un lien effacé n'est pas ravivé.
Bond contacted(Bond b, DateTime day) => b.copy()
  ..level = effectiveLevel(b, day)
  ..lastContact = _later(dayOf(b.lastContact), dayOf(day));

/// Ce qu'écrit une gorgée, en un lot.
class DrinkWrite {
  const DrinkWrite(this.after, this.erased, this.event);
  final Bond after;
  final List<Bond> erased;
  final StoryEvent event;
}

/// [w] dont les liens effacés portent les joueurs actuels de leurs fiches (copies périmées sinon refusées par les règles).
DrinkWrite withCurrentPlayers(DrinkWrite w, Character? Function(String id) byId) => DrinkWrite(w.after, [
      for (final e in w.erased)
        if (byId(e.regnantId) case final r? when byId(e.thrallId) != null) refreshed(e, r, byId(e.thrallId)!) else e,
    ], w.event);

/// Écriture d'une gorgée, ou null si elle est refusée.
DrinkWrite? drinkWrite(Bond base, List<Bond> all, DateTime day, int count, bool known) {
  final out = drinkOutcome(base, all, day, count);
  if (out.refusal != null) return null;
  final after = drunk(base, day, out.level, known);
  return DrinkWrite(after, out.erased, bondEvent(after, day));
}

/// Événement automatique du lié : visible du joueur si le lien lui est connu.
StoryEvent bondEvent(Bond after, DateTime day) {
  final title = 'Boit le sang de ${after.regnantName} · ${bondDots(after.level)}';
  return StoryEvent(
    id: '',
    type: EventType.bond,
    title: title.length > 80 ? '${title.substring(0, 79)}…' : title,
    year: day.year,
    month: day.month,
    day: day.day,
    visibility: after.known ? EventVisibility.player : EventVisibility.staff,
    auto: true,
  );
}

/// Aperçu d'une gorgée : les lignes du panneau, ou le seul refus.
List<String> drinkPreview(Bond base, List<Bond> all, DateTime day, int count) {
  final out = drinkOutcome(base, all, day, count);
  if (out.refusal != null) return [out.refusal!];
  final from = effectiveLevel(base, day);
  final next = nextChange(drunk(base, day, out.level, base.known), day)!;
  final names = [for (final e in out.erased) e.regnantName];
  return [
    'Lien envers ${base.regnantName} : ${bondDots(from)} → ${bondDots(out.level)}',
    if (out.level == 3 && from < 3)
      'Lien complet. Les liens moindres de ${base.thrallName} envers d’autres vampires sont effacés : '
          '${names.isEmpty ? 'aucun' : names.join(', ')}.',
    next.to == 2
        ? 'Sans nouvelle gorgée, il redescendra à ●● le ${_long(next.at)}.'
        : 'Sans contact, il s’effacera le ${_long(next.at)}.',
  ];
}

/// Contrôles du choix des fiches et de la date.
/// Date de gorgée valide : lue, et pas dans le futur si [today] est connu.
bool validDrinkDay(DateTime? day, DateTime? today) => day != null && (today == null || !dayOf(day).isAfter(dayOf(today)));

/// Avec [today], une date postérieure est invalide aussi : les dates ne reculent jamais, une gorgée future gèlerait le lien.
List<String> bondChecks({required String? regnantId, required String? thrallId, required DateTime? day, DateTime? today}) => [
      if (regnantId == null) 'Choisissez qui donne son sang',
      if (thrallId == null) 'Choisissez qui boit',
      if (regnantId != null && regnantId == thrallId) 'Une fiche ne peut pas se lier elle-même',
      if (!validDrinkDay(day, today)) 'Date invalide',
    ];

/// « PNJ · Ventrue », « Goule · PNJ », « PJ · Malkavien ».
String partyTag(Character c) => c.ghoul != null
    ? 'Goule · ${c.kind.label}'
    : [c.kind.label, if ((c.clan ?? '').isNotEmpty) c.clan!].join(' · ');

/// Liens actifs (niveau du jour ≥ 1), échéance la plus proche d'abord.
List<Bond> activeBonds(Iterable<Bond> all, DateTime day) =>
    [for (final b in all) if (effectiveLevel(b, day) > 0) b]..sort((a, b) => nextChange(a, day)!.at.compareTo(nextChange(b, day)!.at));

/// Filtres de la page de la chronique.
enum BondFilter {
  all('Tous'),
  full('Complets'),
  soon('Échéance proche'),
  unknown('Ignorés du lié'),
  pjThrall('PJ liés');

  const BondFilter(this.label);
  final String label;
}

/// Filtre et recherche par nom (régnant ou lié, sans tenir compte de la casse).
bool bondMatches(Bond b, BondFilter f, String query, DateTime day) {
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty && !b.regnantName.toLowerCase().contains(q) && !b.thrallName.toLowerCase().contains(q)) return false;
  return switch (f) {
    BondFilter.all => true,
    BondFilter.full => effectiveLevel(b, day) == 3,
    BondFilter.soon => dueSoon(b, day),
    BondFilter.unknown => !b.known,
    BondFilter.pjThrall => b.thrallPlayerUid != null,
  };
}

/// Compteurs de la page : liens actifs, complets, échéance sous 30 jours, ignorés du lié.
({int active, int full, int soon, int unknown}) bondStats(List<Bond> active, DateTime day) => (
      active: active.length,
      full: active.where((b) => effectiveLevel(b, day) == 3).length,
      soon: active.where((b) => dueSoon(b, day)).length,
      unknown: active.where((b) => !b.known).length,
    );

/// Ancien niveau de la fiche de goule, sans document de lien envers son domitor : à dater ; 0 sinon.
int ghoulBondToDate(Character c, Iterable<Bond> all) {
  final g = c.ghoul;
  if (g == null || g.bond <= 0 || g.domitorId.isEmpty) return 0;
  return all.any((b) => b.regnantId == g.domitorId && b.thrallId == c.id) ? 0 : g.bond.clamp(1, 3);
}

/// Lien de la goule envers son domitor, au niveau de sa fiche, daté de [day], connu des deux.
Bond datedGhoulBond(Character ghoul, Character domitor, DateTime day) =>
    bondBetween(domitor, ghoul, day)..level = ghoul.ghoul!.bond.clamp(1, 3);

/// Ligne du conte : « Dernière gorgée le 20 sept. · Redescend à ●● le 1er déc. ».
String staffLine(Bond b, DateTime day) => 'Dernière gorgée le ${_on(b.lastDrink, day)} · ${dueText(b, day)}';

/// Joueur, lien subi : « 2 gorgées · dernière le 20 sept. ».
String sufferedLine(Bond b, DateTime day) {
  final what = switch (effectiveLevel(b, day)) {
    1 => 'Une gorgée',
    2 => '2 gorgées',
    _ => 'Lien complet',
  };
  return '$what · dernière le ${_on(b.lastDrink, day)}';
}

/// Joueur, lien subi : le délai qui le menace.
String sufferedDelay(Bond b, DateTime day) => switch (effectiveLevel(b, day)) {
      1 => 'Disparaît après un an sans le voir ni lui parler.',
      2 => 'Disparaît après six mois sans le voir ni lui parler.',
      _ => 'Redescend après trois mois sans boire son sang.',
    };

/// Joueur, lien exercé : « Dernière gorgée le 26 sept. · à renforcer avant le 26 déc. ».
String exertedLine(Bond b, DateTime day) {
  final c = nextChange(b, day)!;
  final due = effectiveLevel(b, day) == 3 ? 'à renforcer avant le ${_on(c.at, day)}' : 's’efface le ${_on(c.at, day)} sans contact';
  return 'Dernière gorgée le ${_on(b.lastDrink, day)} · $due';
}
