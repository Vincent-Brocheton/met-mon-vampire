import 'dart:math';

import '../rulebook/rulebook.dart';
import '../rules/creation_rules.dart' show generationName, setClan;
import 'character.dart';

/// Niveau de l'historique Génération d'un rang : 1 Neonate, 2 Ancilla, 3 Pretender.
int rankLevel(GenRank r) => GenRank.values.indexOf(r) + 1;

/// Rang dont le tableau des générations contient le numéro [n].
GenRank? rankOfNumber(int n, {Rulebook rb = const Rulebook()}) =>
    GenRank.values.where((r) => rb.gen(r).numbers.contains(n)).firstOrNull;

/// XP due quand l'XP disponible est négative ; 0 sinon.
int debtOf(Character c) => max(0, -c.xpAvailable);

typedef Transformed = ({Character? after, String? error});

/// Clan, sire, génération, Génération, disciplines 2/1/1 du clan ([first] reçoit 2), Sang du rang.
String? _embraceInto(Character n, Character sire, int genNumber, String? first, Rulebook rb) {
  final rank = rankOfNumber(genNumber, rb: rb);
  if (rank == null) return 'Génération ${genNumber}e absente du tableau des générations';
  if ((sire.clan ?? '').isEmpty) return 'Le sire n’a pas de clan';
  final own = rb.clanDisciplines(sire.clan);
  final lead = own.contains(first) ? first : own.firstOrNull;
  final row = rb.gen(rank);
  n
    ..ghoul = null
    ..clan = sire.clan
    ..sire = sire.name
    ..genRank = rank
    ..genNumber = genNumber
    ..blood = row.blood
    ..bloodPerTurn = row.bloodPerTurn
    ..disciplines = [for (final d in own) Discipline(d, d == lead ? 2 : 1, inClan: true)];
  n.backgrounds
    ..removeWhere((b) => b.name == generationName)
    ..add(Trait(generationName, rankLevel(rank)));
  return null;
}

/// Avertissement pour un sire dont le clan n'a pas de disciplines propres ; null sinon.
String? embraceNote(Character sire, {Rulebook rb = const Rulebook()}) =>
    (sire.clan ?? '').isNotEmpty && rb.clanDisciplines(sire.clan).isEmpty
        ? '${sire.clan} : pas de disciplines propres, à choisir dans C3 après l’étreinte.'
        : null;

Transformed _result(Character n, String? error) => error == null ? (after: n, error: null) : (after: null, error: error);

/// Goule jouée étreinte : la fiche d'origine ne change pas, la copie est renvoyée.
Transformed embraceGhoul(Character g, {required Character sire, required int genNumber, String? first, Rulebook rb = const Rulebook()}) {
  if (g.ghoul == null) return (after: null, error: 'Ce n’est pas une goule');
  final n = g.clone();
  final formerClan = n.bloodClan;
  final error = _embraceInto(n, sire, genNumber, first, rb);
  if (error == null) n.xpSpent += embraceCost(n, formerClan: formerClan, rb: rb);
  return _result(n, error);
}

/// XP de l'étreinte d'une goule (Base p. 297-298) : rareté du nouveau clan moins celle du clan du domitor (remboursée),
/// plus les points de Génération achetés (nouveau niveau ×1 pour un Neonate, ×2 au-delà). L'écart non payé est une dette.
int embraceCost(Character vampire, {required String? formerClan, Rulebook rb = const Rulebook()}) {
  final rank = vampire.genRank ?? GenRank.neonate;
  final factor = rank == GenRank.neonate ? 1 : 2;
  var cost = rb.rarityCost(vampire.clan, vampire.sect) - rb.rarityCost(formerClan, vampire.sect);
  for (var k = 1; k <= rankLevel(rank); k++) {
    cost += k * factor;
  }
  return cost;
}

/// PNJ actif issu de l'étreinte d'un mortel ou d'un serviteur.
Transformed embracedNpc(String name, {required Character sire, required int genNumber, String? first, Rulebook rb = const Rulebook()}) {
  final n = Character(id: '', name: name, kind: CharacterKind.pnj, status: CharacterStatus.active)
    ..willpower = 6
    ..humanity = 5;
  return _result(n, _embraceInto(n, sire, genNumber, first, rb));
}

/// Amorce de PJ issue d'une étreinte : clan posé, clé `embrace` ; le joueur fait la création guidée.
Transformed embracedDraft(
  String name, {
  required String playerUid,
  required String playerName,
  required Character sire,
  required int genNumber,
  Rulebook rb = const Rulebook(),
}) {
  if (rankOfNumber(genNumber, rb: rb) == null) return (after: null, error: 'Génération ${genNumber}e absente du tableau des générations');
  if ((sire.clan ?? '').isEmpty) return (after: null, error: 'Le sire n’a pas de clan');
  final rank = rankOfNumber(genNumber, rb: rb)!;
  final n = Character(id: '', name: name, kind: CharacterKind.pj, playerUid: playerUid, playerName: playerName)
    ..sire = sire.name
    // Génération imposée : l'historique au niveau du rang (un des points gratuits) et le numéro.
    ..backgrounds = [Trait(generationName, rankLevel(rank))]
    ..genRank = rank
    ..genNumber = genNumber
    ..embrace = EmbraceState(sireId: sire.id, sireName: sire.name, clan: sire.clan!, genNumber: genNumber);
  setClan(n, sire.clan, rb: rb);
  return (after: n, error: null);
}

/// Coût d'un serviteur de rang [rank] pour le domitor : comme un historique, niveau par niveau.
int servantCost(Character domitor, int rank, {Rulebook rb = const Rulebook()}) {
  final f = rb.rowFor(domitor).traitFactor;
  var total = 0;
  for (var k = 1; k <= rank; k++) {
    total += k * f;
  }
  return total;
}

/// Domitor après l'achat du serviteur [id] ; inchangé s'il l'a déjà (reprise sans doublon).
Character withServant(Character domitor, String id, String name, ServantKind kind, int rank, {Rulebook rb = const Rulebook()}) {
  final n = domitor.clone();
  if (n.servants.any((s) => s.id == id)) return n;
  n.servants.add(Servant(id, name, kind, rank));
  n.xpSpent += servantCost(domitor, rank, rb: rb);
  return n;
}
