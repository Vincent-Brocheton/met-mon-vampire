import 'package:cloud_firestore/cloud_firestore.dart';

enum PlaceType {
  standard('Standard'),
  prestige('Prestige'),
  iconic('Iconique');

  const PlaceType(this.label);
  final String label;
}

/// Qualité d'un lieu ; [count] de 1 à 3 pour une qualité négative répétable.
class PlaceQuality {
  PlaceQuality(this.name, [this.count = 1]);

  factory PlaceQuality.fromMap(Map<String, dynamic> m) => PlaceQuality(m['name'] as String? ?? '', (m['count'] as num?)?.toInt() ?? 1);

  final String name;
  int count;

  Map<String, dynamic> toMap() => {'name': name, 'count': count};
}

/// Personnage attribué (PJ ou PNJ) : identifiant et nom recopié.
class PlaceHolder {
  const PlaceHolder(this.id, this.name);

  factory PlaceHolder.fromMap(Map<String, dynamic> m) => PlaceHolder(m['id'] as String? ?? '', m['name'] as String? ?? '');

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}

List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List?) ?? const []) Map<String, dynamic>.from(e as Map)];

/// Lieu d'intérêt (`places/{id}`). Mutable : l'édition travaille sur une [copy].
class Place {
  Place({
    this.id = '',
    this.name = '',
    this.type = PlaceType.standard,
    this.rank = 1,
    List<PlaceQuality>? qualities,
    List<PlaceHolder>? holders,
    List<String>? holderPlayers,
    this.public = false,
    this.known = '',
    this.version = 0,
    this.updatedAt,
    this.updatedByName,
  })  : qualities = qualities ?? [],
        holders = holders ?? [],
        holderPlayers = holderPlayers ?? [];

  factory Place.fromMap(String id, Map<String, dynamic> m) => Place(
        id: id,
        name: m['name'] as String? ?? '',
        type: PlaceType.values.asNameMap()[m['type']] ?? PlaceType.standard,
        rank: (m['rank'] as num?)?.toInt() ?? 1,
        qualities: _maps(m['qualities']).map(PlaceQuality.fromMap).toList(),
        holders: _maps(m['holders']).map(PlaceHolder.fromMap).toList(),
        holderPlayers: [for (final u in (m['holderPlayers'] as List?) ?? const []) '$u'],
        public: m['public'] == true,
        known: m['known'] as String? ?? '',
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String name;
  PlaceType type;
  int rank;
  List<PlaceQuality> qualities;
  List<PlaceHolder> holders;

  /// Joueurs des personnages attribués : leur droit de lecture (règles Firestore).
  List<String> holderPlayers;
  bool public;
  String known;
  final int version;
  final DateTime? updatedAt;
  final String? updatedByName;

  List<String> get holderIds => [for (final h in holders) h.id];

  /// Clés écrites par l'application (version, historique et dates ajoutés par le dépôt).
  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'rank': rank,
        'qualities': [for (final q in qualities) q.toMap()],
        'holders': [for (final h in holders) h.toMap()],
        'holderIds': holderIds,
        'holderPlayers': holderPlayers,
        'public': public,
        'known': known,
      };

  /// Résumé public (`publicPlaces/{id}`) : sans contrôleur ni qualités.
  Map<String, dynamic> publicMap() => {'name': name, 'type': type.name, 'known': known};

  /// Copie profonde (nouvelles qualités) pour l'édition.
  Place copy() => Place.fromMap(id, {...toMap(), 'version': version});
}

/// Entrée de l'historique d'un lieu.
class PlaceEntry {
  const PlaceEntry({required this.at, required this.byName, required this.summary, required this.reason});

  factory PlaceEntry.fromMap(Map<String, dynamic> m) => PlaceEntry(
        at: (m['at'] as Timestamp?)?.toDate(),
        byName: m['byName'] as String? ?? '',
        summary: [for (final s in (m['summary'] as List?) ?? const []) '$s'],
        reason: m['reason'] as String? ?? '',
      );

  final DateTime? at;
  final String byName;
  final List<String> summary;
  final String reason;
}
