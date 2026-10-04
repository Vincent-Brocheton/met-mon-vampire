import '../characters/character.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import '../rules/powers_rules.dart';
import '../rules/creation_rules.dart' show Check, CheckLevel, generationName, humanityName, lineageCost, maxMeritPoints, stateCheck;
import 'xp_request.dart';

Trait? _trait(List<Trait> list, String name) => list.where((t) => t.name == name).firstOrNull;

Discipline? _discipline(Character c, String name) => c.disciplines.where((d) => d.name == name).firstOrNull;

/// Niveau actuel du trait sur la fiche.
int levelNow(Character c, XpKind k, String name) => switch (k) {
      XpKind.attribute => c.attributes[AttrCategory.values.byName(name)]!.value,
      XpKind.skill => _trait(c.skills, name)?.level ?? 0,
      XpKind.background => _trait(c.backgrounds, name)?.level ?? 0,
      XpKind.discipline => _discipline(c, name)?.level ?? 0,
      XpKind.merit => _trait(c.merits, name)?.level ?? 0,
      XpKind.humanity => c.humanity,
      XpKind.flawBuyback => _trait(c.flaws, name)?.level ?? 0,
      XpKind.ritual => _knows(c.rituals.map((r) => r.name), name) ? 1 : 0,
      XpKind.technique => _knows(c.techniques, name) ? 1 : 0,
      XpKind.elderPower => _knows(c.elderPowers.map((e) => e.name), name) ? 1 : 0,
    };

/// Niveau après les achats déjà dans la demande.
int levelWith(Character c, List<XpItem> items, XpKind k, String name) {
  final last = items.where((i) => i.kind == k && i.name == name).lastOrNull;
  return last?.toLevel ?? levelNow(c, k, name);
}

GenRow _row(Character c, Rulebook rb) => rb.gen(c.genRank ?? GenRank.neonate);

/// Note d'un achat d'attribut qui place un point bonus de Génération (plafond 10 + 1).
const bonusNote = 'point bonus';

bool _isBonus(XpItem i) => i.kind == XpKind.attribute && i.note == bonusNote;

/// Plafond de la catégorie : 10 + points bonus placés sur la fiche et dans la demande.
int attributeCap(Character c, List<XpItem> items, AttrCategory cat) =>
    10 + (c.attributeBonus[cat] ?? 0) + items.where((i) => _isBonus(i) && i.name == cat.name).length;

/// Points bonus du rang encore libres, compte tenu de la demande.
int bonusLeft(Character c, List<XpItem> items, Rulebook rb) =>
    _row(c, rb).attributeBonus - c.attributeBonus.values.fold<int>(0, (a, b) => a + b) - items.where(_isBonus).length;

bool _knows(Iterable<String> names, String name) => names.any((n) => nameKey(n) == nameKey(name));

bool _isPower(XpKind k) => k == XpKind.ritual || k == XpKind.technique || k == XpKind.elderPower;

/// Contrôle d'un nouveau rituel, d'une technique ou d'un pouvoir d'ancien sur la fiche [c].
String? _powerError(Character c, XpItem i, Rulebook rb) => switch (i.kind) {
      XpKind.ritual => ritualError(c, i.name, rb),
      XpKind.technique => techniqueError(c, i.name, rb),
      XpKind.elderPower => elderError(c, i.name, rb),
      _ => null,
    };

bool inClan(Character c, String discipline, {Rulebook rb = const Rulebook()}) =>
    _discipline(c, discipline)?.inClan ?? rb.clanDisciplines(c.clan).contains(discipline);

/// Catégorie du référentiel d'un type d'achat.
String? ruleCategoryOf(XpKind k) => switch (k) {
      XpKind.skill => 'skills',
      XpKind.background => 'backgrounds',
      XpKind.discipline => 'disciplines',
      XpKind.merit => 'merits',
      XpKind.flawBuyback => 'flaws',
      XpKind.ritual => 'rituals',
      XpKind.technique => 'techniques',
      XpKind.elderPower => 'elderPowers',
      _ => null,
    };

/// Coût au barème actuel de la fiche.
int costOf(Character c, XpItem i, {Rulebook rb = const Rulebook()}) => switch (i.kind) {
      XpKind.attribute => 3,
      XpKind.skill || XpKind.background => i.toLevel * _row(c, rb).traitFactor,
      XpKind.discipline => i.toLevel * (inClan(c, i.name, rb: rb) ? 3 : _row(c, rb).outOfClanFactor),
      XpKind.merit => i.toLevel,
      XpKind.humanity => 10,
      XpKind.flawBuyback => 2 * i.fromLevel,
      XpKind.ritual => ritualCost(i.name, rb),
      XpKind.technique => techniqueCost(c, rb),
      XpKind.elderPower => elderCost(c, i.name, rb),
    };

String ruleText(Character c, XpItem i, {Rulebook rb = const Rulebook()}) => switch (i.kind) {
      XpKind.attribute => '3 XP par point',
      XpKind.skill || XpKind.background => 'Nouveau niveau × ${_row(c, rb).traitFactor}',
      XpKind.discipline =>
        inClan(c, i.name, rb: rb) ? 'En clan · nouveau niveau × 3' : 'Hors clan · nouveau niveau × ${_row(c, rb).outOfClanFactor}',
      XpKind.merit => 'Sa valeur en XP',
      XpKind.humanity => '10 XP le point, 6 au plus',
      XpKind.flawBuyback => '2 × sa valeur',
      XpKind.ritual => 'Niveau du rituel × ${rb.ritualCostPerLevel}',
      XpKind.technique => 'Selon le rang',
      XpKind.elderPower => elderInClan(c, i.name, rb) ? 'En clan' : 'Hors clan',
    };

/// Tableau « Coûts pour un … » (J-XP).
List<(String, String)> costTable(Character c, {Rulebook rb = const Rulebook()}) {
  final row = _row(c, rb);
  return [
    ('Attribut', '3 XP par point'),
    ('Compétence', 'Nouveau niveau × ${row.traitFactor}'),
    ('Historique', 'Nouveau niveau × ${row.traitFactor}'),
    ('Discipline en clan', 'Nouveau niveau × 3'),
    ('Discipline hors clan', 'Nouveau niveau × ${row.outOfClanFactor}'),
    ('Atout', 'Sa valeur en XP'),
    ('Humanité', '10 XP le point, 6 au plus'),
    ('Rituel', 'Niveau × ${rb.ritualCostPerLevel}'),
    ('Technique', row.techniqueCost == 0 ? 'Interdite à ce rang' : '${row.techniqueCost} XP'),
    ('Pouvoir d’ancien', row.eldersAllowed ? 'Selon le pouvoir' : 'Interdit à ce rang'),
    ('Rachat d’un handicap', '2 × sa valeur'),
  ];
}

int capOf(Character c, XpKind k, String name, {Rulebook rb = const Rulebook()}) => switch (k) {
      XpKind.attribute => 10,
      XpKind.humanity => 6,
      XpKind.skill => rb.skillCap(name, c.genRank),
      XpKind.background => rb.backgroundCap(name),
      _ => 5,
    };

/// Précision demandée pour un nouveau point : (libellé, obligatoire), ou null.
(String, bool)? noteSpec(XpKind k, String name, {Rulebook rb = const Rulebook()}) => switch (k) {
      XpKind.background => ('Détail du nouveau point', rb.backgroundAsk(name) != null),
      XpKind.skill => switch (rb.domainMode(name)) {
          'perDot' || 'multiple' => ('Domaine', true),
          'optional' => ('Domaine', false),
          _ => null,
        },
      _ => null,
    };

/// Éléments proposés pour un type : valeur → libellé. Brouillons et interdits ne sont pas proposés.
Map<String, String> elementOptions(Character c, XpKind k, {Rulebook rb = const Rulebook()}) {
  String label(String cat, String n, [String suffix = '']) =>
      '$n$suffix${rb.find(cat, n)?.state == RuleState.approval ? ' · accord du conte' : ''}';
  return switch (k) {
    XpKind.attribute => {for (final a in AttrCategory.values) a.name: a.label},
    XpKind.skill => {for (final n in {...c.skills.map((t) => t.name), ...rb.offeredNames('skills')}) n: label('skills', n)},
    XpKind.background => {
        for (final n in {...c.backgrounds.map((t) => t.name), ...rb.offeredNames('backgrounds')})
          if (n != generationName) n: label('backgrounds', n),
      },
    XpKind.discipline => {
        for (final n in {...c.disciplines.map((d) => d.name), ...rb.clanDisciplines(c.clan), ...rb.commonDisciplines()})
          n: label('disciplines', n),
      },
    XpKind.merit => {
        for (final e in rb.offered('merits'))
          if (e.data['withXp'] == true && rb.cost('merits', e.name) != null && !c.merits.any((m) => nameKey(m.name) == nameKey(e.name)))
            e.name: label('merits', e.name, ' (${rb.cost('merits', e.name)})'),
      },
    XpKind.ritual => {
        for (final e in rb.offered('rituals'))
          if (e.data['withXp'] == true && !_knows(c.rituals.map((r) => r.name), e.name))
            e.name: label('rituals', e.name, ' (niveau ${rb.ritualLevel(e.name)})'),
      },
    XpKind.technique => {
        for (final e in rb.offered('techniques'))
          if (!_knows(c.techniques, e.name)) e.name: label('techniques', e.name),
      },
    XpKind.elderPower => {
        for (final e in rb.offered('elderPowers'))
          if (!_knows(c.elderPowers.map((x) => x.name), e.name)) e.name: label('elderPowers', e.name),
      },
    XpKind.humanity => {humanityName: humanityName},
    XpKind.flawBuyback => {for (final f in c.flaws) f.name: '${f.name} (${f.level})'},
  };
}

/// Le prochain achat pour ce trait, sans contrôle.
XpItem draftItem(Character c, List<XpItem> items, XpKind k, String name, {String? note, Rulebook rb = const Rulebook()}) {
  final from = levelWith(c, items, k, name);
  final to = switch (k) {
    XpKind.merit => rb.cost('merits', name) ?? 0,
    XpKind.flawBuyback => 0,
    XpKind.ritual || XpKind.technique || XpKind.elderPower => 1,
    _ => from + 1,
  };
  final n = (note ?? '').trim();
  final cat = k == XpKind.attribute ? AttrCategory.values.asNameMap()[name] : null;
  // Au-delà du plafond, l'achat place un point bonus de Génération.
  final itemNote = cat != null ? (to > attributeCap(c, items, cat) ? bonusNote : null) : (n.isEmpty ? null : n);
  final draft = XpItem(k, name, from, to, 0, note: itemNote);
  return XpItem(k, name, from, to, costOf(c, draft, rb: rb), note: draft.note);
}

/// Points d'atouts : fiche, rareté du clan pour la secte, atout de lignée et atouts déjà dans la demande.
int meritPoints(Character c, List<XpItem> items, {Rulebook rb = const Rulebook()}) =>
    c.merits.fold(0, (s, m) => s + m.level) +
    rb.rarityCost(c.clan, c.sect) +
    lineageCost(c, rb: rb) +
    items.where((i) => i.kind == XpKind.merit).fold(0, (s, i) => s + i.toLevel);

/// Message si [item] ne peut pas s'ajouter à la demande ; null sinon.
String? itemError(Character c, List<XpItem> items, XpItem item, {required int usable, Rulebook rb = const Rulebook()}) {
  if (item.kind == XpKind.background && item.name == generationName) {
    return 'La Génération ne s’achète qu’à la création.';
  }
  final cat = ruleCategoryOf(item.kind);
  final entry = cat == null ? null : rb.find(cat, item.name);
  // Racheter un handicap interdit reste possible.
  if (entry != null && !entry.state.offered && item.kind != XpKind.flawBuyback) return '${item.name} est interdit dans la chronique.';
  switch (item.kind) {
    case XpKind.merit:
      if (item.fromLevel > 0) return 'Atout déjà pris.';
      if (item.toLevel == 0) return 'Atout inconnu : à demander au conte.';
      if (entry?.data['withXp'] != true) return 'Cet atout ne s’achète pas avec l’XP gagnée.';
      if (meritPoints(c, items, rb: rb) + item.toLevel > maxMeritPoints) {
        return 'Atouts : $maxMeritPoints points au plus, rareté de clan comprise.';
      }
    case XpKind.flawBuyback:
      if (item.fromLevel == 0) return 'Handicap déjà racheté.';
    case XpKind.ritual || XpKind.technique || XpKind.elderPower:
      if (item.fromLevel > 0) return 'Déjà appris.';
      if (item.kind == XpKind.ritual && entry?.data['withXp'] != true) return 'Ce rituel ne s’achète pas avec l’XP gagnée.';
      final e = _powerError(applyRequest(c, items, rb: rb), item, rb);
      if (e != null) return e;
    case XpKind.attribute:
      final cat = AttrCategory.values.byName(item.name);
      if (_isBonus(item) && bonusLeft(c, items, rb) <= 0) {
        return 'Plus de point bonus d’attribut : ${cat.label} ${attributeCap(c, items, cat)} au plus.';
      }
    default:
      final cap = capOf(c, item.kind, item.name, rb: rb);
      if (item.toLevel > cap) return 'Plafond atteint ($cap).';
  }
  final spec = noteSpec(item.kind, item.name, rb: rb);
  if (spec != null && spec.$2 && item.note == null) {
    return spec.$1 == 'Domaine' ? 'Précisez le domaine.' : 'Précisez le détail du nouveau point.';
  }
  final left = usable - items.fold(0, (s, i) => s + i.cost);
  if (item.cost > left) return 'XP libre insuffisante : ${item.cost} requis, $left restant après les achats déjà ajoutés.';
  return null;
}

/// Retire l'achat [index] ; seulement le plus haut niveau d'un trait.
String? removeItem(List<XpItem> items, int index) {
  final i = items[index];
  if (items.skip(index + 1).any((x) => x.kind == i.kind && x.name == i.name)) {
    return 'Retirez d’abord le niveau supérieur.';
  }
  items.removeAt(index);
  return null;
}

/// XP réservée par les demandes ouvertes de la fiche, sauf [exceptId].
int reservedBy(List<XpRequest> requests, String characterId, {String? exceptId}) => requests
    .where((r) => r.characterId == characterId && r.status.open && r.id != exceptId)
    .fold(0, (s, r) => s + r.total);

/// Total au barème actuel de la fiche (le rang a pu changer depuis l'envoi).
int recomputedTotal(Character c, List<XpItem> items, {Rulebook rb = const Rulebook()}) => items.fold(0, (s, i) => s + costOf(c, i, rb: rb));

/// Un achat a la forme produite par draftItem (un niveau, ou la valeur de l'atout, ou un rachat vers 0).
/// Les règles Firestore ne vérifient rien de cela : une demande écrite hors de l'application passe par ici.
bool wellFormed(XpItem i, {Rulebook rb = const Rulebook()}) => switch (i.kind) {
      XpKind.attribute => AttrCategory.values.asNameMap().containsKey(i.name) &&
          i.toLevel == i.fromLevel + 1 &&
          (i.note == null || i.note == bonusNote),
      XpKind.ritual || XpKind.technique || XpKind.elderPower => i.fromLevel == 0 && i.toLevel == 1,
      XpKind.merit => i.fromLevel == 0 && rb.cost('merits', i.name) == i.toLevel,
      XpKind.flawBuyback => i.toLevel == 0 && i.fromLevel > 0,
      _ => i.toLevel == i.fromLevel + 1,
    };

String _gap(XpItem i, int expected) =>
    'La fiche a changé : ${i.displayName} est à ${levelText(i.kind, expected)} (demande faite depuis ${levelText(i.kind, i.fromLevel)})';

/// Ce qui empêche le joueur d'envoyer sa demande (brouillon rouvert, fiche changée, XP réservée ailleurs).
List<String> sendProblems(Character c, List<XpItem> items, {required int usable, Rulebook rb = const Rulebook()}) {
  final out = <String>[];
  final seen = <XpItem>[];
  for (final i in items) {
    // Demande rouverte après un changement du référentiel : le conte la bloquerait de nouveau.
    final value = i.kind == XpKind.merit ? rb.cost('merits', i.name) : null;
    if (value != null && i.fromLevel == 0 && value != i.toLevel) {
      out.add('${i.label} vaut maintenant $value points. Retirez cet achat puis ajoutez-le de nouveau.');
    }
    final expected = levelWith(c, seen, i.kind, i.name);
    if (expected != i.fromLevel) out.add('${_gap(i, expected)}. Retirez cet achat puis ajoutez-le de nouveau.');
    seen.add(i);
  }
  final total = items.fold<int>(0, (s, i) => s + i.cost);
  if (total > usable) out.add('XP libre insuffisante : $total requis, $usable disponible.');
  return out;
}

/// Contrôles affichés au conteur avant de valider (C-Validation). Erreur = validation impossible.
List<Check> requestChecks(Character c, XpRequest r, {required int reservedOthers, Rulebook rb = const Rulebook()}) {
  final out = <Check>[
    if (c.status != CharacterStatus.active) const Check(0, CheckLevel.error, 'La fiche n’est plus active : refusez la demande.'),
  ];
  final seen = <XpItem>[];
  final stated = <String>{};
  for (final i in r.items) {
    if (!wellFormed(i, rb: rb)) {
      // Atout dont la valeur a changé dans le référentiel depuis l'envoi (Review Focus 4).
      final value = i.kind == XpKind.merit && i.fromLevel == 0 ? rb.cost('merits', i.name) : null;
      out.add(Check(
          0,
          CheckLevel.error,
          value != null
              ? 'Achat invalide : ${i.label} vaut $value points, la demande en compte ${i.toLevel}'
              : 'Achat invalide : ${i.label} (${levelText(i.kind, i.fromLevel)} → ${levelText(i.kind, i.toLevel)})'));
      seen.add(i);
      continue;
    }
    final expected = levelWith(c, seen, i.kind, i.name);
    if (expected != i.fromLevel) out.add(Check(0, CheckLevel.error, _gap(i, expected)));
    final cost = costOf(c, i, rb: rb);
    if (cost != i.cost) out.add(Check(0, CheckLevel.warn, 'Coût recalculé : $cost XP au lieu de ${i.cost} (${i.label})'));
    if (i.kind != XpKind.merit && i.kind != XpKind.flawBuyback && i.kind != XpKind.attribute && !_isPower(i.kind)) {
      final cap = capOf(c, i.kind, i.name, rb: rb);
      if (i.toLevel > cap) out.add(Check(0, CheckLevel.error, 'Plafond dépassé : ${i.label} ($cap au plus)'));
    }
    final cat = ruleCategoryOf(i.kind);
    if (cat != null && i.kind != XpKind.flawBuyback && stated.add('$cat/${i.name}')) {
      final k = stateCheck(rb, cat, i.kind.label, i.name, 0);
      if (k != null) out.add(k);
    }
    if (i.kind == XpKind.attribute) {
      final cat = AttrCategory.values.byName(i.name);
      if (i.toLevel > attributeCap(c, seen, cat) + (_isBonus(i) ? 1 : 0)) {
        out.add(Check(0, CheckLevel.error, 'Plafond dépassé : ${i.label} (${attributeCap(c, seen, cat)} au plus)'));
      }
      if (_isBonus(i) && bonusLeft(c, seen, rb) <= 0) out.add(Check(0, CheckLevel.error, 'Plus de point bonus d’attribut pour ${i.label}'));
      // Plafond relevé depuis l'envoi (C3) : valider consommerait un point du rang pour rien.
      if (_isBonus(i) && i.toLevel <= attributeCap(c, seen, cat)) {
        out.add(Check(0, CheckLevel.error, 'Achat invalide : ${i.label} n’a plus besoin de point bonus : retirez-le puis ajoutez-le de nouveau'));
      }
    }
    if (_isPower(i.kind)) {
      final e = _powerError(applyRequest(c, seen, rb: rb), i, rb);
      if (e != null) out.add(Check(0, CheckLevel.error, e));
      // Case décochée depuis l'envoi, ou demande écrite hors de l'application.
      if (i.kind == XpKind.ritual && rb.find('rituals', i.name)?.data['withXp'] != true) {
        out.add(const Check(0, CheckLevel.error, 'Ce rituel ne s’achète pas avec l’XP gagnée.'));
      }
      if (i.kind == XpKind.elderPower && !elderInClan(c, i.name, rb)) {
        out.add(Check(0, CheckLevel.warn, 'Professeur nécessaire : ${i.name} hors clan, à confirmer par le conte'));
      }
    }
    // Livre de base p. 108 : avec l'XP gagnée, toute discipline hors clan demande un professeur.
    if (i.kind == XpKind.discipline && !inClan(c, i.name, rb: rb)) {
      out.add(Check(0, CheckLevel.warn, 'Professeur nécessaire : ${i.name} hors clan, à confirmer par le conte'));
    }
    seen.add(i);
  }
  if (meritPoints(c, r.items, rb: rb) > maxMeritPoints) {
    out.add(Check(0, CheckLevel.error, 'Atouts : plus de $maxMeritPoints points, rareté de clan comprise'));
  }
  final after = c.xpAvailable - reservedOthers - recomputedTotal(c, r.items, rb: rb);
  if (after < 0) out.add(Check(0, CheckLevel.warn, 'Dette après validation : ${-after} XP'));
  if (out.isEmpty) out.add(const Check(0, CheckLevel.ok, 'Niveaux et coûts conformes à la fiche'));
  return out;
}

/// La fiche après la demande : niveaux, atouts, handicaps, Humanité et XP dépensée (barème actuel).
Character applyRequest(Character c, List<XpItem> items, {Rulebook rb = const Rulebook()}) {
  final n = c.clone();
  for (final i in items) {
    switch (i.kind) {
      case XpKind.attribute:
        final cat = AttrCategory.values.byName(i.name);
        n.attributes[cat]!.value = i.toLevel;
        if (_isBonus(i)) n.attributeBonus[cat] = (n.attributeBonus[cat] ?? 0) + 1;
      case XpKind.skill || XpKind.background || XpKind.merit:
        final list = switch (i.kind) {
          XpKind.skill => n.skills,
          XpKind.background => n.backgrounds,
          _ => n.merits,
        };
        final t = _trait(list, i.name);
        if (t == null) {
          list.add(Trait(i.name, i.toLevel, note: i.note));
        } else {
          t.level = i.toLevel;
          if (i.note != null) t.note = [?t.note, i.note!].join(' · ');
        }
      case XpKind.discipline:
        final d = _discipline(n, i.name);
        if (d == null) {
          n.disciplines.add(Discipline(i.name, i.toLevel, inClan: inClan(c, i.name, rb: rb)));
        } else {
          d.level = i.toLevel;
        }
      case XpKind.ritual:
        n.rituals.add(Ritual(i.name, rb.ritualSchool(i.name) ?? '', rb.ritualLevel(i.name)));
      case XpKind.technique:
        n.techniques.add(i.name);
      case XpKind.elderPower:
        n.elderPowers.add(ElderPower(i.name, rb.elderDiscipline(i.name) ?? ''));
      case XpKind.humanity:
        n.humanity = i.toLevel;
      case XpKind.flawBuyback:
        n.flaws.removeWhere((t) => t.name == i.name);
    }
  }
  n.xpSpent += recomputedTotal(c, items, rb: rb);
  return n;
}
