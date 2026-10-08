import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show CharacterHeader, CharacterTab;
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'event_rules.dart';
import 'event_timeline.dart';
import 'events_repository.dart';

/// Onglet « Récit » (J-Recit) : le récit de la fiche et ses événements marquants, en lecture.
/// Le joueur ne voit que les événements qui lui sont ouverts ; l'équipe les voit tous.
class CharacterStoryScreen extends ConsumerWidget {
  const CharacterStoryScreen({super.key, required this.characterId, required this.basePath});

  final String characterId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final staff = ref.watch(currentUserProvider).value?.role.isStaff ?? false;
    final value = ref.watch(characterProvider(characterId));
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    return asyncView(value, (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      final concept = (c.concept ?? '').trim();
      final text = (c.story ?? '').trim();
      final story = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Concept'),
          const SizedBox(height: 8),
          Text(concept.isEmpty ? '—' : concept, style: t.titleMedium),
          const SizedBox(height: 20),
          const SectionTitle('Récit'),
          const SizedBox(height: 8),
          Text(text.isEmpty ? 'Aucun récit.' : text, style: t.bodyLarge?.copyWith(height: 1.6)),
        ]),
      );
      final events = Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Row(children: [
              const Expanded(child: SectionTitle('Événements marquants')),
              Text('Tenus par le conte', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          asyncView(
            ref.watch(characterEventsProvider(c.id)),
            (l) => EventTimeline(events: [for (final e in l) if (visibleTo(e, staff: staff)) e], staff: staff),
            onRetry: () => ref.invalidate(characterEventsProvider(c.id)),
          ),
        ]),
      );
      final header = CharacterHeader(c, basePath: basePath, tab: CharacterTab.story);
      if (!isWide(context)) {
        return PageBody(children: [header, const SizedBox(height: 22), story, const SizedBox(height: 20), events]);
      }
      return PageBody(children: [
        header,
        const SizedBox(height: 22),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: story),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: events),
        ]),
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(characterId)));
  }
}
