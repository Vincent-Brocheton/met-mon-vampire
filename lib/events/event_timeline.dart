import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'event_rules.dart';
import 'story_event.dart';

Color toneColor(EventTone t) => switch (t) {
      EventTone.blood => AppColors.accentIcon,
      EventTone.title => AppColors.goldLight,
      EventTone.moral => AppColors.narrator,
      EventTone.life => AppColors.success,
      EventTone.plot => AppColors.textSecondary,
    };

/// Étiquette de visibilité (maquettes C-Evenements et J-Recit).
class VisibilityChip extends StatelessWidget {
  const VisibilityChip(this.v, {super.key, required this.staff});
  final EventVisibility v;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (v) {
      EventVisibility.public => (AppColors.activeBg, AppColors.success),
      EventVisibility.player => (const Color(0xFF2A2240), AppColors.narrator),
      EventVisibility.staff => (AppColors.deadBg, AppColors.linkHover),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(visibilityLabel(v, staff: staff), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// Chronologie d'une fiche, dans l'ordre reçu.
class EventTimeline extends StatelessWidget {
  const EventTimeline({super.key, required this.events, required this.staff, this.onTap, this.selectedId});

  final List<StoryEvent> events;
  final bool staff;
  final void Function(StoryEvent e)? onTap;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (events.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Text('Aucun événement.', style: t.bodyMedium));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, e) in events.indexed)
        InkWell(
          key: Key('ev-row-${e.id}'),
          onTap: onTap == null ? null : () => onTap!(e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: e.id.isNotEmpty && e.id == selectedId ? AppColors.navActive : null,
              border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: toneColor(e.type.tone), shape: BoxShape.circle)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(formatEventDate(e), style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    Text(e.type.label.toUpperCase(), style: t.labelSmall),
                    VisibilityChip(e.visibility, staff: staff),
                  ]),
                  const SizedBox(height: 4),
                  Text(e.title, style: t.titleMedium),
                  if (e.description.isNotEmpty) Text(e.description, style: t.bodyMedium),
                  const SizedBox(height: 4),
                  Text(sourceLabel(e), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}
