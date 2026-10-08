import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../characters/character.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'bond.dart';
import 'bond_rules.dart';
import 'bonds_repository.dart';

/// Blocs du joueur (J-Moralite) : liens subis et exercés que le conte lui laisse connaître, en lecture.
class PlayerBonds extends ConsumerWidget {
  const PlayerBonds({super.key, required this.character, this.today});

  final Character character;

  /// Date du jour (tests) ; aujourd'hui par défaut.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final day = today ?? DateTime.now();
    final c = character;
    final async = ref.watch(characterBondsProvider(c.id));
    final bonds = async.hasError ? const <Bond>[] : async.value ?? const <Bond>[];
    final suffered = activeBonds(bonds.where((b) => b.thrallId == c.id), day);
    final exerted = activeBonds(bonds.where((b) => b.regnantId == c.id), day);
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);

    Widget card(Bond b, String name, String? tag, List<String> lines) => Container(
          key: Key('bo-${b.id}'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(name, style: t.titleSmall),
                  if (tag != null) Text(tag, style: t.bodySmall?.copyWith(color: AppColors.narrator)),
                ]),
              ),
              Text(bondDots(effectiveLevel(b, day)), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
            ]),
            const SizedBox(height: 4),
            for (final (i, l) in lines.indexed)
              Text(l, style: i == 0 ? t.bodyMedium?.copyWith(color: AppColors.textSecondary) : muted),
          ]),
        );

    // Chargement ou erreur : ni « Aucun lien. » ni l'ancienne valeur.
    Widget empty() => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: async.hasError
              ? Text('Liens indisponibles.', style: t.bodyMedium)
              : async.hasValue
                  ? Text('Aucun lien.', style: t.bodyMedium)
                  : const Center(child: CircularProgressIndicator()),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Liens de sang que vous subissez'),
          if (suffered.isEmpty) empty(),
          for (final b in suffered) card(b, b.regnantName, null, [sufferedLine(b, day), sufferedDelay(b, day)]),
          const SizedBox(height: 12),
          Text(
            '2 gorgées : 1 Volonté par heure pour lui nuire. 3 gorgées : lien complet, qui efface les liens moindres.',
            style: muted,
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Liens que vous exercez'),
          if (exerted.isEmpty) empty(),
          for (final b in exerted) card(b, b.thrallName, b.ghoul ? 'votre goule' : null, [exertedLine(b, day)]),
          const SizedBox(height: 12),
          Text('Le conte choisit ce que vous savez des liens envers vous.', style: muted),
        ]),
      ),
    ]);
  }
}
