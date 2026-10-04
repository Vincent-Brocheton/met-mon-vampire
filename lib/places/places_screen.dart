import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'place.dart';
import 'place_rules.dart';
import 'places_repository.dart';

/// « Lieux d'intérêt » (C-Lieux) : liste filtrable, fiche du lieu, historique.
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  /// Lieu ouvert : id, '' pour un nouveau, null pour aucun.
  String? _selectedId;
  int _version = 0;
  PlaceType? _type;
  String _control = 'all';
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
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les lieux sont gérés par le conte.');
    }
    return asyncView(
      ref.watch(allPlacesProvider),
      (places) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _body(context, me, rb, places, chars),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(allPlacesProvider),
    );
  }

  Widget _body(BuildContext context, AppUser me, Rulebook rb, List<Place> places, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final readOnly = !me.role.managesAccounts;
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final p in places)
        if ((_type == null || p.type == _type) &&
            switch (_control) {
              'held' => p.holders.isNotEmpty,
              'free' => p.holders.isEmpty,
              'negative' => negativesText(p, rb).isNotEmpty,
              _ => true,
            } &&
            (q.isEmpty || p.name.toLowerCase().contains(q) || p.holders.any((h) => h.name.toLowerCase().contains(q))))
          p,
    ];
    final selected = _selectedId == null ? null : (_selectedId!.isEmpty ? Place() : places.where((p) => p.id == _selectedId).firstOrNull);

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        'Lieux d’intérêt',
        subtitle: 'Seul le conte crée un lieu, puis l’attribue à un ou plusieurs personnages. Chaque lieu a un type, un rang de 1 à 5 et des qualités.',
        action: readOnly ? null : FilledButton(key: const Key('pl-new'), onPressed: () => _open(''), child: const Text('+ Nouveau lieu')),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        DropdownButton<PlaceType?>(
          value: _type,
          items: [
            const DropdownMenuItem<PlaceType?>(value: null, child: Text('Tous les types')),
            for (final ty in PlaceType.values) DropdownMenuItem<PlaceType?>(value: ty, child: Text(ty.label)),
          ],
          onChanged: (v) => setState(() => _type = v),
        ),
        DropdownButton<String>(
          value: _control,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous')),
            DropdownMenuItem(value: 'held', child: Text('Attribués')),
            DropdownMenuItem(value: 'free', child: Text('Non attribués')),
            DropdownMenuItem(value: 'negative', child: Text('Avec une qualité négative')),
          ],
          onChanged: (v) => setState(() => _control = v ?? 'all'),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('pl-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Nom, personnage…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun lieu.', style: t.bodyMedium)),
          for (final p in shown)
            InkWell(
              onTap: () => _open(p.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: p.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 220, child: Text(p.name, style: t.titleSmall)),
                  SizedBox(width: 90, child: Text(p.type.label, style: t.bodySmall)),
                  SizedBox(width: 80, child: Text(dots(p.rank), style: const TextStyle(color: AppColors.gold, letterSpacing: 2))),
                  SizedBox(
                    width: 220,
                    child: Text(p.holders.isEmpty ? 'Non attribué' : p.holders.map((h) => h.name).join(', '), style: t.bodySmall),
                  ),
                  SizedBox(width: 70, child: Text('${qualityCount(p, rb)} / ${maxQualities(p.type, p.rank)}', style: t.bodySmall)),
                  Text(negativesText(p, rb).isEmpty ? '—' : negativesText(p, rb), style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(
        'Standard : qualités = rang, quête simple. Prestige : rang × 2, quête complexe, contrôle local. '
        'Iconique : rang × 2, qualités iconiques, quête héroïque. Le refuge reste un historique.',
        style: t.bodySmall,
      ),
    ]);

    Widget? editor;
    if (selected != null) {
      editor = Panel(
        child: _PlaceEditor(
          key: ValueKey('${selected.id}/$_version'),
          place: selected,
          places: places,
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

class _PlaceEditor extends ConsumerStatefulWidget {
  const _PlaceEditor({
    super.key,
    required this.place,
    required this.places,
    required this.chars,
    required this.rb,
    required this.readOnly,
    required this.onSaved,
    required this.onDeleted,
  });

  final Place place;
  final List<Place> places;
  final List<Character> chars;
  final Rulebook rb;
  final bool readOnly;
  final ValueChanged<String> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends ConsumerState<_PlaceEditor> {
  /// Version ouverte : base de l'enregistrement (le flux peut apporter une version plus récente entre-temps).
  late final Place _base;
  late final Place _d = widget.place.copy();
  late final _name = TextEditingController(text: _d.name);
  late final _known = TextEditingController(text: _d.known);
  final _note = TextEditingController();
  final _reason = TextEditingController();
  String _noteBefore = '';
  bool _noteLoaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _base = widget.place;
  }

  @override
  void dispose() {
    _name.dispose();
    _known.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// Qualités proposées de la famille, plus celles du lieu qui ne le sont plus (pour les voir et les retirer).
  List<RuleEntry> _family(String f) => [
        for (final e in widget.rb.all('placeQualities'))
          if (e.data['family'] == f && (e.state.offered || _d.qualities.any((q) => q.name == e.name))) e,
      ];

  bool _main(PlaceQuality q) {
    final f = qualityFamily(widget.rb, q.name);
    return f == null || f == 'standard' || f == 'iconic';
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  Future<void> _save({String? reason}) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    _d
      ..name = _name.text.trim()
      ..known = _known.text.trim();
    if (_d.name.isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    _d.holderPlayers = playersOf(_d.holders, widget.chars);
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref
          .read(placesRepositoryProvider)
          .save(_base, _d, by, note: _note.text, noteBefore: _noteBefore, reason: reason ?? _reason.text);
      messenger.showSnackBar(const SnackBar(content: Text('Lieu enregistré.')));
      widget.onSaved(id);
    } catch (_) {
      final latest = widget.places.where((p) => p.id == _base.id).firstOrNull;
      final moved = _base.id.isNotEmpty && latest != null && latest.version != _base.version;
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
    if (_d.id.isNotEmpty && !_noteLoaded) {
      final note = ref.watch(placeNoteProvider(_d.id));
      if (!note.hasValue) return const Center(child: CircularProgressIndicator());
      _noteBefore = note.value!;
      _note.text = _noteBefore;
      _noteLoaded = true;
    }
    final warnings = [
      ...placeWarnings(_d, rb, places: widget.places, characters: widget.chars),
      if (_d.id.isNotEmpty) ...staleAccess(widget.place, widget.chars),
    ];
    final main = [for (final q in _d.qualities) if (_main(q)) q];
    final supernatural = [for (final q in _d.qualities) if (qualityFamily(rb, q.name) == 'supernatural') q.name].firstOrNull;
    final elysium = _d.qualities.any((q) => qualityFamily(rb, q.name) == 'elysium');
    final addable = [
      for (final e in [..._family('standard'), ..._family('iconic')])
        if (!_d.qualities.any((q) => q.name == e.name)) e,
    ];
    final others = [for (final c in widget.chars) if (!_d.holderIds.contains(c.id)) c];
    String charLabel(Character c) => '${c.name} (${c.kind.label}${c.status == CharacterStatus.active ? '' : ' · ${c.status.label}'})';
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_d.id.isEmpty ? 'Nouveau lieu' : 'Fiche du lieu'),
      const SizedBox(height: 12),
      gap(TextField(key: const Key('pl-name'), controller: _name, enabled: !ro, maxLength: 80, decoration: const InputDecoration(labelText: 'Nom'))),
      gap(Row(children: [
        Expanded(
          child: DropdownButtonFormField<PlaceType>(
            key: const Key('pl-type'),
            isExpanded: true,
            initialValue: _d.type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final ty in PlaceType.values) DropdownMenuItem(value: ty, child: Text(ty.label))],
            onChanged: ro ? null : (v) => setState(() => _d.type = v ?? _d.type),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<int>(
            key: const Key('pl-rank'),
            isExpanded: true,
            initialValue: _d.rank,
            decoration: const InputDecoration(labelText: 'Rang'),
            items: [for (var r = 1; r <= 5; r++) DropdownMenuItem(value: r, child: Text('$r'))],
            onChanged: ro ? null : (v) => setState(() => _d.rank = v ?? _d.rank),
          ),
        ),
      ])),
      Text('Attribué à', style: t.labelMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (_d.holders.isEmpty) Text('Personne.', style: t.bodySmall),
        for (final h in _d.holders)
          InputChip(label: Text(h.name), onDeleted: ro ? null : () => setState(() => _d.holders = [..._d.holders]..remove(h))),
      ]),
      const SizedBox(height: 8),
      if (!ro)
        gap(KeyedSubtree(
          key: ValueKey('holders-${_d.holders.length}'),
          child: DropdownButtonFormField<String>(
            key: const Key('pl-add-holder'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: '+ Attribuer à un personnage'),
            items: [for (final c in others) DropdownMenuItem(value: c.id, child: Text(charLabel(c)))],
            onChanged: (id) {
              final c = others.where((x) => x.id == id).firstOrNull;
              if (c != null) setState(() => _d.holders = [..._d.holders, PlaceHolder(c.id, c.name)]);
            },
          ),
        )),
      Row(children: [
        Expanded(child: Text('Qualités', style: t.labelMedium)),
        Text(
          '${main.length} sur ${maxQualities(_d.type, _d.rank)}${_d.type == PlaceType.standard ? '' : ' (rang ${_d.rank} × 2)'}',
          style: t.bodySmall,
        ),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final q in main) InputChip(label: Text(q.name), onDeleted: ro ? null : () => setState(() => _d.qualities.remove(q))),
      ]),
      const SizedBox(height: 8),
      if (!ro)
        gap(KeyedSubtree(
          key: ValueKey('qualities-${main.length}'),
          child: DropdownButtonFormField<String>(
            key: const Key('pl-add-quality'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: '+ Ajouter une qualité'),
            items: [
              for (final e in addable)
                DropdownMenuItem(value: e.name, child: Text(e.data['family'] == 'iconic' ? '${e.name} · iconique' : e.name)),
            ],
            onChanged: (n) {
              if (n != null) setState(() => _d.qualities.add(PlaceQuality(n)));
            },
          ),
        )),
      gap(DropdownButtonFormField<String?>(
        key: const Key('pl-supernatural'),
        initialValue: _family('supernatural').any((e) => e.name == supernatural) ? supernatural : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Qualité surnaturelle'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
          for (final e in _family('supernatural')) DropdownMenuItem<String?>(value: e.name, child: Text(e.name)),
        ],
        onChanged: ro
            ? null
            : (n) => setState(() {
                  _d.qualities.removeWhere((q) => qualityFamily(rb, q.name) == 'supernatural');
                  if (n != null) _d.qualities.add(PlaceQuality(n));
                }),
      )),
      CheckboxListTile(
        key: const Key('pl-elysium'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Élysée (règles spéciales)'),
        value: elysium,
        onChanged: ro
            ? null
            : (on) => setState(() {
                  _d.qualities.removeWhere((q) => qualityFamily(rb, q.name) == 'elysium');
                  if (on == true) _d.qualities.add(PlaceQuality(_family('elysium').firstOrNull?.name ?? 'Élysée'));
                }),
      ),
      if (_family('negative').isNotEmpty) ...[
        Text('Qualités négatives', style: t.labelMedium),
        for (final e in _family('negative'))
          Builder(builder: (_) {
            final q = _d.qualities.where((x) => x.name == e.name).firstOrNull;
            final count = q?.count ?? 0;
            final most = switch (e.data['repeatable']) {
              final num r => r.toInt().clamp(1, 3),
              _ => 1,
            };
            return Row(children: [
              Expanded(child: Text(e.name)),
              IconButton(
                tooltip: 'Retirer : ${e.name}',
                onPressed: ro || q == null
                    ? null
                    : () => setState(() {
                          if (q.count == 1) {
                            _d.qualities.remove(q);
                          } else {
                            q.count--;
                          }
                        }),
                icon: const Icon(Icons.remove, size: 18),
              ),
              SizedBox(width: 30, child: Text('×$count', textAlign: TextAlign.center)),
              IconButton(
                tooltip: 'Ajouter : ${e.name}',
                onPressed: ro || count >= most
                    ? null
                    : () => setState(() {
                          if (q == null) {
                            _d.qualities.add(PlaceQuality(e.name));
                          } else {
                            q.count++;
                          }
                        }),
                icon: const Icon(Icons.add, size: 18),
              ),
            ]);
          }),
      ],
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.navActive, borderRadius: BorderRadius.circular(6)),
        child: Text('${questText(_d.type, _d.rank)} · infiltration en jeu : difficulté ${infiltration(_d.rank)}', style: t.bodyMedium),
      ),
      const SizedBox(height: 12),
      gap(TextField(
        key: const Key('pl-known'),
        controller: _known,
        enabled: !ro,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Ce que savent ceux qui le connaissent'),
      )),
      CheckboxListTile(
        key: const Key('pl-public'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Connu de tous'),
        value: _d.public,
        onChanged: ro ? null : (v) => setState(() => _d.public = v == true),
      ),
      gap(TextField(
        key: const Key('pl-note'),
        controller: _note,
        enabled: !ro,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note secrète du conte'),
      )),
      for (final w in warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
      if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      if (!ro) ...[
        const SizedBox(height: 8),
        gap(TextField(key: const Key('pl-reason'), controller: _reason, decoration: const InputDecoration(labelText: 'Motif (facultatif)'))),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(key: const Key('pl-save'), onPressed: _busy ? null : () => _save(), child: const Text('Enregistrer')),
          if (_d.id.isNotEmpty) ...[
            OutlinedButton(
              key: const Key('pl-clear'),
              onPressed: _busy
                  ? null
                  : () async {
                      if (!await _confirm('Retirer « ${_d.name} » à tous ?', 'Plus aucun personnage ne contrôlera ce lieu.', 'Retirer')) return;
                      setState(() => _d.holders = []);
                      await _save(reason: _reason.text.trim().isEmpty ? 'Retiré à tous' : _reason.text);
                    },
              child: const Text('Retirer à tous'),
            ),
            TextButton(
              key: const Key('pl-delete'),
              onPressed: _busy
                  ? null
                  : () async {
                      if (!await _confirm('Supprimer « ${_d.name} » ?', 'Cette suppression est définitive.', 'Supprimer')) return;
                      await ref.read(placesRepositoryProvider).delete(_d.id);
                      widget.onDeleted();
                    },
              child: const Text('Supprimer'),
            ),
          ],
        ]),
      ],
      if (_d.id.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionTitle('Historique'),
        const SizedBox(height: 8),
        asyncView(ref.watch(placeHistoryProvider(_d.id)), (entries) {
          if (entries.isEmpty) return Text('Aucune entrée.', style: t.bodySmall);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${formatDay(e.at)} · ${e.byName}', style: t.bodySmall),
                  for (final s in e.summary) Text(s, style: t.bodyMedium),
                  if (e.reason.isNotEmpty) Text('Motif : ${e.reason}', style: t.bodySmall),
                ]),
              ),
          ]);
        }),
      ],
    ]);
  }
}
