import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart' show dots;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rule_entry.dart' show nameKey;
import '../rulebook/rulebook.dart';
import '../rulebook/rulebook_provider.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import '../xp/xp_rules.dart';
import 'allies_repository.dart';
import 'ally_fields.dart';
import 'ally_file.dart';
import 'ally_rules.dart';

/// Alliés demandés dans les demandes ouvertes du personnage (nom en clé de comparaison).
Set<String> pendingAllyNames(List<XpRequest> requests, String characterId) => {
      for (final r in requests)
        if (r.characterId == characterId && r.status.open)
          for (final i in r.items)
            if (i.kind == XpKind.ally) nameKey(i.name),
    };

/// « Alliés » d'un personnage (J-Allies) : ses alliés, leur disponibilité, et la demande d'un allié ou d'un niveau.
class CharacterAlliesScreen extends ConsumerStatefulWidget {
  const CharacterAlliesScreen({super.key, required this.characterId});
  final String characterId;

  @override
  ConsumerState<CharacterAlliesScreen> createState() => _CharacterAlliesScreenState();
}

class _CharacterAlliesScreenState extends ConsumerState<CharacterAlliesScreen> {
  Ally _draft = Ally('', '');
  Ally? _upFrom;
  final _why = TextEditingController();
  bool _tried = false;
  bool _busy = false;

  /// Incrémenté à chaque nouveau formulaire : les champs repartent de [_draft].
  int _form = 0;

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _draft = Ally('', '');
        _upFrom = null;
        _why.clear();
        _tried = false;
        _form++;
      });

  void _levelUp(Ally a) => setState(() {
        _upFrom = a;
        _draft = a.copy()..level = a.level + 1;
        _why.clear();
        _tried = false;
        _form++;
      });

  XpItem _item(Character c, Rulebook rb) {
    final from = _upFrom?.level ?? 0;
    final draft = XpItem(XpKind.ally, _draft.name, from, _draft.level, 0, ally: allyData(_draft));
    return XpItem(XpKind.ally, _draft.name, from, _draft.level, costOf(c, draft, rb: rb), ally: allyData(_draft));
  }

  List<String> _errors(Character c, Rulebook rb, int usable) {
    final item = _item(c, rb);
    return [
      ...allyChecks(_draft, rb),
      if (_upFrom == null && c.allies.any((a) => nameKey(a.name) == nameKey(_draft.name))) 'Un allié porte déjà ce nom.',
      if (item.cost > usable) 'XP libre insuffisante : ${item.cost} requis, $usable disponible.',
      if (_why.text.trim().isEmpty) 'Indiquez comment vous l’avez rencontré.',
    ];
  }

  Future<void> _send(Character c, Rulebook rb, int usable) async {
    if (_errors(c, rb, usable).isNotEmpty) {
      setState(() => _tried = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(xpRepositoryProvider).save(
            XpRequest(
              characterId: c.id,
              characterName: c.name,
              playerUid: c.playerUid ?? '',
              playerName: c.playerName ?? '',
              items: [_item(c, rb)],
              justification: _why.text.trim(),
            ),
            submit: true,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Demande envoyée au conte.')));
      if (mounted) _reset();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Envoi refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rb = ref.watch(rulebookProvider);
    if (rb == null) return const Center(child: CircularProgressIndicator());
    // Garde la session écoutée : l'envoi passe par le dépôt de l'XP.
    ref.watch(currentUserProvider);
    final requests = ref.watch(myRequestsProvider).value ?? const <XpRequest>[];
    final files = ref.watch(characterAllyFilesProvider(widget.characterId)).value ?? const <AllyFile>[];
    return asyncView(ref.watch(characterProvider(widget.characterId)), (c) {
      if (c == null) return const EmptyState(kind: EmptyKind.notFound, title: 'Fiche introuvable', message: 'Elle a pu être retirée.');
      final now = DateTime.now();
      final pending = pendingAllyNames(requests, c.id);
      final byId = {for (final f in files) f.id: f};
      final usable = c.xpAvailable - reservedBy(requests, c.id);
      final requested = [
        for (final r in requests)
          if (r.characterId == c.id && r.status.open)
            for (final i in r.items)
              if (i.kind == XpKind.ally && !c.allies.any((a) => nameKey(a.name) == nameKey(i.name))) allyOfItem(i),
      ];
      final active = c.status == CharacterStatus.active;

      Widget card(Ally a, {required bool onSheet}) {
        final waiting = pending.contains(nameKey(a.name));
        final status = allyStatus(pending: waiting, returnAt: byId[a.id]?.returnAt, now: now);
        return Panel(
          key: Key('al-card-${a.id.isEmpty ? a.name : a.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(a.name, style: t.headlineSmall)),
              Text('●' * a.level + '○' * (allyMaxLevel(rb) - a.level).clamp(0, 99), style: const TextStyle(color: AppColors.gold, letterSpacing: 2)),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (label, color) in [(a.type, AppColors.gold), (a.domain, null)])
                  if (label.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(999)),
                      child: Text(label, style: t.bodySmall?.copyWith(color: color)),
                    ),
              ]),
            ),
            Text([if (a.influence > 0) 'Influence ${a.influence}', ...a.specialties].join(' · '), style: t.bodyMedium),
            Text(status, style: t.bodySmall?.copyWith(color: status == 'Disponible' ? AppColors.success : AppColors.goldLight, fontWeight: FontWeight.w600)),
            if (onSheet && active && !waiting && a.level < allyMaxLevel(rb))
              TextButton(key: Key('al-up-${a.id}'), onPressed: () => _levelUp(a), child: const Text('Monter d’un niveau')),
          ]),
        );
      }

      final cards = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (c.allies.isEmpty && requested.isEmpty) Text('Aucun allié.', style: t.bodyMedium),
        for (final a in c.allies) Padding(padding: const EdgeInsets.only(bottom: 12), child: card(a, onSheet: true)),
        for (final a in requested) Padding(padding: const EdgeInsets.only(bottom: 12), child: card(a, onSheet: false)),
        for (final l in legacyAllies(c)) Text('Ancien historique à convertir par le conte : ${l.name} ${dots(l.level)}', style: t.bodySmall),
      ]);

      Widget? form;
      if (active) {
        final errors = _errors(c, rb, usable);
        final cost = _item(c, rb).cost;
        form = Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: SectionTitle(_upFrom == null ? 'Nouvel allié · demande au conte' : 'Monter ${_upFrom!.name} d’un niveau')),
              if (_upFrom != null) TextButton(key: const Key('al-new'), onPressed: _reset, child: const Text('Nouvel allié')),
            ]),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: ValueKey('ally-form-$_form'),
              child: AllyFields(
                ally: _draft,
                rb: rb,
                prefix: 'al',
                onChanged: () => setState(() {}),
                nameEditable: _upFrom == null,
                minLevel: _upFrom == null ? 1 : _upFrom!.level + 1,
                maxLevel: _upFrom == null ? null : _upFrom!.level + 1,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('al-why'),
              controller: _why,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Comment l’avez-vous rencontré ?'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('Coût : $cost XP · XP libre : $usable', style: t.bodySmall),
            if (_tried)
              for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
            const SizedBox(height: 8),
            FilledButton(key: const Key('al-send'), onPressed: _busy ? null : () => _send(c, rb, usable), child: const Text('Envoyer la demande')),
          ]),
        );
      }

      final title = PageTitle('Alliés', subtitle: 'Les alliés de ${c.name} remplacent les anciens historiques Influence, Alliés et Contacts.');
      if (!isWide(context)) return PageBody(children: [title, const SizedBox(height: 20), cards, if (form != null) ...[const SizedBox(height: 20), form]]);
      return PageBody(children: [
        title,
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 460, child: cards),
          if (form != null) ...[const SizedBox(width: 24), Expanded(child: form)],
        ]),
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }
}

/// Section « Alliés » de la fiche (J2) : alliés, disponibilité, anciens historiques, lien.
class AlliesSection extends ConsumerWidget {
  const AlliesSection({super.key, required this.character, required this.link});
  final Character character;
  final String link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final files = ref.watch(characterAllyFilesProvider(character.id)).value ?? const <AllyFile>[];
    final byId = {for (final f in files) f.id: f};
    final now = DateTime.now();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Alliés'),
        const SizedBox(height: 8),
        if (character.allies.isEmpty) Text('Aucun allié.', style: t.bodySmall),
        for (final a in character.allies)
          Text('${a.name} · ${dots(a.level)} · ${allyStatus(pending: false, returnAt: byId[a.id]?.returnAt, now: now)}', style: t.bodyMedium),
        for (final l in legacyAllies(character)) Text('À convertir par le conte : ${l.name} ${dots(l.level)}', style: t.bodySmall),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go(link), child: const Text('Voir les alliés'))),
      ]),
    );
  }
}
