import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/games_repository.dart';
import 'device.dart';
import 'devices_repository.dart';

/// « Appareils connectés » de Mon compte (Compte) : un appareil par ligne, « Déconnecter ».
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key, required this.onSignOut, this.now});

  /// Déconnexion de cet appareil, comme « Se déconnecter ».
  final Future<void> Function() onSignOut;

  /// Heure de l'appareil ; remplacée dans les tests.
  final DateTime Function()? now;

  Future<void> _revoke(BuildContext context, WidgetRef ref, String uid, Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnecter « ${d.name} » ?'),
        content: const Text('Sa copie hors ligne sera effacée à son prochain passage en ligne.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déconnecter')),
        ],
      ),
    );
    if (ok == true) await ref.read(devicesRepositoryProvider).revoke(uid, d.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final uid = ref.watch(currentUserProvider).value?.uid;
    final devices = ref.watch(myDevicesProvider).value ?? const <Device>[];
    final mine = ref.watch(deviceIdProvider).value;
    final games = ref.watch(gamesProvider).value ?? const <Game>[];
    final today = (now ?? DateTime.now)();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Appareils connectés'),
        const SizedBox(height: 8),
        if (devices.isEmpty) Text('Aucun appareil.', style: t.bodyMedium),
        for (final d in devices)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.id == mine ? '${d.name} · Cet appareil' : d.name, style: t.bodyLarge),
                  Text(deviceLine(d, games, today), style: t.bodySmall),
                ]),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: Key('device-${d.id}'),
                onPressed: uid == null
                    ? null
                    : () {
                        if (d.id == mine) {
                          onSignOut();
                        } else if (d.revokedAt != null) {
                          ref.read(devicesRepositoryProvider).remove(uid, d.id);
                        } else {
                          _revoke(context, ref, uid, d);
                        }
                      },
                child: Text(d.revokedAt != null && d.id != mine ? 'Retirer' : 'Déconnecter'),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Text('Déconnecter un appareil efface aussi sa copie hors ligne.', style: t.bodySmall),
        Text('Un appareil hors ligne est déconnecté à son prochain passage en ligne.', style: t.bodySmall),
      ]),
    );
  }
}
