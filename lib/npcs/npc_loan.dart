import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanMode {
  full('Fiche complète'),
  summary('Fiche résumée');

  const LoanMode(this.label);
  final String label;
}

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

/// Prêt d'un PNJ à un joueur (`npcLoans/{id}`) ; la copie de la fiche est à part (`sheet/copy`).
class NpcLoan {
  NpcLoan({
    this.id = '',
    this.characterId = '',
    this.characterName = '',
    this.playerUid = '',
    this.playerName = '',
    required this.from,
    required this.until,
    this.mode = LoanMode.full,
    this.allowNotes = true,
    this.personality = '',
    this.goals = '',
    this.limits = '',
    this.sheetAt,
    this.revokedAt,
    this.playerNotes = '',
    this.notesAt,
    this.version = 0,
    this.updatedByName,
  });

  factory NpcLoan.fromMap(String id, Map<String, dynamic> m) => NpcLoan(
        id: id,
        characterId: m['characterId'] as String? ?? '',
        characterName: m['characterName'] as String? ?? '',
        playerUid: m['playerUid'] as String? ?? '',
        playerName: m['playerName'] as String? ?? '',
        from: _date(m['from']) ?? DateTime(2000),
        until: _date(m['until']) ?? DateTime(2000),
        mode: LoanMode.values.asNameMap()[m['mode']] ?? LoanMode.full,
        allowNotes: m['allowNotes'] != false,
        personality: m['personality'] as String? ?? '',
        goals: m['goals'] as String? ?? '',
        limits: m['limits'] as String? ?? '',
        sheetAt: _date(m['sheetAt']),
        revokedAt: _date(m['revokedAt']),
        playerNotes: m['playerNotes'] is String ? m['playerNotes'] as String : '',
        notesAt: _date(m['notesAt']),
        version: (m['version'] as num?)?.toInt() ?? 0,
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String characterId;
  String characterName;
  String playerUid;
  String playerName;
  DateTime from;
  DateTime until;
  LoanMode mode;
  bool allowNotes;
  String personality;
  String goals;
  String limits;
  DateTime? sheetAt;
  DateTime? revokedAt;
  String playerNotes;
  DateTime? notesAt;
  final int version;
  final String? updatedByName;

  /// Champs écrits par le conte (jamais `playerNotes` ni `notesAt`, écrits par le joueur).
  Map<String, dynamic> toMap() => {
        'characterId': characterId,
        'characterName': characterName,
        'playerUid': playerUid,
        'playerName': playerName,
        'from': _ts(from),
        'until': _ts(until),
        'mode': mode.name,
        'allowNotes': allowNotes,
        'personality': personality,
        'goals': goals,
        'limits': limits,
        'sheetAt': _ts(sheetAt),
        'revokedAt': _ts(revokedAt),
      };

  NpcLoan copy() => NpcLoan.fromMap(id, {
        ...toMap(),
        'playerNotes': playerNotes,
        'notesAt': _ts(notesAt),
        'version': version,
        'updatedByName': updatedByName,
      });
}
