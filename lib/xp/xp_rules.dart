import '../characters/character.dart';
import '../rules/creation_rules.dart' show Check, CheckLevel, generationName, humanityName, maxMeritPoints;
import '../rules/met_lists.dart';
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
    };

/// Niveau après les achats déjà dans la demande.
int levelWith(Character c, List<XpItem> items, XpKind k, String name) {
  final last = items.where((i) => i.kind == k && i.name == name).lastOrNull;
  return last?.toLevel ?? levelNow(c, k, name);
}

bool _cheap(Character c) => (c.genRank ?? GenRank.neonate) == GenRank.neonate;

bool inClan(Character c, String discipline) =>
    _discipline(c, discipline)?.inClan ?? (clanInfo(c.clan)?.disciplines.contains(discipline) ?? false);

/// Coût au barème actuel de la fiche.
int costOf(Character c, XpItem i) => switch (i.kind) {
      XpKind.attribute => 3,
      XpKind.skill || XpKind.background => i.toLevel * (_cheap(c) ? 1 : 2),
      XpKind.discipline => i.toLevel * (inClan(c, i.name) ? 3 : 4),
      XpKind.merit => i.toLevel,
      XpKind.humanity => 10,
      XpKind.flawBuyback => 2 * i.fromLevel,
    };

String ruleText(Character c, XpItem i) => switch (i.kind) {
      XpKind.attribute => '3 XP par point',
      XpKind.skill || XpKind.background => 'Nouveau niveau × ${_cheap(c) ? 1 : 2}',
      XpKind.discipline => inClan(c, i.name) ? 'En clan · nouveau niveau × 3' : 'Hors clan · nouveau niveau × 4',
      XpKind.merit => 'Sa valeur en XP',
      XpKind.humanity => '10 XP le point',
      XpKind.flawBuyback => '2 × sa valeur',
    };

/// Tableau « Coûts pour un … » (J-XP).
List<(String, String)> costTable(Character c) {
  final f = _cheap(c) ? 1 : 2;
  return [
    ('Attribut', '3 XP par point'),
    ('Compétence', 'Nouveau niveau × $f'),
    ('Historique', 'Nouveau niveau × $f'),
    ('Discipline en clan', 'Nouveau niveau × 3'),
    ('Discipline hors clan', 'Nouveau niveau × 4'),
    ('Atout', 'Sa valeur en XP'),
    ('Humanité', '10 XP le point'),
    ('Rachat d’un handicap', '2 × sa valeur'),
  ];
}

int capOf(XpKind k) => switch (k) {
      XpKind.attribute || XpKind.humanity => 10,
      _ => 5,
    };

/// Libellé de la précision obligatoire pour un nouveau point, ou null.
String? noteLabel(XpKind k, String name) => switch (k) {
      XpKind.background => 'Détail du nouveau point',
      XpKind.skill when domainSkills.contains(name) => 'Domaine',
      _ => null,
    };

/// Éléments proposés pour un type : valeur → libellé.
Map<String, String> elementOptions(Character c, XpKind k) => switch (k) {
      XpKind.attribute => {for (final a in AttrCategory.values) a.name: a.label},
      XpKind.skill => {for (final n in {...c.skills.map((t) => t.name), ...skillNames}) n: n},
      XpKind.background => {
          for (final n in {...c.backgrounds.map((t) => t.name), ...backgroundNames})
            if (n != generationName) n: n,
        },
      XpKind.discipline => {
          for (final n in {
            ...c.disciplines.map((d) => d.name),
            ...?clanInfo(c.clan)?.disciplines,
            ...commonDisciplines,
          })
            n: n,
        },
      XpKind.merit => {
          for (final e in baseMerits.entries)
            if (!c.merits.any((m) => m.name == e.key)) e.key: '${e.key} (${e.value})',
        },
      XpKind.humanity => {humanityName: humanityName},
      XpKind.flawBuyback => {for (final f in c.flaws) f.name: '${f.name} (${f.level})'},
    };

/// Le prochain achat pour ce trait, sans contrôle.
XpItem draftItem(Character c, List<XpItem> items, XpKind k, String name, {String? note}) {
  final from = levelWith(c, items, k, name);
  final to = switch (k) {
    XpKind.merit => baseMerits[name] ?? 0,
    XpKind.flawBuyback => 0,
    _ => from + 1,
  };
  final n = (note ?? '').trim();
  final draft = XpItem(k, name, from, to, 0, note: n.isEmpty ? null : n);
  return XpItem(k, name, from, to, costOf(c, draft), note: draft.note);
}

/// Points d'atouts : fiche, rareté du clan et atouts déjà dans la demande.
int meritPoints(Character c, List<XpItem> items) =>
    c.merits.fold(0, (s, m) => s + m.level) +
    (clanInfo(c.clan)?.rarity.meritPoints ?? 0) +
    items.where((i) => i.kind == XpKind.merit).fold(0, (s, i) => s + i.toLevel);

/// Message si [item] ne peut pas s'ajouter à la demande ; null sinon.
String? itemError(Character c, List<XpItem> items, XpItem item, {required int usable}) {
  if (item.kind == XpKind.background && item.name == generationName) {
    return 'La Génération ne s’achète qu’à la création.';
  }
  switch (item.kind) {
    case XpKind.merit:
      if (item.fromLevel > 0) return 'Atout déjà pris.';
      if (item.toLevel == 0) return 'Atout inconnu : à demander au conte.';
      if (meritPoints(c, items) + item.toLevel > maxMeritPoints) {
        return 'Atouts : $maxMeritPoints points au plus, rareté de clan comprise.';
      }
    case XpKind.flawBuyback:
      if (item.fromLevel == 0) return 'Handicap déjà racheté.';
    default:
      if (item.toLevel > capOf(item.kind)) return 'Plafond atteint (${capOf(item.kind)}).';
  }
  final label = noteLabel(item.kind, item.name);
  if (label != null && item.note == null) {
    return label == 'Domaine' ? 'Précisez le domaine.' : 'Précisez le détail du nouveau point.';
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
int recomputedTotal(Character c, List<XpItem> items) => items.fold(0, (s, i) => s + costOf(c, i));

/// Un achat a la forme produite par draftItem (un niveau, ou la valeur de l'atout, ou un rachat vers 0).
/// Les règles Firestore ne vérifient rien de cela : une demande écrite hors de l'application passe par ici.
bool wellFormed(XpItem i) => switch (i.kind) {
      XpKind.attribute => AttrCategory.values.asNameMap().containsKey(i.name) && i.toLevel == i.fromLevel + 1,
      XpKind.merit => i.fromLevel == 0 && baseMerits[i.name] != null && i.toLevel == baseMerits[i.name],
      XpKind.flawBuyback => i.toLevel == 0 && i.fromLevel > 0,
      _ => i.toLevel == i.fromLevel + 1,
    };

String _gap(XpItem i, int expected) =>
    'La fiche a changé : ${i.displayName} est à ${levelText(i.kind, expected)} (demande faite depuis ${levelText(i.kind, i.fromLevel)})';

/// Ce qui empêche le joueur d'envoyer sa demande (brouillon rouvert, fiche changée, XP réservée ailleurs).
List<String> sendProblems(Character c, List<XpItem> items, {required int usable}) {
  final out = <String>[];
  final seen = <XpItem>[];
  for (final i in items) {
    final expected = levelWith(c, seen, i.kind, i.name);
    if (expected != i.fromLevel) out.add('${_gap(i, expected)}. Retirez cet achat puis ajoutez-le de nouveau.');
    seen.add(i);
  }
  final total = items.fold<int>(0, (s, i) => s + i.cost);
  if (total > usable) out.add('XP libre insuffisante : $total requis, $usable disponible.');
  return out;
}

/// Contrôles affichés au conteur avant de valider (C-Validation). Erreur = validation impossible.
List<Check> requestChecks(Character c, XpRequest r, {required int reservedOthers}) {
  final out = <Check>[
    if (c.status != CharacterStatus.active) const Check(0, CheckLevel.error, 'La fiche n’est plus active : refusez la demande.'),
  ];
  final seen = <XpItem>[];
  for (final i in r.items) {
    if (!wellFormed(i)) {
      out.add(Check(0, CheckLevel.error,
          'Achat invalide : ${i.label} (${levelText(i.kind, i.fromLevel)} → ${levelText(i.kind, i.toLevel)})'));
      seen.add(i);
      continue;
    }
    final expected = levelWith(c, seen, i.kind, i.name);
    if (expected != i.fromLevel) out.add(Check(0, CheckLevel.error, _gap(i, expected)));
    final cost = costOf(c, i);
    if (cost != i.cost) out.add(Check(0, CheckLevel.warn, 'Coût recalculé : $cost XP au lieu de ${i.cost} (${i.label})'));
    if (i.kind != XpKind.merit && i.kind != XpKind.flawBuyback && i.toLevel > capOf(i.kind)) {
      out.add(Check(0, CheckLevel.error, 'Plafond dépassé : ${i.label} (${capOf(i.kind)} au plus)'));
    }
    if (i.kind == XpKind.discipline && !inClan(c, i.name) && !commonDisciplines.contains(i.name)) {
      out.add(Check(0, CheckLevel.warn, 'Mentor nécessaire : ${i.name} hors clan, à confirmer par le conte'));
    }
    seen.add(i);
  }
  if (meritPoints(c, r.items) > maxMeritPoints) {
    out.add(Check(0, CheckLevel.error, 'Atouts : plus de $maxMeritPoints points, rareté de clan comprise'));
  }
  final after = c.xpAvailable - reservedOthers - recomputedTotal(c, r.items);
  if (after < 0) out.add(Check(0, CheckLevel.warn, 'Dette après validation : ${-after} XP'));
  if (out.isEmpty) out.add(const Check(0, CheckLevel.ok, 'Niveaux et coûts conformes à la fiche'));
  return out;
}

/// La fiche après la demande : niveaux, atouts, handicaps, Humanité et XP dépensée (barème actuel).
Character applyRequest(Character c, List<XpItem> items) {
  final n = c.clone();
  for (final i in items) {
    switch (i.kind) {
      case XpKind.attribute:
        n.attributes[AttrCategory.values.byName(i.name)]!.value = i.toLevel;
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
          n.disciplines.add(Discipline(i.name, i.toLevel, inClan: inClan(c, i.name)));
        } else {
          d.level = i.toLevel;
        }
      case XpKind.humanity:
        n.humanity = i.toLevel;
      case XpKind.flawBuyback:
        n.flaws.removeWhere((t) => t.name == i.name);
    }
  }
  n.xpSpent += recomputedTotal(c, items);
  return n;
}
