import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_edit_screen.dart' show askReason;
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/theme.dart';
import '../npcs/loan_rules.dart' show parseDay;
import '../rulebook/rulebook.dart';
import 'court_entry.dart';
import 'title_rules.dart';
import 'titles_repository.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Section « Détenteurs » d'un titre dans le référentiel (C-Titres) : retrait, copie publique, attribution.
class TitleHoldersSection extends ConsumerStatefulWidget {
  const TitleHoldersSection({super.key, required this.title, required this.chars, required this.rb, required this.readOnly});

  final String title;
  final List<Character> chars;
  final Rulebook rb;
  final bool readOnly;

  @override
  ConsumerState<TitleHoldersSection> createState() => _TitleHoldersSectionState();
}

class _TitleHoldersSectionState extends ConsumerState<TitleHoldersSection> {
  String? _sheetId;
  final _since = TextEditingController(text: _day(DateTime.now()));
  bool _busy = false;

  @override
  void dispose() {
    _since.dispose();
    super.dispose();
  }

  Future<void> _assign(Character c, String? title, DateTime? since) async {
    final messenger = ScaffoldMessenger.of(context);
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
      return;
    }
    final reason = await askReason(context, describeChanges(c, withTitle(c, title, since)));
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(titlesRepositoryProvider).assign(c, title, since, reason, by, widget.rb);
      messenger.showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      if (mounted && title != null) setState(() => _sheetId = null);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh(Character c) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(titlesRepositoryProvider).refreshCourt(c, widget.rb);
      messenger.showSnackBar(const SnackBar(content: Text('Copie publique mise à jour.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final t = Theme.of(context).textTheme;
    final holders = titleHolders(widget.title, widget.chars);
    final court = {for (final e in ref.watch(courtProvider).value ?? const <CourtEntry>[]) e.characterId: e};
    final courtRead = ref.watch(courtProvider).hasValue;
    final candidates = [
      for (final c in widget.chars)
        if ((c.kind == CharacterKind.pnj || c.status.settled) && c.status == CharacterStatus.active && !holders.contains(c) && (me == null || c.playerUid != me.uid)) c,
    ];
    final picked = candidates.where((c) => c.id == _sheetId).firstOrNull;
    final since = parseDay(_since.text);
    final checks = picked == null ? null : titleChecks(widget.title, picked, widget.chars, widget.rb, since: since);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      Text('Détenteurs', style: t.titleSmall),
      const SizedBox(height: 8),
      if (holders.isEmpty) Text('Vacant', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
      for (final c in holders)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.name, style: t.titleSmall),
            Text(
              [c.kind == CharacterKind.pnj ? 'PNJ' : 'PJ', if ((c.clan ?? '').isNotEmpty) c.clan!, if (c.titleSince != null) sinceText(c.titleSince!)].join(' · '),
              style: t.bodySmall,
            ),
            if (courtRead && courtOutdated(c, court[c.id], widget.rb))
              Text('Copie publique à mettre à jour', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
            if (!widget.readOnly)
              Wrap(spacing: 8, children: [
                if (courtRead && courtOutdated(c, court[c.id], widget.rb))
                  TextButton(key: Key('th-refresh-${c.id}'), onPressed: _busy ? null : () => _refresh(c), child: const Text('Mettre à jour')),
                TextButton(
                  key: Key('th-remove-${c.id}'),
                  onPressed: _busy ? null : () => _assign(c, null, null),
                  child: const Text('Retirer', style: TextStyle(color: AppColors.linkHover)),
                ),
              ]),
          ]),
        ),
      if (!widget.readOnly) ...[
        const SizedBox(height: 8),
        Text('+ Attribuer à une fiche', style: t.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              key: const Key('th-sheet'),
              isExpanded: true,
              initialValue: picked?.id,
              decoration: const InputDecoration(labelText: 'Fiche'),
              items: [for (final c in candidates) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: _busy ? null : (id) => setState(() => _sheetId = id),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextField(
              key: const Key('th-since'),
              controller: _since,
              decoration: const InputDecoration(labelText: 'Depuis (JJ/MM/AAAA)'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        if (checks != null) ...[
          const SizedBox(height: 8),
          for (final e in checks.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
          for (final w in checks.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('th-assign'),
            onPressed: _busy || picked == null || checks!.errors.isNotEmpty ? null : () => _assign(picked, widget.title, since),
            child: const Text('Attribuer'),
          ),
        ),
      ],
    ]);
  }
}
