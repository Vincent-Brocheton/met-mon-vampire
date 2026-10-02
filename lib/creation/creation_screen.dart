import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rules/creation_rules.dart';
import 'creation_steps.dart';

/// Création guidée en 10 étapes (J-Creation-1 à 10). Le brouillon s'enregistre seul.
class CreationScreen extends ConsumerStatefulWidget {
  const CreationScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CreationScreen> createState() => _CreationScreenState();
}

class _CreationScreenState extends ConsumerState<CreationScreen> {
  Character? _c; // brouillon local
  Character? _base; // dernière version connue du serveur
  int _step = 1;
  Timer? _debounce;
  bool _pending = false;
  bool _saving = false;
  bool _failed = false;
  DateTime? _savedAt;
  late final CharacterRepository _repo; // ref n'est plus utilisable dans dispose
  Future<void>? _inFlight;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(characterRepositoryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_pending && _c != null) {
      // Review Focus 2 : la saisie part même si l'on quitte avant le délai,
      // après l'enregistrement en cours (sa version devient la base).
      final draft = _c!.clone();
      (_inFlight ?? Future<void>.value())
          .catchError((_) {})
          .then((_) => _repo.saveDraft(draft..version = _base!.version))
          .ignore();
    }
    super.dispose();
  }

  void _changed() {
    applyDerived(_c!);
    setState(() {});
    _pending = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _save);
  }

  Future<void> _save() async {
    _debounce?.cancel();
    final c = _c;
    if (c == null || !_pending) return;
    if (_saving) {
      _debounce = Timer(const Duration(milliseconds: 500), _save);
      return;
    }
    _saving = true;
    _pending = false;
    final sent = c.clone();
    try {
      // La base suit l'envoi dans le même futur : dispose() enchaîne dessus.
      await (_inFlight = _repo.saveDraft(sent).then((_) {
        // Le brouillon a pu changer pendant l'envoi : on ne touche qu'à la version.
        _base = sent.clone()..version = sent.version + 1;
        c.version = _base!.version;
      }));
      if (mounted) {
        setState(() {
          _failed = false;
          _savedAt = DateTime.now();
        });
      }
    } catch (_) {
      // Refus (version dépassée) ou réseau : build() reprend la nouvelle version, puis on réessaie.
      _pending = true;
      if (mounted) {
        setState(() => _failed = true);
        _debounce = Timer(const Duration(seconds: 3), _save);
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _goTo(int step) async {
    final c = _c!;
    c.step = max(c.step, step);
    _pending = true;
    await _save();
    if (mounted) setState(() => _step = step);
  }

  Future<void> _submit() async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Soumettre au conte'),
        content: const Text('Une fois soumise, la fiche est verrouillée jusqu’à la réponse du conte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Soumettre')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _pending = true;
    await _save();
    try {
      await _repo.submit(_c!, by);
      _pending = false;
      if (mounted) context.go('/joueur/personnages/${widget.id}/soumise');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soumission impossible. Réessayez.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    return asyncView(ref.watch(characterProvider(widget.id)), (latest) {
      if (latest == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      if (me == null) return const Center(child: CircularProgressIndicator());
      if (latest.playerUid != me.uid || (_c == null && latest.status != CharacterStatus.draft)) {
        return EmptyState(
          kind: EmptyKind.forbidden,
          title: 'Cette fiche n’est pas en brouillon',
          message: 'Seul le joueur remplit sa fiche, et seulement tant qu’elle est en brouillon.',
          actionLabel: 'Voir la fiche',
          onAction: () => context.go('/joueur/personnages/${widget.id}'),
        );
      }
      if (_c == null) {
        _c = latest.clone();
        _base = latest;
        applyDerived(_c!);
        _step = latest.step.clamp(1, 10);
      } else if (!_saving && latest.version > _base!.version) {
        // Review Focus 1 : autre version (bonus du conte) ; on repart d'elle en gardant la saisie.
        _c = rebase(_base!, _c!, latest);
        _base = latest;
        applyDerived(_c!);
      }
      final c = _c!;
      final checks = creationChecks(c);
      final t = Theme.of(context).textTheme;
      final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Étape $_step sur 10 · ${c.name.isEmpty ? 'Nouveau personnage' : c.name}', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Text(creationSteps[_step - 1], style: isWide(context) ? t.displaySmall : t.headlineMedium),
        const SizedBox(height: 8),
        Text(stepIntro[_step - 1], style: t.bodyLarge?.copyWith(color: AppColors.textSecondary)),
      ]);
      final footer = Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
          if (_step > 1)
            OutlinedButton(onPressed: () => _goTo(_step - 1), child: const Text('Précédent'))
          else
            TextButton(
              onPressed: () async {
                await _save();
                if (context.mounted) context.go('/joueur');
              },
              child: const Text('Quitter (brouillon conservé)'),
            ),
          Text(
            _failed
                ? 'Non enregistré, nouvel essai…'
                : _savedAt == null
                    ? ''
                    : 'Brouillon enregistré à ${_savedAt!.hour}:${_savedAt!.minute.toString().padLeft(2, '0')}',
            style: t.bodySmall?.copyWith(color: _failed ? AppColors.linkHover : AppColors.textMuted),
          ),
          if (_step < 10)
            FilledButton(onPressed: () => _goTo(_step + 1), child: Text('Suivant : ${creationSteps[_step]}'))
          else
            FilledButton(onPressed: canSubmit(checks) ? _submit : null, child: const Text('Soumettre au conte')),
        ]),
      );
      final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 24),
        KeyedSubtree(key: ValueKey('step-$_step'), child: creationStep(_step, c, _changed)),
        const SizedBox(height: 24),
        footer,
      ]);
      final aside = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _BudgetPanel(c),
        const SizedBox(height: 20),
        _ChecksPanel(checks),
      ]);
      final nav = _StepNav(current: _step, complete: (s) => stepComplete(c, s, checks), onTap: _goTo);
      if (!isWide(context)) {
        return PageBody(children: [nav, const SizedBox(height: 20), content, const SizedBox(height: 24), aside]);
      }
      return PageBody(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 240, child: nav),
          const SizedBox(width: 32),
          Expanded(child: content),
          const SizedBox(width: 32),
          SizedBox(width: 300, child: aside),
        ]),
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(widget.id)));
  }
}

class _StepNav extends StatelessWidget {
  const _StepNav({required this.current, required this.complete, required this.onTap});
  final int current;
  final bool Function(int) complete;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    Widget item(int s) {
      final selected = s == current;
      final done = complete(s);
      final label = Text(
        creationSteps[s - 1],
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: selected ? AppColors.text : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
      );
      return InkWell(
        onTap: () => onTap(s),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: selected ? AppColors.navActive : null, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: done ? AppColors.activeBg : (selected ? AppColors.accent : Colors.transparent),
              child: done
                  ? const Icon(Icons.check, size: 14, color: AppColors.success)
                  : Text('$s', style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textMuted)),
            ),
            const SizedBox(width: 10),
            wide ? Expanded(child: label) : label,
          ]),
        ),
      );
    }

    if (!wide) {
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (var s = 1; s <= 10; s++) item(s)]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Création · brouillon'),
      const SizedBox(height: 12),
      for (var s = 1; s <= 10; s++) item(s),
    ]);
  }
}

class _BudgetPanel extends StatelessWidget {
  const _BudgetPanel(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = budgetOf(c);
    return Panel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Budget XP initial'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('Restant', style: t.bodyMedium)),
          Text('${b.remaining}', style: t.headlineMedium?.copyWith(color: b.remaining < 0 ? AppColors.linkHover : AppColors.gold)),
        ]),
        Text('$startingXp de départ · ${b.bonus} bonus · ${b.flaws} via handicaps · ${b.spent} dépensé', style: t.bodySmall),
        const SizedBox(height: 6),
        Text('5 XP au plus peuvent être mis de côté à la fin de la création.', style: t.bodySmall),
      ]),
    );
  }
}

class _ChecksPanel extends StatelessWidget {
  const _ChecksPanel(this.checks);
  final List<Check> checks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    (IconData, Color) look(CheckLevel l) => switch (l) {
          CheckLevel.ok => (Icons.check_circle_outline, AppColors.success),
          CheckLevel.todo => (Icons.radio_button_unchecked, AppColors.textMuted),
          CheckLevel.warn => (Icons.info_outline, AppColors.goldLight),
          CheckLevel.error => (Icons.error_outline, AppColors.linkHover),
        };
    return Panel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Contrôles des règles'),
        const SizedBox(height: 10),
        for (final k in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(look(k.level).$1, size: 18, color: look(k.level).$2),
              const SizedBox(width: 8),
              Expanded(child: Text(k.text, style: t.bodyMedium?.copyWith(fontSize: 14))),
            ]),
          ),
        const SizedBox(height: 8),
        Text('À la fin, la fiche est soumise au conte. Vous ne pourrez plus la modifier tant qu’elle est en validation.', style: t.bodySmall),
      ]),
    );
  }
}
