import 'package:flutter/material.dart';

import '../auth/session.dart';
import 'theme.dart';

export 'dates.dart';

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Le logo goutte des maquettes.
class DropLogo extends StatelessWidget {
  const DropLogo({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(Icons.water_drop_outlined, size: size, color: AppColors.accentIcon);
}

/// Carte des maquettes : fond #1C1618, bordure, rayon 10.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsets padding;

  // Material (et non Container) : les ListTile et effets d'encre s'y dessinent.
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
}

/// Titre de section : petites majuscules espacées.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

/// Champ avec libellé au-dessus, comme dans les maquettes.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.trailing,
    this.onSubmitted,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;
  final VoidCallback? onSubmitted;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
            ?trailing,
          ]),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              validator: validator,
              maxLines: obscure ? 1 : maxLines,
              decoration: InputDecoration(hintText: hint),
              onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            ),
          ),
        ],
      );
}

/// Corps de page défilant, avec les marges des maquettes (Web 56 px, Mobile 20 px).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: isWide(context) ? const EdgeInsets.fromLTRB(56, 32, 56, 48) : const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// Titre de page (serif 44 px en Web, 34 px en Mobile), sous-titre et action à droite.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: isWide(context) ? t.displaySmall : t.headlineMedium),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      ],
    ]);
    if (action == null) return text;
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [text, action!],
    );
  }
}

String initialsOf(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();



Color roleColor(Role role) => switch (role) {
      Role.principal || Role.conteur => AppColors.goldLight,
      Role.narrateur => AppColors.narrator,
      Role.disabled || Role.pending => AppColors.textMuted,
      Role.joueur => AppColors.text,
    };
