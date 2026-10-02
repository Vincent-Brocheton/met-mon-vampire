import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../player/welcome_screen.dart';
import 'character.dart';
import 'character_repository.dart';
import 'describe_changes.dart';
import 'sheet_widgets.dart';

int _order(CharacterStatus s) => switch (s) {
      CharacterStatus.active => 0,
      CharacterStatus.review => 1,
      CharacterStatus.draft => 2,
      _ => 3,
    };

/// `/joueur` : Bienvenue (J15) tant qu'aucune fiche, sinon Mes personnages (J1).
class PlayerHome extends ConsumerWidget {
  const PlayerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncView(
        ref.watch(myCharactersProvider),
        (list) => list.isEmpty ? const WelcomeScreen() : _MyCharactersList(list),
        onRetry: () => ref.invalidate(myCharactersProvider),
      );
}

class MyCharactersScreen extends ConsumerWidget {
  const MyCharactersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncView(
        ref.watch(myCharactersProvider),
        (list) => list.isEmpty
            ? const EmptyState(
                kind: EmptyKind.empty,
                title: 'Aucun personnage',
                message: 'Le conte crée l’amorce de votre fiche ; vous pourrez alors la remplir.',
              )
            : _MyCharactersList(list),
        onRetry: () => ref.invalidate(myCharactersProvider),
      );
}

class _MyCharactersList extends StatelessWidget {
  const _MyCharactersList(this.list);
  final List<Character> list;

  @override
  Widget build(BuildContext context) {
    final sorted = [...list]..sort((a, b) => _order(a.status).compareTo(_order(b.status)));
    return PageBody(children: [
      const PageTitle('Mes personnages'),
      const SizedBox(height: 22),
      for (final c in sorted) ...[_CharacterCard(c), const SizedBox(height: 16)],
    ]);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final closed = _order(c.status) == 3;
    Widget stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.2, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: t.titleMedium),
        ]);
    return Opacity(
      opacity: closed ? 0.6 : 1,
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 72,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.navActive,
                border: Border.all(color: AppColors.fieldBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(initialsOf(c.name), style: t.headlineSmall),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: t.headlineSmall?.copyWith(fontSize: 28)),
                if (identityLine(c).isNotEmpty) Text(identityLine(c), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [StatusChip(c.status), KindTag(c.kind)]),
              ]),
            ),
          ]),
          if (c.status == CharacterStatus.active) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 28, runSpacing: 12, children: [
              stat('XP dispo.', '${c.xpAvailable}'),
              stat('Sang', '${c.blood} · ${c.bloodPerTurn}/tour'),
              stat('Volonté', '${c.willpower}'),
              stat('Humanité', dots(c.humanity)),
            ]),
          ],
          if (c.status == CharacterStatus.draft) ...[
            const SizedBox(height: 12),
            Text('Brouillon : la création guidée arrive bientôt dans l’application.', style: t.bodySmall),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => context.go('/joueur/personnages/${c.id}'),
              child: const Text('Ouvrir la fiche'),
            ),
          ),
        ]),
      ),
    );
  }
}
