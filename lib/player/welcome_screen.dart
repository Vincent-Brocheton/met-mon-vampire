import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

const _steps = [
  ('1', 'Lisez sur les clans et les sectes', 'Le wiki présente les clans jouables dans la chronique.', AppColors.gold),
  ('2', 'Créez votre personnage', 'Dix étapes guidées, 30 XP de départ. Votre brouillon est enregistré à chaque étape.', AppColors.gold),
  ('3', 'Soumettez-le au conte', 'Il le valide ou vous propose des corrections. Ensuite, il entre en jeu.', AppColors.textMuted),
];

/// J15 : joueur validé, sans personnage.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final name = ref.watch(currentUserProvider).value?.displayName ?? '';
    final first = name.split(' ').first;
    final main = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bienvenue, $first', style: isWide(context) ? t.displayMedium : t.headlineLarge),
      const SizedBox(height: 18),
      Text('Votre compte est validé. Vous n’avez pas encore de personnage : voici comment entrer dans la chronique.',
          style: t.bodyLarge),
      const SizedBox(height: 18),
      for (final (n, title, detail, color) in _steps)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
              child: Text(n, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(detail, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton(onPressed: () => context.go('/joueur/personnages'), child: const Text('Créer mon personnage')),
        OutlinedButton(onPressed: () => context.go('/joueur/wiki'), child: const Text('Ouvrir le wiki')),
      ]),
    ]);
    Widget aside(String title, String text) => Panel(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title),
            const SizedBox(height: 8),
            Text(text, style: t.bodyMedium?.copyWith(color: AppColors.textSoft)),
          ]),
        );
    final asides = [
      aside('Votre fiche importée ?',
          'Si vous jouiez déjà avant l’application, le conte importe votre fiche : elle apparaîtra ici dès sa validation.'),
      const SizedBox(height: 20),
      aside('PNJ confiés', 'Le conte peut aussi vous confier un PNJ à interpréter. Vous le verrez dans « PNJ confiés ».'),
    ];
    return PageBody(children: [
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: main)),
          const SizedBox(width: 32),
          SizedBox(width: 380, child: Column(children: asides)),
        ])
      else ...[
        main,
        const SizedBox(height: 28),
        ...asides,
      ],
    ]);
  }
}
