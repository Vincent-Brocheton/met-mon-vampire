import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../characters/character.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'derangement_form.dart';
import 'derangement_rules.dart';

/// Bloc « Dérangements » du joueur (J-Moralite) : ses dérangements, le compteur, ses demandes, et la demande d'un dérangement.
class PlayerDerangements extends ConsumerStatefulWidget {
  const PlayerDerangements({super.key, required this.character, required this.rb, required this.basePath});

  final Character character;
  final Rulebook rb;
  final String basePath;

  @override
  ConsumerState<PlayerDerangements> createState() => _PlayerDerangementsState();
}

class _PlayerDerangementsState extends ConsumerState<PlayerDerangements> {
  bool _open = false;
  bool _busy = false;
  int _form = 0;

  Character get c => widget.character;

  Future<void> _send(Derangement d, String why) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(xpRepositoryProvider).save(
            XpRequest(
              characterId: c.id,
              characterName: c.name,
              playerUid: c.playerUid ?? '',
              playerName: c.playerName ?? '',
              items: [XpItem(XpKind.derangement, d.name, 0, 1, 0, derangement: derangementData(d..clan = false))],
              justification: why,
            ),
            submit: true,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Demande envoyée au conte.')));
      if (mounted) {
        setState(() {
          _open = false;
          _form++;
        });
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Envoi refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final requests = ref.watch(myRequestsProvider).value ?? const <XpRequest>[];
    final pending = [
      for (final r in requests)
        if (r.characterId == c.id && r.status.open)
          for (final i in r.items)
            if (i.kind == XpKind.derangement) i.name,
    ];
    final traits = clampTraits(c, c.derangementTraits);
    final canAsk = widget.basePath.startsWith('/joueur') && c.status == CharacterStatus.active;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Dérangements'),
        const SizedBox(height: 4),
        Text('Handicaps de 2 points, déclencheur au choix.', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        if (c.derangements.isEmpty && pending.isEmpty) Text('Aucun dérangement.', style: t.bodyMedium),
        for (final d in c.derangements) DerangementTile(d),
        for (final p in pending)
          Row(key: Key('de-pending-$p'), children: [
            Expanded(child: Text(p, style: t.titleSmall)),
            Text('En attente du conte', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
          ]),
        const SizedBox(height: 12),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Traits de dérangement en jeu : ', style: t.bodyMedium),
          Text('●' * traits + '○' * (3 - traits), key: const Key('de-traits'), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
        ]),
        if (canAsk && !_open)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(key: const Key('de-ask'), onPressed: () => setState(() => _open = true), child: const Text('Demander un dérangement')),
          ),
        if (canAsk && _open) ...[
          const SizedBox(height: 12),
          DerangementForm(
            key: ValueKey('de-ask-form-$_form'),
            rb: widget.rb,
            initial: Derangement('', ''),
            existing: [...c.derangements, for (final p in pending) Derangement('pending', p)],
            showClan: false,
            askWhy: true,
            busy: _busy,
            actionLabel: 'Envoyer la demande',
            onSubmit: _send,
            onCancel: () => setState(() => _open = false),
          ),
        ],
      ]),
    );
  }
}
