enum ItemCategory {
  melee('Arme de mêlée'),
  ranged('Arme à distance'),
  armor('Protection'),
  gear('Matériel divers');

  const ItemCategory(this.label);
  final String label;
}

enum ItemGrade {
  normal('Courant'),
  cheap('Bon marché');

  const ItemGrade(this.label);
  final String label;
}

enum ItemState {
  requested('Demande à valider'),
  active('En jeu'),
  refused('Refusée'),
  confiscated('Confisqué'),
  destroyed('Détruit');

  const ItemState(this.label);
  final String label;
}

/// Objet d'un personnage (`items/{id}`). Mutable : l'édition travaille sur une [copy].
class Item {
  Item({
    this.id = '',
    this.name = '',
    this.category = ItemCategory.melee,
    this.grade = ItemGrade.normal,
    List<String>? qualities,
    this.extraQuality,
    this.characterId = '',
    this.characterName = '',
    this.playerUid = '',
    this.state = ItemState.active,
    this.description = '',
    this.origin = '',
    this.refusal = '',
    this.version = 0,
    this.updatedByName,
  }) : qualities = qualities ?? [];

  factory Item.fromMap(String id, Map<String, dynamic> m) => Item(
        id: id,
        name: m['name'] as String? ?? '',
        category: ItemCategory.values.asNameMap()[m['category']] ?? ItemCategory.gear,
        grade: ItemGrade.values.asNameMap()[m['grade']] ?? ItemGrade.normal,
        qualities: [for (final q in (m['qualities'] as List?) ?? const []) '$q'],
        extraQuality: m['extraQuality'] as String?,
        characterId: m['characterId'] as String? ?? '',
        characterName: m['characterName'] as String? ?? '',
        playerUid: m['playerUid'] as String? ?? '',
        state: ItemState.values.asNameMap()[m['state']] ?? ItemState.active,
        description: m['description'] as String? ?? '',
        origin: m['origin'] as String? ?? '',
        refusal: m['refusal'] as String? ?? '',
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String name;
  ItemCategory category;
  ItemGrade grade;
  List<String> qualities;
  String? extraQuality;
  String characterId;
  String characterName;
  String playerUid;
  ItemState state;
  String description;
  String origin;
  String refusal;
  final int version;
  final String? updatedByName;

  /// Clés écrites (le suivi — version, historique, dates — est ajouté par le dépôt).
  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category.name,
        'grade': grade.name,
        'qualities': qualities,
        'extraQuality': extraQuality,
        'characterId': characterId,
        'characterName': characterName,
        'playerUid': playerUid,
        'state': state.name,
        'description': description,
        'origin': origin,
        'refusal': refusal,
      };

  Item copy() => Item.fromMap(id, {...toMap(), 'qualities': [...qualities], 'version': version, 'updatedByName': updatedByName});
}
