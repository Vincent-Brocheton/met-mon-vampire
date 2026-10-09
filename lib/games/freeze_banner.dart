import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Bandeau bleu du gel (J-Fiche, C-Figer) : cadenas et texte.
class FreezeBanner extends StatelessWidget {
  const FreezeBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.frozenBg,
          border: Border.all(color: AppColors.frozenBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.frozen),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.frozenText, fontSize: 14))),
        ]),
      );
}
