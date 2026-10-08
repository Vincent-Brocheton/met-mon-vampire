import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show CharacterHeader, CharacterTab;
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'morality_staff.dart';
import 'sin.dart';
import 'sins_repository.dart';

/// Onglet « Moralité & liens » : vue du conte (C-Moralite) pour l'équipe sur la fiche d'un autre,
/// vue du joueur (J-Moralite) sinon.
class CharacterMoralityScreen extends ConsumerWidget {
  const CharacterMoralityScreen({super.key, required this.characterId, required this.basePath});

  final String characterId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final rb = ref.watch(rulebookProvider);
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
    if (rb == null) return const Center(child: CircularProgressIndicator());
    return asyncView(value, (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      final staffView = me != null && me.role.isStaff && c.playerUid != me.uid;
      final canEdit = staffView && me.role.managesAccounts;
      return asyncView(
        ref.watch(characterSinsProvider(c.id)),
        (sins) => PageBody(children: [
          CharacterHeader(c, basePath: basePath, tab: CharacterTab.morality),
          const SizedBox(height: 22),
          if (staffView) StaffMorality(character: c, sins: sins, rb: rb, canEdit: canEdit) else playerMorality(context, c, sins, rb, basePath),
        ]),
        onRetry: () => ref.invalidate(characterSinsProvider(c.id)),
      );
    }, onRetry: () => ref.invalidate(characterProvider(characterId)));
  }
}

/// Vue du joueur, complétée à la tâche 5.
Widget playerMorality(BuildContext context, Character c, List<Sin> sins, Rulebook rb, String basePath) => const SizedBox.shrink();
