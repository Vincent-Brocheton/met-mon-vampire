import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../characters/transformations.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/trace.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'servant_file.dart';
import 'servant_rules.dart';
import 'servants_repository.dart';
import 'transform_actions.dart';
import 'transform_dialogs.dart';

/// « Goules et mortels » (C-Goules, C-Animaux) : serviteurs des fiches, fiches libérées, mortels.
class ServantsScreen extends ConsumerStatefulWidget {
  const ServantsScreen({super.key});

  @override
  ConsumerState<ServantsScreen> createState() => _ServantsScreenState();
}

class _ServantsScreenState extends ConsumerState<ServantsScreen> {
  /// Ligne ouverte : id, '' pour un nouveau mortel, null pour aucune.
  String? _selectedId;
  int _version = 0;
  String _filter = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(String? id) => setState(() {
        _selectedId = id;
        _version++;
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final rb = ref.watch(rulebookProvider);
    if (me == null || rb == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les serviteurs sont gérés par le conte.');
    }
    return asyncView(
      ref.watch(allServantFilesProvider),
      (files) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, !me.role.managesAccounts, rb, servantRows(chars, files)),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allServantFilesProvider),
    );
  }

  Widget _body(BuildContext context, bool readOnly, Rulebook rb, List<ServantRow> rows) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final r in rows)
        if (switch (_filter) {
              'late' => dueState(r.file?.lastDrink, now) == DueState.late,
              'toComplete' => r.toComplete,
              'mortal' => r.kind == 'mortal',
              _ => true,
            } &&
            (q.isEmpty || r.name.toLowerCase().contains(q) || r.owner.toLowerCase().contains(q)))
          r,
    ];
    final ServantRow? selected = switch (_selectedId) {
      null => null,
      '' => const ServantRow(),
      final id => rows.where((r) => r.id == id).firstOrNull,
    };

    String due(ServantRow r) {
      if (r.toComplete) return 'À compléter';
      if (r.released) return 'Libéré le ${formatDay(r.file!.releasedAt)}';
      final last = r.file?.lastDrink;
      return last == null ? '—' : formatDay(dueDate(last));
    }

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        'Goules et mortels',
        subtitle: 'Serviteurs achetés par les personnages, goules animales, et mortels suivis par le conte.',
        action: readOnly ? null : FilledButton(key: const Key('sv-new-mortal'), onPressed: () => _open(''), child: const Text('+ Nouveau mortel')),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        DropdownButton<String>(
          value: _filter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous')),
            DropdownMenuItem(value: 'late', child: Text('Échéance dépassée')),
            DropdownMenuItem(value: 'toComplete', child: Text('À compléter')),
            DropdownMenuItem(value: 'mortal', child: Text('Mortels')),
          ],
          onChanged: (v) => setState(() => _filter = v ?? 'all'),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('sv-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Nom, domitor…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucune fiche.', style: t.bodyMedium)),
          for (final r in shown)
            InkWell(
              onTap: () => _open(r.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: r.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 200, child: Text(r.name, style: t.titleSmall)),
                  SizedBox(width: 120, child: Text(r.typeLabel, style: t.bodySmall)),
                  SizedBox(width: 200, child: Text(r.owner, style: t.bodySmall)),
                  SizedBox(width: 70, child: Text(r.rank == 0 ? '—' : dots(r.rank), style: const TextStyle(color: AppColors.gold, letterSpacing: 2))),
                  SizedBox(width: 60, child: Text(r.file == null || r.kind == 'mortal' ? '—' : '${r.file!.vitae} / 5', style: t.bodySmall)),
                  Text(due(r), style: t.bodySmall?.copyWith(color: dueState(r.file?.lastDrink, now) == DueState.late ? AppColors.linkHover : null)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(
        'Serviteur de rang N : N spécialités, réserve 2 × N, N niveaux de santé, pas de Volonté. '
        'Goule animale : N points de qualités animales en plus. Sans vitae pendant un mois, son âge le rattrape.',
        style: t.bodySmall,
      ),
    ]);

    Widget? editor;
    if (selected != null) {
      editor = Panel(
        child: _ServantEditor(
          key: ValueKey('${selected.id}/$_version'),
          row: selected,
          rb: rb,
          readOnly: readOnly,
          onSaved: _open,
          onDeleted: () => setState(() => _selectedId = null),
        ),
      );
    }

    if (!isWide(context)) {
      if (editor != null) {
        return PageBody(children: [
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _open(null), child: const Text('← Retour à la liste'))),
          editor,
        ]);
      }
      return PageBody(children: [list]);
    }
    return PageBody(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: list),
        if (editor != null) ...[const SizedBox(width: 24), SizedBox(width: 440, child: editor)],
      ]),
    ]);
  }
}

class _ServantEditor extends ConsumerStatefulWidget {
  const _ServantEditor({
    super.key,
    required this.row,
    required this.rb,
    required this.readOnly,
    required this.onSaved,
    required this.onDeleted,
  });

  final ServantRow row;
  final Rulebook rb;
  final bool readOnly;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ServantEditor> createState() => _ServantEditorState();
}

class _ServantEditorState extends ConsumerState<_ServantEditor> {
  /// Version ouverte : base de l'enregistrement (le flux peut apporter une version plus récente entre-temps).
  late final ServantFile _base;
  late final ServantFile _d;
  late final TextEditingController _name;
  late final TextEditingController _attachment;
  late final TextEditingController _description;
  final _note = TextEditingController();
  final _reason = TextEditingController();
  String _noteBefore = '';
  bool _noteLoaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _base = r.file ?? ServantFile(id: r.id, kind: r.kind);
    _d = _base.copy();
    _name = TextEditingController(text: _d.name);
    _attachment = TextEditingController(text: _d.attachment);
    _description = TextEditingController(text: _d.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _attachment.dispose();
    _description.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// Lance une transformation ; ferme la fiche et affiche le résultat.
  Future<void> _transform(Future<String?> Function(Actor by) action) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final partial = await action(by);
      messenger.showSnackBar(SnackBar(content: Text(partial ?? 'Transformation enregistrée.')));
      widget.onDeleted();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Transformation refusée : rechargez la page.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toServant() async {
    final row = widget.row;
    final entry = row.entry;
    final owner = row.domitor;
    if (entry != null && owner != null) {
      // Déjà sur la fiche du domitor (conversion interrompue) : on termine sans redemander ni débiter.
      await _transform((by) => mortalToServant(ref.read(characterRepositoryProvider), ref.read(servantsRepositoryProvider),
          mortal: _base, domitor: owner, kind: entry.kind, rank: entry.rank, reason: 'Reprise de la conversion', by: by, rb: widget.rb));
      return;
    }
    final r = await showDialog<(Character?, ServantKind, int, String)>(context: context, builder: (_) => ServantOfDialog(name: _base.name));
    final d = r?.$1;
    if (r == null || d == null) return;
    await _transform((by) => mortalToServant(ref.read(characterRepositoryProvider), ref.read(servantsRepositoryProvider),
        mortal: _base, domitor: d, kind: r.$2, rank: r.$3, reason: r.$4, by: by, rb: widget.rb));
  }

  Future<void> _toGhoul() async {
    final r = await showDialog<(AppUser, Character)>(context: context, builder: (_) => GhoulOfDialog(name: _base.name));
    if (r == null) return;
    await _transform((by) => mortalToGhoul(ref.read(characterRepositoryProvider), ref.read(servantsRepositoryProvider),
        mortal: _base, player: r.$1, domitor: r.$2, by: by));
  }

  Future<void> _embrace() async {
    final row = widget.row;
    final choice = await showDialog<EmbraceChoice>(
      context: context,
      builder: (_) => EmbraceDialog(name: row.name, initialSireId: row.domitor?.id, allowPj: true),
    );
    if (choice == null) return;
    final player = choice.player;
    final made = player == null
        ? embracedNpc(row.name, sire: choice.sire, genNumber: choice.genNumber, first: choice.first, rb: widget.rb)
        : embracedDraft(row.name, playerUid: player.uid, playerName: player.displayName, sire: choice.sire, genNumber: choice.genNumber, rb: widget.rb);
    final sheet = made.after;
    if (sheet == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(made.error!)));
      return;
    }
    await _transform((by) => embraceFollower(ref.read(characterRepositoryProvider), ref.read(servantsRepositoryProvider),
        row: row, sheet: sheet, reason: choice.reason, by: by));
  }


  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final r = widget.row;
    final entry = r.entry;
    final domitor = r.domitor;
    if (entry != null && domitor != null) {
      // Nom, type et domitor suivent la fiche du personnage ; l'accès suit son joueur.
      _d
        ..name = entry.name
        ..kind = entry.kind.name
        ..domitorId = domitor.id
        ..domitorName = domitor.name
        ..holderPlayers = [?domitor.playerUid];
    } else if (_d.isMortal) {
      _d
        ..name = _name.text.trim()
        ..attachment = _attachment.text.trim();
    }
    // Libération manquée (échec dans C3, annulation d'achat) : la date est posée ici.
    if (r.released) _d.releasedAt ??= DateTime.now();
    _d.description = _description.text.trim();
    if (_d.name.isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref
          .read(servantsRepositoryProvider)
          .save(_base, _d, by, note: _note.text, noteBefore: _noteBefore, reason: _reason.text);
      messenger.showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      widget.onSaved(id);
    } catch (_) {
      final latest = ref.read(allServantFilesProvider).value?.where((f) => f.id == _base.id).firstOrNull;
      final moved = latest != null && latest.version != _base.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = widget.rb;
    final ro = widget.readOnly;
    final r = widget.row;
    if (_base.version > 0 && !_noteLoaded) {
      final note = ref.watch(servantNoteProvider(_base.id));
      // Sans la note, enregistrer l'effacerait : pas de formulaire tant qu'elle n'est pas lue.
      if (note.hasError) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Note secrète illisible.'),
          TextButton(onPressed: () => ref.invalidate(servantNoteProvider(_base.id)), child: const Text('Réessayer')),
        ]);
      }
      if (!note.hasValue) return const Center(child: CircularProgressIndicator());
      _noteBefore = note.value!;
      _note.text = _noteBefore;
      _noteLoaded = true;
    }
    final mortal = _d.isMortal;
    final animal = _d.kind == 'animal';
    final rank = r.rank;
    final warnings = servantWarnings(_d, rb, entry: r.entry, domitor: r.domitor, now: DateTime.now());
    final specialtyChoices = [for (final s in specialtyOptions(r.domitor, rb)) if (!_d.specialties.contains(s)) s];
    final qualityChoices = [for (final e in rb.offered('animalQualities')) if (!_d.qualities.contains(e.name)) e];
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(r.isNew ? 'Nouveau mortel' : (mortal ? 'Fiche du mortel' : 'Fiche du serviteur')),
      const SizedBox(height: 12),
      if (mortal) ...[
        gap(TextField(key: const Key('sv-name'), controller: _name, enabled: !ro, maxLength: 80, decoration: const InputDecoration(labelText: 'Nom'))),
        gap(TextField(
          key: const Key('sv-attachment'),
          controller: _attachment,
          enabled: !ro,
          decoration: const InputDecoration(labelText: 'Rattachement (lieu, personnage, groupe)'),
        )),
      ] else ...[
        Text(r.name, style: t.headlineSmall),
        Text('${r.typeLabel} · ${rank == 0 ? 'rang inconnu' : 'rang $rank'} · ${r.owner}', style: t.bodyMedium),
        if (rank > 0) Text('Réserve ${pool(rank)} · santé $rank · pas de Volonté', style: t.bodySmall),
        if (r.released) Text('Libéré le ${formatDay(_d.releasedAt)}', style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        const SizedBox(height: 12),
        Text('Spécialités', style: t.labelMedium),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (_d.specialties.isEmpty) Text('Aucune.', style: t.bodySmall),
          for (final s in _d.specialties) InputChip(label: Text(s), onDeleted: ro ? null : () => setState(() => _d.specialties.remove(s))),
        ]),
        const SizedBox(height: 8),
        if (!ro)
          gap(KeyedSubtree(
            key: ValueKey('specialties-${_d.specialties.length}'),
            child: DropdownButtonFormField<String>(
              key: const Key('sv-add-specialty'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: '+ Ajouter une compétence ou une discipline'),
              items: [for (final s in specialtyChoices) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (s) {
                if (s != null) setState(() => _d.specialties.add(s));
              },
            ),
          )),
        if (animal) ...[
          Row(children: [
            Expanded(child: Text('Qualités animales', style: t.labelMedium)),
            Text('${animalPoints(_d.qualities, rb)} points sur $rank', style: t.bodySmall),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in _d.qualities) InputChip(label: Text(q), onDeleted: ro ? null : () => setState(() => _d.qualities.remove(q))),
          ]),
          const SizedBox(height: 8),
          if (!ro)
            gap(KeyedSubtree(
              key: ValueKey('qualities-${_d.qualities.length}'),
              child: DropdownButtonFormField<String>(
                key: const Key('sv-add-quality'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: '+ Ajouter une qualité animale'),
                items: [
                  for (final e in qualityChoices) DropdownMenuItem(value: e.name, child: Text('${e.name} (${rb.cost('animalQualities', e.name) ?? 0})')),
                ],
                onChanged: (q) {
                  if (q != null) setState(() => _d.qualities.add(q));
                },
              ),
            )),
        ],
        gap(Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('sv-vitae'),
              isExpanded: true,
              initialValue: _d.vitae.clamp(0, 5),
              decoration: const InputDecoration(labelText: 'Vitae (sur 5)'),
              items: [for (var v = 0; v <= 5; v++) DropdownMenuItem(value: v, child: Text('$v'))],
              onChanged: ro ? null : (v) => setState(() => _d.vitae = v ?? _d.vitae),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('sv-bond'),
              isExpanded: true,
              initialValue: _d.bond.clamp(0, 3),
              decoration: const InputDecoration(labelText: 'Lien de sang'),
              items: [for (var v = 0; v <= 3; v++) DropdownMenuItem(value: v, child: Text(v == 0 ? 'Aucun' : dots(v)))],
              onChanged: ro ? null : (v) => setState(() => _d.bond = v ?? _d.bond),
            ),
          ),
        ])),
        Row(children: [
          Expanded(
            child: Text(
              _d.lastDrink == null
                  ? 'Aucune gorgée notée'
                  : 'Dernière gorgée : ${formatDay(_d.lastDrink)} · échéance ${formatDay(dueDate(_d.lastDrink!))}',
              style: t.bodyMedium,
            ),
          ),
          if (!ro)
            OutlinedButton(
              key: const Key('sv-drink'),
              onPressed: () => setState(() {
                _d.lastDrink = DateTime.now();
                _d.vitae = (_d.vitae + 1).clamp(0, 5);
              }),
              child: const Text('+ Gorgée'),
            ),
        ]),
        const SizedBox(height: 12),
      ],
      gap(TextField(
        key: const Key('sv-description'),
        controller: _description,
        enabled: !ro,
        maxLines: 3,
        decoration: InputDecoration(labelText: mortal ? 'Description' : 'Description et consignes (lue par le joueur)'),
      )),
      gap(TextField(
        key: const Key('sv-note'),
        controller: _note,
        enabled: !ro,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note secrète du conte'),
      )),
      for (final w in warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      if (!ro) ...[
        const SizedBox(height: 8),
        gap(TextField(key: const Key('sv-reason'), controller: _reason, decoration: const InputDecoration(labelText: 'Motif (facultatif)'))),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(key: const Key('sv-save'), onPressed: _busy ? null : _save, child: const Text('Enregistrer')),
          if (mortal && _base.version > 0)
            TextButton(
              key: const Key('sv-delete'),
              onPressed: _busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (!await confirm(context, title: 'Supprimer « ${_d.name} » ?', body: 'Cette suppression est définitive.', action: 'Supprimer')) return;
                      setState(() => _busy = true);
                      try {
                        await ref.read(servantsRepositoryProvider).delete(_base.id);
                        widget.onDeleted();
                      } catch (_) {
                        messenger.showSnackBar(const SnackBar(content: Text('Suppression refusée : réessayez.')));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Supprimer'),
            ),
          if (mortal && _base.version > 0) ...[
            OutlinedButton(key: const Key('sv-to-servant'), onPressed: _busy ? null : _toServant, child: const Text('Devenir serviteur de…')),
            OutlinedButton(key: const Key('sv-to-ghoul'), onPressed: _busy ? null : _toGhoul, child: const Text('Devenir goule jouée…')),
          ],
          if ((mortal && _base.version > 0) || (r.entry != null && r.entry!.kind != ServantKind.animal))
            OutlinedButton(key: const Key('sv-embrace'), onPressed: _busy ? null : _embrace, child: const Text('Étreindre…')),
        ]),
      ],
      if (_base.version > 0) ...[
        const SizedBox(height: 16),
        const SectionTitle('Historique'),
        const SizedBox(height: 8),
        asyncView(ref.watch(servantHistoryProvider(_base.id)), TraceHistory.new),
      ],
    ]);
  }
}
