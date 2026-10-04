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
