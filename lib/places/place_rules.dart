import '../characters/character.dart';
import '../rulebook/rulebook.dart';
import 'place.dart';

/// Qualités au plus : le rang (standard), le double (prestige, iconique).
int maxQualities(PlaceType t, int rank) => t == PlaceType.standard ? rank : rank * 2;

/// Famille de la qualité dans le référentiel (standard, iconic, supernatural, negative, elysium), ou null.
String? qualityFamily(Rulebook rb, String name) => switch (rb.find('placeQualities', name)?.data['family']) {
      final String f => f,
      _ => null,
    };

/// Qualités qui comptent dans le maximum : standard, iconiques et surnaturelle, prise à la place d'une standard
/// (V2 p. 131) ; hors référentiel : comptée. Négatives et Élysée n'y comptent pas.
int qualityCount(Place p, Rulebook rb) => p.qualities.where((q) {
      final f = qualityFamily(rb, q.name);
      return f == null || f == 'standard' || f == 'iconic' || f == 'supernatural';
    }).length;

String questText(PlaceType t, int rank) => switch (t) {
      PlaceType.standard => 'Quête simple, difficulté $rank',
      PlaceType.prestige => 'Quête complexe, difficulté $rank',
      PlaceType.iconic => 'Quête héroïque',
    };

/// Difficulté d'infiltration en jeu.
int infiltration(int rank) => 5 * rank;

/// Lieux qu'un personnage peut contrôler : 5, plus 1 par point de serviteur.
int controlLimit(Character c) => 5 + c.servants.fold<int>(0, (s, x) => s + x.rank);

/// « Compromis ×2, Endommagé ×1 », ou chaîne vide.
String negativesText(Place p, Rulebook rb) =>
    [for (final q in p.qualities) if (qualityFamily(rb, q.name) == 'negative') '${q.name} ×${q.count}'].join(', ');

/// Joueurs des personnages attribués (droit de lecture).
List<String> playersOf(List<PlaceHolder> holders, List<Character> characters) => [
      for (final h in holders) ?characters.where((c) => c.id == h.id).firstOrNull?.playerUid,
    ];

/// Avertissements (le conte peut quand même enregistrer).
List<String> placeWarnings(Place p, Rulebook rb, {List<Place> places = const [], List<Character> characters = const []}) {
  final out = <String>[];
  final max = maxQualities(p.type, p.rank);
  final n = qualityCount(p, rb);
  if (n > max) out.add('$n qualités sur $max : trop pour un lieu ${p.type.label.toLowerCase()} de rang ${p.rank}');
  var supernatural = 0;
  for (final q in p.qualities) {
    final e = rb.find('placeQualities', q.name);
    if (e == null) {
      out.add('${q.name} : hors du référentiel');
      continue;
    }
    final family = e.data['family'];
    if (family == 'iconic' && p.type != PlaceType.iconic) out.add('${q.name} : qualité iconique, réservée aux lieux iconiques');
    if (!e.state.offered) out.add('${q.name} est interdite dans la chronique');
    final types = [for (final t in (e.data['placeTypes'] as List?) ?? const []) '$t'];
    if (types.isNotEmpty && !types.contains(p.type.name)) out.add('${q.name} : non permise pour un lieu ${p.type.label.toLowerCase()}');
    if (family == 'supernatural') supernatural++;
    final repeatable = switch (e.data['repeatable']) {
      final num r => r.toInt().clamp(1, 3),
      _ => 1,
    };
    if (q.count > repeatable) out.add('${q.name} : ${q.count} fois, $repeatable au plus');
  }
  if (supernatural > 1) out.add('Une seule qualité surnaturelle par lieu');
  for (final h in p.holders) {
    final c = characters.where((x) => x.id == h.id).firstOrNull;
    if (c == null) continue;
    final count = places.where((x) => x.id != p.id && x.holderIds.contains(h.id)).length + 1;
    final limit = controlLimit(c);
    if (count > limit) out.add('${c.name} contrôle $count lieux sur $limit (5 + Serviteurs)');
    if (c.status == CharacterStatus.retired || c.status == CharacterStatus.dead) out.add('${c.name} est une fiche retirée ou morte');
  }
  return out;
}

/// Lieu enregistré dont l'accès ne suit plus les joueurs des personnages : corrigé au prochain enregistrement.
List<String> staleAccess(Place stored, List<Character> characters) {
  final players = playersOf(stored.holders, characters);
  final changed = [
    for (final h in stored.holders)
      if (characters.where((c) => c.id == h.id).firstOrNull case final c?
          when c.playerUid != null && !stored.holderPlayers.contains(c.playerUid))
        'Le joueur de ${c.name} a changé : enregistrez pour mettre à jour l’accès',
  ];
  if (changed.isEmpty && stored.holderPlayers.any((u) => !players.contains(u))) {
    return ['Un ancien joueur a encore accès : enregistrez pour le retirer'];
  }
  return changed;
}

/// Une ligne par changement, pour l'historique du lieu.
List<String> placeChanges(Place a, Place b) {
  final out = <String>[];
  if (a.name != b.name) out.add('Nom : ${a.name} → ${b.name}');
  if (a.type != b.type) out.add('Type : ${a.type.label} → ${b.type.label}');
  if (a.rank != b.rank) out.add('Rang ${a.rank} → ${b.rank}');
  for (final h in b.holders) {
    if (!a.holderIds.contains(h.id)) out.add('+ Attribué à ${h.name}');
  }
  for (final h in a.holders) {
    if (!b.holderIds.contains(h.id)) out.add('− Retiré à ${h.name}');
  }
  final before = {for (final q in a.qualities) q.name: q.count};
  final after = {for (final q in b.qualities) q.name: q.count};
  for (final q in b.qualities) {
    if (!before.containsKey(q.name)) out.add('+ Qualité ${q.name}${q.count > 1 ? ' ×${q.count}' : ''}');
  }
  for (final q in a.qualities) {
    if (!after.containsKey(q.name)) out.add('− Qualité ${q.name}');
  }
  for (final q in b.qualities) {
    final old = before[q.name];
    if (old != null && old != q.count) out.add('${q.name} : ×$old → ×${q.count}');
  }
  if (a.public != b.public) out.add(b.public ? 'Connu de tous' : 'Plus connu de tous');
  if (a.known != b.known) out.add('Ce qui s’en sait modifié');
  return out;
}
