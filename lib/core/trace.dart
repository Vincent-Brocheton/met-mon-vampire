import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dates.dart';

/// Entrée de l'historique d'un document suivi (lieu, serviteur) : `…/history/{h}`.
class TraceEntry {
  const TraceEntry({required this.at, required this.byName, required this.summary, required this.reason});

  factory TraceEntry.fromMap(Map<String, dynamic> m) => TraceEntry(
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

/// Historique affiché : date, auteur, une ligne par changement, motif.
class TraceHistory extends StatelessWidget {
  const TraceHistory(this.entries, {super.key});
  final List<TraceEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (entries.isEmpty) return Text('Aucune entrée.', style: t.bodySmall);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${formatDay(e.at)} · ${e.byName}', style: t.bodySmall),
            for (final s in e.summary) Text(s, style: t.bodyMedium),
            if (e.reason.isNotEmpty) Text('Motif : ${e.reason}', style: t.bodySmall),
          ]),
        ),
    ]);
  }
}

/// Ajoute à [batch] un document suivi : version + 1 (1 à la création), entrée d'historique, et note secrète
/// (`private/note`) si [note] est donnée. À la mise à jour, la fusion garde `createdAt` ; les autres clés sont réécrites.
void stageTraced(
  WriteBatch batch,
  DocumentReference<Map<String, dynamic>> ref,
  Map<String, dynamic> data, {
  required bool creating,
  required int fromVersion,
  required String byUid,
  required String byName,
  required List<String> summary,
  required String reason,
  String? note,
}) {
  final h = ref.collection('history').doc();
  final now = FieldValue.serverTimestamp();
  batch
    ..set(
      ref,
      {
        ...data,
        'version': creating ? 1 : fromVersion + 1,
        'lastHistoryId': h.id,
        'updatedAt': now,
        'updatedByName': byName,
        if (creating) 'createdAt': now,
      },
      SetOptions(merge: !creating),
    )
    ..set(h, {
      'at': now,
      'byUid': byUid,
      'byName': byName,
      'summary': summary.isEmpty ? ['Enregistré sans changement'] : summary,
      'reason': reason.trim(),
    });
  if (note != null) batch.set(ref.collection('private').doc('note'), {'text': note.trim()});
}

/// Supprime [ref], sa note secrète, son historique et les documents [also], en un seul lot.
Future<void> deleteTraced(FirebaseFirestore db, DocumentReference<Map<String, dynamic>> ref, {List<DocumentReference> also = const []}) async {
  // ponytail: un seul lot, limité à 500 écritures (≈ 495 entrées d'historique) ; découper si un document en a davantage.
  final history = await ref.collection('history').get();
  final batch = db.batch()
    ..delete(ref.collection('private').doc('note'))
    ..delete(ref);
  for (final d in [...also, for (final h in history.docs) h.reference]) {
    batch.delete(d);
  }
  await batch.commit();
}
