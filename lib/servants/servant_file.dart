import 'package:cloud_firestore/cloud_firestore.dart';

/// « Goule humaine », « Goule animale », « Mortel ».
String servantKindLabel(String kind) => switch (kind) {
      'animal' => 'Goule animale',
      'mortal' => 'Mortel',
      _ => 'Goule humaine',
    };

List<String> _names(Object? v) => [for (final e in (v as List?) ?? const []) '$e'];

/// Fiche détaillée d'un serviteur ou d'un mortel (`servants/{id}`). Mutable : l'édition travaille sur une [copy].
class ServantFile {
  ServantFile({
    required this.id,
    this.kind = 'human',
    this.name = '',
    this.domitorId,
    this.domitorName,
    this.attachment = '',
    List<String>? holderPlayers,
    List<String>? specialties,
    List<String>? qualities,
    this.vitae = 0,
    this.bond = 0,
    this.lastDrink,
    this.description = '',
    this.releasedAt,
    this.releasedRank = 0,
    this.version = 0,
    this.updatedAt,
    this.updatedByName,
  })  : holderPlayers = holderPlayers ?? [],
        specialties = specialties ?? [],
        qualities = qualities ?? [];

  factory ServantFile.fromMap(String id, Map<String, dynamic> m) => ServantFile(
        id: id,
        kind: m['kind'] as String? ?? 'human',
        name: m['name'] as String? ?? '',
        domitorId: m['domitorId'] as String?,
        domitorName: m['domitorName'] as String?,
        attachment: m['attachment'] as String? ?? '',
        holderPlayers: _names(m['holderPlayers']),
        specialties: _names(m['specialties']),
        qualities: _names(m['qualities']),
        vitae: (m['vitae'] as num?)?.toInt() ?? 0,
        bond: (m['bond'] as num?)?.toInt() ?? 0,
        lastDrink: (m['lastDrink'] as Timestamp?)?.toDate(),
        description: m['description'] as String? ?? '',
        releasedAt: (m['releasedAt'] as Timestamp?)?.toDate(),
        releasedRank: (m['releasedRank'] as num?)?.toInt() ?? 0,
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String kind;
  String name;
  String? domitorId;
  String? domitorName;
  String attachment;

  /// Joueur du domitor : son droit de lecture (règles Firestore).
  List<String> holderPlayers;
  List<String> specialties;
  List<String> qualities;
  int vitae;
  int bond;
  DateTime? lastDrink;
  String description;
  DateTime? releasedAt;

  /// Rang du serviteur au moment de sa libération : durée de l'indisponibilité pour le domitor.
  int releasedRank;
  final int version;
  final DateTime? updatedAt;
  final String? updatedByName;

  bool get isMortal => kind == 'mortal';

  /// Clés écrites par l'application (version, historique et dates ajoutés par le dépôt).
  Map<String, dynamic> toMap() => {
        'kind': kind,
        'name': name,
        'domitorId': domitorId,
        'domitorName': domitorName,
        'attachment': attachment,
        'holderPlayers': holderPlayers,
        'specialties': specialties,
        'qualities': qualities,
        'vitae': vitae,
        'bond': bond,
        'lastDrink': lastDrink == null ? null : Timestamp.fromDate(lastDrink!),
        'description': description,
        'releasedAt': releasedAt == null ? null : Timestamp.fromDate(releasedAt!),
        'releasedRank': releasedRank,
      };

  ServantFile copy() => ServantFile.fromMap(id, {...toMap(), 'version': version});
}
