import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'rule_entry.dart';

/// Sous un élément choisi : « Accord du conte » et la règle affichée aux joueurs.
class RuleHint extends StatelessWidget {
  const RuleHint(this.entry, {super.key, this.maxLines});
  final RuleEntry? entry;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final approval = e?.state == RuleState.approval;
    if (e == null || (!approval && e.description.isEmpty)) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (approval) Text('Accord du conte', style: t.labelMedium?.copyWith(color: AppColors.goldLight)),
        if (e.description.isNotEmpty)
          Text(e.description, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: t.bodySmall),
      ]),
    );
  }
}
