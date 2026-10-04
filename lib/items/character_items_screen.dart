import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'item.dart';
import 'item_rules.dart';
import 'items_repository.dart';
import 'items_screen.dart' show itemStateColor;

/// « Équipement » d'un personnage (J-Equipement) : ses objets et la demande d'un nouvel objet.
class CharacterItemsScreen extends ConsumerStatefulWidget {
  const CharacterItemsScreen({super.key, required this.characterId});
  final String characterId;

  @override
  ConsumerState<CharacterItemsScreen> createState() => _CharacterItemsScreenState();
}

class _CharacterItemsScreenState extends ConsumerState<CharacterItemsScreen> {
  final _name = TextEditingController();
  final _origin = TextEditingController();
  Item _draft = Item(state: ItemState.requested, category: ItemCategory.gear);
  bool _tried = false;
  bool _busy = false;

  /// Incrémenté à chaque envoi réussi : les listes déroulantes repartent à vide.
  int _form = 0;

  @override
  void dispose() {
    _name.dispose();
    _origin.dispose();
    super.dispose();
  }

  Item _request(Character c, String uid) => _draft.copy()
    ..name = _name.text.trim()
    ..origin = _origin.text.trim()
    ..characterId = c.id
    ..characterName = c.name
    ..playerUid = uid
    ..state = ItemState.requested;

  Future<void> _send(Character c, Rulebook rb) async {
    final me = ref.read(currentUserProvider).value;
    final by = actorOf(me);
    if (me == null || by == null) return;
    final r = _request(c, me.uid);
    if (itemChecks(r, rb, byPlayer: true).errors.isNotEmpty) {
      setState(() => _tried = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(itemsRepositoryProvider).request(r, by);
      messenger.showSnackBar(const SnackBar(content: Text('Demande envoyée au conte.')));
      if (mounted) {
        setState(() {
          _name.clear();
          _origin.clear();
          _draft = Item(state: ItemState.requested, category: ItemCategory.gear);
          _tried = false;
          _form++;
        });
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Envoi refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Item i) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirm(context, title: 'Supprimer la demande ?', body: '« ${i.name} » sera supprimé.', action: 'Supprimer')) return;
    try {
      await ref.read(itemsRepositoryProvider).deleteRequest(i.id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Suppression refusée : réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = ref.watch(rulebookProvider);
    if (rb == null) return const Center(child: CircularProgressIndicator());
    final character = ref.watch(characterProvider(widget.characterId));
    final c = character.value;
    // Garde la session écoutée : l'envoi la lit.
    ref.watch(currentUserProvider);
    return asyncView(ref.watch(characterItemsProvider(widget.characterId)), (items) {
      final list = Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun objet.', style: t.bodyMedium)),
          for (final i in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 200, child: Text(i.name, style: t.titleSmall)),
                  SizedBox(width: 140, child: Text(i.category.label, style: t.bodySmall)),
                  SizedBox(width: 220, child: Text(itemQualitiesText(i), style: t.bodySmall)),
                  SizedBox(width: 90, child: Text(i.grade.label, style: t.bodySmall)),
                  Text(i.state.label, style: t.bodySmall?.copyWith(color: itemStateColor(i.state), fontWeight: FontWeight.w600)),
                  if (i.state == ItemState.requested || i.state == ItemState.refused)
                    TextButton(key: Key('rq-delete-${i.id}'), onPressed: () => _delete(i), child: const Text('Supprimer')),
                ]),
                if (i.state == ItemState.refused && i.refusal.isNotEmpty) Text('Motif : ${i.refusal}', style: t.bodySmall),
              ]),
            ),
        ]),
      );
      final Widget? form = character.hasError
          ? Text('Fiche illisible : la demande d’objet est indisponible.', style: t.bodyMedium)
          : c == null
              ? (character.isLoading ? const LinearProgressIndicator() : null)
              : c.status == CharacterStatus.active
                  ? _requestForm(context, c, rb)
                  : null;
      final title = PageTitle('Équipement',
          subtitle: c == null ? null : 'Ce que ${c.name} possède. Un nouvel objet est validé par le conte avant d’entrer en jeu.');
      if (!isWide(context)) {
        return PageBody(children: [title, const SizedBox(height: 20), list, if (form != null) ...[const SizedBox(height: 20), form]]);
      }
      return PageBody(children: [
        title,
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: list),
          if (form != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: form)],
        ]),
      ]);
    }, onRetry: () => ref.invalidate(characterItemsProvider(widget.characterId)));
  }

  Widget _requestForm(BuildContext context, Character c, Rulebook rb) {
    final t = Theme.of(context).textTheme;
    final checks = itemChecks(_request(c, ''), rb, byPlayer: true);
    final showErrors = _tried || _name.text.trim().isNotEmpty;
    final slots = categoryRules(rb, _draft.category).max(_draft.grade);
    final options = qualityOptions(rb, _draft.category);
    final help = rulesText(rb, _draft.category);
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Demander un objet'),
        const SizedBox(height: 12),
        gap(TextField(
          key: const Key('rq-name'),
          controller: _name,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Nom'),
          onChanged: (_) => setState(() {}),
        )),
        gap(Row(children: [
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('rq-category/$_form'),
              child: DropdownButtonFormField<ItemCategory>(
                key: const Key('rq-category'),
                isExpanded: true,
                initialValue: _draft.category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [for (final cat in ItemCategory.values) DropdownMenuItem(value: cat, child: Text(cat.label))],
                onChanged: (v) => setState(() {
                  _draft.category = v ?? _draft.category;
                  final keep = qualityOptions(rb, _draft.category);
                  _draft.qualities = [for (final q in _draft.qualities) if (keep.contains(q)) q];
                }),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('rq-grade/$_form'),
              child: DropdownButtonFormField<ItemGrade>(
                key: const Key('rq-grade'),
                isExpanded: true,
                initialValue: _draft.grade,
                decoration: const InputDecoration(labelText: 'Gamme'),
                items: [
                  for (final g in ItemGrade.values)
                    DropdownMenuItem(value: g, child: Text('${g.label} · ${categoryRules(rb, _draft.category).max(g)} qualité(s)')),
                ],
                onChanged: (v) => setState(() => _draft.grade = v ?? _draft.grade),
              ),
            ),
          ),
        ])),
        for (var i = 0; i < slots; i++)
          gap(KeyedSubtree(
            key: ValueKey('rq-q$i/$_form/${_draft.category.name}/${_draft.qualities.join('|')}'),
            child: DropdownButtonFormField<String?>(
              key: Key('rq-q$i'),
              isExpanded: true,
              initialValue: i < _draft.qualities.length ? _draft.qualities[i] : null,
              decoration: InputDecoration(labelText: 'Qualité ${i + 1}'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
                for (final n in options) DropdownMenuItem<String?>(value: n, child: Text(n)),
              ],
              onChanged: (n) => setState(() => _draft.qualities = setQuality(_draft.qualities, i, n)),
            ),
          )),
        gap(TextField(
          key: const Key('rq-origin'),
          controller: _origin,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Comment l’obtient-il ?'),
        )),
        if (help.isNotEmpty) gap(Text(help, style: t.bodySmall)),
        if (showErrors)
          for (final e in checks.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        for (final w in checks.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        const SizedBox(height: 8),
        FilledButton(key: const Key('rq-send'), onPressed: _busy ? null : () => _send(c, rb), child: const Text('Envoyer la demande')),
      ]),
    );
  }
}

/// Section « Équipement » d'une fiche (J2, C3) : objets du personnage et lien.
class ItemsSection extends ConsumerWidget {
  const ItemsSection({super.key, required this.characterId, required this.link});
  final String characterId;
  final String link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(characterItemsProvider(characterId));
    final items = async.value ?? const <Item>[];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Équipement'),
        const SizedBox(height: 8),
        if (async.hasError)
          Text('Équipement indisponible.', style: t.bodySmall)
        else if (!async.hasValue)
          const LinearProgressIndicator()
        else if (items.isEmpty)
          Text('Aucun objet.', style: t.bodySmall),
        for (final i in items) Text('${i.name} · ${itemQualitiesText(i)} · ${i.state.label}', style: t.bodyMedium),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go(link), child: const Text('Voir l’équipement'))),
      ]),
    );
  }
}
