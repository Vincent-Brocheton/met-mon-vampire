import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/trace.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'item.dart';
import 'item_rules.dart';
import 'items_repository.dart';

Color itemStateColor(ItemState s) => switch (s) {
      ItemState.active => AppColors.success,
      ItemState.requested => AppColors.goldLight,
      _ => AppColors.linkHover,
    };

/// « Objets en jeu » (C-Objets) : l'équipement de tous les personnages, demandes à valider comprises.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  /// Objet ouvert : id, '' pour un nouveau, null pour aucun.
  String? _selectedId;
  int _version = 0;
  ItemCategory? _category;
  String _state = 'all';
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
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les objets sont gérés par le conte.');
    }
    return asyncView(
      ref.watch(allItemsProvider),
      (items) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, me, rb, items, chars),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allItemsProvider),
    );
  }

  Widget _body(BuildContext context, AppUser me, Rulebook rb, List<Item> items, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final readOnly = !me.role.managesAccounts;
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final i in items)
        if ((_category == null || i.category == _category) &&
            switch (_state) {
              'requested' => i.state == ItemState.requested,
              'active' => i.state == ItemState.active,
              'refused' => i.state == ItemState.refused,
              'gone' => i.state == ItemState.confiscated || i.state == ItemState.destroyed,
              _ => true,
            } &&
            (q.isEmpty || i.name.toLowerCase().contains(q) || i.characterName.toLowerCase().contains(q)))
          i,
    ];
    final selected = _selectedId == null ? null : (_selectedId!.isEmpty ? Item() : items.where((i) => i.id == _selectedId).firstOrNull);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        'Objets en jeu',
        subtitle: 'L’équipement de tous les personnages. Un joueur demande un objet depuis sa fiche ; il n’entre en jeu qu’après validation.',
        action: readOnly ? null : FilledButton(key: const Key('it-new'), onPressed: () => _open(''), child: const Text('+ Nouvel objet')),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        DropdownButton<ItemCategory?>(
          key: const Key('it-cat-filter'),
          value: _category,
          items: [
            const DropdownMenuItem<ItemCategory?>(value: null, child: Text('Toutes les catégories')),
            for (final c in ItemCategory.values) DropdownMenuItem<ItemCategory?>(value: c, child: Text(c.label)),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        DropdownButton<String>(
          key: const Key('it-state-filter'),
          value: _state,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous les états')),
            DropdownMenuItem(value: 'requested', child: Text('Demandes à valider')),
            DropdownMenuItem(value: 'active', child: Text('En jeu')),
            DropdownMenuItem(value: 'refused', child: Text('Refusées')),
            DropdownMenuItem(value: 'gone', child: Text('Confisqués ou détruits')),
          ],
          onChanged: (v) => setState(() => _state = v ?? 'all'),
        ),
        TextButton(onPressed: () => context.go('/conteur/referentiel/equipment'), child: const Text('Qualités d’équipement')),
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('it-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Objet, personnage…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun objet.', style: t.bodyMedium)),
          for (final i in shown)
            InkWell(
              key: Key('it-row-${i.id}'),
              onTap: () => _open(i.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: i.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 200, child: Text(i.name, style: t.titleSmall)),
                  SizedBox(width: 140, child: Text(i.category.label, style: t.bodySmall)),
                  SizedBox(width: 240, child: Text(itemQualitiesText(i), style: t.bodySmall)),
                  SizedBox(width: 180, child: Text(holderText(i), style: t.bodySmall)),
                  Text(i.state.label, style: t.bodySmall?.copyWith(color: itemStateColor(i.state), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
    ]);

    Widget? editor;
    if (selected != null) {
      editor = Panel(
        child: _ItemEditor(
          key: ValueKey('${selected.id}/$_version'),
          item: selected,
          items: items,
          chars: chars,
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

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.items,
    required this.chars,
    required this.rb,
    required this.readOnly,
    required this.onSaved,
    required this.onDeleted,
  });

  final Item item;
  final List<Item> items;
  final List<Character> chars;
  final Rulebook rb;
  final bool readOnly;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  /// Version ouverte : base de l'enregistrement (le flux peut apporter une version plus récente entre-temps).
  late final Item _base;
  late final Item _d = widget.item.copy();
  late final _name = TextEditingController(text: _d.name);
  late final _description = TextEditingController(text: _d.description);
  final _note = TextEditingController();
  final _reason = TextEditingController();
  String _noteBefore = '';
  bool _noteLoaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _base = widget.item;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save({String? reason}) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    _d
      ..name = _name.text.trim()
      ..description = _description.text.trim();
    // Le porteur donne l'accès : son joueur est recopié à chaque enregistrement.
    final holder = widget.chars.where((c) => c.id == _d.characterId).firstOrNull;
    if (_d.characterId.isEmpty) {
      _d
        ..characterName = ''
        ..playerUid = '';
    } else if (holder != null) {
      _d
        ..characterName = holder.name
        ..playerUid = holder.playerUid ?? '';
    }
    if (itemChecks(_d, widget.rb).errors.isNotEmpty) {
      setState(() => _error = 'Corrigez les erreurs avant d’enregistrer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref
          .read(itemsRepositoryProvider)
          .save(_base, _d, by, note: _note.text, noteBefore: _noteBefore, reason: reason ?? _reason.text);
      messenger.showSnackBar(const SnackBar(content: Text('Objet enregistré.')));
      widget.onSaved(id);
    } catch (_) {
      final latest = widget.items.where((i) => i.id == _base.id).firstOrNull;
      final moved = _base.id.isNotEmpty && latest != null && latest.version != _base.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    _d
      ..state = ItemState.active
      ..refusal = '';
    await _save(reason: 'Demande validée');
  }

  Future<void> _refuse() async {
    final field = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Refuser « ${_d.name} » ?'),
        content: TextField(key: const Key('refusal'), controller: field, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif, visible par le joueur')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(key: const Key('refusal-ok'), onPressed: () => Navigator.pop(d, field.text.trim()), child: const Text('Refuser')),
        ],
      ),
    );
    if (text == null || !mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez un motif.')));
      return;
    }
    _d
      ..state = ItemState.refused
      ..refusal = text;
    await _save(reason: 'Demande refusée');
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirm(context, title: 'Supprimer « ${_d.name} » ?', body: 'Cette suppression est définitive.', action: 'Supprimer')) return;
    setState(() => _busy = true);
    try {
      await ref.read(itemsRepositoryProvider).delete(_d.id);
      widget.onDeleted();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Suppression refusée : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = widget.rb;
    final ro = widget.readOnly;
    if (_d.id.isNotEmpty && !_noteLoaded) {
      final note = ref.watch(itemNoteProvider(_d.id));
      // Sans la note, enregistrer l'effacerait : pas de formulaire tant qu'elle n'est pas lue.
      if (note.hasError) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Note secrète illisible.'),
          TextButton(onPressed: () => ref.invalidate(itemNoteProvider(_d.id)), child: const Text('Réessayer')),
        ]);
      }
      if (!note.hasValue) return const Center(child: CircularProgressIndicator());
      _noteBefore = note.value!;
      _note.text = _noteBefore;
      _noteLoaded = true;
    }
    final checks = itemChecks(_d.copy()..name = _name.text, rb);
    final slots = math.max(categoryRules(rb, _d.category).max(_d.grade), _d.qualities.length);
    final options = qualityOptions(rb, _d.category);
    final extras = extraOptions(rb, _d.category);
    final holders = [for (final c in widget.chars) if (c.status == CharacterStatus.active || c.id == _d.characterId) c];
    final help = rulesText(rb, _d.category);
    final pending = _base.id.isNotEmpty && _base.state == ItemState.requested;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    Widget choice(String key, String label, String? value, List<String> names, ValueChanged<String?> onChanged) => KeyedSubtree(
          key: ValueKey('$key/$value/${_d.category.name}'),
          child: DropdownButtonFormField<String?>(
            key: Key(key),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
              for (final n in [...names, if (value != null && !names.contains(value)) value]) DropdownMenuItem<String?>(value: n, child: Text(n)),
            ],
            onChanged: ro ? null : onChanged,
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_d.id.isEmpty ? 'Nouvel objet' : 'Modifier l’objet'),
      const SizedBox(height: 12),
      gap(TextField(
        key: const Key('it-name'),
        controller: _name,
        enabled: !ro,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nom'),
        onChanged: (_) => setState(() {}),
      )),
      gap(Row(children: [
        Expanded(
          child: DropdownButtonFormField<ItemCategory>(
            key: const Key('it-category'),
            isExpanded: true,
            initialValue: _d.category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [for (final c in ItemCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: ro ? null : (v) => setState(() => _d.category = v ?? _d.category),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<ItemGrade>(
            key: const Key('it-grade'),
            isExpanded: true,
            initialValue: _d.grade,
            decoration: const InputDecoration(labelText: 'Gamme'),
            items: [for (final g in ItemGrade.values) DropdownMenuItem(value: g, child: Text(g.label))],
            onChanged: ro ? null : (v) => setState(() => _d.grade = v ?? _d.grade),
          ),
        ),
      ])),
      for (var i = 0; i < slots; i++)
        gap(choice('it-q$i', 'Qualité ${i + 1}', i < _d.qualities.length ? _d.qualities[i] : null, options,
            (n) => setState(() => _d.qualities = setQuality(_d.qualities, i, n)))),
      gap(choice('it-extra', 'Qualité hors limite', _d.extraQuality, extras, (n) => setState(() => _d.extraQuality = n))),
      gap(KeyedSubtree(
        key: ValueKey('holder/${_d.characterId}'),
        child: DropdownButtonFormField<String>(
          key: const Key('it-holder'),
          isExpanded: true,
          initialValue: _d.characterId.isEmpty || holders.any((c) => c.id == _d.characterId) ? _d.characterId : null,
          decoration: const InputDecoration(labelText: 'Porté par'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Personne (réserve du conte)')),
            for (final c in holders) DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: ro ? null : (id) => setState(() => _d.characterId = id ?? ''),
        ),
      )),
      gap(KeyedSubtree(
        key: ValueKey('state/${_d.state.name}'),
        child: DropdownButtonFormField<ItemState>(
          key: const Key('it-state'),
          isExpanded: true,
          initialValue: _d.state,
          decoration: const InputDecoration(labelText: 'État'),
          items: [for (final s in ItemState.values) DropdownMenuItem(value: s, child: Text(s.label))],
          onChanged: ro ? null : (v) => setState(() => _d.state = v ?? _d.state),
        ),
      )),
      if (_d.origin.isNotEmpty) gap(Text('Comment l’obtient-il ? ${_d.origin}', style: t.bodyMedium)),
      if (_d.state == ItemState.refused && _d.refusal.isNotEmpty) gap(Text('Motif du refus : ${_d.refusal}', style: t.bodyMedium)),
      gap(TextField(
        key: const Key('it-description'),
        controller: _description,
        enabled: !ro,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Description'),
      )),
      gap(TextField(
        key: const Key('it-note'),
        controller: _note,
        enabled: !ro,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Note secrète du conte'),
      )),
      if (help.isNotEmpty)
        gap(Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.navActive, borderRadius: BorderRadius.circular(6)),
          child: Text(help, style: t.bodyMedium),
        )),
      for (final e in checks.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      for (final w in checks.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      if (!ro) ...[
        const SizedBox(height: 8),
        gap(TextField(key: const Key('it-reason'), controller: _reason, decoration: const InputDecoration(labelText: 'Motif (facultatif)'))),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(key: const Key('it-save'), onPressed: _busy ? null : () => _save(), child: const Text('Enregistrer')),
          if (pending) ...[
            FilledButton(key: const Key('it-validate'), onPressed: _busy ? null : _validate, child: const Text('Valider')),
            OutlinedButton(key: const Key('it-refuse'), onPressed: _busy ? null : _refuse, child: const Text('Refuser…')),
          ],
          if (_d.id.isNotEmpty) TextButton(key: const Key('it-delete'), onPressed: _busy ? null : _delete, child: const Text('Supprimer')),
        ]),
      ],
      if (_d.id.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionTitle('Historique'),
        const SizedBox(height: 8),
        asyncView(ref.watch(itemHistoryProvider(_d.id)), TraceHistory.new),
      ],
    ]);
  }
}
