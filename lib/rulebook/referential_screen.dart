import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'base_rules.dart';
import 'csv.dart';
import 'rule_entry.dart';
import 'rule_form.dart';
import 'rules_repository.dart';
import 'schema.dart';
import 'usage.dart';

String _plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

/// Référentiel : catégories, liste, réglages, import / export, édition.
class ReferentialScreen extends ConsumerStatefulWidget {
  const ReferentialScreen({super.key, this.categoryId = 'merits'});
  final String categoryId;

  @override
  ConsumerState<ReferentialScreen> createState() => _ReferentialScreenState();
}

class _ReferentialScreenState extends ConsumerState<ReferentialScreen> {
  /// Élément ouvert : id, '' pour un nouveau, null pour aucun.
  String? _selectedId;

  /// Version de l'élément à l'ouverture du formulaire (conflit entre conteurs).
  RuleEntry? _opened;

  /// Version d'où part le formulaire (peut différer de [_opened] juste après « Marquer Interdit »).
  RuleEntry? _formEntry;

  /// Après un enregistrement : la prochaine version reçue (≠ [_staleAt]) devient la référence du conflit.
  // ponytail: si un autre conteur écrit avant que notre version n'arrive, la sienne sert de référence.
  bool _rearm = false;
  DateTime? _staleAt;
  int _formVersion = 0;

  /// Modifications non enregistrées dans le formulaire ouvert.
  bool _dirty = false;
  bool _loadingBase = false;

  /// Flux de la note de l'élément ouvert, gardé d'une reconstruction à l'autre.
  Stream<String>? _note;
  String? _noteKey;
  RuleState? _stateFilter;
  String? _chip;
  final _search = TextEditingController();

  @override
  void didUpdateWidget(ReferentialScreen old) {
    super.didUpdateWidget(old);
    if (old.categoryId != widget.categoryId) {
      _selectedId = null;
      _opened = null;
      _formEntry = null;
      _rearm = false;
      _dirty = false;
      _stateFilter = null;
      _chip = null;
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(RuleEntry? e) => setState(() {
        _selectedId = e?.id ?? '';
        // Écriture encore en attente (date nulle) : la référence du conflit sera la version confirmée.
        final pending = e != null && e.updatedAt == null;
        _opened = pending ? null : e;
        _rearm = pending;
        _staleAt = null;
        _formEntry = e;
        _dirty = false;
        _noteKey = null;
        _formVersion++;
      });

  Future<bool> _canLeave() async {
    if (!_dirty) return true;
    return confirm(context, title: 'Abandonner les modifications ?', body: 'Les changements de l’élément ouvert ne sont pas enregistrés.', action: 'Abandonner', cancel: 'Continuer l’édition');
  }

  Future<void> _switchTo(RuleEntry? e) async {
    if (await _canLeave() && mounted) _open(e);
  }

  Stream<String> _noteOf(String cat, String id) {
    final key = '$cat/$id';
    if (key != _noteKey) {
      _noteKey = key;
      _note = ref.read(rulesRepositoryProvider).watchNote(cat, id).asBroadcastStream();
    }
    return _note!;
  }

  Actor? get _actor => actorOf(ref.read(currentUserProvider).value);

  Future<void> _save(RuleCategory cat, RuleEntry edited, String note, List<RuleEntry> current, List<Character> chars) async {
    final by = _actor;
    if (by == null) return;
    final opened = _opened;
    final latest = opened == null ? null : current.where((e) => e.id == opened.id).firstOrNull;
    // Date nulle : notre propre écriture n'est pas encore confirmée, ce n'est pas un conflit.
    if (opened != null && latest != null && latest.updatedAt != null && latest.updatedAt != opened.updatedAt) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Modifié par ${latest.updatedByName ?? 'un autre conteur'} à l’instant'),
          content: const Text('Recharger pour voir sa version, ou écraser avec la vôtre ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Recharger')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Écraser')),
          ],
        ),
      );
      if (overwrite == null || !mounted) return;
      if (!overwrite) return _open(latest);
    }
    if (opened != null && nameKey(opened.name) != nameKey(edited.name)) {
      final used = usageCount(cat.id, opened.name, chars) ?? 0;
      if (used > 0) {
        final ok = await confirm(
          context,
          title: 'Renommer « ${opened.name} » ?',
          body: '${_plural(used, 'fiche porte', 'fiches portent')} l’ancien nom ; elles ne sont pas modifiées.',
          action: 'Renommer',
        );
        if (!ok || !mounted) return;
      }
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref.read(rulesRepositoryProvider).save(cat.id, edited, by, note: note);
      if (!mounted) return;
      setState(() {
        _selectedId = id;
        _opened = null;
        _rearm = true;
        _staleAt = current.where((e) => e.id == id).firstOrNull?.updatedAt;
        _dirty = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Enregistré.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement impossible. Réessayez.')));
    }
  }

  Future<void> _delete(RuleCategory cat, RuleEntry e, List<Character> chars) async {
    final by = _actor;
    if (by == null) return;
    final used = usageCount(cat.id, e.name, chars) ?? 0;
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Supprimer « ${e.name} » ?'),
        content: Text(used > 0
            ? 'Utilisé par ${_plural(used, 'fiche', 'fiches')}, qui garderont ce nom. Vous pouvez plutôt le marquer Interdit.'
            : 'Cette suppression est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          if (used > 0) OutlinedButton(onPressed: () => Navigator.pop(d, 'forbid'), child: const Text('Marquer Interdit')),
          FilledButton(onPressed: () => Navigator.pop(d, 'delete'), child: const Text('Supprimer')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(rulesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'forbid') {
        final forbidden = e.copy()..state = RuleState.forbidden;
        await repo.save(cat.id, forbidden, by);
        if (!mounted) return;
        setState(() {
          _formEntry = forbidden;
          _opened = null;
          _rearm = true;
          _staleAt = e.updatedAt;
          _dirty = false;
          _formVersion++;
        });
      } else {
        await repo.delete(cat.id, e.id);
        if (mounted) setState(() => _selectedId = null);
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Opération impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Le référentiel est géré par les conteurs.');
    }
    final cat = categoryById(widget.categoryId);
    if (cat == null) {
      return const EmptyState(kind: EmptyKind.notFound, title: 'Catégorie inconnue', message: 'Choisissez une catégorie dans le menu.');
    }
    return asyncView(
      ref.watch(allRuleEntriesProvider),
      (all) => asyncView(
        ref.watch(allRuleSettingsProvider),
        (settings) => asyncView(
          ref.watch(allCharactersProvider),
          (chars) => _body(context, me, cat, all, settings, chars),
          onRetry: () => ref.invalidate(allCharactersProvider),
        ),
        onRetry: () => ref.invalidate(allRuleSettingsProvider),
      ),
      onRetry: () => ref.invalidate(allRuleEntriesProvider),
    );
  }

  Widget _body(BuildContext context, AppUser me, RuleCategory cat, Map<String, List<RuleEntry>> all,
      Map<String, Map<String, dynamic>> settings, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final readOnly = !me.role.managesAccounts;
    final entries = all[cat.id] ?? const <RuleEntry>[];
    final sectEntries = all['sects'] ?? const <RuleEntry>[];
    final keyOptions = {'sects': [for (final e in sectEntries.isEmpty ? baseEntries('sects') : sectEntries) e.name]};
    final filterField = cat.filter == null ? null : cat.fields.firstWhere((f) => f.key == cat.filter);
    final query = nameKey(_search.text);
    bool chipMatch(RuleEntry e) {
      final v = e.data[cat.filter];
      return _chip == null || v == _chip || (v is List && v.contains(_chip));
    }

    final shown = [
      for (final e in entries)
        if ((_stateFilter == null || e.state == _stateFilter) &&
            chipMatch(e) &&
            (query.isEmpty || nameKey(e.name).contains(query) || nameKey(e.vo ?? '').contains(query)))
          e,
    ];
    final found = _selectedId == null ? null : (_selectedId!.isEmpty ? RuleEntry(name: '', data: newEntryData(cat.id)) : entries.where((e) => e.id == _selectedId).firstOrNull);
    // Supprimé par un autre conteur pendant l'édition : le formulaire reste, enregistrer le recrée.
    final vanished = found == null && (_selectedId?.isNotEmpty ?? false) && _formEntry?.id == _selectedId;
    final selected = vanished ? _formEntry : found;
    if (_rearm && selected != null && selected.updatedAt != null && selected.updatedAt != _staleAt) {
      _opened = selected;
      _rearm = false;
    }

    final menu = Panel(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8), child: SectionTitle('Référentiel')),
        for (final c in ruleCategories)
          InkWell(
            onTap: () async {
              if (await _canLeave() && context.mounted) context.go('/conteur/referentiel/${c.id}');
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: c.id == cat.id ? AppColors.navActive : null,
              child: Row(children: [
                Expanded(child: Text(c.label, style: TextStyle(fontWeight: c.id == cat.id ? FontWeight.w600 : FontWeight.w400))),
                Text('${all[c.id]?.length ?? 0}', style: t.bodySmall),
              ]),
            ),
          ),
      ]),
    );

    final settingsPanel = cat.settings.isEmpty
        ? null
        : _SettingsPanel(
            key: ValueKey('settings-${cat.id}'),
            category: cat,
            values: settings[cat.id] ?? const {},
            readOnly: readOnly,
            onSave: (v) async {
              final by = _actor;
              if (by != null) await ref.read(rulesRepositoryProvider).saveSettings(cat.id, v, by);
            },
          );

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        cat.label,
        subtitle: cat.help,
        action: Wrap(spacing: 10, runSpacing: 10, children: [
          TextButton(
            key: const Key('ref-io'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ImportExportDialog(
                category: cat,
                entries: entries,
                chars: chars,
                readOnly: readOnly,
                onImport: (items) async {
                  final by = _actor;
                  if (by != null) await ref.read(rulesRepositoryProvider).importEntries(cat.id, items, by);
                },
              ),
            ),
            child: Text(readOnly ? 'Exporter' : 'Importer / exporter'),
          ),
          if (!readOnly) FilledButton(key: const Key('ref-new'), onPressed: () => _switchTo(null), child: const Text('Nouvel élément')),
        ]),
      ),
      const SizedBox(height: 16),
      if (settingsPanel != null) ...[settingsPanel, const SizedBox(height: 16)],
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final s in [null, ...RuleState.values])
          ChoiceChip(
            label: Text(s?.label ?? 'Tous'),
            selected: _stateFilter == s,
            selectedColor: AppColors.navActive,
            onSelected: (_) => setState(() => _stateFilter = s),
          ),
        if (filterField != null) ...[
          const SizedBox(width: 12),
          for (final o in [null, ...filterField.options])
            ChoiceChip(
              label: Text(o?.$2 ?? 'Toutes'),
              selected: _chip == o?.$1,
              selectedColor: AppColors.navActive,
              onSelected: (_) => setState(() => _chip = o?.$1),
            ),
        ],
        SizedBox(
          width: 220,
          child: TextField(
            key: const Key('ref-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Rechercher', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aucun élément dans cette catégorie.', style: t.bodyMedium),
                if (!readOnly && baseEntries(cat.id).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('ref-base'),
                    onPressed: _loadingBase
                        ? null
                        : () async {
                            final by = _actor;
                            // Garde aussi un second clic arrivé avant la reconstruction du bouton.
                            if (by == null || _loadingBase) return;
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _loadingBase = true);
                            try {
                              await ref.read(rulesRepositoryProvider).importEntries(cat.id, baseEntries(cat.id), by);
                            } catch (_) {
                              messenger.showSnackBar(const SnackBar(content: Text('Chargement impossible. Réessayez.')));
                            } finally {
                              if (mounted) setState(() => _loadingBase = false);
                            }
                          },
                    child: Text('Charger les valeurs de base (${baseEntries(cat.id).length})'),
                  ),
                ],
              ]),
            )
          else if (shown.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('Aucun élément ne correspond.', style: t.bodyMedium)),
          for (final e in shown)
            InkWell(
              onTap: () => _switchTo(e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: e.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 240,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.name, style: t.titleSmall),
                      if (e.vo != null) Text(e.vo!, style: t.bodySmall),
                    ]),
                  ),
                  for (final key in cat.columns)
                    SizedBox(
                      width: 150,
                      child: Text(displayValue(cat.fields.firstWhere((f) => f.key == key), e.data[key]),
                          style: t.bodySmall, overflow: TextOverflow.ellipsis),
                    ),
                  SizedBox(width: 60, child: Text('${usageCount(cat.id, e.name, chars) ?? '—'}', style: t.bodySmall)),
                  _StatePill(e.state),
                ]),
              ),
            ),
        ]),
      ),
    ]);

    Widget? form;
    if (selected != null) {
      final sel = selected;
      final otherNames = {for (final e in entries) if (e.id != selected.id) nameKey(e.name)};
      Widget formWith(String note) => RuleEntryForm(
            key: ValueKey('${cat.id}/${selected.id}/$_formVersion'),
            category: cat,
            entry: _formEntry ?? selected,
            keyOptions: keyOptions,
            existingNames: otherNames,
            readOnly: readOnly,
            note: note,
            usage: selected.id.isEmpty ? null : usageCount(cat.id, selected.name, chars),
            onSave: (e, n) => _save(cat, e, n, entries, chars),
            onDelete: sel.id.isEmpty ? null : () => _delete(cat, sel, chars),
            onDirty: () => _dirty = true,
          );
      final body = selected.id.isEmpty
          ? formWith('')
          : StreamBuilder<String>(
              key: ValueKey('note-${cat.id}/${selected.id}'),
              stream: _noteOf(cat.id, selected.id),
              builder: (_, snap) => snap.hasData ? formWith(snap.data!) : const Center(child: CircularProgressIndicator()),
            );
      // Même structure avec ou sans avertissement : le flux de la note n'est pas réabonné.
      form = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (vanished) ...[
            Text('Cet élément a été supprimé entre-temps par un autre conteur. Enregistrer le recrée.',
                style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
            const SizedBox(height: 12),
          ],
          body,
        ]),
      );
    }

    if (!isWide(context)) {
      if (form != null) {
        return PageBody(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                if (!await _canLeave() || !mounted) return;
                setState(() {
                  _selectedId = null;
                  _dirty = false;
                });
              },
              child: const Text('← Retour à la liste'),
            ),
          ),
          form,
        ]);
      }
      return PageBody(children: [
        DropdownButtonFormField<String>(
          initialValue: cat.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Catégorie'),
          items: [for (final c in ruleCategories) DropdownMenuItem(value: c.id, child: Text('${c.label} · ${all[c.id]?.length ?? 0}'))],
          onChanged: (id) => context.go('/conteur/referentiel/$id'),
        ),
        const SizedBox(height: 16),
        list,
      ]);
    }
    // Moins de 1280 px : le menu laisse sa place au formulaire, la liste garde une largeur utilisable.
    final threeColumns = MediaQuery.sizeOf(context).width >= 1280;
    return PageBody(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (form == null || threeColumns) ...[SizedBox(width: 240, child: menu), const SizedBox(width: 24)],
        Expanded(child: list),
        if (form != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: form)],
      ]),
    ]);
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill(this.state);
  final RuleState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      RuleState.available => (AppColors.activeBg, AppColors.success),
      RuleState.approval => (AppColors.reviewBg, AppColors.goldLight),
      RuleState.draft => (AppColors.navActive, AppColors.textSecondary),
      RuleState.forbidden => (AppColors.deadBg, AppColors.linkHover),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(state.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Réglages de la catégorie (`rules/{cat}`), repliables.
class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({super.key, required this.category, required this.values, required this.readOnly, required this.onSave});
  final RuleCategory category;
  final Map<String, dynamic> values;
  final bool readOnly;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late Map<String, dynamic> _v = _read();
  int _version = 0;

  Map<String, dynamic> _read() => {
        for (final f in widget.category.settings)
          if (widget.values[f.key] != null) f.key: widget.values[f.key],
      };

  /// Un autre conteur a enregistré : ses valeurs remplacent le panneau.
  @override
  void didUpdateWidget(_SettingsPanel old) {
    super.didUpdateWidget(old);
    if (widget.values['updatedAt'] != old.values['updatedAt']) {
      _v = _read();
      _version++;
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // null : la clé est effacée (le dépôt écrit en fusion).
      await widget.onSave({for (final f in widget.category.settings) f.key: _v[f.key]});
      messenger.showSnackBar(const SnackBar(content: Text('Paramètres enregistrés.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          title: const Text('Paramètres de la catégorie'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final f in widget.category.settings)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RuleFieldEditor(
                  key: ValueKey('rs-${f.key}-$_version'),
                  f,
                  _v[f.key],
                  (x) => setState(() {
                    if (x == null) {
                      _v.remove(f.key);
                    } else {
                      _v[f.key] = x;
                    }
                  }),
                  enabled: !widget.readOnly,
                  keyPrefix: 'rs',
                ),
              ),
            if (!widget.readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(onPressed: _save, child: const Text('Enregistrer les paramètres')),
              ),
          ],
        ),
      );
}

class _ImportExportDialog extends StatefulWidget {
  const _ImportExportDialog({required this.category, required this.entries, required this.chars, required this.readOnly, required this.onImport});
  final RuleCategory category;
  final List<RuleEntry> entries;
  final List<Character> chars;
  final bool readOnly;
  final Future<void> Function(List<RuleEntry>) onImport;

  @override
  State<_ImportExportDialog> createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends State<_ImportExportDialog> {
  final _text = TextEditingController();
  ImportPreview? _preview;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = widget.category;
    final csv = exportCsv(cat, widget.entries);
    final p = _preview;
    final count = p == null ? 0 : p.news.length + p.updates.length;
    return AlertDialog(
      title: Text('${cat.label} — import et export'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const SectionTitle('Exporter'),
            const SizedBox(height: 6),
            Text('${_plural(widget.entries.length, 'élément', 'éléments')}, séparés par « ; » (ouvrable dans un tableur).', style: t.bodySmall),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
              child: SingleChildScrollView(child: SelectableText(csv, style: t.bodySmall)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('export-copy'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: csv));
                  messenger.showSnackBar(const SnackBar(content: Text('Copié.')));
                },
                child: const Text('Copier'),
              ),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: 12),
              const SectionTitle('Importer'),
              const SizedBox(height: 6),
              Text('Collez un CSV (« ; ») ou des cellules de tableur, avec la ligne d’en-tête. Colonnes : ${columnsOf(cat).join(', ')}.',
                  style: t.bodySmall),
              const SizedBox(height: 6),
              TextField(
                key: const Key('import-text'),
                controller: _text,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'name;state;…'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('import-analyse'),
                  onPressed: () => setState(() => _preview = previewImport(cat, widget.entries, _text.text)),
                  child: const Text('Analyser'),
                ),
              ),
              if (p != null) ...[
                Text(
                  '${_plural(p.news.length, 'nouveau', 'nouveaux')}, ${_plural(p.updates.length, 'modifié', 'modifiés')}, '
                  '${_plural(p.errors.length, 'ligne en erreur', 'lignes en erreur')}'
                  '${p.unchanged > 0 ? ', ${_plural(p.unchanged, 'inchangé', 'inchangés')}' : ''}',
                  key: const Key('import-summary'),
                  style: t.titleSmall,
                ),
                for (final u in p.updates)
                  if (usageCount(cat.id, u.name, widget.chars) case final n? when n > 0)
                    Text('Modifié : ${u.name} (utilisé par ${_plural(n, 'fiche', 'fiches')})', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
                for (final w in p.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
                for (final e in p.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
              ],
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        if (!widget.readOnly && p != null && count > 0)
          FilledButton(
            key: const Key('import-go'),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await widget.onImport([...p.news, ...p.updates]);
                      nav.pop();
                    } catch (_) {
                      messenger.showSnackBar(const SnackBar(content: Text('Import impossible. Réessayez.')));
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text('Importer ${_plural(count, 'élément', 'éléments')}'),
          ),
      ],
    );
  }
}
