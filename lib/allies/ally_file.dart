import 'package:cloud_firestore/cloud_firestore.dart';

import '../npcs/loan_rules.dart' show formatLoanDay;

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

/// Suivi d'usage d'un allié (`allies/{id}`, même identifiant que sur la fiche).
class AllyFile {
  AllyFile({
    required this.id,
    this.name = '',
    this.characterId = '',
    this.characterName = '',
    List<String>? holderPlayers,
    this.usedAt,
    this.returnAt,
    this.lastUse = '',
    this.version = 0,
  }) : holderPlayers = holderPlayers ?? [];

  factory AllyFile.fromMap(String id, Map<String, dynamic> m) => AllyFile(
        id: id,
        name: m['name'] as String? ?? '',
        characterId: m['characterId'] as String? ?? '',
        characterName: m['characterName'] as String? ?? '',
        holderPlayers: [for (final u in (m['holderPlayers'] as List?) ?? const []) '$u'],
        usedAt: _date(m['usedAt']),
        returnAt: _date(m['returnAt']),
        lastUse: m['lastUse'] as String? ?? '',
        version: (m['version'] as num?)?.toInt() ?? 0,
      );

  final String id;
  String name;
  String characterId;
  String characterName;
  List<String> holderPlayers;
  DateTime? usedAt;
  DateTime? returnAt;
  String lastUse;
  final int version;

  Map<String, dynamic> toMap() => {
        'name': name,
        'characterId': characterId,
        'characterName': characterName,
        'holderPlayers': holderPlayers,
        'usedAt': _ts(usedAt),
        'returnAt': _ts(returnAt),
        'lastUse': lastUse,
      };

  AllyFile copy() => AllyFile.fromMap(id, {...toMap(), 'holderPlayers': [...holderPlayers], 'version': version});
}

/// Résumé d'un enregistrement du suivi, pour l'historique.
List<String> allyFileChanges(AllyFile a, AllyFile b) => [
      if (b.usedAt == null && a.usedAt != null)
        'Rendu disponible'
      else if (b.usedAt != null && (a.usedAt != b.usedAt || a.lastUse != b.lastUse))
        'Utilisé le ${formatLoanDay(b.usedAt)}${b.lastUse.isEmpty ? '' : ' : ${b.lastUse}'}',
      if (b.usedAt != null && b.returnAt != null && a.returnAt != b.returnAt) 'Retour le ${formatLoanDay(b.returnAt)}',
      if (a.holderPlayers.join(',') != b.holderPlayers.join(',')) 'Accès du joueur mis à jour',
    ];
