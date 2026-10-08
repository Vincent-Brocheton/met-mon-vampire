import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rule_hint.dart';
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import '../rules/creation_rules.dart' show humanityName;
import 'xp_repository.dart';
import 'xp_request.dart';
import 'xp_rules.dart';

/// « Dépenser de l'XP » (J-XP, J-Rachat) : une demande de plusieurs achats, envoyée au conte.
class SpendScreen extends ConsumerStatefulWidget {
  const SpendScreen({super.key, required this.characterId, this.requestId});
  final String characterId;

  /// Demande à modifier (brouillon, en attente ou à compléter) ; null pour une nouvelle.
  final String? requestId;

  @override
  ConsumerState<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends ConsumerState<SpendScreen> {
  XpRequest? _r;
  XpKind _kind = XpKind.skill;
  String? _name;
  final _note = TextEditingController();
  final _why = TextEditingController();
  bool _dirty = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    _why.dispose();
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  Future<void> _leave() async {
    if (_dirty) {
      final ok = await confirm(context, title: 'Abandonner les changements ?', body: 'La demande ne sera pas enregistrée.', action: 'Abandonner', cancel: 'Continuer');
      if (!ok || !mounted) return;
    }
    context.go('/joueur/demandes');
  }

  Future<void> _save({required bool submit}) async {
    final r = _r!..justification = _why.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref.read(xpRepositoryProvider).save(r, submit: submit);
      if (mounted) context.go('/joueur/demandes?d=$id');
    } catch (_) {
      if (!mounted) return;
      if (r.id.isNotEmpty) {
        // Refus des règles sur une demande existante : le conte l'a traitée (version) ; retour au détail.
        messenger.showSnackBar(const SnackBar(content: Text('La demande a été traitée entre-temps.')));
        context.go('/joueur/demandes?d=${r.id}');
      } else {
        setState(() {
          _busy = false;
          _error = 'Envoi impossible. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    return asyncView(ref.watch(characterProvider(widget.characterId)), (c) {
      if (c == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      if (me == null) return const Center(child: CircularProgressIndicator());
      if (c.playerUid != me.uid) {
        return EmptyState(
          kind: EmptyKind.forbidden,
          title: 'Cette fiche n’est pas la vôtre',
          message: 'Vous ne dépensez l’XP que de vos propres personnages.',
          actionLabel: 'Mes personnages',
          onAction: () => context.go('/joueur/personnages'),
        );
      }
      if (c.status != CharacterStatus.active) {
        return EmptyState(
          kind: EmptyKind.forbidden,
          title: 'Cette fiche n’est pas active',
          message: 'L’XP se dépense sur une fiche validée par le conte.',
          actionLabel: 'Voir la fiche',
          onAction: () => context.go('/joueur/personnages/${c.id}'),
        );
      }
      final rb = ref.watch(rulebookProvider);
      if (rb == null) return const Center(child: CircularProgressIndicator());
      return asyncView(ref.watch(myRequestsProvider), (requests) {
        if (_r == null) {
          if (widget.requestId == null) {
            _r = XpRequest.forCharacter(c);
          } else {
            final existing = requests.where((r) => r.id == widget.requestId).firstOrNull;
            if (existing == null || existing.characterId != c.id || !existing.status.editable) {
              return EmptyState(
                kind: EmptyKind.notFound,
                title: 'Cette demande ne se modifie plus',
                message: 'Elle a pu être traitée ou annulée.',
                actionLabel: 'Mes demandes',
                onAction: () => context.go('/joueur/demandes'),
              );
            }
            _r = existing.clone();
            _why.text = existing.justification;
          }
        }
        return _body(context, c, requests, rb);
      }, onRetry: () => ref.invalidate(myRequestsProvider));
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }

  Widget _body(BuildContext context, Character c, List<XpRequest> requests, Rulebook rb) {
    final t = Theme.of(context).textTheme;
    final r = _r!;
    final others = [for (final x in requests) if (x.characterId == c.id && x.status.open && x.id != r.id) x];
    final usable = c.xpAvailable - others.fold<int>(0, (s, x) => s + x.total);
    final name = _kind == XpKind.humanity ? humanityName : _name;
    final item = name == null ? null : draftItem(c, r.items, _kind, name, note: _note.text, rb: rb);
    final error = item == null ? null : itemError(c, r.items, item, usable: usable, rb: rb);
    // Un serviteur ajouté à la demande peut y monter de rang.
    final options = elementOptions(_kind == XpKind.servant ? applyRequest(c, r.items, rb: rb) : c, _kind, rb: rb);
    final spec = name == null ? null : noteSpec(_kind, name, rb: rb);
    final rank = (c.genRank ?? GenRank.neonate).label;
    final problems = sendProblems(c, r.items, usable: usable, rb: rb);
    final canSend = r.items.isNotEmpty && problems.isEmpty && _why.text.trim().isNotEmpty && !_busy;

    final addSection = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Ajouter un achat'),
        const SizedBox(height: 14),
        Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<XpKind>(
              key: const Key('xp-kind'),
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final k in XpKind.values) if (k != XpKind.ally && ghoulXpError(c, k) == null) DropdownMenuItem(value: k, child: Text(k.label))],
              onChanged: (k) => setState(() {
                _kind = k ?? _kind;
                _name = null;
                _note.clear();
              }),
            ),
          ),
          if (_kind != XpKind.humanity)
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: ValueKey('xp-name-${_kind.name}'),
                initialValue: options.containsKey(_name) ? _name : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Élément'),
                items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (n) => setState(() {
                  _name = n;
                  _note.clear();
                }),
              ),
            ),
          if (item != null)
            Text(
              '${levelText(item.kind, item.fromLevel)} → ${levelText(item.kind, item.toLevel)} · ${item.cost} XP (${ruleText(c, item, rb: rb)})',
              style: t.bodyLarge,
            ),
        ]),
        if (name != null && ruleCategoryOf(_kind) != null) RuleHint(rb.find(ruleCategoryOf(_kind)!, name)),
        if (_kind == XpKind.flawBuyback) ...[
          const SizedBox(height: 10),
          Text('Coût : 2 fois la valeur du handicap · accord du conte obligatoire', style: t.bodySmall),
        ],
        if (spec != null) ...[
          const SizedBox(height: 14),
          TextField(
            key: const Key('xp-note'),
            controller: _note,
            decoration: InputDecoration(labelText: '${spec.$1} (${spec.$2 ? 'obligatoire' : 'facultatif'})'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: AppColors.linkHover)),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: item == null || error != null
                ? null
                : () => _change(() {
                      r.items.add(item);
                      _note.clear();
                    }),
            child: const Text('Ajouter à la demande'),
          ),
        ),
      ]),
    );

    final content = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.all(18), child: SectionTitle('Contenu de la demande')),
        if (r.items.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: Text('Aucun achat pour l’instant.', style: t.bodySmall)),
        for (final (index, i) in r.items.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 260, child: Text(i.note == null ? i.label : '${i.label} (${i.note})', style: t.bodyMedium)),
              SizedBox(
                width: 110,
                child: Text('${levelText(i.kind, i.fromLevel)} → ${levelText(i.kind, i.toLevel)}', style: const TextStyle(color: AppColors.gold)),
              ),
              SizedBox(width: 200, child: Text(ruleText(c, i, rb: rb), style: t.bodySmall)),
              SizedBox(width: 60, child: Text('${i.cost} XP', textAlign: TextAlign.right, style: t.titleSmall)),
              IconButton(
                tooltip: 'Retirer ${i.displayName}',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  final e = removeItem(r.items, index);
                  if (e == null) {
                    _change(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
                  }
                },
              ),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(child: Text('Total', style: t.titleMedium)),
            Text('${r.total} XP', style: t.headlineSmall?.copyWith(color: AppColors.gold)),
          ]),
        ),
      ]),
    );

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${c.name} / ${r.id.isEmpty ? 'Nouvelle demande' : 'Modifier la demande'}', style: t.bodySmall),
      const SizedBox(height: 6),
      Text('Dépenser de l’XP', style: isWide(context) ? t.displaySmall : t.headlineMedium),
      const SizedBox(height: 6),
      Text(
        'Le coût est calculé selon ${c.ghoul != null ? 'les règles de goule' : 'la génération du personnage ($rank)'}. L’XP est réservée jusqu’à la décision du conte.',
        style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
      ),
      if (r.status == RequestStatus.changes && r.thread.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Le conte : « ${r.thread.last.text} »', style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
      ],
      const SizedBox(height: 24),
      addSection,
      const SizedBox(height: 20),
      content,
      const SizedBox(height: 20),
      TextField(
        key: const Key('xp-why'),
        controller: _why,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Justification en jeu (visible par le conte)',
          hintText: 'Comment le personnage a-t-il appris ou progressé ?',
        ),
        onChanged: (_) => _change(() {}),
      ),
      for (final p in problems) ...[
        const SizedBox(height: 10),
        Text(p, style: const TextStyle(color: AppColors.linkHover)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.end, children: [
        TextButton(onPressed: _leave, child: const Text('Annuler')),
        // À compléter : seul le renvoi est permis (règles : changes → pending).
        if (r.status != RequestStatus.changes)
          OutlinedButton(
            onPressed: r.items.isEmpty || _busy ? null : () => _save(submit: false),
            child: Text(r.status == RequestStatus.draft ? 'Enregistrer le brouillon' : 'Enregistrer'),
          ),
        FilledButton(
          onPressed: canSend ? () => _save(submit: true) : null,
          child: Text('Envoyer au conte · ${r.total} XP'),
        ),
      ]),
    ]);

    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(k, style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
            const SizedBox(width: 8),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: t.bodyMedium)),
          ]),
        );
    final aside = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Solde d’XP'),
          const SizedBox(height: 10),
          line('Disponible', '${c.xpAvailable}'),
          for (final x in others) line('Réservé (${x.summary})', '− ${x.total}'),
          line('Cette demande', '− ${r.total}'),
          const Divider(height: 20),
          Row(children: [
            Expanded(child: Text('Restera libre', style: t.bodyLarge)),
            Text('${usable - r.total}', style: t.headlineMedium?.copyWith(color: AppColors.gold)),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      Panel(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(c.ghoul != null ? 'Coûts pour une goule' : 'Coûts pour un $rank'),
          const SizedBox(height: 10),
          for (final (k, v) in costTable(c, rb: rb)) line(k, v),
          const SizedBox(height: 8),
          Text('La Génération et les atouts de lignée ne s’achètent qu’à la création.', style: t.bodySmall),
        ]),
      ),
    ]);

    if (!isWide(context)) return PageBody(children: [main, const SizedBox(height: 24), aside]);
    return PageBody(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: main),
        const SizedBox(width: 32),
        SizedBox(width: 360, child: aside),
      ]),
    ]);
  }
}
