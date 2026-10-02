import '../characters/character.dart';

/// Listes de règles de base (Mind's Eye Theatre). Éditables au sous-projet 5.
enum ClanRarity {
  common(0),
  uncommon(2),
  rare(4);

  const ClanRarity(this.meritPoints);
  final int meritPoints;
}

class ClanInfo {
  const ClanInfo(this.name, this.disciplines, this.rarity);
  final String name;

  /// Vide pour le Caïtiff : trois disciplines communes au choix.
  final List<String> disciplines;
  final ClanRarity rarity;
}

const sects = ['Camarilla', 'Anarchs', 'Sabbat', 'Indépendants'];

const clans = [
  ClanInfo('Brujah', ['Célérité', 'Puissance', 'Présence'], ClanRarity.common),
  ClanInfo('Caïtiff', [], ClanRarity.common),
  ClanInfo('Gangrel', ['Animalisme', 'Force d’âme', 'Protéisme'], ClanRarity.common),
  ClanInfo('Malkavien', ['Aliénation', 'Auspex', 'Occultation'], ClanRarity.common),
  ClanInfo('Nosferatu', ['Animalisme', 'Occultation', 'Puissance'], ClanRarity.common),
  ClanInfo('Toreador', ['Auspex', 'Célérité', 'Présence'], ClanRarity.common),
  ClanInfo('Tremere', ['Auspex', 'Domination', 'Thaumaturgie'], ClanRarity.common),
  ClanInfo('Ventrue', ['Domination', 'Force d’âme', 'Présence'], ClanRarity.common),
  ClanInfo('Assamites', ['Célérité', 'Occultation', 'Quietus'], ClanRarity.uncommon),
  ClanInfo('Giovanni', ['Domination', 'Nécromancie', 'Puissance'], ClanRarity.uncommon),
  ClanInfo('Disciples de Set', ['Occultation', 'Présence', 'Serpentis'], ClanRarity.uncommon),
  ClanInfo('Ravnos', ['Animalisme', 'Chimérie', 'Force d’âme'], ClanRarity.uncommon),
  ClanInfo('Lasombra', ['Domination', 'Obténébration', 'Puissance'], ClanRarity.rare),
  ClanInfo('Tzimisce', ['Animalisme', 'Auspex', 'Vicissitude'], ClanRarity.rare),
  ClanInfo('Salubri', ['Auspex', 'Force d’âme', 'Obeah'], ClanRarity.rare),
];

ClanInfo? clanInfo(String? name) {
  for (final c in clans) {
    if (c.name == name) return c;
  }
  return null;
}

/// Seules disciplines achetables hors clan à la création.
const commonDisciplines = [
  'Animalisme', 'Auspex', 'Célérité', 'Domination', 'Force d’âme', 'Occultation', 'Présence', 'Puissance',
];

const allDisciplines = [
  'Aliénation', 'Animalisme', 'Auspex', 'Célérité', 'Chimérie', 'Domination', 'Force d’âme', 'Nécromancie',
  'Obeah', 'Obténébration', 'Occultation', 'Présence', 'Protéisme', 'Puissance', 'Quietus', 'Serpentis',
  'Thaumaturgie', 'Vicissitude',
];

const focuses = {
  AttrCategory.physical: ['Force', 'Dextérité', 'Vigueur'],
  AttrCategory.social: ['Charisme', 'Manipulation', 'Apparence'],
  AttrCategory.mental: ['Perception', 'Intelligence', 'Astuce'],
};

const skillNames = [
  'Animaux', 'Armes à feu', 'Artisanat', 'Athlétisme', 'Bagarre', 'Commandement', 'Conduite', 'Connaissances',
  'Empathie', 'Érudition', 'Esquive', 'Expérience de la rue', 'Furtivité', 'Informatique', 'Intimidation',
  'Investigation', 'Linguistique', 'Médecine', 'Mêlée', 'Occultisme', 'Représentation', 'Sciences', 'Sécurité',
  'Subterfuge', 'Survie', 'Vigilance',
];

/// Compétences dont le domaine est obligatoire.
const domainSkills = {'Artisanat', 'Représentation', 'Sciences'};

const backgroundNames = [
  'Alliés', 'Célébrité', 'Génération', 'Identité d’emprunt', 'Refuge', 'Ressources', 'Serviteurs', 'Troupeau',
];

const archetypes = [
  'Architecte', 'Autocrate', 'Bon vivant', 'Bravache', 'Conformiste', 'Déviant', 'Enfant', 'Fanatique',
  'Gentilhomme', 'Je-sais-tout', 'Juge', 'Loup solitaire', 'Martyr', 'Monstre', 'Pédagogue', 'Pénitent',
  'Protecteur', 'Rebelle', 'Survivant', 'Visionnaire',
];

const generationNumbers = {
  GenRank.neonate: [13, 12, 11],
  GenRank.ancilla: [10, 9],
  GenRank.pretender: [8],
};

/// (Sang, Sang par tour) selon le rang.
const bloodByRank = {
  GenRank.neonate: (10, 1),
  GenRank.ancilla: (12, 2),
  GenRank.pretender: (15, 3),
};

const baseMerits = {
  'Cœur calme': 1, 'Érudit des traditions': 1, 'Sommeil léger': 1, 'Visage angélique': 1,
  'Oreille qui traîne': 1, 'Chanceux': 2, 'Apprenti efficace': 2, 'Volonté de fer': 3, 'Esprit labyrinthique': 3,
};

const baseFlaws = {
  'Amnésie': 1, 'Sombre secret': 1, 'Illettré': 1, 'Intolérance': 1, 'Addiction': 2, 'Impatient': 2,
  'Sommeil profond': 2, 'Curiosité': 2, 'Traqué': 4,
};
