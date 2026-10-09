import 'package:cloud_firestore/cloud_firestore.dart';

/// Copie publique d'un titre (`court/{characterId}`) : ce que tous les joueurs voient dans la Cour.
class CourtEntry {
  const CourtEntry({required this.characterId, required this.name, required this.title, this.sect = '', this.under = '', this.since});

  factory CourtEntry.fromMap(String id, Map<String, dynamic> m) => CourtEntry(
        characterId: id,
        name: m['name'] as String? ?? '',
        title: m['title'] as String? ?? '',
        sect: m['sect'] as String? ?? '',
        under: m['under'] as String? ?? '',
        since: (m['since'] as Timestamp?)?.toDate(),
      );

  final String characterId;
  final String name;
  final String title;
  final String sect;
  final String under;
  final DateTime? since;

  Map<String, dynamic> toMap() => {
        'name': name,
        'title': title,
        'sect': sect,
        'under': under,
        'since': since == null ? null : Timestamp.fromDate(since!),
      };
}
