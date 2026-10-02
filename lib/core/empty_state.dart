import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';
import 'widgets.dart';

enum EmptyKind { empty, noResult, notFound, forbidden, offline, error, comingSoon }

/// Les états vides et erreurs communs à tous les écrans (maquette « Etats »).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  factory EmptyState.comingSoon(String feature) => EmptyState(
        kind: EmptyKind.comingSoon,
        title: feature,
        message: 'Cette partie arrive dans une prochaine version de l’application.',
      );

  factory EmptyState.error({VoidCallback? onRetry}) => EmptyState(
        kind: EmptyKind.error,
        title: 'Quelque chose s’est mal passé',
        message: 'Rien n’est perdu : votre saisie est conservée sur cet appareil.',
        actionLabel: onRetry == null ? null : 'Réessayer',
        onAction: onRetry,
      );

  final EmptyKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  (String, Color) get _glyph => switch (kind) {
        EmptyKind.empty => ('○', AppColors.textSecondary),
        EmptyKind.noResult => ('?', AppColors.textSecondary),
        EmptyKind.notFound => ('∅', AppColors.goldLight),
        EmptyKind.forbidden => ('!', AppColors.linkHover),
        EmptyKind.offline => ('≠', AppColors.offline),
        EmptyKind.error => ('×', AppColors.linkHover),
        EmptyKind.comingSoon => ('…', AppColors.gold),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (symbol, color) = _glyph;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Panel(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
                child: Text(symbol, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              Text(title, style: t.headlineSmall),
              const SizedBox(height: 8),
              Text(message, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              if (actionLabel != null) ...[
                const SizedBox(height: 18),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Chargement → indicateur, erreur → EmptyState.error, données → [builder].
Widget asyncView<T>(AsyncValue<T> value, Widget Function(T data) builder, {VoidCallback? onRetry}) =>
    switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError() => EmptyState.error(onRetry: onRetry),
      _ => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
    };
