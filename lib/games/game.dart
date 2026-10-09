import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();

/// Une partie (`games/{id}`) et le gel de ses fiches (sous-projet 8a).
class Game {
  const Game({
    this.id = '',
    required this.date,
    required this.frozenAt,
    required this.until,
    this.liftedAt,
    this.liftedByUid,
    this.byUid = '',
    this.sheetIds = const [],
  });

  /// L'heure du gel est celle du serveur : absente de l'écho local de l'écriture, on prend celle de l'appareil.
  factory Game.fromMap(String id, Map<String, dynamic> m) => Game(
        id: id,
        date: _date(m['date']) ?? DateTime(2000),
        frozenAt: _date(m['frozenAt']) ?? DateTime.now(),
        until: _date(m['until']) ?? DateTime(2000),
        liftedAt: _date(m['liftedAt']),
        liftedByUid: m['liftedByUid'] as String?,
        byUid: m['byUid'] as String? ?? '',
        sheetIds: [for (final s in (m['sheetIds'] as List?) ?? const []) '$s'],
      );

  final String id;

  /// Jour de la partie (minuit, heure locale).
  final DateTime date;
  final DateTime frozenAt;

  /// Levée prévue : le gel s'arrête seul à cette heure.
  final DateTime until;
  final DateTime? liftedAt;
  final String? liftedByUid;
  final String byUid;
  final List<String> sheetIds;
}

/// Version figée d'une fiche (`characters/{id}/frozen/{gameId}`).
class FrozenSheet {
  const FrozenSheet({
    required this.characterId,
    required this.gameId,
    required this.sheet,
    required this.version,
    required this.gameDate,
    this.at,
    this.byUid = '',
    this.reason,
  });

  factory FrozenSheet.fromMap(String characterId, String gameId, Map<String, dynamic> m) => FrozenSheet(
        characterId: characterId,
        gameId: gameId,
        sheet: m['sheet'] is Map ? Map<String, dynamic>.from(m['sheet'] as Map) : const {},
        version: (m['version'] as num?)?.toInt() ?? 0,
        gameDate: _date(m['gameDate']) ?? DateTime(2000),
        at: _date(m['at']),
        byUid: m['byUid'] as String? ?? '',
        reason: m['reason'] as String?,
      );

  final String characterId;
  final String gameId;

  /// La fiche au moment de la copie (`Character.toMap()`).
  final Map<String, dynamic> sheet;

  /// Version de la fiche copiée : la fiche actuelle en diffère si elle a changé depuis.
  final int version;
  final DateTime gameDate;
  final DateTime? at;
  final String byUid;

  /// Null pour la copie du gel ; le motif d'une correction urgente sinon.
  final String? reason;

  Character get character => Character.fromMap(characterId, sheet);
}
