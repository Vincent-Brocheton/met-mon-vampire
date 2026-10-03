/// Types de champ du formulaire générique.
enum FieldType { text, longText, number, choice, multi, flag, list, keyed, rows }

typedef Option = (String value, String label);

class RuleField {
  const RuleField(this.key, this.label, this.type, {this.options = const [], this.keysFrom, this.rowFields = const [], this.help});

  final String key;
  final String label;
  final FieldType type;

  /// choice, multi, keyed : valeurs permises.
  final List<Option> options;

  /// keyed : catégorie dont les noms servent de clés (ex. 'sects').
  final String? keysFrom;

  /// rows : champs de chaque ligne (types simples seulement).
  final List<RuleField> rowFields;
  final String? help;
}

class RuleCategory {
  const RuleCategory(this.id, this.label, this.help, {this.fields = const [], this.columns = const [], this.filter, this.settings = const []});

  final String id;
  final String label;
  final String help;
  final List<RuleField> fields;

  /// Champs affichés en colonnes dans la liste.
  final List<String> columns;

  /// Champ proposé en puces de filtre (choice ou multi).
  final String? filter;

  /// Réglages de la catégorie (`rules/{cat}`).
  final List<RuleField> settings;
}

const _meritTypes = [
  ('general', 'Général'),
  ('clan', 'Clan'),
  ('sect', 'Secte'),
  ('morality', 'Moralité'),
  ('rarity', 'Rareté et lignée'),
  ('chronicle', 'Chronique'),
];
const _schools = [('thaumaturgy', 'Thaumaturgie'), ('necromancy', 'Nécromancie'), ('abyss', 'Mysticisme de l’Abysse')];
const _rarities = [('common', 'Commun'), ('uncommon', 'Peu commun · 2 pts'), ('rare', 'Rare · 4 pts'), ('forbidden', 'Interdit')];
const _equipmentCategories = [('melee', 'Armes de mêlée'), ('ranged', 'Armes à distance'), ('armor', 'Protections'), ('gear', 'Matériel divers')];
const _bloodBlocks = [('resonance', 'Résonance du sang'), ('hunting', 'Chasse avancée'), ('territory', 'Territoires de chasse')];

List<RuleField> _traitFields(String limitLabel) => [
      const RuleField('cost', 'Coût (points)', FieldType.number),
      const RuleField('type', 'Catégorie', FieldType.choice, options: _meritTypes),
      const RuleField('restrictedTo', 'Réservé à', FieldType.text, help: 'Nom d’un clan, d’une lignée ou d’une secte'),
      const RuleField('atCreation', 'À la création', FieldType.flag),
      const RuleField('withXp', 'Avec l’XP gagnée', FieldType.flag),
      RuleField('countsInLimit', limitLabel, FieldType.flag),
    ];

final ruleCategories = <RuleCategory>[
  RuleCategory('merits', 'Atouts', 'Ce que les joueurs peuvent choisir à la création et acheter ensuite.',
      fields: _traitFields('Compte dans la limite de 7 points'), columns: const ['type', 'restrictedTo', 'cost'], filter: 'type'),
  RuleCategory('flaws', 'Handicaps', 'Ils rapportent des points d’XP, 7 au plus.',
      fields: _traitFields('Rapporte des points, dans la limite de 7'), columns: const ['type', 'restrictedTo', 'cost'], filter: 'type'),
  const RuleCategory('clans', 'Clans & lignées', 'La rareté se paie en atout à la création, selon la secte.',
      fields: [
        RuleField('disciplines', 'Disciplines de clan', FieldType.list),
        RuleField('rarity', 'Rareté par secte', FieldType.keyed, keysFrom: 'sects', options: _rarities),
        RuleField('weakness', 'Faiblesse, affichée sur la fiche', FieldType.longText),
        RuleField('bloodlines', 'Lignées', FieldType.rows, rowFields: [
          RuleField('name', 'Lignée', FieldType.text),
          RuleField('merit', 'Atout de lignée', FieldType.text),
        ]),
      ],
      columns: ['disciplines', 'rarity']),
  const RuleCategory('disciplines', 'Disciplines & pouvoirs', 'Communes ou propres ; les voies rattachées à une école de magie.',
      fields: [
        RuleField('common', 'Commune (achetable hors clan)', FieldType.flag),
        RuleField('school', 'École de magie', FieldType.choice, options: _schools),
        RuleField('parent', 'Discipline mère (pour une voie)', FieldType.text),
        RuleField('powers', 'Pouvoirs', FieldType.rows, rowFields: [
          RuleField('level', 'Niveau', FieldType.number),
          RuleField('name', 'Nom', FieldType.text),
          RuleField('vo', 'Nom VO', FieldType.text),
          RuleField('elder', 'Pouvoir d’ancien', FieldType.flag),
          RuleField('activation', 'Coût d’activation', FieldType.text),
          RuleField('test', 'Test', FieldType.text),
          RuleField('effect', 'Effet affiché aux joueurs', FieldType.longText),
        ]),
      ],
      columns: ['common', 'school'],
      filter: 'school'),
  const RuleCategory('rituals', 'Rituels', 'Achetés à part des voies. Coût : niveau du rituel × 2.',
      fields: [
        RuleField('school', 'École', FieldType.choice, options: _schools),
        RuleField('level', 'Niveau (1 à 5)', FieldType.number),
        RuleField('talisman', 'Peut être placé dans un talisman', FieldType.flag),
        RuleField('atCreation', 'À la création', FieldType.flag),
        RuleField('withXp', 'Avec l’XP gagnée', FieldType.flag),
      ],
      columns: ['school', 'level'],
      filter: 'school',
      settings: [RuleField('costPerLevel', 'Coût par niveau (XP)', FieldType.number)]),
  const RuleCategory('techniques', 'Techniques', 'Accès et coûts selon la génération.',
      fields: [
        RuleField('prerequisites', 'Prérequis (une alternative par ligne)', FieldType.list, help: 'Ex. « Présence 2 + Auspex 1 »'),
        RuleField('transformation', 'Transformation', FieldType.choice, options: [('none', 'Aucune'), ('minor', 'Mineure'), ('major', 'Majeure')]),
      ],
      columns: ['prerequisites']),
  const RuleCategory('elderPowers', 'Pouvoirs d’anciens', 'Cinq points dans la discipline ; hors clan, un professeur.',
      fields: [
        RuleField('discipline', 'Discipline', FieldType.text),
        RuleField('costInClan', 'Coût en clan (XP)', FieldType.number),
        RuleField('costOutOfClan', 'Coût hors clan (XP)', FieldType.number),
      ],
      columns: ['discipline']),
  const RuleCategory('skills', 'Compétences', 'Plafond de 5 points. Certaines demandent un domaine.',
      fields: [
        RuleField('domainMode', 'Domaines', FieldType.choice, options: [
          ('perDot', 'Un domaine par point'),
          ('multiple', 'Achetée plusieurs fois'),
          ('optional', 'Domaines facultatifs'),
          ('none', 'Sans domaine'),
        ]),
        RuleField('domains', 'Domaines proposés aux joueurs', FieldType.list),
        RuleField('cap', 'Plafond', FieldType.number),
      ],
      columns: ['domainMode', 'cap'],
      filter: 'domainMode'),
  const RuleCategory('generations', 'Générations', 'Valeurs vérifiées à chaque achat et à chaque validation.',
      fields: [
        RuleField('rank', 'Rang', FieldType.choice, options: [('neonate', 'Neonate'), ('ancilla', 'Ancilla'), ('pretender', 'Pretender Elder')]),
        RuleField('numbers', 'Générations (une par ligne)', FieldType.list),
        RuleField('blood', 'Sang', FieldType.number),
        RuleField('bloodPerTurn', 'Sang par tour', FieldType.number),
        RuleField('attributeBonus', 'Points bonus d’attribut', FieldType.number),
        RuleField('skillCap', 'Plafond des compétences', FieldType.number),
        RuleField('traitFactor', 'Compétences et historiques : nouveau niveau ×', FieldType.number),
        RuleField('outOfClanFactor', 'Disciplines hors clan : nouveau niveau ×', FieldType.number),
        RuleField('techniqueCost', 'Coût d’une technique (0 : interdit)', FieldType.number),
        RuleField('eldersAllowed', 'Pouvoirs d’anciens permis', FieldType.flag),
        RuleField('eldersLimit', 'Nombre de pouvoirs d’anciens', FieldType.number),
      ],
      columns: ['rank', 'numbers', 'blood']),
  const RuleCategory('backgrounds', 'Historiques', 'Ce que chaque historique demande au joueur de préciser.',
      fields: [
        RuleField('ask', 'Détail demandé', FieldType.choice, options: [
          ('monthly', 'Montant mensuel'),
          ('people', 'Liste de personnes'),
          ('specialties', 'Liste de spécialités'),
          ('text', 'Texte libre'),
        ]),
        RuleField('cap', 'Plafond', FieldType.number),
        RuleField('approvalRequired', 'Le montant est validé par le conte', FieldType.flag),
        RuleField('scale', 'Barème par niveau (un montant par ligne)', FieldType.list),
      ],
      columns: ['ask', 'cap']),
  const RuleCategory('allies', 'Alliés', 'Spécialisations des alliés ; règles générales dans les paramètres.',
      fields: [
        RuleField('effect', 'Effet', FieldType.longText),
        RuleField('condition', 'Condition', FieldType.text),
      ],
      columns: ['condition'],
      settings: [
        RuleField('maxLevel', 'Niveau maximum', FieldType.number),
        RuleField('returnAfter', 'Retour après usage', FieldType.text),
        RuleField('types', 'Types (un par ligne)', FieldType.list),
        RuleField('domains', 'Domaines (un par ligne)', FieldType.list),
      ]),
  const RuleCategory('archetypes', 'Archétypes', 'Sans effet mécanique : ils guident l’interprétation.',
      settings: [RuleField('freeAllowed', 'Archétypes libres autorisés, validés par le conte', FieldType.flag)]),
  const RuleCategory('sects', 'Sectes', 'Quelles sectes sont jouables.',
      fields: [
        RuleField('playable', 'Jouable', FieldType.choice, options: [
          ('all', 'PJ et PNJ'),
          ('pjOnApproval', 'PNJ, PJ sur accord'),
          ('npcOnly', 'PNJ seulement'),
        ]),
        RuleField('isDefault', 'Secte par défaut des nouvelles fiches', FieldType.flag),
      ],
      columns: ['playable', 'isDefault']),
  const RuleCategory('paths', 'Voies & moralité', 'Humanité par défaut ; une voie d’illumination s’achète comme atout de moralité.',
      fields: [
        RuleField('meritCost', 'Coût de l’atout', FieldType.number),
        RuleField('maxMorality', 'Moralité maximum', FieldType.number),
        RuleField('sins', 'Hiérarchie des péchés (un niveau par ligne)', FieldType.list),
        RuleField('sectStatus', 'Statut par secte', FieldType.keyed, keysFrom: 'sects', options: [
          ('accepted', 'Acceptée'),
          ('heretic', 'Hérétique'),
          ('none', 'Ni l’un ni l’autre'),
        ]),
        RuleField('changeNeedsApproval', 'Changement de voie soumis au conte', FieldType.flag),
      ],
      columns: ['meritCost', 'maxMorality']),
  const RuleCategory('derangements', 'Dérangements', 'Modèles de départ ; chaque joueur décrit le sien.',
      fields: [
        RuleField('type', 'Type', FieldType.choice, options: [
          ('belief', 'Croyance'),
          ('incapacity', 'Incapacité'),
          ('compulsion', 'Compulsion'),
          ('phobia', 'Phobie'),
          ('destruction', 'Destruction'),
          ('obsession', 'Obsession'),
        ]),
        RuleField('gameEffect', 'Effet de jeu', FieldType.longText),
        RuleField('asFlaw', 'Peut être pris comme handicap à la création', FieldType.flag),
        RuleField('byPower', 'Peut être infligé par un pouvoir', FieldType.flag),
      ],
      columns: ['type'],
      filter: 'type'),
  const RuleCategory('titles', 'Titres', 'Les charges de la chronique, sans coût en XP.',
      fields: [
        RuleField('sect', 'Secte', FieldType.text),
        RuleField('count', 'Nombre', FieldType.text, help: 'Illimité, Unique, Un par clan, ou un nombre'),
        RuleField('under', 'Placé sous', FieldType.text),
        RuleField('public', 'Titre public', FieldType.flag),
        RuleField('onSheet', 'Affiché sur la fiche du détenteur', FieldType.flag),
        RuleField('npcOnly', 'Réservé aux PNJ', FieldType.flag),
      ],
      columns: ['sect', 'count']),
  const RuleCategory('equipment', 'Équipement', 'Qualités d’objets ; règles de base par catégorie dans les paramètres.',
      fields: [
        RuleField('categories', 'Catégories', FieldType.multi, options: _equipmentCategories),
        RuleField('incompatible', 'Incompatible avec (une par ligne)', FieldType.list),
        RuleField('outsideLimit', 'Ne compte pas dans la limite de qualités', FieldType.flag),
        RuleField('resale', 'Valeur de revente', FieldType.text),
      ],
      columns: ['categories'],
      filter: 'categories',
      settings: [
        RuleField('rules', 'Règles de base par catégorie', FieldType.rows, rowFields: [
          RuleField('category', 'Catégorie', FieldType.choice, options: _equipmentCategories),
          RuleField('damage', 'Dégâts de base', FieldType.text),
          RuleField('hands', 'Mains', FieldType.number),
          RuleField('qualitiesNormal', 'Qualités, objet courant', FieldType.number),
          RuleField('qualitiesCheap', 'Qualités, bon marché', FieldType.number),
        ]),
      ]),
  const RuleCategory('placeQualities', 'Qualités de lieu', 'Une négative se cumule jusqu’à 3 fois ; une seule surnaturelle par lieu.',
      fields: [
        RuleField('family', 'Famille', FieldType.choice, options: [
          ('standard', 'Standard'),
          ('iconic', 'Iconique'),
          ('supernatural', 'Surnaturelle'),
          ('negative', 'Négative'),
          ('elysium', 'Élysée'),
        ]),
        RuleField('repeatable', 'Répétable (1 à 3)', FieldType.number),
        RuleField('placeTypes', 'Types de lieu autorisés', FieldType.multi, options: [('standard', 'Standard'), ('prestige', 'Prestige'), ('iconic', 'Iconique')]),
      ],
      columns: ['family', 'repeatable'],
      filter: 'family'),
  const RuleCategory('animalQualities', 'Qualités animales', 'Le total ne dépasse pas les points de Serviteurs de la goule.',
      fields: [
        RuleField('cost', 'Coût (points)', FieldType.number),
        RuleField('requires', 'Demande la qualité', FieldType.text),
      ],
      columns: ['cost']),
  const RuleCategory('blood', 'Sang & chasse', 'Règles optionnelles de l’extension ; chaque bloc s’active séparément.',
      fields: [
        RuleField('block', 'Bloc', FieldType.choice, options: _bloodBlocks),
        RuleField('effect', 'Effet', FieldType.longText),
        RuleField('linkedTo', 'Lié à', FieldType.text),
      ],
      columns: ['block'],
      filter: 'block',
      settings: [RuleField('enabled', 'Blocs activés', FieldType.multi, options: _bloodBlocks)]),
];

RuleCategory? categoryById(String id) => ruleCategories.where((c) => c.id == id).firstOrNull;

String _optionLabel(RuleField f, Object? v) => f.options.where((o) => o.$1 == v).firstOrNull?.$2 ?? '$v';

/// Valeur lisible d'un champ, pour les colonnes de la liste.
String displayValue(RuleField f, Object? v) {
  if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty) || (v is Map && v.isEmpty)) return '—';
  return switch (f.type) {
    FieldType.flag => v == true ? 'Oui' : 'Non',
    FieldType.choice => _optionLabel(f, v),
    FieldType.multi => [for (final x in v as List) _optionLabel(f, x)].join(', '),
    FieldType.list => (v as List).join(', '),
    FieldType.keyed => [for (final e in (v as Map).entries) '${e.key} : ${_optionLabel(f, e.value)}'].join(', '),
    FieldType.rows => switch ((v as List).length) { 1 => '1 ligne', final n => '$n lignes' },
    _ => '$v',
  };
}
