import 'dart:math';

import '../characters/character.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import 'powers_rules.dart';

const maxMeritPoints = 7;
const maxOutOfClanDots = 3;
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
  static const ritual = 'ritual';
  static const technique = 'technique';
  static const elderPower = 'elderPower';
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
      Buy.ritual => c.rituals.any((r) => nameKey(r.name) == nameKey(name)) ? 1 : 0,
      Buy.technique => c.techniques.any((t) => nameKey(t) == nameKey(name)) ? 1 : 0,
      Buy.elderPower => c.elderPowers.any((e) => nameKey(e.name) == nameKey(name)) ? 1 : 0,
      _ => 0,
    };

int freeLevelOf(Character c, String kind, String name) => levelOf(c, kind, name) - purchasedCount(c, kind, name);

bool isInClan(Character c, String discipline, {Rulebook rb = const Rulebook()}) =>
    _findD(c.disciplines, discipline)?.inClan ?? rb.clanDisciplines(c.clan).contains(discipline);

/// Valeurs de création : la ligne « Goule » pour une goule, sinon le rang de la Génération choisie.
GenRow creationRow(Character c, {Rulebook rb = const Rulebook()}) => c.ghoul != null ? rb.ghoulRow() : rb.gen(rankFor(c) ?? GenRank.neonate);

/// Points de disciplines d'une goule, pris chez son domitor.
const ghoulDisciplinePoints = 5;

/// Achat impossible pour une goule, à la création comme ensuite ; null sinon.
String? ghoulPurchaseError(Character c, String kind, String name) {
  if (c.ghoul == null) return null;
  return switch (kind) {
    Buy.discipline => 'Les disciplines d’une goule ne s’achètent pas avec l’XP.',
    Buy.technique || Buy.elderPower => 'Une goule n’apprend ni technique ni pouvoir d’ancien.',
    Buy.background when name == generationName => 'Une goule n’a pas de Génération.',
    _ => null,
  };
}

/// Niveau d'une discipline de goule (0 la retire).
void setGhoulDiscipline(Character c, String name, int level) {
  c.disciplines.removeWhere((d) => d.name == name);
  if (level > 0) c.disciplines.add(Discipline(name, level, inClan: true));
}

/// Coût d'un achat au niveau [toLevel], selon le rang actuel (recalculé à chaque changement de Génération).
int purchaseCost(Character c, String kind, String name, int toLevel, {Rulebook rb = const Rulebook()}) {
  final row = creationRow(c, rb: rb);
  return switch (kind) {
    Buy.attribute => 3,
    Buy.skill => toLevel * row.traitFactor,
    Buy.background => toLevel * (name == generationName ? 2 : row.traitFactor),
    Buy.discipline => toLevel * (isInClan(c, name, rb: rb) ? 3 : row.outOfClanFactor),
    Buy.humanity => 10,
    Buy.ritual => ritualCost(name, rb),
    Buy.technique => row.techniqueCost,
    Buy.elderPower => elderCost(c, name, rb),
    _ => 0,
  };
}

/// Plafond d'un trait à la création.
int capFor(Character c, String kind, String name, {Rulebook rb = const Rulebook()}) => switch (kind) {
      Buy.attribute => 10 + _bonusLeftFor(c, AttrCategory.values.byName(name), rb),
      Buy.humanity => 6,
      Buy.background when name == generationName => 3,
      Buy.skill => rb.skillCap(name, rankFor(c), row: creationRow(c, rb: rb)),
      Buy.background => rb.backgroundCap(name),
      Buy.ritual || Buy.technique || Buy.elderPower => 1,
      _ => 5,
    };

/// Points bonus du rang que la catégorie [cat] peut encore prendre (les autres catégories gardent les leurs).
int _bonusLeftFor(Character c, AttrCategory cat, Rulebook rb) {
  final placed = _sum([for (final a in AttrCategory.values) if (a != cat) max(0, c.attributes[a]!.value - 10)]);
  return max(0, creationRow(c, rb: rb).attributeBonus - placed);
}

/// Valeur de l'atout de lignée, s'il n'est pas déjà pris comme atout.
int lineageCost(Character c, {Rulebook rb = const Rulebook()}) {
  final m = rb.lineageMerit(c.clan, c.lineage);
  if (m == null || c.merits.any((t) => nameKey(t.name) == nameKey(m.$1))) return 0;
  return m.$2;
}

class Budget {
  const Budget({
    required this.start,
    required this.bonus,
    required this.flaws,
    required this.flawsTaken,
    required this.merits,
    required this.purchases,
    required this.setAsideCap,
  });

  /// XP de départ de la chronique, bonus de départ par défaut compris.
  final int start;
  final int bonus;

  /// XP rapportée par les handicaps (plafonnée).
  final int flaws;

  /// Points de handicaps pris (peuvent dépasser le plafond).
  final int flawsTaken;

  /// Points d'atouts, rareté de clan et atout de lignée compris.
  final int merits;
  final int purchases;

  /// XP qui peut être mise de côté à la fin de la création.
  final int setAsideCap;

  int get total => start + bonus + flaws;
  int get spent => merits + purchases;
  int get remaining => total - spent;
  int get setAside => remaining.clamp(0, setAsideCap);
  int get lost => remaining > setAsideCap ? remaining - setAsideCap : 0;
}

Budget budgetOf(Character c, {Rulebook rb = const Rulebook()}) {
  final v = rb.creation;
  final flaws = _sum(c.flaws.map((t) => t.level));
  return Budget(
    start: v.startingXp + v.defaultBonus,
    bonus: c.xpBonus,
    flaws: min(flaws, v.maxFlawXp),
    flawsTaken: flaws,
    merits: _sum(c.merits.map((t) => t.level)) + rb.rarityCost(c.clan, c.sect) + lineageCost(c, rb: rb),
    purchases: _sum(c.purchases.map((p) => purchaseCost(c, p.kind, p.name, p.toLevel, rb: rb))),
    setAsideCap: v.maxSetAside,
  );
}

void _setLevel(Character c, String kind, String name, int level, Rulebook rb) {
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
        if (level > 0) c.disciplines.add(Discipline(name, level, inClan: isInClan(c, name, rb: rb)));
      } else if (level <= 0 && !d.inClan) {
        c.disciplines.remove(d);
      } else {
        d.level = level;
      }
    case Buy.ritual:
      c.rituals.removeWhere((r) => nameKey(r.name) == nameKey(name));
      if (level > 0) c.rituals.add(Ritual(name, rb.ritualSchool(name) ?? '', rb.ritualLevel(name)));
    case Buy.technique:
      c.techniques.removeWhere((t) => nameKey(t) == nameKey(name));
      if (level > 0) c.techniques.add(name);
    case Buy.elderPower:
      c.elderPowers.removeWhere((e) => nameKey(e.name) == nameKey(name));
      if (level > 0) c.elderPowers.add(ElderPower(name, rb.elderDiscipline(name) ?? ''));
    case Buy.humanity:
      c.humanity = level;
  }
}

/// Achète un niveau. Renvoie un message si l'achat est impossible.
String? addPurchase(Character c, String kind, String name, {Rulebook rb = const Rulebook()}) {
  final ghoulError = ghoulPurchaseError(c, kind, name);
  if (ghoulError != null) return ghoulError;
  final to = levelOf(c, kind, name) + 1;
  final ritual = kind == Buy.ritual ? rb.find('rituals', name) : null;
  if (ritual != null && ritual.data['atCreation'] != true) return 'Ce rituel ne s’apprend pas à la création.';
  final powerError = switch (kind) {
    Buy.ritual => ritualError(c, name, rb),
    Buy.technique => techniqueError(c, name, rb),
    Buy.elderPower => elderError(c, name, rb),
    _ => null,
  };
  if (powerError != null) return powerError;
  final cap = capFor(c, kind, name, rb: rb);
  if (to > cap) return 'Plafond atteint ($cap).';
  if (kind == Buy.discipline && !isInClan(c, name, rb: rb)) {
    if (!rb.isCommon(name)) {
      return 'Hors clan, seules les disciplines communes s’achètent à la création.';
    }
    final outOfClan = _sum(c.disciplines.where((d) => !d.inClan).map((d) => d.level));
    if (outOfClan + 1 > maxOutOfClanDots) return 'Hors clan : $maxOutOfClanDots points au plus à la création.';
  }
  final cost = purchaseCost(c, kind, name, to, rb: rb);
  _setLevel(c, kind, name, to, rb);
  c.purchases.add(Purchase(kind, name, to, cost));
  return null;
}

/// Retire un achat ; seulement le plus haut niveau acheté d'un trait.
String? removePurchase(Character c, int index, {Rulebook rb = const Rulebook()}) {
  final p = c.purchases[index];
  if (levelOf(c, p.kind, p.name) != p.toLevel) return 'Retirez d’abord l’achat de niveau supérieur.';
  c.purchases.removeAt(index);
  _setLevel(c, p.kind, p.name, p.toLevel - 1, rb);
  return null;
}

/// Choix du clan : disciplines en clan du clan ; les anciennes sont retirées, ou passent hors clan si achetées.
void setClan(Character c, String? name, {Rulebook rb = const Rulebook()}) {
  if (name == c.clan) return; // Caïtiff : ne pas effacer les disciplines déjà choisies
  c.clan = name;
  final own = rb.clanDisciplines(name);
  bool inNew(Discipline d) => own.contains(d.name);
  c.disciplines.removeWhere((d) => d.inClan && purchasedCount(c, Buy.discipline, d.name) == 0 && !inNew(d));
  for (final d in c.disciplines) {
    if (d.inClan && !inNew(d)) {
      // Hors clan, seuls les points achetés restent (pas de points gratuits).
      d
        ..inClan = false
        ..level = purchasedCount(c, Buy.discipline, d.name);
    }
  }
  for (final n in own) {
    final d = _findD(c.disciplines, n);
    if (d == null) {
      c.disciplines.add(Discipline(n, 0, inClan: true));
    } else {
      d.inClan = true;
    }
  }
}

/// Niveau gratuit d'une compétence ou d'un historique (le niveau final ajoute les achats).
void setFreeLevel(Character c, String kind, String name, int free, {Rulebook rb = const Rulebook()}) =>
    _setLevel(c, kind, name, free + purchasedCount(c, kind, name), rb);

void setDisciplineFree(Character c, String name, int free) {
  final d = _findD(c.disciplines, name);
  if (d != null) d.level = free + purchasedCount(c, Buy.discipline, name);
}

/// Les achats d'un trait occupent toujours les niveaux juste au-dessus de ses points gratuits,
/// même après un changement de niveau gratuit, de catégorie ou de clan.
void _renumberPurchases(Character c, Rulebook rb) {
  final seen = <String, int>{};
  for (var i = 0; i < c.purchases.length; i++) {
    final p = c.purchases[i];
    final key = '${p.kind}/${p.name}';
    final n = seen[key] = (seen[key] ?? 0) + 1;
    final to = freeLevelOf(c, p.kind, p.name) + n;
    final cost = purchaseCost(c, p.kind, p.name, to, rb: rb);
    if (to != p.toLevel || cost != p.cost) c.purchases[i] = Purchase(p.kind, p.name, to, cost);
  }
}

/// Recalcule rang, Sang, Volonté, Humanité, Santé, attributs et compteurs d'XP.
void applyDerived(Character c, {Rulebook rb = const Rulebook()}) {
  final ghoul = c.ghoul != null;
  final rank = ghoul ? null : rankFor(c);
  c.genRank = rank;
  final row = ghoul ? rb.ghoulRow() : (rank == null ? null : rb.gen(rank));
  if (ghoul || row == null || !row.numbers.contains(c.genNumber)) c.genNumber = null;
  c
    ..blood = row?.blood ?? 0
    ..bloodPerTurn = row?.bloodPerTurn ?? 0
    ..willpower = 6
    ..humanity = levelOf(c, Buy.humanity, humanityName)
    ..health = '3 · 3 · 3';
  final slots = rb.creation.attributeSlots;
  for (final cat in AttrCategory.values) {
    final i = c.attributeRanks.indexOf(cat);
    c.attributes[cat]!.value = (i >= 0 ? slots[i] : 0) + purchasedCount(c, Buy.attribute, cat.name);
  }
  // Création : les points bonus placés se lisent dans les valeurs (au-delà de 10).
  c.attributeBonus = {for (final cat in AttrCategory.values) cat: max(0, c.attributes[cat]!.value - 10)};
  _renumberPurchases(c, rb);
  final b = budgetOf(c, rb: rb);
  c
    ..xpInitial = b.start + c.xpBonus + b.flaws
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

/// État dans le référentiel d'un nom porté par la fiche : hors liste ou accord du conte (avertissement),
/// interdit ou brouillon (erreur) ; null si rien à signaler.
Check? stateCheck(Rulebook rb, String cat, String noun, String name, int step) {
  final e = rb.find(cat, name);
  if (e == null) return Check(step, CheckLevel.warn, '$noun $name hors liste : à confirmer par le conte');
  if (!e.state.offered) return Check(step, CheckLevel.error, '$name est interdit dans la chronique');
  if (e.state == RuleState.approval) return Check(step, CheckLevel.warn, '$name : accord du conte nécessaire');
  return null;
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
List<Check> creationChecks(Character c, {Rulebook rb = const Rulebook()}) {
  final out = <Check>[];
  void add(int step, CheckLevel level, String text) => out.add(Check(step, level, text));
  void state(int step, String cat, String noun, String? name) {
    final k = name == null ? null : stateCheck(rb, cat, noun, name, step);
    if (k != null) out.add(k);
  }

  final v = rb.creation;

  final identity = [c.name, c.concept, c.archetype, c.sect].every((s) => (s ?? '').trim().isNotEmpty);
  add(1, identity ? CheckLevel.ok : CheckLevel.todo,
      identity ? 'Nom, concept, archétype et secte renseignés' : 'Renseignez le nom, le concept, l’archétype et la secte');
  state(1, 'archetypes', 'Archétype', c.archetype);
  state(1, 'sects', 'Secte', c.sect);
  if (c.kind == CharacterKind.pj && c.sect != null) {
    final playable = rb.playable(c.sect);
    if (playable == 'npcOnly') add(1, CheckLevel.error, 'Secte ${c.sect} : réservée aux PNJ');
    if (playable == 'pjOnApproval') add(1, CheckLevel.warn, 'Secte ${c.sect} : PJ sur accord du conte');
  }

  final clan = rb.find('clans', c.clan);
  if (c.ghoul != null) {
    add(3, CheckLevel.ok, ghoulLine(c.ghoul!));
  } else if (c.clan == null) {
    add(3, CheckLevel.todo, 'Choisissez un clan');
  } else if (clan == null) {
    add(3, CheckLevel.warn, 'Clan ${c.clan} hors liste : à confirmer par le conte');
  } else {
    state(3, 'clans', 'Clan', c.clan);
    switch (rb.rarity(c.clan, c.sect)) {
      case 'forbidden':
        add(3, CheckLevel.error, 'Clan ${c.clan} : interdit pour la secte ${c.sect ?? 'choisie'}');
      case 'uncommon':
        add(3, CheckLevel.ok, 'Clan ${c.clan} : peu commun, atout de 2 points');
      case 'rare':
        add(3, CheckLevel.warn, 'Clan ${c.clan} : rare, atout de 4 points, accord du conte nécessaire');
      default:
        add(3, CheckLevel.ok, 'Clan ${c.clan} : commun, aucun atout de rareté');
    }
  }

  final ranked = c.attributeRanks.whereType<AttrCategory>().toSet().length == 3;
  final focused = AttrCategory.values.every((a) => (c.attributes[a]!.focus ?? '').isNotEmpty);
  final attributes = v.attributeSlots.join(' / ');
  add(4, ranked && focused ? CheckLevel.ok : CheckLevel.todo,
      ranked && focused ? 'Attributs répartis $attributes, un focus chacun' : 'Classez les attributs $attributes et choisissez un focus par catégorie');
  final bonus = _sum(c.attributeBonus.values);
  final allowed = creationRow(c, rb: rb).attributeBonus;
  if (bonus > allowed) add(4, CheckLevel.error, 'Points bonus d’attribut : $bonus placés, $allowed au plus');

  _slots(out, 5, ('compétence', 'compétences'), [for (final s in c.skills) freeLevelOf(c, Buy.skill, s.name)], v.skillSlots,
      'Compétences ${slotsText(v.skillSlots)}');
  for (final s in c.skills) {
    final mode = rb.domainMode(s.name);
    if ((mode == 'perDot' || mode == 'multiple') && (s.note ?? '').trim().isEmpty) add(5, CheckLevel.todo, 'Précisez le domaine de ${s.name}');
    state(5, 'skills', 'Compétence', s.name);
    final cap = rb.skillCap(s.name, rankFor(c), row: creationRow(c, rb: rb));
    if (s.level > cap) add(5, CheckLevel.error, '${s.name} : $cap au plus');
  }

  _slots(out, 6, ('historique', 'historiques'), [for (final b in c.backgrounds) freeLevelOf(c, Buy.background, b.name)],
      v.backgroundSlots, 'Historiques ${v.backgroundSlots.join(' / ')}');
  for (final b in c.backgrounds) {
    if (b.name == generationName) continue;
    state(6, 'backgrounds', 'Historique', b.name);
    final note = (b.note ?? '').trim();
    final ask = rb.backgroundAsk(b.name);
    if (ask != null && note.isEmpty) add(6, CheckLevel.todo, 'Précisez ${b.name}');
    final scale = rb.backgroundScale(b.name);
    if (ask == 'monthly' && note.isNotEmpty && b.level >= 1 && b.level <= scale.length && nameKey(note) != nameKey(scale[b.level - 1])) {
      add(6, CheckLevel.warn, '${b.name} : montant hors barème, à valider par le conte');
    }
    if (rb.backgroundApproval(b.name)) add(6, CheckLevel.warn, '${b.name} : montant à valider par le conte');
    final cap = rb.backgroundCap(b.name);
    if (b.level > cap) add(6, CheckLevel.error, '${b.name} : $cap au plus');
  }
  if (c.ghoul != null) {
    if (generationLevel(c) > 0) add(6, CheckLevel.error, 'Une goule n’a pas de Génération');
  } else if (generationLevel(c) == 0) {
    add(6, CheckLevel.error, 'Sans point de Génération, le personnage est un mortel');
  } else if (c.genNumber == null) {
    add(6, CheckLevel.todo, 'Choisissez la génération');
  }

  final inClan = c.disciplines.where((d) => d.inClan).toList();
  if (c.ghoul != null) {
    _ghoulDisciplines(out, c);
  } else if (inClan.length != 3) {
    final choose = clan != null && rb.clanDisciplines(c.clan).isEmpty;
    add(7, CheckLevel.todo, choose ? 'Choisissez trois disciplines communes' : 'Trois disciplines en clan attendues');
  } else {
    _slots(out, 7, ('discipline en clan', 'disciplines en clan'), [for (final d in inClan) freeLevelOf(c, Buy.discipline, d.name)],
        v.disciplineSlots, 'Disciplines en clan ${v.disciplineSlots.join(' / ')}');
  }
  for (final d in c.disciplines) {
    state(7, 'disciplines', 'Discipline', d.name);
  }
  for (final d in c.disciplines.where((d) => !d.inClan && c.ghoul == null)) {
    if (freeLevelOf(c, Buy.discipline, d.name) > 0) add(7, CheckLevel.error, '${d.name} hors clan : uniquement par achat');
    if (d.level > 0 && !rb.isCommon(d.name)) add(7, CheckLevel.error, '${d.name} hors clan : seules les disciplines communes à la création');
  }

  final b = budgetOf(c, rb: rb);
  if (b.merits > maxMeritPoints) {
    add(8, CheckLevel.error, 'Atouts : ${b.merits} / $maxMeritPoints points');
  } else {
    add(8, CheckLevel.ok, 'Atouts ${b.merits} / $maxMeritPoints · handicaps ${b.flawsTaken} / ${v.maxFlawXp} XP');
  }
  if (b.flawsTaken > v.maxFlawXp) add(8, CheckLevel.warn, 'Handicaps au-delà de ${v.maxFlawXp} : pas d’XP en plus');
  for (final (cat, noun, list) in [('merits', 'Atout', c.merits), ('flaws', 'Handicap', c.flaws)]) {
    for (final t in list) {
      state(8, cat, noun, t.name);
      final value = rb.cost(cat, t.name);
      if (value != null && value != t.level) add(8, CheckLevel.warn, '${t.name} : $value points dans le référentiel, ${t.level} sur la fiche');
    }
  }

  // Plafond du livre (p. 300) ; un brouillon d'avant ce plafond a pu aller au-delà.
  if (c.humanity > 6) add(9, CheckLevel.error, 'Humanité : 6 au plus.');
  if (b.remaining < 0) {
    add(9, CheckLevel.error, 'Budget dépassé de ${-b.remaining} XP');
  } else {
    add(9, CheckLevel.ok, '${b.spent} XP dépensés, ${b.setAside} mis de côté');
    if (b.lost > 0) add(9, CheckLevel.warn, '${b.lost} XP perdus (${v.maxSetAside} au plus mis de côté)');
  }

  // Brouillon écrit hors de l'application : ce que l'écran refuse à une goule est bloqué ici aussi.
  if (c.ghoul != null) {
    final forbidden = {for (final p in c.purchases) ?ghoulPurchaseError(c, p.kind, p.name)};
    if (c.techniques.isNotEmpty || c.elderPowers.isNotEmpty) forbidden.add(ghoulPurchaseError(c, Buy.technique, '')!);
    for (final e in forbidden) {
      add(9, CheckLevel.error, e);
    }
  }
  for (final r in c.rituals) {
    state(9, 'rituals', 'Rituel', r.name);
  }
  for (final t in c.techniques) {
    state(9, 'techniques', 'Technique', t);
  }
  for (final e in c.elderPowers) {
    state(9, 'elderPowers', 'Pouvoir d’ancien', e.name);
    if (!elderInClan(c, e.name, rb)) add(9, CheckLevel.warn, 'Professeur nécessaire : ${e.name} hors clan, à confirmer par le conte');
  }
  for (final p in powerProblems(c, rb)) {
    add(9, CheckLevel.error, p);
  }
  if (c.rituals.isNotEmpty) add(9, CheckLevel.warn, 'Rituels choisis à la création : à confirmer par le conte');

  // Les règles Firestore ne recalculent rien : une fiche écrite hors de l'application, ou calculée
  // avant un changement des valeurs de création, se voit ici (Review Focus 3).
  final derived = c.clone();
  applyDerived(derived, rb: rb);
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

void _ghoulDisciplines(List<Check> out, Character c) {
  final g = c.ghoul!;
  final total = _sum(c.disciplines.map((d) => d.level));
  final level = total < ghoulDisciplinePoints ? CheckLevel.todo : (total > ghoulDisciplinePoints ? CheckLevel.error : CheckLevel.ok);
  out.add(Check(7, level, 'Disciplines de goule : $total points sur $ghoulDisciplinePoints'));
  for (final d in c.disciplines) {
    final own = g.domitorDisciplines.where((x) => x.name == d.name).firstOrNull;
    if (own == null) {
      out.add(Check(7, CheckLevel.error, '${d.name} : le domitor ne la possède pas'));
    } else if (d.level > own.level) {
      out.add(Check(7, CheckLevel.error, '${d.name} : niveau ${d.level} au-delà de celui du domitor (${own.level})'));
    }
  }
}

bool canSubmit(List<Check> checks) => checks.every((k) => k.level == CheckLevel.ok || k.level == CheckLevel.warn);

/// Coche d'une étape dans la navigation.
bool stepComplete(Character c, int step, List<Check> checks) => switch (step) {
      2 => c.step > 2,
      10 => canSubmit(checks),
      _ => checks.where((k) => k.step == step).every((k) => k.level == CheckLevel.ok || k.level == CheckLevel.warn),
    };
