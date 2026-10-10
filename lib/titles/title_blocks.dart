import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_edit_screen.dart' show askReason;
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show parseDay;
import '../offline/offline.dart';
import '../rulebook/rule_entry.dart' show nameKey;
import '../rulebook/rulebook.dart';
import 'title_rules.dart';
import 'titles_repository.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _current(Character c) {
  final t = c.title?.trim() ?? '';
  if (t.isEmpty) return 'Aucun titre.';
  return c.titleSince == null ? t : '$t · ${sinceText(c.titleSince!)}';
}

/// Bloc « Titre » du conte (C-Moralite) : choix dans le référentiel, date, contrôles, motif.
class StaffTitle extends ConsumerStatefulWidget {
  const StaffTitle({super.key, required this.character, required this.rb, required this.canEdit});

  final Character character;
  final Rulebook rb;
  final bool canEdit;

  @override
  ConsumerState<StaffTitle> createState() => _StaffTitleState();
}

class _StaffTitleState extends ConsumerState<StaffTitle> {
  late String? _title = _trimmed(widget.character.title);
  late final _since = TextEditingController(text: _day(widget.character.titleSince ?? DateTime.now()));
  bool _busy = false;
  bool _sinceEdited = false;

  static String? _trimmed(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  Character get c => widget.character;

  @override
  void dispose() {
    _since.dispose();
    super.dispose();
  }

  bool get _changed {
    final now = _trimmed(_title);
    if (nameKey(now ?? '') != nameKey(_trimmed(c.title) ?? '')) return true;
    return now != null && _sinceEdited && parseDay(_since.text) != c.titleSince;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
      return;
    }
    final since = parseDay(_since.text);
    final changes = describeChanges(c, withTitle(c, _title, since));
    if (changes.isEmpty) return;
    final reason = await askReason(context, changes);
    if (reason == null || !mounted) return;
    // Données relues après le dialogue : un autre conte a pu prendre le titre entre-temps.
    final fresh = ref.read(allCharactersProvider).value;
    if (_title != null && fresh != null) {
      final errs = titleChecks(_title, c, fresh, widget.rb, since: since).errors;
      if (errs.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(errs.first)));
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ref.read(titlesRepositoryProvider).assign(c, _title, since, reason, by, widget.rb);
      messenger.showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
    } catch (e) {
      if (!mounted) return;
      final latest = ref.read(characterProvider(c.id)).value;
      final moved = latest != null && latest.version != c.version;
      messenger.showSnackBar(SnackBar(content: Text(refusalText(e, moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserProvider); // garde le flux de l'acteur abonné pour _save
    final t = Theme.of(context).textTheme;
    final rb = widget.rb;
    // Une fiche en création ou en validation se modifie dans le parcours de création, pas ici.
    final ro = !widget.canEdit || !(c.kind == CharacterKind.pnj || c.status.settled);
    final current = _trimmed(c.title);
    final options = titleOptions(rb);
    final outside = current != null && !options.any((o) => nameKey(o) == nameKey(current));
    final links = Wrap(spacing: 8, runSpacing: 4, children: [
      TextButton(key: const Key('ti-manage'), onPressed: () => context.go('/conteur/referentiel/titles'), child: const Text('Gérer la liste des titres')),
      TextButton(key: const Key('ti-court'), onPressed: () => context.go('/conteur/cour'), child: const Text('Voir la Cour')),
    ]);
    Widget panel(List<Widget> children) => Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionTitle('Titre'), const SizedBox(height: 8), ...children]),
        );

    if (ro) {
      return panel([
        Text(_current(c), style: t.bodyMedium),
        if (outside) Text('$current : hors liste', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        links,
      ]);
    }
    final all = ref.watch(allCharactersProvider);
    if (!all.hasValue) {
      return panel([asyncView(all, (_) => const SizedBox.shrink(), onRetry: () => ref.invalidate(allCharactersProvider))]);
    }
    final checks = titleChecks(_title, c, all.requireValue, rb, since: parseDay(_since.text));
    final items = [null, ...options, if (outside) current];
    return panel([
      if (outside) Text('$current : hors liste', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String?>(
            key: const Key('ti-title'),
            isExpanded: true,
            initialValue: items.contains(_title) ? _title : null,
            decoration: const InputDecoration(labelText: 'Titre'),
            items: [for (final o in items) DropdownMenuItem<String?>(value: o, child: Text(o ?? 'Aucun'))],
            onChanged: _busy ? null : (v) => setState(() {
              _title = v;
              _sinceEdited = false;
              _since.text = _day(nameKey(v ?? '') == nameKey(_trimmed(c.title) ?? '') ? c.titleSince ?? DateTime.now() : DateTime.now());
            }),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            key: const Key('ti-since'),
            controller: _since,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Depuis (JJ/MM/AAAA)'),
            onChanged: (_) => setState(() => _sinceEdited = true),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      for (final e in checks.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      for (final w in checks.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton(
          key: const Key('ti-save'),
          onPressed: _busy || !_changed || checks.errors.isNotEmpty ? null : _save,
          child: const Text('Enregistrer'),
        ),
        links,
      ]),
    ]);
  }
}

/// Bloc « Titre » du joueur (J-Moralite) : son titre s'il est affiché sur la fiche, et le lien vers la Cour.
class PlayerTitle extends StatelessWidget {
  const PlayerTitle({super.key, required this.character, required this.rb, required this.basePath});

  final Character character;
  final Rulebook rb;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = titleInfo(rb, character.title);
    final hidden = info != null && !info.onSheet;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Titre'),
        const SizedBox(height: 8),
        Text(hidden ? 'Aucun titre.' : _current(character), style: t.bodyMedium),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(key: const Key('ti-court'), onPressed: () => context.go(basePath.startsWith('/conteur') ? '/conteur/cour' : '/joueur/cour'), child: const Text('La Cour')),
        ),
      ]),
    );
  }
}
