import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bonds/bond.dart';
import '../bonds/bond_rules.dart' show bondDots, effectiveLevel;
import '../bonds/bonds_repository.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../servants/servant_rules.dart' show DueState, dueDate, dueState;
import 'character.dart';
import 'sheet_widgets.dart' show InfoRow;

/// « État de goule » (J-Goule) : domitor, lien, vitae, échéance, rappels des règles.
/// Le lien envers le domitor est lu dans les liens de sang (sous-projet 7c) ; à défaut, l’ancien niveau de la fiche.
class GhoulPanel extends ConsumerWidget {
  const GhoulPanel(this.g, {super.key, required this.characterId, this.now});
  final GhoulState g;

  /// Fiche de la goule.
  final String characterId;

  /// Date du jour (tests) ; maintenant par défaut.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = now ?? DateTime.now();
    final last = g.lastDrink;
    final state = dueState(last, today);
    final alert = switch (state) {
      DueState.late => 'Échéance dépassée le ${formatDay(dueDate(last!))} : son âge le rattrape, 10 ans par jour.',
      DueState.soon => 'Buvez avant le ${formatDay(dueDate(last!))}, sinon son âge le rattrape : 10 ans par jour.',
      _ => null,
    };
    final async = ref.watch(characterBondsProvider(characterId));
    final bond = ((async.hasError ? null : async.value) ?? const <Bond>[]).where((b) => b.regnantId == g.domitorId && b.thrallId == characterId).firstOrNull;
    // Le repli sur l'ancien niveau de la fiche seulement une fois les liens lus.
    final level = bond != null ? effectiveLevel(bond, today) : g.bond.clamp(0, 3);
    final bondText = async.hasError
        ? 'Liens indisponibles.'
        : !async.hasValue
            ? '…'
            : level == 0
                ? 'aucun'
                : bondDots(level);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('État de goule'),
        const SizedBox(height: 10),
        Text(ghoulLine(g), style: t.titleSmall),
        const SizedBox(height: 6),
        InfoRow('Lien de sang', bondText),
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
