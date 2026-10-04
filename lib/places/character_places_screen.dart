import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'place.dart';
import 'place_rules.dart';
import 'places_repository.dart';

/// Qualités lisibles : principales, surnaturelle, Élysée, puis négatives avec leur nombre.
String qualitiesText(Place p, Rulebook rb) {
  final names = [for (final q in p.qualities) if (qualityFamily(rb, q.name) != 'negative') q.name];
  final negatives = negativesText(p, rb);
  return [...names, if (negatives.isNotEmpty) negatives].join(' · ');
}

/// « Mes lieux » (J-Lieux) : les lieux du personnage, puis ceux que tout le monde connaît.
class CharacterPlacesScreen extends ConsumerWidget {
  const CharacterPlacesScreen({super.key, required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final rb = ref.watch(rulebookProvider) ?? const Rulebook();
    final name = ref.watch(characterProvider(characterId)).value?.name ?? '';
    return asyncView(ref.watch(characterPlacesProvider(characterId)), (mine) {
      return asyncView(ref.watch(publicPlacesProvider), (public) {
        final ids = {for (final p in mine) p.id};
        final others = [for (final p in public) if (!ids.contains(p.id)) p];
        Widget card(Place p) {
          final shared = [for (final h in p.holders) if (h.id != characterId) h.name];
          return SizedBox(
            width: 380,
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.name, style: t.headlineSmall)),
                  Text(dots(p.rank), style: const TextStyle(color: AppColors.gold, letterSpacing: 2)),
                ]),
                Text(p.type.label, style: t.titleSmall),
                const SizedBox(height: 8),
                if (p.qualities.isNotEmpty) Text('Qualités : ${qualitiesText(p, rb)}', style: t.bodyMedium),
                Text(shared.isEmpty ? 'À vous seul' : 'Partagé avec ${shared.join(', ')}', style: t.bodySmall?.copyWith(color: AppColors.success)),
                if (p.known.isNotEmpty) Text(p.known, style: t.bodySmall),
              ]),
            ),
          );
        }

        return PageBody(children: [
          PageTitle('Lieux', subtitle: name.isEmpty ? 'Les lieux que le conte vous a attribués.' : 'Les lieux que le conte a attribués à $name.'),
          const SizedBox(height: 20),
          if (mine.isEmpty)
            const EmptyState(kind: EmptyKind.empty, title: 'Aucun lieu', message: 'Le conte n’a attribué aucun lieu à ce personnage.')
          else
            Wrap(spacing: 16, runSpacing: 16, children: [for (final p in mine) card(p)]),
          const SizedBox(height: 24),
          const SectionTitle('Lieux connus de tous'),
          const SizedBox(height: 10),
          if (others.isEmpty) Text('Aucun.', style: t.bodySmall),
          for (final p in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: t.titleSmall),
                Text(p.type.label, style: t.bodySmall),
                if (p.known.isNotEmpty) Text(p.known, style: t.bodyMedium),
              ]),
            ),
          const SizedBox(height: 16),
          Text('Lecture seule. Seul le conte crée un lieu et l’attribue. Votre refuge n’est pas ici : c’est un historique.', style: t.bodySmall),
        ]);
      }, onRetry: () => ref.invalidate(publicPlacesProvider));
    }, onRetry: () => ref.invalidate(characterPlacesProvider(characterId)));
  }
}

/// Section « Lieux » d'une fiche (J2, C3) : noms des lieux contrôlés et lien.
class PlacesSection extends ConsumerWidget {
  const PlacesSection({super.key, required this.characterId, required this.link});
  final String characterId;
  final String link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final places = ref.watch(characterPlacesProvider(characterId)).value ?? const <Place>[];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Lieux'),
        const SizedBox(height: 8),
        if (places.isEmpty) Text('Aucun lieu.', style: t.bodySmall),
        for (final p in places) Text(p.name, style: t.bodyMedium),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go(link), child: const Text('Voir les lieux'))),
      ]),
    );
  }
}
