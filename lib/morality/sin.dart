import 'package:cloud_firestore/cloud_firestore.dart';

/// Test de remords d'un péché.
enum Remorse {
  success('Réussi (−1)', 'Réussi (−1 trait)'),
  failed('Échoué', 'Échoué'),
  none('Non tenté', 'Non tenté');

  const Remorse(this.label, this.choice);

  /// Libellé du tableau.
  final String label;

  /// Libellé du choix dans le formulaire.
  final String choice;

  static Remorse parse(String? s) => values.where((r) => r.name == s).firstOrNull ?? none;
}

/// La soirée d'une date : le jour, à minuit.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Péché d'une soirée (`characters/{id}/sins/{s}`), saisi par le conte (sous-projet 7b).
class Sin {
  Sin({
    required this.id,
    required this.date,
    this.level = 1,
    this.what = '',
    this.remorse = Remorse.none,
    this.lossApplied = false,
    this.byName = '',
    this.byUid = '',
    this.createdAt,
    this.distinct = false,
  });

  factory Sin.fromMap(String id, Map<String, dynamic> m) => Sin(
        id: id,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime(1900),
        level: (m['level'] as num?)?.toInt() ?? 1,
        what: m['what'] as String? ?? '',
        remorse: Remorse.parse(m['remorse'] as String?),
        lossApplied: m['lossApplied'] == true,
        byName: m['byName'] as String? ?? '',
        byUid: m['byUid'] as String? ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        distinct: m['distinct'] == true,
      );

  final String id;
  DateTime date;
  int level;
  String what;
  Remorse remorse;

  /// Vrai une fois la perte de la soirée appliquée : le péché ne se modifie plus.
  bool lossApplied;
  String byName;

  /// Auteur de la dernière écriture.
  String byUid;

  /// Null tant que la création n'est pas confirmée par le serveur.
  final DateTime? createdAt;

  /// Tranché « distinct » d'un péché voisin (sous-projet 8d) : il ne fait plus conflit.
  bool distinct;

  /// `distinct` n'est écrit que s'il est vrai : les anciens documents ne changent pas.
  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(dayOf(date)),
        'level': level,
        'what': what,
        'remorse': remorse.name,
        'lossApplied': lossApplied,
        if (distinct) 'distinct': true,
      };

  Sin copy() => Sin(
        id: id,
        date: date,
        level: level,
        what: what,
        remorse: remorse,
        lossApplied: lossApplied,
        byName: byName,
        byUid: byUid,
        createdAt: createdAt,
        distinct: distinct,
      );
}

/// Document d'un nouveau péché : exactement les clés permises par les règles.
Map<String, dynamic> newSinData(Sin s, String byUid, String byName) {
  final now = FieldValue.serverTimestamp();
  return {...s.toMap(), 'byUid': byUid, 'byName': byName, 'createdAt': now, 'updatedAt': now};
}
