import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rules/met_lists.dart';
import 'character.dart';
import 'character_repository.dart';
import 'character_screen.dart';
import 'describe_changes.dart';
import 'edit_widgets.dart';
import 'sheet_widgets.dart';

/// Motif obligatoire, visible par le joueur. Renvoie null si annulé.
Future<String?> askReason(BuildContext context, List<String> summary) =>
    showDialog<String>(context: context, builder: (_) => _ReasonDialog(summary));

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog(this.summary);
  final List<String> summary;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Enregistrer les modifications'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final line in widget.summary) Text(line, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('reason'),
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motif (obligatoire, visible par le joueur)'),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Indiquez un motif.';
                  if (s.length > 500) return '500 caractères maximum.';
                  return null;
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour')),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) Navigator.pop(context, _reason.text.trim());
            },
            child: const Text('Confirmer'),
          ),
        ],
      );
}

/// C3 : fiche en édition, côté conteur.
class CharacterEditScreen extends ConsumerStatefulWidget {
  const CharacterEditScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends ConsumerState<CharacterEditScreen> {
  Character? _base;
  Character? _draft;
  Character? _incoming;
  int _generation = 0; // reconstruit les champs texte après Annuler / Recharger
  bool _saving = false;

  List<String> get _changes => (_base == null || _draft == null) ? const [] : describeChanges(_base!, _draft!);

  void _touch() => setState(() {});

  void _reset(Character to) => setState(() {
        _base = to;
        _draft = to.clone();
        _incoming = null;
        _generation++;
      });

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    final changes = _changes;
    if (by == null || changes.isEmpty || _saving) return;
    final reason = await askReason(context, changes);
    if (reason == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(characterRepositoryProvider).saveEdit(_base!, _draft!, reason, by);
      if (mounted) {
        setState(() {
          _base = _draft!.clone()..version = _base!.version + 1;
          _incoming = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche enregistrée.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrement refusé : la fiche a peut-être été modifiée entre-temps. Vos changements sont conservés.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(characterProvider(widget.id), (_, next) {
      final c = next.value;
      // Pendant son propre enregistrement, Firestore renvoie d'abord l'écriture locale : on l'ignore.
      if (c == null || _base == null || _saving || c.version == _base!.version) return;
      if (_changes.isEmpty) {
        _reset(c);
      } else {
        setState(() => _incoming = c);
      }
    });
    final me = ref.watch(currentUserProvider).value;
    return asyncView(ref.watch(characterProvider(widget.id)), (latest) {
      if (latest == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      final readOnlyReason = switch (latest) {
        _ when me == null || !me.role.managesAccounts => 'Seuls les conteurs modifient les fiches.',
        _ when latest.playerUid == me.uid => 'C’est votre propre fiche : un autre conteur doit la modifier.',
        _ when latest.kind == CharacterKind.pj && !latest.status.settled =>
          'Cette fiche est en ${latest.status.label.toLowerCase()} : c’est au joueur de la remplir, puis au conte de la valider.',
        _ => null,
      };
      if (readOnlyReason != null) {
        return PageBody(children: [
          CharacterHeader(latest, basePath: '/conteur/fiches/${latest.id}', history: false),
          const SizedBox(height: 16),
          _Banner(readOnlyReason),
          const SizedBox(height: 22),
          CharacterSheetView(latest),
        ]);
      }
      _base ??= latest;
      _draft ??= latest.clone();
      final changes = _changes;
      return Column(children: [
        Expanded(
          child: PageBody(children: [
              CharacterHeader(_base!, basePath: '/conteur/fiches/${latest.id}', history: false),
              const SizedBox(height: 16),
              const _Banner('Mode conteur — les modifications s’appliquent directement et sont tracées dans l’historique, avec un motif.'),
              if (_incoming != null) ...[
                const SizedBox(height: 12),
                _Banner(
                  'Une nouvelle version a été enregistrée par quelqu’un d’autre.',
                  action: TextButton(
                    onPressed: () => setState(() {
                      _draft = rebase(_base!, _draft!, _incoming!);
                      _base = _incoming;
                      _incoming = null;
                      _generation++;
                    }),
                    child: const Text('Repartir de la dernière version'),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              // Reconstruit les champs texte après Annuler / Repartir ; les notes restent hors de ce sous-arbre.
              KeyedSubtree(key: ValueKey(_generation), child: _Editor(c: _draft!, onChanged: _touch)),
              const SizedBox(height: 22),
              NotesPanel(id: latest.id),
            ]),
        ),
        if (changes.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  changes.length == 1 ? '1 modification non enregistrée' : '${changes.length} modifications non enregistrées',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextButton(onPressed: () => _reset(_base!), child: const Text('Annuler')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
            ]),
          ),
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(widget.id)));
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.reviewBg,
          border: Border.all(color: AppColors.gold),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.goldLight, fontSize: 14))),
          ?action,
        ]),
      );
}

/// Tous les champs éditables de la fiche (le brouillon est modifié en place).
class _Editor extends ConsumerWidget {
  const _Editor({required this.c, required this.onChanged});
  final Character c;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void set(void Function() change) {
      change();
      onChanged();
    }

    Widget section(String title, List<Widget> children) => Panel(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle(title),
            const SizedBox(height: 12),
            for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: 12), w],
          ]),
        );
    final users = ref.watch(allUsersProvider).value ?? const <AppUser>[];
    final players = users.where((u) => u.role != Role.pending && u.role != Role.disabled).toList();

    final identity = section('Identité', [
      TextFieldRow(label: 'Nom', value: c.name, onChanged: (v) => set(() => c.name = v ?? c.name)),
      DropdownButtonFormField<CharacterStatus>(
        initialValue: c.status,
        decoration: const InputDecoration(labelText: 'Statut'),
        items: [
          for (final s in [CharacterStatus.active, CharacterStatus.retired, CharacterStatus.dead])
            DropdownMenuItem(value: s, child: Text(s.label)),
        ],
        onChanged: (s) => set(() => c.status = s ?? c.status),
      ),
      if (c.kind == CharacterKind.pj)
        DropdownButtonFormField<String>(
          initialValue: players.any((u) => u.uid == c.playerUid) ? c.playerUid : null,
          decoration: const InputDecoration(labelText: 'Joueur'),
          items: [for (final u in players) DropdownMenuItem(value: u.uid, child: Text(u.displayName))],
          onChanged: (uid) => set(() {
            final u = players.firstWhere((p) => p.uid == uid);
            c.playerUid = u.uid;
            c.playerName = u.displayName;
          }),
        ),
      ChoiceField(label: 'Clan', value: c.clan, options: [for (final k in clans) k.name], onChanged: (v) => set(() => c.clan = v)),
      TextFieldRow(label: 'Lignée', value: c.lineage, onChanged: (v) => set(() => c.lineage = v)),
      ChoiceField(label: 'Secte', value: c.sect, options: sects, onChanged: (v) => set(() => c.sect = v)),
      DropdownButtonFormField<GenRank?>(
        initialValue: c.genRank,
        decoration: const InputDecoration(labelText: 'Rang de génération'),
        items: [
          const DropdownMenuItem<GenRank?>(value: null, child: Text('—')),
          for (final g in GenRank.values) DropdownMenuItem<GenRank?>(value: g, child: Text(g.label)),
        ],
        onChanged: (g) => set(() {
          c.genRank = g;
          if (g == null || !(generationNumbers[g] ?? const []).contains(c.genNumber)) c.genNumber = null;
        }),
      ),
      if (c.genRank != null)
        DropdownButtonFormField<int?>(
          initialValue: c.genNumber,
          decoration: const InputDecoration(labelText: 'Génération'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('—')),
            for (final n in generationNumbers[c.genRank]!) DropdownMenuItem<int?>(value: n, child: Text('${n}e')),
          ],
          onChanged: (n) => set(() => c.genNumber = n),
        ),
      ChoiceField(label: 'Archétype', value: c.archetype, options: archetypes, onChanged: (v) => set(() => c.archetype = v)),
      TextFieldRow(label: 'Concept', value: c.concept, onChanged: (v) => set(() => c.concept = v)),
      TextFieldRow(label: 'Sire', value: c.sire, onChanged: (v) => set(() => c.sire = v)),
      TextFieldRow(label: 'Titre', value: c.title, onChanged: (v) => set(() => c.title = v)),
    ]);

    final attributes = section('Attributs', [
      for (final cat in AttrCategory.values) ...[
        PointsField(
          label: cat.label,
          value: c.attributes[cat]!.value,
          asDots: false,
          onChanged: (v) => set(() => c.attributes[cat]!.value = v),
        ),
        ChoiceField(
          label: 'Focus ${cat.label}',
          value: c.attributes[cat]!.focus,
          options: focuses[cat]!,
          onChanged: (v) => set(() => c.attributes[cat]!.focus = v),
        ),
      ],
    ]);

    final derived = section('Traits dérivés et expérience', [
      PointsField(label: 'Sang', value: c.blood, max: 30, asDots: false, onChanged: (v) => set(() => c.blood = v)),
      PointsField(label: 'Sang par tour', value: c.bloodPerTurn, max: 5, asDots: false, onChanged: (v) => set(() => c.bloodPerTurn = v)),
      PointsField(label: 'Volonté', value: c.willpower, onChanged: (v) => set(() => c.willpower = v)),
      PointsField(label: 'Humanité', value: c.humanity, onChanged: (v) => set(() => c.humanity = v)),
      TextFieldRow(label: 'Santé', value: c.health, onChanged: (v) => set(() => c.health = v ?? '')),
      PointsField(label: 'XP initiale', value: c.xpInitial, max: 2000, asDots: false, onChanged: (v) => set(() => c.xpInitial = v)),
      PointsField(label: 'XP gagnée', value: c.xpEarned, max: 2000, asDots: false, onChanged: (v) => set(() => c.xpEarned = v)),
      PointsField(label: 'XP dépensée', value: c.xpSpent, max: 2000, asDots: false, onChanged: (v) => set(() => c.xpSpent = v)),
      Text('Disponible : ${c.xpAvailable} XP', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.gold)),
    ]);

    final lists = [
      section('Compétences', [TraitListEditor(items: c.skills, options: skillNames, noteLabel: 'Domaine', onChanged: onChanged)]),
      section('Historiques', [TraitListEditor(items: c.backgrounds, options: backgroundNames, noteLabel: 'Précisions', onChanged: onChanged)]),
      section('Disciplines', [DisciplineListEditor(items: c.disciplines, options: allDisciplines, onChanged: onChanged)]),
      section('Atouts', [TraitListEditor(items: c.merits, options: baseMerits.keys.toList(), max: 7, asDots: false, onChanged: onChanged)]),
      section('Handicaps', [TraitListEditor(items: c.flaws, options: baseFlaws.keys.toList(), max: 7, asDots: false, onChanged: onChanged)]),
    ];

    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in items.indexed) ...[if (i > 0) const SizedBox(height: 20), w],
        ]);
    if (!isWide(context)) return column([identity, attributes, derived, ...lists]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: column([identity, derived])),
      const SizedBox(width: 20),
      Expanded(child: column([attributes, ...lists])),
    ]);
  }
}

/// Notes privées du conte, enregistrées à part (jamais visibles des joueurs).
class NotesPanel extends ConsumerStatefulWidget {
  const NotesPanel({super.key, required this.id});
  final String id;

  @override
  ConsumerState<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends ConsumerState<NotesPanel> {
  final _text = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(characterRepositoryProvider).saveNotes(widget.id, _text.text, by);
      messenger.showSnackBar(const SnackBar(content: Text('Notes enregistrées.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(characterNotesProvider(widget.id)).value;
    if (!_loaded && notes != null) {
      _text.text = notes;
      _loaded = true;
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Notes privées du conte'),
        const SizedBox(height: 10),
        TextField(controller: _text, maxLines: 5, decoration: const InputDecoration(hintText: 'Jamais visibles par les joueurs.')),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: _save, child: const Text('Enregistrer les notes'))),
      ]),
    );
  }
}
