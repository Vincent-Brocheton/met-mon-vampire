import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show CharacterHeader, CharacterTab;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'event_rules.dart';
import 'event_timeline.dart';
import 'events_repository.dart';
import 'story_event.dart';

/// Onglet « Événements » de la fiche, côté équipe (C-Evenements). Le conte ajoute, modifie et supprime.
class CharacterEventsScreen extends ConsumerStatefulWidget {
  const CharacterEventsScreen({super.key, required this.characterId});
  final String characterId;

  @override
  ConsumerState<CharacterEventsScreen> createState() => _CharacterEventsScreenState();
}

class _CharacterEventsScreenState extends ConsumerState<CharacterEventsScreen> {
  EventVisibility? _vis;
  EventType? _type;

  /// Événement ouvert dans le formulaire (identifiant vide : nouveau), ou null.
  StoryEvent? _open;

  /// Incrémenté à chaque formulaire ouvert ou fermé : les champs repartent de zéro.
  int _form = 0;

  void _edit(StoryEvent? e) => setState(() {
        _open = e?.copy() ?? StoryEvent.blank(DateTime.now());
        _form++;
      });

  void _close() => setState(() {
        _open = null;
        _form++;
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    return asyncView(ref.watch(characterProvider(widget.characterId)), (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      final canEdit = me != null && me.role.managesAccounts && c.playerUid != me.uid;
      return asyncView(
        ref.watch(characterEventsProvider(widget.characterId)),
        (events) => _body(context, c, events, canEdit),
        onRetry: () => ref.invalidate(characterEventsProvider(widget.characterId)),
      );
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }

  Widget _body(BuildContext context, Character c, List<StoryEvent> events, bool canEdit) {
    final wide = isWide(context);
    // Sur sa propre fiche, le conte ne voit pas « conte seul » (comme le joueur).
    final uid = ref.read(currentUserProvider).value?.uid;
    final own = uid != null && uid == c.playerUid;
    final shown = [
      for (final e in events)
        if ((_vis == null || e.visibility == _vis) && (_type == null || e.type == _type)) e,
    ];
    Widget chip(EventVisibility? v, String label) => ChoiceChip(
          key: Key('ev-filter-${v?.name ?? 'all'}'),
          label: Text(label),
          selected: _vis == v,
          onSelected: (_) => setState(() => _vis = v),
        );
    final filters = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      chip(null, 'Tous'),
      for (final v in EventVisibility.values)
        if (!own || v != EventVisibility.staff) chip(v, visibilityLabel(v, staff: !own)),
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<EventType?>(
          key: const Key('ev-type-filter'),
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            const DropdownMenuItem<EventType?>(value: null, child: Text('Tous les types')),
            for (final t in EventType.values) DropdownMenuItem<EventType?>(value: t, child: Text(t.label)),
          ],
          onChanged: (v) => setState(() => _type = v),
        ),
      ),
      if (canEdit && !wide) FilledButton(key: const Key('ev-add'), onPressed: () => _edit(null), child: const Text('+ Ajouter un événement')),
    ]);
    final timeline = Panel(
      padding: EdgeInsets.zero,
      child: EventTimeline(events: shown, staff: !own, selectedId: _open?.id, onTap: canEdit ? _edit : null),
    );
    // En Web, le formulaire d'ajout reste ouvert à droite ; en mobile, il s'ouvre en pleine page.
    final editing = _open ?? (canEdit && wide ? StoryEvent.blank(DateTime.now()) : null);
    final form = editing == null
        ? null
        : Panel(child: EventForm(key: ValueKey('ev-form-$_form'), characterId: c.id, initial: editing, onDone: _close));
    final header = CharacterHeader(c, basePath: '/conteur/fiches/${c.id}', tab: CharacterTab.events);

    if (!wide) {
      if (form != null) {
        return PageBody(children: [
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _close, child: const Text('← Retour'))),
          form,
        ]);
      }
      return PageBody(children: [header, const SizedBox(height: 22), filters, const SizedBox(height: 16), timeline]);
    }
    return PageBody(children: [
      header,
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [filters, const SizedBox(height: 16), timeline])),
        if (form != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: form)],
      ]),
    ]);
  }
}

/// Formulaire d'un événement : ajout ([initial] sans identifiant) ou modification, avec suppression.
class EventForm extends ConsumerStatefulWidget {
  const EventForm({super.key, required this.characterId, required this.initial, required this.onDone});
  final String characterId;
  final StoryEvent initial;
  final VoidCallback onDone;

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  late final StoryEvent _e = widget.initial.copy();
  late final _year = TextEditingController(text: '${_e.year}');
  late final _title = TextEditingController(text: _e.title);
  late final _desc = TextEditingController(text: _e.description);
  bool _busy = false;

  bool get _isNew => _e.id.isEmpty;

  @override
  void dispose() {
    _year.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _read() => _e
    ..year = int.tryParse(_year.text.trim()) ?? 0
    ..title = _title.text.trim()
    ..description = _desc.text.trim();

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    _read();
    if (by == null || eventChecks(_e).isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepositoryProvider).save(widget.characterId, _e, by);
      messenger.showSnackBar(SnackBar(content: Text(_isNew ? 'Événement ajouté.' : 'Événement enregistré.')));
      widget.onDone();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l’événement ?'),
        content: Text('« ${_e.title} » sera retiré de la chronologie.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(key: const Key('ev-delete-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepositoryProvider).delete(widget.characterId, _e.id);
      messenger.showSnackBar(const SnackBar(content: Text('Événement supprimé.')));
      widget.onDone();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    _read();
    final errors = eventChecks(_e);
    void touch(String _) => setState(() {});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_isNew ? 'Ajouter un événement' : 'Modifier l’événement'),
      const SizedBox(height: 12),
      DropdownButtonFormField<EventType>(
        key: const Key('ev-type'),
        initialValue: _e.type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Type'),
        items: [for (final ty in EventType.values) DropdownMenuItem(value: ty, child: Text(ty.label))],
        onChanged: (v) => setState(() => _e.type = v ?? _e.type),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            key: const Key('ev-year'),
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Année'),
            onChanged: touch,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: const Key('ev-month'),
            initialValue: _e.month,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mois'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('—')),
              for (var m = 1; m <= 12; m++) DropdownMenuItem<int?>(value: m, child: Text(monthAbbr(m))),
            ],
            onChanged: (v) => setState(() {
              _e.month = v;
              if (v == null) _e.day = null;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          // Recréé quand le mois change : sans mois, le jour est vidé et fermé.
          child: KeyedSubtree(
            key: ValueKey('ev-day-${_e.month}'),
            child: DropdownButtonFormField<int?>(
              key: const Key('ev-day'),
              initialValue: _e.day,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Jour'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                for (var d = 1; d <= 31; d++) DropdownMenuItem<int?>(value: d, child: Text('$d')),
              ],
              onChanged: _e.month == null ? null : (v) => setState(() => _e.day = v),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextField(
        key: const Key('ev-title'),
        controller: _title,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Titre'),
        onChanged: touch,
      ),
      TextField(
        key: const Key('ev-desc'),
        controller: _desc,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Ce qui s’est passé'),
        onChanged: touch,
      ),
      const SizedBox(height: 12),
      Text('Qui le voit', style: t.labelMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in EventVisibility.values)
          ChoiceChip(
            key: Key('ev-vis-${v.name}'),
            label: Text(visibilityLabel(v, staff: true)),
            selected: _e.visibility == v,
            onSelected: (_) => setState(() => _e.visibility = v),
          ),
      ]),
      const SizedBox(height: 8),
      for (final err in errors) Text(err, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton(
          key: const Key('ev-save'),
          onPressed: _busy || errors.isNotEmpty ? null : _save,
          child: Text(_isNew ? 'Ajouter l’événement' : 'Enregistrer'),
        ),
        if (!_isNew) ...[
          TextButton(
            key: const Key('ev-delete'),
            onPressed: _busy ? null : _delete,
            child: const Text('Supprimer', style: TextStyle(color: AppColors.linkHover)),
          ),
          TextButton(onPressed: widget.onDone, child: const Text('Annuler')),
        ],
      ]),
    ]);
  }
}
