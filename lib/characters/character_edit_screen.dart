import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../items/character_items_screen.dart';
import '../items/items_repository.dart';
import '../npcs/my_npc_loans_screen.dart';
import '../places/character_places_screen.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import '../rules/met_lists.dart' show focuses;
import '../servants/servants_repository.dart';
import '../servants/servants_section.dart';
import '../servants/transform_dialogs.dart';
import 'character.dart';
import 'character_repository.dart';
import 'character_screen.dart';
import 'describe_changes.dart';
import 'edit_widgets.dart';
import 'sheet_widgets.dart';
import 'transformations.dart';

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

  /// Étreinte d'une goule jouée : une seule écriture tracée « embrace », clé `ghoul` supprimée.
  Future<void> _embraceGhoul(Character latest) async {
    final rb = ref.read(rulebookProvider) ?? const Rulebook();
    final choice = await showDialog<EmbraceChoice>(
      context: context,
      builder: (_) => EmbraceDialog(
        name: latest.name,
        initialSireId: latest.ghoul!.domitorId,
        debt: (c) => debtOf(embraceGhoul(latest, sire: c.sire, genNumber: c.genNumber, first: c.first, rb: rb).after ?? latest),
      ),
    );
    final by = actorOf(ref.read(currentUserProvider).value);
    if (choice == null || by == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = embraceGhoul(latest, sire: choice.sire, genNumber: choice.genNumber, first: choice.first, rb: rb);
    if (r.after == null) {
      messenger.showSnackBar(SnackBar(content: Text(r.error!)));
      return;
    }
    try {
      await ref.read(characterRepositoryProvider).saveEdit(latest, r.after!, choice.reason, by, kind: 'embrace', extra: {'ghoul': FieldValue.delete()});
      messenger.showSnackBar(const SnackBar(content: Text('Étreinte enregistrée.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Modifié entre-temps : rechargez la page.')));
    }
  }

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    final changes = _changes;
    if (by == null || changes.isEmpty || _saving) return;
    if (_draft!.ghoul != null && _draft!.humanity < _base!.humanity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L’Humanité d’une goule ne peut pas baisser.')));
      return;
    }
    final reason = await askReason(context, changes);
    if (reason == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(characterRepositoryProvider).saveEdit(_base!, _draft!, reason, by);
      // Serviteurs retirés : leur fiche détaillée est marquée libérée (lot séparé ; un échec n'annule pas la fiche).
      final kept = {for (final s in _draft!.servants) s.id};
      final failed = <String>[];
      for (final s in _base!.servants) {
        if (kept.contains(s.id)) continue;
        try {
          await ref.read(servantsRepositoryProvider).release(s.id, by, rank: s.rank);
        } catch (_) {
          failed.add(s.name);
        }
      }
      // Joueur changé : l'accès aux fiches détaillées des serviteurs suit.
      if (_base!.playerUid != _draft!.playerUid) {
        for (final s in _draft!.servants) {
          try {
            await ref.read(servantsRepositoryProvider).setPlayers(s.id, [?_draft!.playerUid], by);
          } catch (_) {
            failed.add(s.name);
          }
        }
        try {
          await ref.read(itemsRepositoryProvider).setPlayer(_draft!.id, _draft!.playerUid ?? '', by);
        } catch (_) {
          failed.add('Équipement');
        }
      }
      if (mounted) {
        setState(() {
          _base = _draft!.clone()..version = _base!.version + 1;
          _incoming = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failed.isEmpty
              ? 'Fiche enregistrée.'
              : '${failed.join(', ')} : fiche du serviteur non mise à jour. Ouvrez-la dans « Goules et mortels » et enregistrez.'),
        ));
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
          if (latest.kind == CharacterKind.pj &&
              latest.status == CharacterStatus.draft &&
              me != null &&
              me.role.managesAccounts &&
              latest.playerUid != me.uid) ...[
            const SizedBox(height: 16),
            _BonusPanel(latest),
          ],
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
              const SizedBox(height: 20),
              PlacesSection(characterId: latest.id, link: '/conteur/lieux'),
              const SizedBox(height: 20),
              ItemsSection(characterId: latest.id, link: '/conteur/objets'),
              const SizedBox(height: 20),
              ServantsSection(character: latest, linkOf: (_) => '/conteur/goules'),
              if (latest.kind == CharacterKind.pnj) ...[
                const SizedBox(height: 20),
                NpcLoansSection(characterId: latest.id),
              ],
              if (latest.ghoul != null && latest.status == CharacterStatus.active) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const Key('c3-embrace'),
                    // Une étreinte sur un brouillon non enregistré serait écrasée au prochain enregistrement.
                    onPressed: _changes.isEmpty ? () => _embraceGhoul(latest) : null,
                    child: const Text('Étreindre…'),
                  ),
                ),
              ],
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
    final rb = ref.watch(rulebookProvider) ?? const Rulebook();
    List<String> names(String cat) => [for (final e in rb.all(cat)) e.name];
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
          key: const Key('c3-player'),
          initialValue: players.any((u) => u.uid == c.playerUid) ? c.playerUid : null,
          decoration: const InputDecoration(labelText: 'Joueur'),
          items: [for (final u in players) DropdownMenuItem(value: u.uid, child: Text(u.displayName))],
          onChanged: (uid) => set(() {
            final u = players.firstWhere((p) => p.uid == uid);
            c.playerUid = u.uid;
            c.playerName = u.displayName;
          }),
        ),
      ChoiceField(label: 'Clan', value: c.clan, options: names('clans'), onChanged: (v) => set(() => c.clan = v)),
      TextFieldRow(label: 'Lignée', value: c.lineage, onChanged: (v) => set(() => c.lineage = v)),
      ChoiceField(label: 'Secte', value: c.sect, options: names('sects'), onChanged: (v) => set(() => c.sect = v)),
      if (c.ghoul == null)
      DropdownButtonFormField<GenRank?>(
        initialValue: c.genRank,
        decoration: const InputDecoration(labelText: 'Rang de génération'),
        items: [
          const DropdownMenuItem<GenRank?>(value: null, child: Text('—')),
          for (final g in GenRank.values) DropdownMenuItem<GenRank?>(value: g, child: Text(g.label)),
        ],
        onChanged: (g) => set(() {
          c.genRank = g;
          if (g == null || !rb.gen(g).numbers.contains(c.genNumber)) c.genNumber = null;
        }),
      ),
      if (c.ghoul == null && c.genRank != null)
        DropdownButtonFormField<int?>(
          // Numéro retiré du référentiel ou en double : le menu ne doit pas planter.
          initialValue: rb.gen(c.genRank!).numbers.contains(c.genNumber) ? c.genNumber : null,
          decoration: const InputDecoration(labelText: 'Génération'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('—')),
            for (final n in rb.gen(c.genRank!).numbers.toSet()) DropdownMenuItem<int?>(value: n, child: Text('${n}e')),
          ],
          onChanged: (n) => set(() => c.genNumber = n),
        ),
      ChoiceField(label: 'Archétype', value: c.archetype, options: names('archetypes'), onChanged: (v) => set(() => c.archetype = v)),
      TextFieldRow(label: 'Concept', value: c.concept, onChanged: (v) => set(() => c.concept = v)),
      TextFieldRow(label: 'Sire', value: c.sire, onChanged: (v) => set(() => c.sire = v)),
      TextFieldRow(label: 'Titre', value: c.title, onChanged: (v) => set(() => c.title = v)),
    ]);

    final attributes = section('Attributs', [
      for (final cat in AttrCategory.values) ...[
        PointsField(
          label: cat.label,
          value: c.attributes[cat]!.value,
          max: 10 + (c.attributeBonus[cat] ?? 0),
          asDots: false,
          onChanged: (v) => set(() => c.attributes[cat]!.value = v),
        ),
        ChoiceField(
          label: 'Focus ${cat.label}',
          value: c.attributes[cat]!.focus,
          options: focuses[cat]!,
          onChanged: (v) => set(() => c.attributes[cat]!.focus = v),
        ),
        PointsField(
          label: 'Points bonus ${cat.label}',
          value: c.attributeBonus[cat] ?? 0,
          max: rb.rowFor(c).attributeBonus,
          asDots: false,
          onChanged: (v) => set(() => c.attributeBonus[cat] = v),
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

    final g = c.ghoul;
    final domitor = g == null ? null : ref.watch(allCharactersProvider).value?.where((x) => x.id == g.domitorId).firstOrNull;
    final ghoulSection = g == null
        ? null
        : section('État de goule', [
            Text(ghoulLine(g), style: Theme.of(context).textTheme.titleSmall),
            KeyedSubtree(
              key: ValueKey('vitae-${g.vitae}'),
              child: DropdownButtonFormField<int>(
                key: const Key('ghoul-vitae'),
                initialValue: g.vitae.clamp(0, 5),
                decoration: const InputDecoration(labelText: 'Vitae (sur 5)'),
                items: [for (var v = 0; v <= 5; v++) DropdownMenuItem(value: v, child: Text('$v'))],
                onChanged: (v) => set(() => g.vitae = v ?? g.vitae),
              ),
            ),
            DropdownButtonFormField<int>(
              key: const Key('ghoul-bond'),
              initialValue: g.bond.clamp(0, 3),
              decoration: const InputDecoration(labelText: 'Lien de sang'),
              items: [for (var v = 0; v <= 3; v++) DropdownMenuItem(value: v, child: Text(v == 0 ? 'Aucun' : dots(v)))],
              onChanged: (v) => set(() => g.bond = v ?? g.bond),
            ),
            Row(children: [
              Expanded(child: Text(g.lastDrink == null ? 'Aucune gorgée notée' : 'Dernière gorgée : ${formatDay(g.lastDrink)}')),
              OutlinedButton(
                key: const Key('ghoul-drink'),
                onPressed: () => set(() {
                  g.lastDrink = DateTime.now();
                  g.vitae = (g.vitae + 1).clamp(0, 5);
                }),
                child: const Text('+ Gorgée'),
              ),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('ghoul-refresh'),
                onPressed: domitor == null
                    ? null
                    : () => set(() {
                          final copy = GhoulState.of(domitor);
                          g
                            ..domitorName = copy.domitorName
                            ..domitorClan = copy.domitorClan
                            ..domitorDisciplines = copy.domitorDisciplines;
                        }),
                child: const Text('Recopier les disciplines du domitor'),
              ),
            ),
            if (domitor != null && (domitor.status == CharacterStatus.retired || domitor.status == CharacterStatus.dead))
              const Text('Le domitor est une fiche retirée ou morte', style: TextStyle(color: AppColors.goldLight)),
          ]);

    final lists = [
      section('Compétences', [TraitListEditor(items: c.skills, options: names('skills'), noteLabel: 'Domaine', onChanged: onChanged)]),
      section('Historiques', [TraitListEditor(items: c.backgrounds, options: [for (final n in names('backgrounds')) if (n != servantsBackground) n], noteLabel: 'Précisions', onChanged: onChanged)]),
      section('Serviteurs', [ServantListEditor(characterId: c.id, items: c.servants, onChanged: onChanged)]),
      section('Disciplines', [DisciplineListEditor(items: c.disciplines, options: names('disciplines'), onChanged: onChanged)]),
      section('Atouts', [TraitListEditor(items: c.merits, options: names('merits'), max: 7, asDots: false, onChanged: onChanged)]),
      section('Handicaps', [TraitListEditor(items: c.flaws, options: names('flaws'), max: 7, asDots: false, onChanged: onChanged)]),
      section('Rituels', [
        NameListEditor(
          label: 'Rituels',
          items: [for (final r in c.rituals) r.name],
          options: names('rituals'),
          onAdd: (n) => set(() => c.rituals.add(Ritual(n, rb.ritualSchool(n) ?? '', rb.ritualLevel(n)))),
          onRemove: (n) => set(() => c.rituals.removeWhere((r) => r.name == n)),
        ),
      ]),
      section('Techniques', [
        NameListEditor(
          label: 'Techniques',
          items: c.techniques,
          options: names('techniques'),
          onAdd: (n) => set(() => c.techniques.add(n)),
          onRemove: (n) => set(() => c.techniques.remove(n)),
        ),
      ]),
      section('Pouvoirs d’anciens', [
        NameListEditor(
          label: 'Pouvoirs d’anciens',
          items: [for (final e in c.elderPowers) e.name],
          options: names('elderPowers'),
          onAdd: (n) => set(() => c.elderPowers.add(ElderPower(n, rb.elderDiscipline(n) ?? ''))),
          onRemove: (n) => set(() => c.elderPowers.removeWhere((e) => e.name == n)),
        ),
      ]),
    ];

    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in items.indexed) ...[if (i > 0) const SizedBox(height: 20), w],
        ]);
    if (!isWide(context)) return column([identity, attributes, derived, ?ghoulSection, ...lists]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: column([identity, derived, ?ghoulSection])),
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

/// Bonus d'XP du conte sur un brouillon (J-Creation-2, « Bonus du conte »).
class _BonusPanel extends ConsumerStatefulWidget {
  const _BonusPanel(this.c);
  final Character c;

  @override
  ConsumerState<_BonusPanel> createState() => _BonusPanelState();
}

class _BonusPanelState extends ConsumerState<_BonusPanel> {
  late int _bonus = widget.c.xpBonus;

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(characterRepositoryProvider).setBonus(widget.c, _bonus, by);
      messenger.showSnackBar(SnackBar(content: Text('Bonus du conte : $_bonus XP.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Bonus du conte'),
          const SizedBox(height: 8),
          Text('Pour un personnage expérimenté : XP ajoutée au budget de création.', style: Theme.of(context).textTheme.bodySmall),
          PointsField(label: 'Bonus', value: _bonus, max: 500, asDots: false, onChanged: (v) => setState(() => _bonus = v)),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: _bonus == widget.c.xpBonus ? null : _save, child: const Text('Enregistrer le bonus')),
          ),
        ]),
      );
}
