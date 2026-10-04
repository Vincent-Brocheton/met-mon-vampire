import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'character.dart';
import 'character_filter.dart';
import 'character_repository.dart';
import 'sheet_widgets.dart';

/// C2 : toutes les fiches, filtres, nouvelle fiche.
class CharactersListScreen extends ConsumerStatefulWidget {
  const CharactersListScreen({super.key});

  @override
  ConsumerState<CharactersListScreen> createState() => _CharactersListScreenState();
}

class _CharactersListScreenState extends ConsumerState<CharactersListScreen> {
  CharacterFilter _filter = const CharacterFilter();

  Future<void> _newCharacter() async {
    final result = await showDialog<(String, CharacterKind, String)>(
      context: context,
      builder: (_) => const NewCharacterDialog(),
    );
    if (result == null || !mounted) return;
    final (id, kind, name) = result;
    if (kind == CharacterKind.pnj) {
      context.go('/conteur/fiches/$id');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amorce créée : $name attend que son joueur remplisse la fiche.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final canCreate = ref.watch(currentUserProvider).value?.role.managesAccounts ?? false;
    final rb = ref.watch(rulebookProvider) ?? const Rulebook();
    final sects = [for (final e in rb.all('sects')) e.name];
    final clans = [for (final e in rb.all('clans')) e.name];
    return asyncView(ref.watch(allCharactersProvider), (all) {
      final shown = filterCharacters(all, _filter);
      final activePj = all.where((c) => c.kind == CharacterKind.pj && c.status == CharacterStatus.active).length;
      final pnj = all.where((c) => c.kind == CharacterKind.pnj).length;
      final filters = _Filters(sects: sects, clans: clans, filter: _filter, onChanged: (f) => setState(() => _filter = f));
      final results = shown.isEmpty
          ? const EmptyState(kind: EmptyKind.noResult, title: 'Aucune fiche', message: 'Aucune fiche ne correspond à ces filtres.')
          : Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [for (final (i, c) in shown.indexed) _Row(c, first: i == 0)]),
            );
      return PageBody(children: [
        PageTitle(
          'Toutes les fiches',
          subtitle: '${all.length} fiches · $activePj PJ actifs · $pnj PNJ',
          action: Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton(onPressed: () => context.go('/conteur/lieux'), child: const Text('Lieux d’intérêt')),
            OutlinedButton(onPressed: () => context.go('/conteur/goules'), child: const Text('Goules et mortels')),
            if (canCreate)
              FilledButton.icon(onPressed: _newCharacter, icon: const Icon(Icons.add, size: 18), label: const Text('Nouvelle fiche')),
          ]),
        ),
        const SizedBox(height: 22),
        if (isWide(context))
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 260, child: filters),
            const SizedBox(width: 24),
            Expanded(child: results),
          ])
        else ...[
          TextField(
            decoration: const InputDecoration(hintText: 'Nom, joueur…', prefixIcon: Icon(Icons.search)),
            onChanged: (q) => setState(() => _filter = _filter.copyWith(query: q)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppColors.card,
                isScrollControlled: true,
                builder: (_) => StatefulBuilder(
                  builder: (context, setSheet) => SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _Filters(
                      sects: sects,
                      clans: clans,
                      filter: _filter,
                      showSearch: false,
                      onChanged: (f) {
                        setState(() => _filter = f);
                        setSheet(() {});
                      },
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
              label: Text('Filtres', style: t.labelMedium),
            ),
          ),
          const SizedBox(height: 8),
          results,
        ],
      ]);
    }, onRetry: () => ref.invalidate(allCharactersProvider));
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.sects, required this.clans, required this.filter, required this.onChanged, this.showSearch = true});
  final List<String> sects;
  final List<String> clans;
  final CharacterFilter filter;
  final ValueChanged<CharacterFilter> onChanged;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    Widget check(String label, bool value, ValueChanged<bool> on) => CheckboxListTile(
          value: value,
          onChanged: (v) => on(v ?? false),
          title: Text(label, style: const TextStyle(fontSize: 15)),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );
    Set<T> toggle<T>(Set<T> s, T v, bool on) => on ? {...s, v} : ({...s}..remove(v));
    Widget select(String label, String? value, List<String> options, ValueChanged<String?> on) =>
        DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Tous')),
            for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
          ],
          onChanged: on,
        );
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showSearch) ...[
          TextField(
            decoration: const InputDecoration(hintText: 'Nom, joueur…', prefixIcon: Icon(Icons.search)),
            onChanged: (q) => onChanged(filter.copyWith(query: q)),
          ),
          const SizedBox(height: 16),
        ],
        const SectionTitle('Type'),
        for (final k in CharacterKind.values)
          check(k.label, filter.kinds.contains(k), (on) => onChanged(filter.copyWith(kinds: toggle(filter.kinds, k, on)))),
        const SizedBox(height: 10),
        const SectionTitle('Statut'),
        for (final s in CharacterStatus.values)
          check(s.label, filter.statuses.contains(s), (on) => onChanged(filter.copyWith(statuses: toggle(filter.statuses, s, on)))),
        const SizedBox(height: 14),
        select('Secte', filter.sect, sects, (v) => onChanged(filter.copyWith(sect: v))),
        const SizedBox(height: 14),
        select('Clan', filter.clan, clans, (v) => onChanged(filter.copyWith(clan: v))),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: () => onChanged(const CharacterFilter()), child: const Text('Réinitialiser les filtres')),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.c, {required this.first});
  final Character c;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final player = c.kind == CharacterKind.pnj ? 'PNJ' : (c.playerName ?? '—');
    return InkWell(
      onTap: () => context.go('/conteur/fiches/${c.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.border))),
        child: isWide(context)
            ? Row(children: [
                Expanded(flex: 3, child: Text(c.name, style: t.titleMedium?.copyWith(fontSize: 15))),
                Expanded(flex: 3, child: Text(identityLine(c), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text(player, style: t.bodyMedium)),
                SizedBox(width: 50, child: Text('${c.xpAvailable}', textAlign: TextAlign.right, style: t.bodyMedium)),
                const SizedBox(width: 20),
                SizedBox(width: 130, child: Align(alignment: Alignment.centerLeft, child: StatusChip(c.status))),
                SizedBox(width: 80, child: Text(formatDay(c.updatedAt), style: t.bodySmall)),
              ])
            : Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: t.titleMedium?.copyWith(fontSize: 15)),
                    Text('${identityLine(c)} · $player', style: t.bodySmall),
                  ]),
                ),
                StatusChip(c.status),
              ]),
      ),
    );
  }
}

/// Nouvelle fiche : amorce de PJ (le joueur la remplira) ou PNJ (rempli par le conte).
/// Renvoie (id, type, nom).
class NewCharacterDialog extends ConsumerStatefulWidget {
  const NewCharacterDialog({super.key});

  @override
  ConsumerState<NewCharacterDialog> createState() => _NewCharacterDialogState();
}

class _NewCharacterDialogState extends ConsumerState<NewCharacterDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  CharacterKind _kind = CharacterKind.pj;
  AppUser? _player;
  bool _ghoul = false;
  Character? _domitor;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !_form.currentState!.validate()) return;
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(characterRepositoryProvider).create(
            name: _name.text,
            kind: _kind,
            playerUid: _player?.uid,
            playerName: _player?.displayName,
            ghoul: _ghoul && _domitor != null ? GhoulState.of(_domitor!) : null,
            by: by,
          );
      if (mounted) Navigator.pop(context, (id, _kind, _name.text.trim()));
    } catch (_) {
      if (mounted) setState(() => _error = 'Création impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(allUsersProvider).value ?? const <AppUser>[];
    final players = users
        .where((u) => u.uid != me?.uid && u.role != Role.pending && u.role != Role.disabled)
        .toList();
    return AlertDialog(
      title: const Text('Nouvelle fiche'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pj', label: Text('PJ')),
                ButtonSegment(value: 'ghoul', label: Text('Goule')),
                ButtonSegment(value: 'pnj', label: Text('PNJ')),
              ],
              selected: {_ghoul ? 'ghoul' : _kind.name},
              onSelectionChanged: (s) => setState(() {
                _ghoul = s.first == 'ghoul';
                _kind = s.first == 'pnj' ? CharacterKind.pnj : CharacterKind.pj;
              }),
            ),
            const SizedBox(height: 10),
            Text(
              _ghoul
                  ? 'Une goule jouée : choisissez son joueur et son domitor. Le joueur remplira sa fiche par la création guidée.'
                  : _kind == CharacterKind.pj
                  ? 'Vous créez l’amorce : le joueur remplira sa fiche par la création guidée, puis la soumettra au conte.'
                  : 'Le PNJ est actif tout de suite ; vous le remplissez ensuite.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom du personnage'),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Indiquez un nom.';
                if (s.length > 80) return '80 caractères maximum.';
                return null;
              },
            ),
            if (_kind == CharacterKind.pj) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<AppUser>(
                key: const Key('new-player'),
                initialValue: _player,
                decoration: const InputDecoration(labelText: 'Joueur'),
                items: [for (final u in players) DropdownMenuItem(value: u, child: Text(u.displayName))],
                onChanged: (u) => setState(() => _player = u),
                validator: (u) => u == null ? 'Choisissez le joueur.' : null,
              ),
              if (_ghoul) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<Character>(
                  key: const Key('new-domitor'),
                  initialValue: _domitor,
                  decoration: const InputDecoration(labelText: 'Domitor'),
                  items: [
                    for (final c in ref.watch(allCharactersProvider).value ?? const <Character>[])
                      if (c.ghoul == null && c.status == CharacterStatus.active) DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (c) => setState(() => _domitor = c),
                  validator: (c) => c == null ? 'Choisissez le domitor.' : null,
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _busy ? null : _create, child: const Text('Créer')),
      ],
    );
  }
}
