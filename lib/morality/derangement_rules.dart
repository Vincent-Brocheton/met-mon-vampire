import '../characters/character.dart';
import '../rulebook/rule_entry.dart' show nameKey;
import '../rulebook/rulebook.dart';
import '../xp/xp_request.dart';

/// Catégorie du référentiel : modèles de dérangements (champ `type`).
const derangementsCat = 'derangements';

/// Types de dérangements : valeur stockée → libellé.
const derangementTypes = {
  'belief': 'Croyance',
  'incapacity': 'Incapacité',
  'compulsion': 'Compulsion',
  'phobia': 'Phobie',
  'destruction': 'Destruction',
  'obsession': 'Obsession',
};

/// Erreurs d'un dérangement ; [existing] : ceux de la fiche (le dérangement lui-même est ignoré).
List<String> derangementChecks(Derangement d, List<Derangement> existing) {
  final name = d.name.trim();
  return [
    if (name.isEmpty) 'Nom obligatoire',
    if (name.length > 80) 'Nom : 80 caractères au plus',
    if (!derangementTypes.containsKey(d.type)) 'Type inconnu',
    if (d.trigger.length > 200) 'Déclencheur : 200 caractères au plus',
    if (name.isNotEmpty && existing.any((x) => x.id != d.id && nameKey(x.name) == nameKey(name))) 'Un dérangement porte déjà ce nom',
  ];
}

int derangementPoints(Derangement d) => d.severe ? 3 : 2;

/// « Principal · clan », « Sévère · 3 pts » ou « 2 pts ».
String derangementLine(Derangement d) => d.clan ? 'Principal · clan' : (d.severe ? 'Sévère · 3 pts' : '2 pts');

/// Plancher des traits de dérangement : 1 pour un Malkavien.
int traitsFloor(Character c) => nameKey(c.clan ?? '') == nameKey('Malkavien') ? 1 : 0;

int clampTraits(Character c, int n) => n.clamp(traitsFloor(c), 3);

/// Handicaps d'une fiche jouée (ou d'un PNJ) qui correspondent à un modèle et n'ont pas encore de dérangement détaillé.
List<Trait> toDetail(Character c, Rulebook rb) {
  if (!(c.kind == CharacterKind.pnj || c.status.settled)) return const [];
  return [
    for (final f in c.flaws)
      if (rb.find(derangementsCat, f.name) != null && !c.derangements.any((d) => nameKey(d.name) == nameKey(f.name))) f,
  ];
}

/// Dérangement prérempli depuis un modèle du référentiel.
Derangement fromModel(Rulebook rb, String name, {required String id}) {
  final e = rb.find(derangementsCat, name);
  final type = '${e?.data['type'] ?? ''}';
  return Derangement(id, e?.name ?? name, type: derangementTypes.containsKey(type) ? type : 'belief');
}

/// Détail d'un dérangement demandé, porté par l'achat.
Map<String, dynamic> derangementData(Derangement d) => {'type': d.type, 'trigger': d.trigger, 'severe': d.severe, 'clan': d.clan};

/// Le dérangement tel que l'achat le demande.
Derangement derangementOfItem(XpItem i, {String id = ''}) => Derangement.fromMap({...?i.derangement, 'id': id, 'name': i.name});
