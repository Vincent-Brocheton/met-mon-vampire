import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'session_providers.dart';

/// Carte centrée des écrans hors connexion (style de MotDePasse.dc.html).
class AuthCard extends ConsumerWidget {
  const AuthCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(chronicleProvider).value?.displayName ?? 'Portail MET';
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Panel(
                padding: EdgeInsets.all(isWide(context) ? 36 : 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const DropLogo(size: 28),
                    const SizedBox(width: 10),
                    Flexible(child: Text(name, style: t.headlineSmall?.copyWith(fontSize: 28))),
                  ]),
                  const SizedBox(height: 18),
                  Text(title, style: t.headlineMedium),
                  const SizedBox(height: 18),
                  for (final (i, child) in children.indexed) ...[
                    if (i > 0) const SizedBox(height: 16),
                    child,
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texte d’erreur annoncé aux lecteurs d’écran.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Text(message, style: const TextStyle(color: AppColors.linkHover, fontSize: 15)),
      );
}
