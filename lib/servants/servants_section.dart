import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'servant_file.dart';
import 'servant_rules.dart';
import 'servants_repository.dart';

/// Section « Serviteurs » d'une fiche (J2, C3) : serviteurs, échéances, points indisponibles.
class ServantsSection extends ConsumerWidget {
  const ServantsSection({super.key, required this.character, required this.linkOf});
  final Character character;

  /// Lien vers la fiche d'un serviteur, selon l'écran.
  final String Function(String servantId) linkOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final files = ref.watch(characterServantFilesProvider(character.id)).value ?? const <ServantFile>[];
    final byId = {for (final f in files) f.id: f};
    final now = DateTime.now();
    final ids = {for (final s in character.servants) s.id};
    final released = [
      for (final f in files)
        if (!ids.contains(f.id) && f.releasedAt != null && now.isBefore(unavailableUntil(f.releasedAt!, f.releasedRank))) f,
    ];
    String status(Servant s) {
      final f = byId[s.id];
      if (f == null) return 'à compléter';
      return switch (dueState(f.lastDrink, now)) {
        null => 'aucune gorgée notée',
        DueState.late => 'échéance dépassée : son âge le rattrape',
        DueState.soon => 'échéance le ${formatDay(dueDate(f.lastDrink!))}',
        DueState.ok => 'vitae ${f.vitae} / 5',
      };
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Serviteurs'),
        const SizedBox(height: 8),
        if (character.servants.isEmpty) Text('Aucun serviteur.', style: t.bodySmall),
        for (final s in character.servants)
          InkWell(
            onTap: () => context.go(linkOf(s.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(s.name, style: t.titleSmall),
                Text('${s.kind.label} ${dots(s.rank)}', style: t.bodySmall),
                Text(status(s), style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
              ]),
            ),
          ),
        for (final f in released)
          Text('${f.name} : points indisponibles jusqu’au ${formatDay(unavailableUntil(f.releasedAt!, f.releasedRank))}', style: t.bodySmall),
      ]),
    );
  }
}

/// Fiche d'un serviteur en lecture, pour le joueur (sans la note secrète).
class ServantScreen extends ConsumerWidget {
  const ServantScreen({super.key, required this.characterId, required this.servantId});
  final String characterId;
  final String servantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return asyncView(ref.watch(characterProvider(characterId)), (c) {
      final s = c?.servants.where((x) => x.id == servantId).firstOrNull;
      if (c == null || s == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Serviteur introuvable', message: 'Il n’est plus sur la fiche du personnage.');
      }
      return asyncView(ref.watch(characterServantFilesProvider(characterId)), (files) {
        final f = files.where((x) => x.id == servantId).firstOrNull;
        return PageBody(children: [
          PageTitle(s.name, subtitle: '${s.kind.label} de ${c.name} · rang ${s.rank}'),
          const SizedBox(height: 20),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Réserve ${pool(s.rank)} · santé ${s.rank} · pas de Volonté', style: t.bodyMedium),
              const SizedBox(height: 10),
              if (f == null)
                Text('Le conte n’a pas encore détaillé ce serviteur.', style: t.bodySmall)
              else ...[
                Text('Spécialités : ${f.specialties.isEmpty ? 'aucune' : f.specialties.join(' · ')}', style: t.bodyMedium),
                if (s.kind == ServantKind.animal) Text('Qualités animales : ${f.qualities.isEmpty ? 'aucune' : f.qualities.join(' · ')}', style: t.bodyMedium),
                Text('Vitae ${f.vitae} / 5 · lien de sang ${f.bond == 0 ? 'aucun' : dots(f.bond)}', style: t.bodyMedium),
                Text(
                  f.lastDrink == null
                      ? 'Aucune gorgée notée.'
                      : 'Dernière gorgée le ${formatDay(f.lastDrink)}. Buvez avant le ${formatDay(dueDate(f.lastDrink!))}, sinon son âge le rattrape : 10 ans par jour.',
                  style: t.bodySmall,
                ),
                if (f.description.isNotEmpty) ...[const SizedBox(height: 10), Text(f.description, style: t.bodyMedium)],
              ],
            ]),
          ),
        ]);
      }, onRetry: () => ref.invalidate(characterServantFilesProvider(characterId)));
    }, onRetry: () => ref.invalidate(characterProvider(characterId)));
  }
}
