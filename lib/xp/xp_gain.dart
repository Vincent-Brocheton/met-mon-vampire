import 'dart:math';

import '../characters/character.dart';
import 'xp_settings.dart';

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Mois au format 'aaaa-mm', en UTC : tous les appareils voient le même mois, quel que soit leur fuseau.
String monthKey(DateTime d) {
  final u = d.toUtc();
  return '${u.year}-${u.month.toString().padLeft(2, '0')}';
}

/// Rang du mois depuis l'an 0 : les écarts entre mois se calculent par soustraction.
int monthIndex(String key) {
  final p = key.split('-');
  return int.parse(p[0]) * 12 + int.parse(p[1]) - 1;
}

String keyOfIndex(int i) => '${i ~/ 12}-${(i % 12 + 1).toString().padLeft(2, '0')}';

String monthLabel(String key) {
  final i = monthIndex(key);
  return '${_months[i % 12]} ${i ~/ 12}';
}

/// « oct. 2026 », « sept.–oct. 2026 », « déc. 2026–janv. 2027 ».
String monthRange(List<String> keys) {
  if (keys.length == 1) return monthLabel(keys.single);
  final a = monthIndex(keys.first), b = monthIndex(keys.last);
  return a ~/ 12 == b ~/ 12 ? '${_months[a % 12]}–${monthLabel(keys.last)}' : '${monthLabel(keys.first)}–${monthLabel(keys.last)}';
}

/// Palier qui couvre l'ancienneté [age] (en mois, à partir de 1).
int tierAt(List<XpTier> tiers, int age) {
  var start = 1;
  for (final (i, t) in tiers.indexed) {
    if (t.months == null || age < start + t.months!) return i;
    start += t.months!;
  }
  return tiers.length - 1;
}

int _tierStart(List<XpTier> tiers, int index) => 1 + tiers.take(index).fold<int>(0, (s, t) => s + (t.months ?? 0));

/// XP du mois d'ancienneté [age]. Le premier mois d'un palier compte (« tous les 2 mois » : 1er, 3e, 5e…).
int gainAt(List<XpTier> tiers, int age) {
  final i = tierAt(tiers, age);
  final t = tiers[i];
  return (age - _tierStart(tiers, i)) % t.every == 0 ? t.xp : 0;
}

/// XP cumulée sur les [months] premiers mois.
int gainOver(List<XpTier> tiers, int months) => [for (var a = 1; a <= months; a++) gainAt(tiers, a)].fold(0, (s, x) => s + x);

/// Activation : validation de la fiche, à défaut sa création.
DateTime? activationOf(Character c) => c.decidedAt ?? c.createdAt;

/// Gain dû à une fiche : ses mois dus, le total et le palier du mois courant.
class GainDue {
  const GainDue(this.c, this.months, this.xp, this.tier);
  final Character c;
  final List<String> months;
  final int xp;
  final int tier;

  /// Nouveau `gainedThrough` après versement.
  String get through => months.last;
}

/// Ce que l'application propose de verser : PJ actifs, mois de `max(gainedThrough + 1, gainSince, activation + 1)`
/// jusqu'au mois de [now] inclus. Le mois d'activation ne donne rien.
List<GainDue> monthlyGain(List<Character> all, XpSettings s, DateTime now) {
  final since = s.gainSince;
  if (!s.monthlyEnabled || since == null) return const [];
  final current = monthIndex(monthKey(now));
  return [
    for (final c in all)
      if (c.kind == CharacterKind.pj && c.status == CharacterStatus.active && activationOf(c) != null)
        ?_due(c, s.tiers, monthIndex(monthKey(activationOf(c)!)), monthIndex(since), current),
  ];
}

GainDue? _due(Character c, List<XpTier> tiers, int activated, int since, int current) {
  var from = max(activated + 1, since);
  if (c.gainedThrough != null) from = max(from, monthIndex(c.gainedThrough!) + 1);
  if (from > current) return null;
  final months = [for (var m = from; m <= current; m++) keyOfIndex(m)];
  final xp = [for (var m = from; m <= current; m++) gainAt(tiers, m - activated)].fold(0, (s, x) => s + x);
  return GainDue(c, months, xp, tierAt(tiers, current - activated));
}
