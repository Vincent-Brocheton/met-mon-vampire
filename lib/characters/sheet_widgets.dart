import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'character.dart';
import 'describe_changes.dart';

/// Lecture refusée par les règles (fiche d'un autre joueur).
bool isDenied(Object error) => error is FirebaseException && error.code == 'permission-denied';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final CharacterStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      CharacterStatus.active => (AppColors.activeBg, AppColors.success),
      CharacterStatus.review => (AppColors.reviewBg, AppColors.goldLight),
      CharacterStatus.dead || CharacterStatus.rejected => (AppColors.deadBg, AppColors.linkHover),
      _ => (AppColors.navActive, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class KindTag extends StatelessWidget {
  const KindTag(this.kind, {super.key});
  final CharacterKind kind;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.fieldBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(kind.label, style: const TextStyle(fontSize: 12, color: AppColors.text)),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(v == null || v.isEmpty ? '—' : v, textAlign: TextAlign.right, style: t.bodyMedium),
        ),
      ]),
    );
  }
}

class DotsRow extends StatelessWidget {
  const DotsRow(this.name, this.level, {super.key, this.note});
  final String name;
  final int level;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final n = note;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: t.bodyMedium),
            if (n != null && n.isNotEmpty) Text(n, style: t.bodySmall),
          ]),
        ),
        Text(dots(level), style: const TextStyle(color: AppColors.gold, letterSpacing: 2, fontSize: 15)),
      ]),
    );
  }
}

String identityLine(Character c) =>
    [c.clan, c.sect, c.genRank?.label].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

String _generation(Character c) =>
    c.genRank == null ? '' : '${c.genRank!.label}${c.genNumber == null ? '' : ' (${c.genNumber}e)'}';

/// Fiche en lecture (J2, aperçu de C4). Sans défilement propre.
class CharacterSheetView extends StatelessWidget {
  const CharacterSheetView(this.c, {super.key});
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Panel(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle(title),
            const SizedBox(height: 10),
            ...children,
          ]),
        );
    Widget empty(String text) => Text(text, style: t.bodySmall);
    List<Trait> sorted(List<Trait> l) => [...l]..sort((a, b) => b.level.compareTo(a.level));

    final identity = section('Identité', [
      InfoRow('Clan', c.clan),
      if ((c.lineage ?? '').isNotEmpty) InfoRow('Lignée', c.lineage),
      InfoRow('Secte', c.sect),
      InfoRow('Génération', _generation(c)),
      InfoRow('Archétype', c.archetype),
      InfoRow('Concept', c.concept),
      InfoRow('Sire', c.sire),
      InfoRow('Titre', c.title),
    ]);
    final derived = section('Traits dérivés', [
      InfoRow('Sang', '${c.blood} · ${c.bloodPerTurn} par tour'),
      InfoRow('Volonté', dots(c.willpower)),
      InfoRow('Humanité', dots(c.humanity)),
      InfoRow('Santé', c.health),
    ]);
    final xp = section('Expérience', [
      InfoRow('XP initiale', '${c.xpInitial}'),
      InfoRow('XP gagnée', '${c.xpEarned}'),
      InfoRow('XP dépensée', '${c.xpSpent}'),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Text('Disponible', style: t.bodyMedium)),
        Text('${c.xpAvailable}', style: t.headlineMedium?.copyWith(color: AppColors.gold)),
      ]),
    ]);
    final attributes = section('Attributs', [
      for (final cat in AttrCategory.values)
        DotsRow(
          cat.label,
          c.attributes[cat]!.value,
          note: c.attributes[cat]!.focus == null ? null : 'Focus : ${c.attributes[cat]!.focus}',
        ),
    ]);
    final skills = section('Compétences', [
      if (c.skills.isEmpty) empty('Aucune compétence.'),
      for (final s in sorted(c.skills)) DotsRow(s.name, s.level, note: s.note),
    ]);
    final backgrounds = section('Historiques', [
      if (c.backgrounds.isEmpty) empty('Aucun historique.'),
      for (final b in sorted(c.backgrounds)) DotsRow(b.name, b.level, note: b.note),
    ]);
    final disciplines = section('Disciplines', [
      if (c.disciplines.isEmpty) empty('Aucune discipline.'),
      for (final d in c.disciplines)
        DotsRow(d.inClan ? d.name : '${d.name} (hors clan)', d.level, note: d.powers.join(' · ')),
    ]);
    final meritsFlaws = section('Atouts et handicaps', [
      Text('Atouts', style: t.labelMedium),
      if (c.merits.isEmpty) empty('Aucun.'),
      for (final m in c.merits) InfoRow(m.name, '${m.level}'),
      const SizedBox(height: 10),
      Text('Handicaps', style: t.labelMedium),
      if (c.flaws.isEmpty) empty('Aucun.'),
      for (final f in c.flaws) InfoRow(f.name, '${f.level}'),
    ]);

    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in items.indexed) ...[if (i > 0) const SizedBox(height: 20), w],
        ]);

    if (!isWide(context)) {
      return column([identity, derived, xp, attributes, skills, backgrounds, disciplines, meritsFlaws]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: column([identity, derived, xp])),
      const SizedBox(width: 20),
      Expanded(flex: 2, child: column([attributes, skills, backgrounds, disciplines, meritsFlaws])),
    ]);
  }
}
