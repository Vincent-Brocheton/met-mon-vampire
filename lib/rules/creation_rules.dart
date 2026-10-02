import 'dart:math';

import '../characters/character.dart';
import 'met_lists.dart';

const startingXp = 30;
const maxFlawXp = 7;
const maxMeritPoints = 7;
const maxSetAside = 5;
const maxOutOfClanDots = 3;
const attributeSlots = [7, 5, 3];
const skillSlots = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
const backgroundSlots = [3, 2, 1];
const disciplineSlots = [2, 1, 1];
const generationName = 'Génération';
const humanityName = 'Humanité';

const creationSteps = [
  'Inspiration', 'XP initiale', 'Clan', 'Attributs', 'Compétences', 'Historiques', 'Disciplines',
  'Atouts & handicaps', 'Dépense d’XP', 'Finitions & récit',
];

/// Types d'achat de l'étape 9 (valeur de Purchase.kind).
abstract final class Buy {
  static const attribute = 'attribute';
  static const skill = 'skill';
  static const background = 'background';
  static const discipline = 'discipline';
  static const humanity = 'humanity';
}

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

Trait? _find(List<Trait> list, String name) {
  for (final t in list) {
    if (t.name == name) return t;
  }
  return null;
}

Discipline? _findD(List<Discipline> list, String name) {
  for (final d in list) {
    if (d.name == name) return d;
  }
  return null;
}

int purchasedCount(Character c, String kind, String name) =>
    c.purchases.where((p) => p.kind == kind && p.name == name).length;

int generationLevel(Character c) => _find(c.backgrounds, generationName)?.level ?? 0;

GenRank? rankFor(Character c) => switch (generationLevel(c)) {
      <= 0 => null,
      1 => GenRank.neonate,
      2 => GenRank.ancilla,
      _ => GenRank.pretender,
    };

int levelOf(Character c, String kind, String name) => switch (kind) {
      Buy.attribute => c.attributes[AttrCategory.values.byName(name)]!.value,
      Buy.skill => _find(c.skills, name)?.level ?? 0,
      Buy.background => _find(c.backgrounds, name)?.level ?? 0,
      Buy.discipline => _findD(c.disciplines, name)?.level ?? 0,
      Buy.humanity => 5 + purchasedCount(c, Buy.humanity, humanityName),
      _ => 0,
    };

int freeLevelOf(Character c, String kind, String name) => levelOf(c, kind, name) - purchasedCount(c, kind, name);

bool isInClan(Character c, String discipline) =>
    _findD(c.disciplines, discipline)?.inClan ?? (clanInfo(c.clan)?.disciplines.contains(discipline) ?? false);

/// Coût d'un achat au niveau [toLevel], selon le rang actuel (recalculé à chaque changement de Génération).
int purchaseCost(Character c, String kind, String name, int toLevel) {
  final cheap = (rankFor(c) ?? GenRank.neonate) == GenRank.neonate;
  return switch (kind) {
    Buy.attribute => 3,
    Buy.skill => toLevel * (cheap ? 1 : 2),
    Buy.background => name == generationName ? toLevel * 2 : toLevel * (cheap ? 1 : 2),
    Buy.discipline => toLevel * (isInClan(c, name) ? 3 : 4),
    Buy.humanity => toLevel * 2,
    _ => 0,
  };
}

class Budget {
  const Budget({required this.bonus, required this.flaws, required this.flawsTaken, required this.merits, required this.purchases});

  final int bonus;

  /// XP rapportée par les handicaps (7 au plus).
  final int flaws;

  /// Points de handicaps pris (peuvent dépasser 7).
  final int flawsTaken;

  /// Points d'atouts, rareté de clan comprise.
  final int merits;
  final int purchases;

  int get total => startingXp + bonus + flaws;
  int get spent => merits + purchases;
  int get remaining => total - spent;
  int get setAside => remaining.clamp(0, maxSetAside);
  int get lost => remaining > maxSetAside ? remaining - maxSetAside : 0;
}

Budget budgetOf(Character c) {
  final flaws = _sum(c.flaws.map((t) => t.level));
  return Budget(
    bonus: c.xpBonus,
    flaws: min(flaws, maxFlawXp),
    flawsTaken: flaws,
    merits: _sum(c.merits.map((t) => t.level)) + (clanInfo(c.clan)?.rarity.meritPoints ?? 0),
    purchases: _sum(c.purchases.map((p) => purchaseCost(c, p.kind, p.name, p.toLevel))),
  );
}

void _setLevel(Character c, String kind, String name, int level) {
  switch (kind) {
    case Buy.attribute:
      c.attributes[AttrCategory.values.byName(name)]!.value = level;
    case Buy.skill || Buy.background:
      final list = kind == Buy.skill ? c.skills : c.backgrounds;
      final t = _find(list, name);
      if (level <= 0) {
        list.removeWhere((x) => x.name == name);
      } else if (t == null) {
        list.add(Trait(name, level));
      } else {
        t.level = level;
      }
    case Buy.discipline:
      final d = _findD(c.disciplines, name);
      if (d == null) {
        if (level > 0) c.disciplines.add(Discipline(name, level, inClan: isInClan(c, name)));
      } else if (level <= 0 && !d.inClan) {
        c.disciplines.remove(d);
      } else {
        d.level = level;
      }
    case Buy.humanity:
      c.humanity = level;
  }
}

/// Achète un niveau. Renvoie un message si l'achat est impossible.
String? addPurchase(Character c, String kind, String name) {
  final to = levelOf(c, kind, name) + 1;
  final cap = switch (kind) {
    Buy.attribute || Buy.humanity => 10,
    Buy.background when name == generationName => 3,
    _ => 5,
  };
  if (to > cap) return 'Plafond atteint ($cap).';
  if (kind == Buy.discipline && !isInClan(c, name)) {
    if (!commonDisciplines.contains(name)) {
      return 'Hors clan, seules les disciplines communes s’achètent à la création.';
    }
    final outOfClan = _sum(c.disciplines.where((d) => !d.inClan).map((d) => d.level));
    if (outOfClan + 1 > maxOutOfClanDots) return 'Hors clan : $maxOutOfClanDots points au plus à la création.';
  }
  final cost = purchaseCost(c, kind, name, to);
  _setLevel(c, kind, name, to);
  c.purchases.add(Purchase(kind, name, to, cost));
  return null;
}

/// Retire un achat ; seulement le plus haut niveau acheté d'un trait.
String? removePurchase(Character c, int index) {
  final p = c.purchases[index];
  if (levelOf(c, p.kind, p.name) != p.toLevel) return 'Retirez d’abord l’achat de niveau supérieur.';
  c.purchases.removeAt(index);
  _setLevel(c, p.kind, p.name, p.toLevel - 1);
  return null;
}

/// Choix du clan : disciplines en clan du clan ; les anciennes sont retirées, ou passent hors clan si achetées.
void setClan(Character c, String? name) {
  if (name == c.clan) return; // Caïtiff : ne pas effacer les disciplines déjà choisies
  c.clan = name;
  final info = clanInfo(name);
  bool inNew(Discipline d) => info?.disciplines.contains(d.name) ?? false;
  c.disciplines.removeWhere((d) => d.inClan && purchasedCount(c, Buy.discipline, d.name) == 0 && !inNew(d));
  for (final d in c.disciplines) {
    if (d.inClan && !inNew(d)) {
      // Hors clan, seuls les points achetés restent (pas de points gratuits).
      d
        ..inClan = false
        ..level = purchasedCount(c, Buy.discipline, d.name);
    }
  }
  if (info == null) return;
  for (final n in info.disciplines) {
    final d = _findD(c.disciplines, n);
    if (d == null) {
      c.disciplines.add(Discipline(n, 0, inClan: true));
    } else {
      d.inClan = true;
    }
  }
}

/// Niveau gratuit d'une compétence ou d'un historique (le niveau final ajoute les achats).
void setFreeLevel(Character c, String kind, String name, int free) =>
    _setLevel(c, kind, name, free + purchasedCount(c, kind, name));

void setDisciplineFree(Character c, String name, int free) {
  final d = _findD(c.disciplines, name);
  if (d != null) d.level = free + purchasedCount(c, Buy.discipline, name);
}

/// Les achats d'un trait occupent toujours les niveaux juste au-dessus de ses points gratuits,
/// même après un changement de niveau gratuit, de catégorie ou de clan.
void _renumberPurchases(Character c) {
  final seen = <String, int>{};
  for (var i = 0; i < c.purchases.length; i++) {
    final p = c.purchases[i];
    final key = '${p.kind}/${p.name}';
    final n = seen[key] = (seen[key] ?? 0) + 1;
    final to = freeLevelOf(c, p.kind, p.name) + n;
    if (to != p.toLevel) c.purchases[i] = Purchase(p.kind, p.name, to, purchaseCost(c, p.kind, p.name, to));
  }
}

/// Recalcule rang, Sang, Volonté, Humanité, Santé, attributs et compteurs d'XP.
void applyDerived(Character c) {
  final rank = rankFor(c);
  c.genRank = rank;
  if (rank == null || !generationNumbers[rank]!.contains(c.genNumber)) c.genNumber = null;
  final (blood, perTurn) = rank == null ? (0, 0) : bloodByRank[rank]!;
  c
    ..blood = blood
    ..bloodPerTurn = perTurn
    ..willpower = 6
    ..humanity = levelOf(c, Buy.humanity, humanityName)
    ..health = '3 · 3 · 3';
  for (final cat in AttrCategory.values) {
    final i = c.attributeRanks.indexOf(cat);
    c.attributes[cat]!.value = (i >= 0 ? attributeSlots[i] : 0) + purchasedCount(c, Buy.attribute, cat.name);
  }
  _renumberPurchases(c);
  final b = budgetOf(c);
  c
    ..xpInitial = startingXp + c.xpBonus + b.flaws
    ..xpSpent = b.spent
    ..xpEarned = b.setAside;
}

enum CheckLevel { ok, todo, warn, error }

class Check {
  const Check(this.step, this.level, this.text);
  final int step;
  final CheckLevel level;
  final String text;
}

String _plural(int n, String one, String many) => n > 1 ? many : one;

void _slots(List<Check> out, int step, (String, String) noun, List<int> free, List<int> slots, String okText) {
  final placed = free.where((l) => l > 0).toList();
  final messages = <String>[];
  for (final level in slots.toSet()) {
    final expected = slots.where((s) => s == level).length;
    final actual = placed.where((l) => l == level).length;
    final pts = _plural(level, 'point', 'points');
    if (actual < expected) {
      final n = expected - actual;
      messages.add('il reste $n ${_plural(n, noun.$1, noun.$2)} à placer à $level $pts');
    } else if (actual > expected) {
      messages.add('trop de ${noun.$2} à $level $pts');
    }
  }
  if (placed.any((l) => !slots.contains(l))) messages.add('niveau gratuit non prévu');
  if (messages.isEmpty) {
    out.add(Check(step, CheckLevel.ok, okText));
  } else {
    final text = messages.join(', ');
    out.add(Check(step, CheckLevel.todo, '${text[0].toUpperCase()}${text.substring(1)}.'));
  }
}

/// Contrôles des maquettes (étapes 4 et 10, C4). Bloquants : todo et error.
List<Check> creationChecks(Character c) {
  final out = <Check>[];
  void add(int step, CheckLevel level, String text) => out.add(Check(step, level, text));

  final identity = [c.name, c.concept, c.archetype, c.sect].every((s) => (s ?? '').trim().isNotEmpty);
  add(1, identity ? CheckLevel.ok : CheckLevel.todo,
      identity ? 'Nom, concept, archétype et secte renseignés' : 'Renseignez le nom, le concept, l’archétype et la secte');
  if (c.archetype != null && !archetypes.contains(c.archetype)) {
    add(1, CheckLevel.warn, 'Archétype hors liste : à confirmer par le conte');
  }

  final clan = clanInfo(c.clan);
  if (c.clan == null) {
    add(3, CheckLevel.todo, 'Choisissez un clan');
  } else if (clan == null) {
    add(3, CheckLevel.warn, 'Clan ${c.clan} hors liste : à confirmer par le conte');
  } else {
    add(
      3,
      clan.rarity == ClanRarity.rare ? CheckLevel.warn : CheckLevel.ok,
      switch (clan.rarity) {
        ClanRarity.common => 'Clan ${clan.name} : commun, aucun atout de rareté',
        ClanRarity.uncommon => 'Clan ${clan.name} : peu commun, atout de 2 points',
        ClanRarity.rare => 'Clan ${clan.name} : rare, atout de 4 points, accord du conte nécessaire',
      },
    );
  }

  final ranked = c.attributeRanks.whereType<AttrCategory>().toSet().length == 3;
  final focused = AttrCategory.values.every((a) => (c.attributes[a]!.focus ?? '').isNotEmpty);
  add(4, ranked && focused ? CheckLevel.ok : CheckLevel.todo,
      ranked && focused ? 'Attributs répartis 7 / 5 / 3, un focus chacun' : 'Classez les attributs 7 / 5 / 3 et choisissez un focus par catégorie');

  _slots(out, 5, ('compétence', 'compétences'), [for (final s in c.skills) freeLevelOf(c, Buy.skill, s.name)], skillSlots,
      'Compétences 4 / 3-3 / 2-2-2 / 1-1-1-1');
  for (final s in c.skills) {
    if (domainSkills.contains(s.name) && (s.note ?? '').trim().isEmpty) add(5, CheckLevel.todo, 'Précisez le domaine de ${s.name}');
    if (!skillNames.contains(s.name)) add(5, CheckLevel.warn, 'Compétence ${s.name} hors liste : à confirmer par le conte');
  }

  _slots(out, 6, ('historique', 'historiques'), [for (final b in c.backgrounds) freeLevelOf(c, Buy.background, b.name)],
      backgroundSlots, 'Historiques 3 / 2 / 1');
  if (generationLevel(c) == 0) {
    add(6, CheckLevel.error, 'Sans point de Génération, le personnage est un mortel');
  } else if (c.genNumber == null) {
    add(6, CheckLevel.todo, 'Choisissez la génération');
  }

  final inClan = c.disciplines.where((d) => d.inClan).toList();
  if (inClan.length != 3) {
    add(7, CheckLevel.todo, clan?.name == 'Caïtiff' ? 'Choisissez trois disciplines communes' : 'Trois disciplines en clan attendues');
  } else {
    _slots(out, 7, ('discipline en clan', 'disciplines en clan'),
        [for (final d in inClan) freeLevelOf(c, Buy.discipline, d.name)], disciplineSlots, 'Disciplines en clan 2 / 1 / 1');
  }
  for (final d in c.disciplines.where((d) => !d.inClan)) {
    if (freeLevelOf(c, Buy.discipline, d.name) > 0) add(7, CheckLevel.error, '${d.name} hors clan : uniquement par achat');
  }

  final b = budgetOf(c);
  if (b.merits > maxMeritPoints) {
    add(8, CheckLevel.error, 'Atouts : ${b.merits} / $maxMeritPoints points');
  } else {
    add(8, CheckLevel.ok, 'Atouts ${b.merits} / $maxMeritPoints · handicaps ${b.flawsTaken} / $maxFlawXp XP');
  }
  if (b.flawsTaken > maxFlawXp) add(8, CheckLevel.warn, 'Handicaps au-delà de 7 : pas d’XP en plus');

  if (b.remaining < 0) {
    add(9, CheckLevel.error, 'Budget dépassé de ${-b.remaining} XP');
  } else {
    add(9, CheckLevel.ok, '${b.spent} XP dépensés, ${b.setAside} mis de côté');
    if (b.lost > 0) add(9, CheckLevel.warn, '${b.lost} XP perdus (5 au plus mis de côté)');
  }

  // Les règles Firestore ne recalculent rien : une fiche écrite hors de l'application se voit ici.
  final derived = c.clone();
  applyDerived(derived);
  String stored(Character x) => [
        x.xpInitial, x.xpSpent, x.xpEarned, x.blood, x.bloodPerTurn, x.willpower, x.humanity, x.genRank,
        for (final a in AttrCategory.values) x.attributes[a]!.value,
        for (final p in x.purchases) '${p.toLevel}:${p.cost}',
      ].join('|');
  if (stored(derived) != stored(c)) {
    add(9, CheckLevel.error, 'Valeurs calculées incohérentes : réenregistrez la fiche depuis l’application');
  }

  if ((c.story ?? '').trim().isEmpty) add(10, CheckLevel.warn, 'Récit vide : quelques lignes aideront le conte');
  return out;
}

bool canSubmit(List<Check> checks) => checks.every((k) => k.level == CheckLevel.ok || k.level == CheckLevel.warn);

/// Coche d'une étape dans la navigation.
bool stepComplete(Character c, int step, List<Check> checks) => switch (step) {
      2 => c.step > 2,
      10 => canSubmit(checks),
      _ => checks.where((k) => k.step == step).every((k) => k.level == CheckLevel.ok || k.level == CheckLevel.warn),
    };
