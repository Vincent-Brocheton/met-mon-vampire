import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../servants/servant_rules.dart' show DueState, dueDate, dueState;
import 'character.dart';
import 'describe_changes.dart' show dots;
import 'sheet_widgets.dart' show InfoRow;

/// « État de goule » (J-Goule) : domitor, lien, vitae, échéance, rappels des règles.
class GhoulPanel extends StatelessWidget {
  const GhoulPanel(this.g, {super.key, this.now});
  final GhoulState g;

  /// Date du jour (tests) ; maintenant par défaut.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = g.lastDrink;
    final state = dueState(last, now ?? DateTime.now());
    final alert = switch (state) {
      DueState.late => 'Échéance dépassée le ${formatDay(dueDate(last!))} : son âge le rattrape, 10 ans par jour.',
      DueState.soon => 'Buvez avant le ${formatDay(dueDate(last!))}, sinon son âge le rattrape : 10 ans par jour.',
      _ => null,
    };
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('État de goule'),
        const SizedBox(height: 10),
        Text(ghoulLine(g), style: t.titleSmall),
        const SizedBox(height: 6),
        InfoRow('Lien de sang', g.bond == 0 ? 'aucun' : dots(g.bond)),
        InfoRow('Vitae', '${g.vitae} / 5'),
        InfoRow('Dernière gorgée', last == null ? '—' : formatDay(last)),
        if (alert != null) Text(alert, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        const InfoRow('Génération', 'aucune'),
        const InfoRow('Traits de Bête', 'jamais'),
        const InfoRow('Humanité', 'ne peut pas baisser'),
      ]),
    );
  }
}
