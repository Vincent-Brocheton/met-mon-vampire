import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import 'auth_card.dart';
import 'forms.dart';
import 'session_providers.dart';

/// Compte en attente de validation, ou profil jamais créé (Review Focus 1).
class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _busy = false;
  String? _info;
  String? _error;

  /// Lance [action] ; le texte qu'elle renvoie s'affiche comme information.
  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _info = null;
      _error = null;
    });
    try {
      final info = await action();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(authRepositoryProvider);
    final profile = ref.watch(currentUserProvider).value;
    final authUser = ref.watch(authStateProvider).value;
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final signOut = Align(
      alignment: Alignment.centerLeft,
      child: TextButton(onPressed: _busy ? null : repo.signOut, child: const Text('Se déconnecter')),
    );
    final feedback = [
      if (_info != null) Semantics(liveRegion: true, child: Text(_info!, style: muted)),
      if (_error != null) FormError(_error!),
    ];

    if (profile == null) {
      return AuthCard(title: 'Demande incomplète', children: [
        Text('Votre compte existe, mais votre demande n’a pas été enregistrée jusqu’au bout.', style: muted),
        ...feedback,
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await repo.ensureProfile();
                    return null;
                  }),
          child: const Text('Finaliser ma demande'),
        ),
        signOut,
      ]);
    }

    final verified = authUser?.emailVerified ?? false;
    return AuthCard(title: 'Bonjour, ${profile.displayName}', children: [
      Text('Un conteur va valider votre compte. Vous pourrez alors entrer dans la chronique.', style: muted),
      if (!verified && authUser != null) ...[
        Text('Confirmez aussi votre adresse : un e-mail vous a été envoyé à ${profile.email}.', style: muted),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await repo.resendVerification();
                    return 'E-mail de confirmation renvoyé.';
                  }),
          child: const Text('Renvoyer l’e-mail'),
        ),
      ],
      ...feedback,
      FilledButton(
        onPressed: _busy
            ? null
            : () => _run(() async => await repo.applyInvitation()
                ? null
                : 'Aucune invitation pour cette adresse, ou adresse pas encore confirmée : un conteur va valider votre demande.'),
        child: const Text('J’ai confirmé mon e-mail'),
      ),
      signOut,
    ]);
  }
}
