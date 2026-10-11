import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import 'wiki_markdown.dart';
import 'wiki_page.dart';
import 'wiki_repository.dart';
import 'wiki_rules.dart';
import 'wiki_view.dart';

/// Identifiant de route d'une nouvelle page libre.
const newPageId = 'nouvelle';

/// Édition d'une page (C-WikiEdit) : texte et aperçu, visibilité ; brouillon à part, publication en un lot.
class WikiEditScreen extends ConsumerStatefulWidget {
  const WikiEditScreen({super.key, required this.pageId});
  final String pageId;

  @override
  ConsumerState<WikiEditScreen> createState() => _WikiEditScreenState();
}

class _WikiEditScreenState extends ConsumerState<WikiEditScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _source = TextEditingController();
  var _audience = audienceAll;
  var _rubric = 'systeme';
  var _loaded = false;
  var _busy = false;
  var _showPreview = false;

  /// Version publiée sur laquelle part la saisie, fixée au chargement : une publication faite entre-temps
  /// par un autre conteur fait refuser la nôtre au lieu de l'écraser.
  var _baseVersion = 0;
  late final String _id = widget.pageId == newPageId ? ref.read(wikiRepositoryProvider).newId() : widget.pageId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _source.dispose();
    super.dispose();
  }

  void _load(WikiPage? from, WikiItem? item) {
    _title.text = from?.title ?? item?.title ?? '';
    _body.text = from?.body ?? '';
    _source.text = from?.source ?? item?.entry?.source ?? '';
    _audience = from?.audience ?? audienceAll;
    _rubric = item?.rubric ?? 'systeme';
    _baseVersion = from?.version ?? 0;
    _loaded = true;
  }

  WikiPage _current(WikiItem? item) {
    final rule = item?.isRule ?? false;
    return WikiPage(
      id: _id,
      title: rule ? item!.title : _title.text.trim(),
      rubric: rule ? item!.rubric : _rubric,
      audience: _audience,
      body: _body.text,
      source: _source.text.trim(),
      cat: item?.cat,
      entryId: item?.entry != null ? entryKey(item!.entry!) : item?.page?.entryId ?? item?.draft?.entryId,
      version: _baseVersion,
    );
  }

  bool _valid(WikiItem? item) {
    if ((item?.isRule ?? false) || _title.text.trim().isNotEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre obligatoire.')));
    return false;
  }

  Actor get _by => actorOf(ref.read(currentUserProvider).value)!;

  /// Vrai si l'écriture a réussi ; sinon le formulaire reste tel quel.
  Future<bool> _run(Future<void> Function() write, String done, {String refused = 'Enregistrement refusé : réessayez.'}) async {
    setState(() => _busy = true);
    try {
      await write();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      return true;
    } catch (e) {
      final denied = e is FirebaseException && e.code == 'permission-denied';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(denied ? refused : 'Enregistrement refusé : réessayez.')));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Une nouvelle page prend son adresse définitive une fois enregistrée.
  void _openSaved() {
    if (mounted && widget.pageId == newPageId) context.go('/conteur/wiki/edition/$_id');
  }

  Future<void> _saveDraft(WikiItem? item) async {
    if (!_valid(item)) return;
    if (await _run(() => ref.read(wikiRepositoryProvider).saveDraft(_current(item), _by), 'Brouillon enregistré.')) _openSaved();
  }

  Future<void> _publish(WikiItem? item) async {
    if (!_valid(item)) return;
    final note = await showDialog<String>(context: context, builder: (_) => const _NoteDialog());
    if (note == null || !mounted) return;
    final page = _current(item);
    if (await _run(() => ref.read(wikiRepositoryProvider).publish(page, _by, note: note), 'Page publiée.',
        refused: 'Cette page a été publiée entre-temps. Rechargez-la avant de publier.')) {
      _baseVersion = page.version + 1;
      _openSaved();
    }
  }

  Future<void> _discard(WikiItem item) async {
    if (!await confirm(context, title: 'Abandonner le brouillon', body: 'Les modifications non publiées seront perdues.', action: 'Abandonner')) return;
    if (!await _run(() => ref.read(wikiRepositoryProvider).discardDraft(_id), 'Brouillon abandonné.') || !mounted) return;
    if (item.page == null) {
      context.go('/conteur/wiki');
    } else {
      setState(() => _load(item.page, item));
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context,
        title: 'Supprimer la page', body: 'La page publiée et son brouillon seront supprimés. Les versions restent dans l’historique.', action: 'Supprimer')) {
      return;
    }
    if (await _run(() => ref.read(wikiRepositoryProvider).delete(_id), 'Page supprimée.') && mounted) context.go('/conteur/wiki');
  }

  void _apply(TextEditingValue Function(TextEditingValue) edit) => setState(() => _body.value = edit(_body.value));

  @override
  Widget build(BuildContext context) {
    final manages = ref.watch(currentUserProvider.select((u) => u.value?.role.managesAccounts ?? false));
    final rb = ref.watch(rulebookProvider);
    final drafts = ref.watch(wikiDraftsProvider);
    if (rb == null) return const Center(child: CircularProgressIndicator());
    return asyncView(
      ref.watch(wikiPagesProvider),
      (pages) => asyncView(drafts, (drafts) {
        final items = wikiIndex(rb, pages, drafts: drafts, staff: true);
        final item = items.where((i) => i.id == _id).firstOrNull;
        if (item == null && widget.pageId != newPageId) {
          return const EmptyState(kind: EmptyKind.notFound, title: 'Page introuvable', message: 'Cette page n’existe pas.');
        }
        if (!_loaded) _load(item?.draft ?? item?.page, item);
        return _form(context, rb, items, item, manages: manages);
      }, onRetry: () => ref.invalidate(wikiDraftsProvider)),
      onRetry: () => ref.invalidate(wikiPagesProvider),
    );
  }

  Widget _form(BuildContext context, Rulebook rb, List<WikiItem> items, WikiItem? item, {required bool manages}) {
    final t = Theme.of(context).textTheme;
    final readOnly = !manages || _busy;
    final rule = item?.isRule ?? false;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final options = audienceOptions(rb);
    final audiences = [...options, if (!options.any((o) => o.$1 == _audience)) (_audience, audienceLabel(_audience, rb))];

    Widget tool(String label, String glyph, TextEditingValue Function(TextEditingValue) edit) => Tooltip(
          message: label,
          child: TextButton(key: Key('wk-tool-$label'), onPressed: readOnly ? null : () => _apply(edit), child: Text(glyph)),
        );

    final field = TextField(
      key: const Key('wk-body'),
      controller: _body,
      maxLength: 50000,
      readOnly: readOnly,
      minLines: 16,
      maxLines: null,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(hintText: 'Texte de la page…'),
    );
    // Aperçu : les liens ne quittent pas l'édition.
    final preview = WikiBody(_body.text, target: (title) => resolveLink(title, items)?.id, onOpen: (_) {});
    final editor = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 4, children: [
            tool('Gras', 'B', (v) => wrapSelection(v, '**', '**', 'texte')),
            tool('Italique', 'I', (v) => wrapSelection(v, '*', '*', 'texte')),
            tool('Titre', 'T', (v) => prefixLine(v, '## ')),
            tool('Liste', '•', (v) => prefixLine(v, '- ')),
            tool('Lien vers une page', '[[ ]]', (v) => wrapSelection(v, '[[', ']]', 'Titre de la page')),
            tool('Encadré règle', '§', (v) => prefixLine(v, '§ ')),
            tool('Tableau', '▦', (v) => insertBlock(v, '| Colonne | Colonne |\n|---|---|\n| | |')),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: field),
                  const SizedBox(width: 20),
                  Expanded(child: preview),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SegmentedButton<bool>(
                    key: const Key('wk-tabs'),
                    segments: const [ButtonSegment(value: false, label: Text('Texte')), ButtonSegment(value: true, label: Text('Aperçu'))],
                    selected: {_showPreview},
                    onSelectionChanged: (s) => setState(() => _showPreview = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_showPreview) preview else field,
                ]),
        ),
      ]),
    );

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Publication'),
          const SizedBox(height: 12),
          Text('Visible par', style: t.labelMedium),
          DropdownButton<String>(
            key: const Key('wk-audience'),
            isExpanded: true,
            value: _audience,
            items: [for (final (v, label) in audiences) DropdownMenuItem(value: v, child: Text(label))],
            onChanged: readOnly ? null : (v) => setState(() => _audience = v ?? audienceAll),
          ),
          if (!rule) ...[
            const SizedBox(height: 12),
            Text('Rubrique', style: t.labelMedium),
            DropdownButton<String>(
              key: const Key('wk-rubric'),
              isExpanded: true,
              value: _rubric,
              items: [for (final r in rubrics) DropdownMenuItem(value: r.id, child: Text(r.label))],
              onChanged: readOnly ? null : (v) => setState(() => _rubric = v ?? _rubric),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('wk-source'),
            controller: _source,
            readOnly: readOnly,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Source', hintText: 'MET : VTM, p. 120'),
          ),
        ]),
      ),
      if (item != null && item.entry != null) ...[
        const SizedBox(height: 20),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: SectionTitle('Données du référentiel')),
              TextButton(onPressed: () => context.go('/conteur/referentiel/${item.cat}'), child: const Text('Modifier')),
            ]),
            RuleDataView(cat: item.cat!, entry: item.entry!),
            const SizedBox(height: 8),
            Text('Affichées automatiquement sur la page ; elles ne se retapent pas.', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
        ),
      ],
      if (manages && (!rule || item!.orphan) && (item?.page != null || item?.draft != null)) ...[
        // Page libre, ou page d'une entrée supprimée du référentiel.
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(key: const Key('wk-delete'), onPressed: _busy ? null : _delete, child: const Text('Supprimer la page')),
        ),
      ],
    ]);

    final heading = rule ? item!.title : (_title.text.trim().isEmpty ? 'Nouvelle page' : _title.text.trim());
    return PageBody(children: [
      WikiCrumbs([
        ('Wiki', '/conteur/wiki'),
        if (item != null) (rubricById(item.rubric).label, const WikiNav(staff: true).rubric(item.rubric)),
      ], heading),
      const SizedBox(height: 8),
      if (rule)
        Text(item!.title, style: wide ? t.displaySmall : t.headlineMedium)
      else
        TextField(
          key: const Key('wk-title'),
          controller: _title,
          readOnly: readOnly,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
          style: t.headlineSmall,
          decoration: const InputDecoration(hintText: 'Titre de la page'),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (item?.page != null)
          OutlinedButton(onPressed: () => context.go(const WikiNav(staff: true, preview: true).page(_id)), child: const Text('Aperçu joueur')),
        if (manages) ...[
          OutlinedButton(key: const Key('wk-save-draft'), onPressed: _busy ? null : () => _saveDraft(item), child: const Text('Enregistrer le brouillon')),
          FilledButton(key: const Key('wk-publish'), onPressed: _busy ? null : () => _publish(item), child: const Text('Publier')),
        ],
      ]),
      if (item?.draft != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: AppColors.reviewBg, borderRadius: BorderRadius.circular(6)),
          child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Brouillon en cours, non publié.', style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
            if (manages)
              TextButton(key: const Key('wk-discard'), onPressed: _busy ? null : () => _discard(item!), child: const Text('Abandonner le brouillon')),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: editor),
          const SizedBox(width: 24),
          SizedBox(width: 400, child: side),
        ])
      else ...[
        editor,
        const SizedBox(height: 20),
        side,
      ],
    ]);
  }
}

/// Note de version facultative, demandée à la publication.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Publier la page'),
        content: TextField(
          key: const Key('wk-note'),
          controller: _note,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Note de version (facultative)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(key: const Key('wk-publish-ok'), onPressed: () => Navigator.pop(context, _note.text.trim()), child: const Text('Publier')),
        ],
      );
}
