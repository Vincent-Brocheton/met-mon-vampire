import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/trace.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show parseDay, formatLoanDay;
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'allies_repository.dart';
import 'ally_fields.dart';
import 'ally_file.dart';
import 'ally_rules.dart';

String _day(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// « Alliés en jeu » (C-AlliesSuivi) : tous les alliés, leur suivi d'usage, les demandes et les fiches à convertir.
class AlliesAdminScreen extends ConsumerStatefulWidget {
  const AlliesAdminScreen({super.key});

  @override
  ConsumerState<AlliesAdminScreen> createState() => _AlliesAdminScreenState();
}

class _AlliesAdminScreenState extends ConsumerState<AlliesAdminScreen> {
  String _filter = 'all';

  /// Allié ouvert (identifiant), ou conversion ouverte (personnage, historique).
  String? _ally;
  (String, String)? _convert;
  int _version = 0;

  void _open({String? ally, (String, String)? convert}) => setState(() {
        _ally = ally;
        _convert = convert;
        _version++;
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final rb = ref.watch(rulebookProvider);
    if (me == null || rb == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Les alliés sont suivis par le conte.');
    }
    final pending = ref.watch(pendingRequestsProvider).value ?? const <XpRequest>[];
    return asyncView(
      ref.watch(allCharactersProvider),
      (chars) => asyncView(
        ref.watch(allAllyFilesProvider),
        (files) => _body(context, !me.role.managesAccounts, rb, chars, files, pending),
        onRetry: () => ref.invalidate(allAllyFilesProvider),
      ),
      onRetry: () => ref.invalidate(allCharactersProvider),
    );
  }

  Widget _body(BuildContext context, bool readOnly, Rulebook rb, List<Character> chars, List<AllyFile> files, List<XpRequest> pending) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final byId = {for (final f in files) f.id: f};
    bool out(Ally a) => byId[a.id]?.returnAt?.isAfter(now) ?? false;
    final rows = [
      for (final c in chars)
        if (c.status != CharacterStatus.draft)
          for (final a in c.allies) (c, a),
    ];
    final requested = [
      for (final r in pending)
        for (final i in r.items)
          if (i.kind == XpKind.ally) (r, i),
    ];
    final legacy = [
      for (final c in chars)
        if (c.status == CharacterStatus.active)
          for (final b in legacyAllies(c)) (c, b),
    ];
    final outCount = rows.where((x) => out(x.$2)).length;

    Widget chip(String key, String label) => ChoiceChip(
          key: Key('al-filter-$key'),
          label: Text(label),
          selected: _filter == key,
          onSelected: (_) => setState(() => _filter = key),
        );

    Widget row(Character c, Ally a) => InkWell(
          key: Key('al-row-${a.id}'),
          onTap: () => _open(ally: a.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: a.id == _ally ? AppColors.navActive : null,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 240,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: t.titleSmall),
                  Text([if (a.influence > 0) 'Influence ${a.influence}', ...a.specialties].join(' · '), style: t.bodySmall),
                ]),
              ),
              SizedBox(width: 160, child: Text(c.name, style: t.bodySmall)),
              SizedBox(width: 80, child: Text(dots(a.level), style: const TextStyle(color: AppColors.gold, letterSpacing: 2))),
              SizedBox(width: 200, child: Text('${a.type} · ${a.domain}', style: t.bodySmall)),
              SizedBox(
                width: 100,
                child: Text(out(a) ? 'Indisponible' : 'Disponible',
                    style: t.bodySmall?.copyWith(color: out(a) ? AppColors.goldLight : AppColors.success)),
              ),
              SizedBox(
                width: 150,
                child: Text(out(a) ? allyStatus(pending: false, returnAt: byId[a.id]?.returnAt, now: now) : '—', style: t.bodySmall),
              ),
            ]),
          ),
        );

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageTitle('Alliés en jeu',
          subtitle: 'Tous les alliés de la chronique. Un allié utilisé revient après X mois (X = son niveau), ou 2 mois s’il est Remplaçable.'),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        chip('all', 'Tous · ${rows.length}'),
        chip('out', 'Indisponibles · $outCount'),
        chip('requests', 'Demandes · ${requested.length}'),
        chip('convert', 'À convertir · ${legacy.length}'),
        TextButton(onPressed: () => context.go('/conteur/referentiel/allies'), child: const Text('Règles des alliés')),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_filter == 'all' || _filter == 'out') ...[
            if (isWide(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Wrap(spacing: 16, runSpacing: 4, children: [
                  for (final (label, w) in const [('Allié', 240.0), ('Personnage', 160.0), ('Niveau', 80.0), ('Type · domaine', 200.0), ('État', 100.0), ('Retour', 150.0)])
                    SizedBox(width: w, child: Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1))),
                ]),
              ),
            for (final (c, a) in rows)
              if (_filter == 'all' || out(a)) row(c, a),
            if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun allié.', style: t.bodyMedium)),
          ],
          if (_filter == 'requests') ...[
            if (requested.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucune demande.', style: t.bodyMedium)),
            for (final (r, i) in requested)
              ListTile(
                title: Text('${i.name} · ${dots(i.toLevel)}'),
                subtitle: Text('${r.characterName} · ${i.fromLevel == 0 ? 'nouvel allié' : 'niveau ${i.toLevel}'}'),
                trailing: TextButton(onPressed: () => context.go('/conteur/demandes'), child: const Text('Ouvrir les demandes')),
              ),
          ],
          if (_filter == 'convert') ...[
            if (legacy.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Aucune fiche à convertir.', style: t.bodyMedium)),
            for (final (c, b) in legacy)
              ListTile(
                key: Key('al-convert-${c.id}-${b.name}'),
                title: Text('${c.name} · ${b.name} ${dots(b.level)}'),
                subtitle: const Text('À transformer en allié'),
                onTap: () => _open(convert: (c.id, b.name)),
              ),
          ],
        ]),
      ),
    ]);

    Widget? panel;
    final open = rows.where((x) => x.$2.id == _ally).firstOrNull;
    if (open != null) {
      panel = Panel(
        child: _TrackPanel(key: ValueKey('track/$_ally/$_version'), character: open.$1, ally: open.$2, file: byId[open.$2.id], readOnly: readOnly),
      );
    } else if (_convert != null) {
      final c = chars.where((x) => x.id == _convert!.$1).firstOrNull;
      final b = c == null ? null : legacyAllies(c).where((x) => x.name == _convert!.$2).firstOrNull;
      if (c != null && b != null) {
        panel = Panel(
          child: _ConvertPanel(
            key: ValueKey('convert/${c.id}/${b.name}/${b.level}/$_version'),
            character: c,
            background: b,
            rb: rb,
            readOnly: readOnly,
            onDone: () => _open(),
          ),
        );
      }
    }

    if (!isWide(context)) {
      if (panel != null) {
        return PageBody(children: [
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _open(), child: const Text('← Retour à la liste'))),
          panel,
        ]);
      }
      return PageBody(children: [list]);
    }
    return PageBody(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: list),
        if (panel != null) ...[const SizedBox(width: 24), SizedBox(width: 440, child: panel)],
      ]),
    ]);
  }
}

class _TrackPanel extends ConsumerStatefulWidget {
  const _TrackPanel({super.key, required this.character, required this.ally, required this.file, required this.readOnly});
  final Character character;
  final Ally ally;
  final AllyFile? file;
  final bool readOnly;

  @override
  ConsumerState<_TrackPanel> createState() => _TrackPanelState();
}

class _TrackPanelState extends ConsumerState<_TrackPanel> {
  late AllyFile _base = widget.file ?? AllyFile(id: widget.ally.id);
  late final _used = TextEditingController(text: _day(_base.usedAt));
  late final _what = TextEditingController(text: _base.lastUse);
  late final _return = TextEditingController(text: _day(_base.returnAt));
  bool _busy = false;

  /// Le fichier reçu du flux (après un enregistrement) devient la nouvelle base des versions.
  @override
  void didUpdateWidget(_TrackPanel old) {
    super.didUpdateWidget(old);
    _base = widget.file ?? _base;
  }

  @override
  void dispose() {
    _used.dispose();
    _what.dispose();
    _return.dispose();
    super.dispose();
  }

  void _usedChanged(String v) {
    final d = parseDay(v);
    if (d != null) _return.text = _day(returnDate(widget.ally, d));
    setState(() {});
  }

  Future<void> _save({bool free = false}) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final used = free ? null : parseDay(_used.text);
    final back = free ? null : parseDay(_return.text);
    if (!free && (used == null || back == null)) {
      messenger.showSnackBar(const SnackBar(content: Text('Dates attendues au format JJ/MM/AAAA.')));
      return;
    }
    final c = widget.character;
    final f = _base.copy()
      ..name = widget.ally.name
      ..characterId = c.id
      ..characterName = c.name
      ..holderPlayers = [?c.playerUid]
      ..usedAt = used
      ..returnAt = back
      ..lastUse = free ? _base.lastUse : _what.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(alliesRepositoryProvider).save(_base, f, by, reason: free ? 'Rendu disponible' : 'Usage noté');
      messenger.showSnackBar(SnackBar(content: Text(free ? 'Allié rendu disponible.' : 'Suivi enregistré.')));
    } catch (_) {
      final latest = ref.read(allAllyFilesProvider).value?.where((x) => x.id == _base.id).firstOrNull;
      final moved = (latest?.version ?? 0) != _base.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = widget.ally;
    final c = widget.character;
    final ro = widget.readOnly;
    final now = DateTime.now();
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Suivi de l’allié'),
      const SizedBox(height: 10),
      Text(a.name, style: t.headlineSmall),
      Text('Allié de ${c.name} · niveau ${a.level} · ${a.type} · ${a.domain}', style: t.bodySmall),
      Text([if (a.influence > 0) 'Influence ${a.influence}', ...a.specialties].join(' · '), style: t.bodyMedium),
      const SizedBox(height: 12),
      if (_base.returnAt != null && now.isBefore(_base.returnAt!))
        gap(Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.reviewBg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            'Utilisé le ${formatLoanDay(_base.usedAt)}. Retour le ${formatLoanDay(_base.returnAt)} (${returnMonths(a)} mois).',
            style: t.bodyMedium,
          ),
        )),
      gap(TextField(
        key: const Key('al-used'),
        controller: _used,
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Dernière utilisation (JJ/MM/AAAA)'),
        onChanged: _usedChanged,
      )),
      gap(TextField(
        key: const Key('al-what'),
        controller: _what,
        enabled: !ro,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Ce qu’il a fait'),
      )),
      gap(TextField(
        key: const Key('al-return'),
        controller: _return,
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Date de retour (JJ/MM/AAAA)'),
      )),
      if (!ro)
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(key: const Key('al-save'), onPressed: _busy ? null : () => _save(), child: const Text('Enregistrer')),
          if (_base.usedAt != null)
            OutlinedButton(key: const Key('al-free'), onPressed: _busy ? null : () => _save(free: true), child: const Text('Rendre disponible')),
        ]),
      if (_base.version > 0) ...[
        const SizedBox(height: 16),
        const SectionTitle('Historique'),
        const SizedBox(height: 8),
        asyncView(ref.watch(allyHistoryProvider(_base.id)), TraceHistory.new),
      ],
    ]);
  }
}

class _ConvertPanel extends ConsumerStatefulWidget {
  const _ConvertPanel({super.key, required this.character, required this.background, required this.rb, required this.readOnly, required this.onDone});
  final Character character;
  final Trait background;
  final Rulebook rb;
  final bool readOnly;
  final VoidCallback onDone;

  @override
  ConsumerState<_ConvertPanel> createState() => _ConvertPanelState();
}

class _ConvertPanelState extends ConsumerState<_ConvertPanel> {
  late final Ally _a = Ally(
    newAllyId(widget.character.id),
    '',
    level: widget.background.level.clamp(1, allyMaxLevel(widget.rb)),
    type: allyTypes(widget.rb).first,
    domain: allyDomains(widget.rb).first,
  );
  bool _busy = false;

  Future<void> _save() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final c = widget.character;
    setState(() => _busy = true);
    try {
      await ref.read(characterRepositoryProvider).saveEdit(c, convertLegacy(c, widget.background.name, _a), 'Conversion des anciens historiques', by);
      messenger.showSnackBar(const SnackBar(content: Text('Allié créé.')));
      widget.onDone();
    } catch (_) {
      final latest = ref.read(allCharactersProvider).value?.where((x) => x.id == c.id).firstOrNull;
      final moved = (latest?.version ?? c.version) != c.version;
      messenger.showSnackBar(SnackBar(content: Text(moved ? 'Modifié entre-temps : rechargez la page.' : 'Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = widget.background;
    final errors = [...allyChecks(_a, widget.rb), ?conversionError(widget.character, b.name, _a)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Convertir « ${b.name} »'),
      const SizedBox(height: 8),
      Text('${widget.character.name} · ${b.name} ${dots(b.level)} : un ou plusieurs alliés, ${b.level} niveau${b.level > 1 ? 'x' : ''} au plus en tout.',
          style: t.bodySmall),
      const SizedBox(height: 12),
      AllyFields(ally: _a, rb: widget.rb, prefix: 'cv', maxLevel: b.level.clamp(1, allyMaxLevel(widget.rb)), onChanged: () => setState(() {})),
      const SizedBox(height: 8),
      for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
      if (!widget.readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(key: const Key('cv-save'), onPressed: _busy || errors.isNotEmpty ? null : _save, child: const Text('Convertir')),
        ),
    ]);
  }
}
