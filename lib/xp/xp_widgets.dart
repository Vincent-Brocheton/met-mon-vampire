import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'xp_request.dart';

/// Étiquette arrondie (types et statuts des maquettes J-Demandes et C-Validation).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class XpTypePill extends StatelessWidget {
  const XpTypePill({super.key});

  @override
  Widget build(BuildContext context) => const Pill('Dépense XP', bg: AppColors.reviewBg, fg: AppColors.goldLight);
}

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.status, {super.key});
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      RequestStatus.pending => (AppColors.reviewBg, AppColors.goldLight),
      RequestStatus.changes => (AppColors.deadBg, AppColors.linkHover),
      RequestStatus.accepted => (AppColors.activeBg, AppColors.success),
      RequestStatus.rejected => (AppColors.navActive, AppColors.linkHover),
      RequestStatus.draft || RequestStatus.cancelled => (AppColors.navActive, AppColors.textSecondary),
    };
    return Pill(status.label, bg: bg, fg: fg);
  }
}
