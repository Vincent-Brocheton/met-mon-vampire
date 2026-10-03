import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/character_screen.dart' show xpText;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'xp_corrections.dart';
import 'xp_repository.dart';
import 'xp_request.dart';

/// « Corrections et remboursements » (C-Correction). Rien ne s'efface : une entrée d'historique par correction.
class CorrectionsScreen extends ConsumerStatefulWidget {
  const CorrectionsScreen({super.key});

  @override
  ConsumerState<CorrectionsScreen> createState() => _CorrectionsScreenState();
}

class _CorrectionsScreenState extends ConsumerState<CorrectionsScreen> {
  String? _sheetId;
  CorrectionKind _kind = CorrectionKind.costError;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _itemKey;
  String? _flaw;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _reset() {
    _amount.clear();
    _reason.clear();
    _itemKey = null;
    _flaw = null;
  }

  Future<void> _save(Character before, Character after) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(xpRepositoryProvider).correct(before, after, _kind, _reason.text, by);
      messenger.showSnackBar(const SnackBar(content: Text('Correction enregistrée.')));
      if (mounted) setState(_reset);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Correction refusée : la fiche a changé entre-temps. Réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.managesAccounts) {
      return const EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Réservé aux conteurs',
        message: 'Les corrections d’XP sont faites par un conteur ou le principal.',
      );
    }
    return asyncView(ref.watch(allCharactersProvider), (chars) {
      final t = Theme.of(context).textTheme;
      final names = {for (final c in chars) c.id: c.name};
      // Les règles (staffEdit) n'acceptent une correction que sur un PNJ ou une fiche jouée ou close.
      final options = [
        for (final c in chars)
          if (c.playerUid != me.uid && (c.kind == CharacterKind.pnj || c.status.settled)) c,
      ];
      final sheet = options.where((c) => c.id == _sheetId).firstOrNull;

      final recent = Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.all(18), child: SectionTitle('Dernières corrections')),
          asyncView(ref.watch(correctionsProvider), (list) {
            if (list.isEmpty) {
              return Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: Text('Aucune correction pour l’instant.', style: t.bodySmall));
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final x in list)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Wrap(spacing: 16, runSpacing: 4, children: [
                    SizedBox(width: 70, child: Text(formatDay(x.entry.at), style: t.bodySmall)),
                    SizedBox(width: 170, child: Text(names[x.characterId] ?? '—', style: t.bodyMedium)),
                    SizedBox(width: 230, child: Text(x.entry.summary.firstOrNull ?? '—', style: t.bodySmall)),
                    SizedBox(width: 260, child: Text(x.entry.reason, style: t.bodyMedium)),
                    SizedBox(width: 70, child: Text(xpText(x.entry), style: t.titleSmall)),
                    Text(x.entry.byName, style: t.bodySmall),
                  ]),
                ),
            ]);
          }, onRetry: () => ref.invalidate(correctionsProvider)),
        ]),
      );

      final form = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Nouvelle correction'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('corr-sheet'),
            initialValue: sheet?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Fiche'),
            items: [for (final c in options) DropdownMenuItem(value: c.id, child: Text('${c.name} · ${c.playerName ?? 'PNJ'}'))],
            onChanged: (id) => setState(() {
              _sheetId = id;
              _reset();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CorrectionKind>(
            key: const Key('corr-kind'),
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final k in CorrectionKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
            onChanged: (k) => setState(() {
              _kind = k ?? _kind;
              _reset();
            }),
          ),
          const SizedBox(height: 12),
          if (sheet != null) _details(context, sheet),
        ]),
      );

      return PageBody(children: [
        const PageTitle(
          'Corrections et remboursements',
          subtitle: 'Rien ne s’efface : chaque correction ajoute une ligne à l’historique de la fiche, avec son motif.',
        ),
        const SizedBox(height: 22),
        if (isWide(context))
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: recent),
            const SizedBox(width: 24),
            SizedBox(width: 440, child: form),
          ])
        else ...[recent, const SizedBox(height: 20), form],
      ]);
    }, onRetry: () => ref.invalidate(allCharactersProvider));
  }

  /// Champs propres au type, aperçu, motif et bouton.
  Widget _details(BuildContext context, Character sheet) {
    final t = Theme.of(context).textTheme;
    Widget tail(XpItem? item) {
      final amount = int.tryParse(_amount.text.trim()) ?? 0;
      final touched = switch (_kind) {
        CorrectionKind.costError || CorrectionKind.refund => _amount.text.trim().isNotEmpty,
        CorrectionKind.cancelPurchase => item != null,
        CorrectionKind.forcedBuyback => _flaw != null,
      };
      final result = applyCorrection(sheet, _kind, amount: amount, item: item, flaw: _flaw);
      final after = result.after;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (touched && result.error != null) Text(result.error!, style: const TextStyle(color: AppColors.linkHover)),
        if (after != null)
          Text(correctionPreview(sheet, after), key: const Key('corr-preview'), style: t.titleMedium?.copyWith(color: AppColors.gold)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('corr-reason'),
          controller: _reason,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motif (obligatoire)', helperText: 'Visible par le joueur dans son historique'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: after == null || _reason.text.trim().isEmpty || _busy ? null : () => _save(sheet, after),
            child: const Text('Enregistrer la correction'),
          ),
        ),
      ]);
    }

    switch (_kind) {
      case CorrectionKind.costError || CorrectionKind.refund:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            key: const Key('corr-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: _kind == CorrectionKind.costError ? 'XP à rendre (+) ou à reprendre (−)' : 'XP à rendre',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          tail(null),
        ]);
      case CorrectionKind.forcedBuyback:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            key: const Key('corr-flaw'),
            initialValue: _flaw,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Handicap'),
            items: [for (final f in sheet.flaws) DropdownMenuItem(value: f.name, child: Text('${f.name} (${f.level})'))],
            onChanged: (f) => setState(() => _flaw = f),
          ),
          const SizedBox(height: 12),
          tail(null),
        ]);
      case CorrectionKind.cancelPurchase:
        return asyncView(ref.watch(characterRequestsProvider(sheet.id)), (requests) {
          final purchases = {
            for (final r in requests)
              if (r.status == RequestStatus.accepted)
                for (final (i, item) in r.items.indexed)
                  '${r.id}/$i': (
                    item,
                    '${item.label} ${levelText(item.kind, item.toLevel)} · achat du ${formatDay(r.decidedAt)} · ${item.cost} XP',
                  ),
          };
          final item = purchases[_itemKey]?.$1;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              key: const Key('corr-item'),
              initialValue: purchases.containsKey(_itemKey) ? _itemKey : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: purchases.isEmpty ? 'Aucun achat validé sur cette fiche' : 'Achat à annuler'),
              items: [for (final e in purchases.entries) DropdownMenuItem(value: e.key, child: Text(e.value.$2))],
              onChanged: (k) => setState(() => _itemKey = k),
            ),
            const SizedBox(height: 12),
            tail(item),
          ]);
        }, onRetry: () => ref.invalidate(characterRequestsProvider(sheet.id)));
    }
  }
}
