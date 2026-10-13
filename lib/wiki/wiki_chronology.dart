import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../events/event_rules.dart';
import '../events/events_repository.dart';
import '../events/story_event.dart';

/// Années de la chronologie, de la plus récente à la plus ancienne, chacune avec ses événements dans l'ordre des fiches.
List<(int, List<StoryEvent>)> timelineGroups(List<StoryEvent> events) {
  final sorted = [...events]..sort(compareEvents);
  final groups = <(int, List<StoryEvent>)>[];
  for (final e in sorted) {
    if (groups.isEmpty || groups.last.$1 != e.year) groups.add((e.year, <StoryEvent>[]));
    groups.last.$2.add(e);
  }
  return groups;
}

/// « Isaure de Valcourt · Titre » ; le titre seul pour un ancien événement sans nom.
String timelineLine(StoryEvent e) => e.charName.isEmpty ? e.title : '${e.charName} · ${e.title}';

/// Chronologie publique (sous-projet 9b) : les événements « Public » de toutes les fiches.
class ChronologyView extends ConsumerWidget {
  const ChronologyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted);
    return switch (ref.watch(publicEventsProvider)) {
      AsyncData(:final value) when value.isEmpty => Text('Aucun événement public pour l’instant.', style: muted),
      AsyncData(:final value) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (year, list) in timelineGroups(value)) ...[
            SectionTitle('$year'),
            const SizedBox(height: 8),
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(timelineLine(e), style: t.titleSmall),
                  Text(formatEventDate(e), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  if (e.description.isNotEmpty) Text(e.description, style: t.bodyMedium?.copyWith(color: AppColors.textSoft)),
                ]),
              ),
            const SizedBox(height: 8),
          ],
        ]),
      AsyncError() => Text('Chronologie indisponible : réessayez plus tard.', style: muted),
      _ => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
    };
  }
}
