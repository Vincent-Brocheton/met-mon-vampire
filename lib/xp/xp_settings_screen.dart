import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rulebook.dart';
import 'xp_gain.dart';
import 'xp_repository.dart';
import 'xp_settings.dart';

/// `/conteur/parametres` : menu des paramètres de la chronique.
class ParametersScreen extends ConsumerWidget {
  const ParametersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principal = ref.watch(currentUserProvider).value?.role == Role.principal;
    final entries = [
      ('Expérience', 'XP de création, gain mensuel par paliers.', '/conteur/parametres/xp'),
      ('Liste de démarrage', 'Les étapes pour ouvrir la chronique.', '/conteur/demarrage'),
      // L'équipe est gérée par le principal seul (redirect.dart).
      if (principal) ('Équipe de conteurs', 'Rôles et invitations.', '/conteur/equipe'),
      ('Journal de la chronique', 'À venir.', null),
    ];
    return PageBody(children: [
      const PageTitle('Paramètres de la chronique'),
      const SizedBox(height: 22),
      for (final (title, subtitle, path) in entries) ...[
        Panel(
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: path == null ? null : const Icon(Icons.chevron_right),
            enabled: path != null,
            onTap: path == null ? null : () => context.go(path),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class _TierRow {
  _TierRow(XpTier t)
      : years = TextEditingController(text: t.months == null ? '' : '${t.months! ~/ 12}'),
        xp = TextEditingController(text: '${t.xp}'),
        every = TextEditingController(text: '${t.every}');

  final TextEditingController years, xp, every;

  void dispose() {
    years.dispose();
    xp.dispose();
    every.dispose();
  }
}

/// « Paramètres d'expérience » (C-Parametres, partie Expérience).
class XpSettingsScreen extends ConsumerStatefulWidget {
  const XpSettingsScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<XpSettingsScreen> createState() => _XpSettingsScreenState();
}

class _XpSettingsScreenState extends ConsumerState<XpSettingsScreen> {
  XpSettings? _saved;
  bool _enabled = false;
  String? _since;
  List<_TierRow> _rows = [];
  bool _busy = false;
  static const _creationKeys = [
    'startingXp', 'defaultBonus', 'maxFlawXp', 'maxSetAside', 'attributeSlots', 'skillSlots', 'backgroundSlots', 'disciplineSlots',
  ];
  final _creation = {for (final k in _creationKeys) k: TextEditingController()};

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    for (final c in _creation.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(XpSettings s) {
    for (final r in _rows) {
      r.dispose();
    }
    _saved = s;
    _enabled = s.monthlyEnabled;
    _since = s.gainSince ?? monthKey(widget.now());
    _rows = [for (final t in s.tiers) _TierRow(t)];
    final v = s.creation;
    _creation['startingXp']!.text = '${v.startingXp}';
    _creation['defaultBonus']!.text = '${v.defaultBonus}';
    _creation['maxFlawXp']!.text = '${v.maxFlawXp}';
    _creation['maxSetAside']!.text = '${v.maxSetAside}';
    _creation['attributeSlots']!.text = v.attributeSlots.join(' / ');
    _creation['skillSlots']!.text = slotsText(v.skillSlots);
    _creation['backgroundSlots']!.text = v.backgroundSlots.join(' / ');
    _creation['disciplineSlots']!.text = v.disciplineSlots.join(' / ');
  }

  /// Paliers saisis, ou le premier message d'erreur.
  (List<XpTier>?, String?) _parse() {
    final out = <XpTier>[];
    for (final (i, r) in _rows.indexed) {
      final last = i == _rows.length - 1;
      final xp = int.tryParse(r.xp.text.trim());
      final every = int.tryParse(r.every.text.trim());
      final years = last ? null : int.tryParse(r.years.text.trim());
      if (xp == null || xp < 0 || xp > 20) return (null, 'Palier ${i + 1} : le gain va de 0 à 20 XP.');
      if (every == null || every < 1 || every > 12) return (null, 'Palier ${i + 1} : « tous les » va de 1 à 12 mois.');
      if (!last && (years == null || years < 1 || years > 50)) return (null, 'Palier ${i + 1} : la durée va de 1 à 50 ans.');
      out.add(XpTier(years == null ? null : years * 12, xp, every));
    }
    return (out, null);
  }

  /// Valeurs de création saisies, ou le premier message d'erreur.
  (CreationValues?, String?) _parseCreation() {
    List<int>? slots(String k) {
      final v = [for (final m in RegExp(r'\d+').allMatches(_creation[k]!.text)) int.parse(m.group(0)!)];
      return v.isEmpty || v.any((x) => x < 1 || x > 10) ? null : v;
    }

    int? count(String k, int most) {
      final n = int.tryParse(_creation[k]!.text.trim());
      return n == null || n < 0 || n > most ? null : n;
    }

    final a = slots('attributeSlots'), s = slots('skillSlots'), b = slots('backgroundSlots'), d = slots('disciplineSlots');
    if (a == null || a.length != 3) return (null, 'Attributs : trois valeurs, par exemple 7 / 5 / 3.');
    if (s == null) return (null, 'Compétences : des valeurs de 1 à 10, par exemple 4 / 3-3 / 2-2-2 / 1-1-1-1.');
    if (b == null) return (null, 'Historiques : des valeurs de 1 à 10, par exemple 3 / 2 / 1.');
    if (d == null || d.length != 3) return (null, 'Disciplines en clan : trois valeurs, par exemple 2 / 1 / 1.');
    final start = count('startingXp', 200), bonus = count('defaultBonus', 100), flaws = count('maxFlawXp', 50), aside = count('maxSetAside', 50);
    if (start == null || bonus == null || flaws == null || aside == null) return (null, 'XP de création : des nombres entiers positifs.');
    return (
      CreationValues(
        attributeSlots: a,
        skillSlots: s,
        backgroundSlots: b,
        disciplineSlots: d,
        startingXp: start,
        defaultBonus: bonus,
        maxFlawXp: flaws,
        maxSetAside: aside,
      ),
      null,
    );
  }

  Future<void> _save(List<XpTier> tiers, CreationValues creation) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(xpRepositoryProvider).saveSettings(XpSettings(monthlyEnabled: _enabled, gainSince: _since, tiers: tiers, creation: creation), by);
      messenger.showSnackBar(const SnackBar(content: Text('Paramètres d’expérience enregistrés.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement impossible. Réessayez.')));
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
        message: 'Les paramètres de la chronique se règlent par un conteur ou le principal.',
      );
    }
    return asyncView(ref.watch(xpSettingsProvider), (s) {
      // Premier chargement, ou paramètres enregistrés depuis (ici ou par un autre conteur).
      if (_saved == null || s.updatedAt != _saved!.updatedAt) _load(s);
      return _body(context);
    }, onRetry: () => ref.invalidate(xpSettingsProvider));
  }

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (tiers, error) = _parse();
    final (creation, creationError) = _parseCreation();
    final current = monthIndex(monthKey(widget.now()));
    final months = {for (var m = current - 12; m <= current + 12; m++) keyOfIndex(m), ?_since};
    Widget field(Key key, TextEditingController c, String label, double width) => SizedBox(
          width: width,
          child: TextField(
            key: key,
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
        );
    Widget slotField(String key, String label) => SizedBox(
          width: 230,
          child: TextField(
            key: Key('creation-$key'),
            controller: _creation[key],
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
        );
    String perYear(_TierRow r) {
      final xp = int.tryParse(r.xp.text.trim()), every = int.tryParse(r.every.text.trim());
      if (xp == null || every == null || every <= 0) return '—';
      final v = xp * 12 / every;
      return v == v.roundToDouble() ? '${v.round()} XP par an' : '${v.toStringAsFixed(1).replaceAll('.', ',')} XP par an';
    }

    return PageBody(children: [
      const PageTitle(
        'Expérience',
        subtitle: 'L’XP de création et le gain mensuel. Les bonus ponctuels se donnent dans « XP », « Attribuer un bonus d’XP ».',
      ),
      const SizedBox(height: 22),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('XP de création'),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 10, children: [
            field(const Key('creation-startingXp'), _creation['startingXp']!, 'XP de départ', 150),
            field(const Key('creation-defaultBonus'), _creation['defaultBonus']!, 'Bonus de départ par défaut', 220),
            field(const Key('creation-maxFlawXp'), _creation['maxFlawXp']!, 'Maximum via handicaps', 200),
            field(const Key('creation-maxSetAside'), _creation['maxSetAside']!, 'Maximum mis de côté', 200),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 10, children: [
            slotField('attributeSlots', 'Attributs'),
            slotField('skillSlots', 'Compétences'),
            slotField('backgroundSlots', 'Historiques'),
            slotField('disciplineSlots', 'Disciplines en clan'),
          ]),
          if (creationError != null) ...[
            const SizedBox(height: 8),
            Text(creationError, style: const TextStyle(color: AppColors.linkHover)),
          ],
          const SizedBox(height: 6),
          Text(
            'Le bonus de départ s’ajoute à l’XP de départ de chaque fiche en création. Une fiche déjà soumise est '
            'calculée avec les anciennes valeurs : renvoyez-la au joueur pour qu’il la réenregistre.',
            style: t.bodySmall,
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Gain mensuel d’XP'),
          SwitchListTile(
            key: const Key('gain-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Activé'),
            value: _enabled,
            onChanged: (v) => setState(() {
              // Réactivé : on repart du mois courant, sans rattraper les mois où le gain était coupé.
              final current = monthKey(widget.now());
              if (v && !_enabled && (_since == null || monthIndex(_since!) < monthIndex(current))) _since = current;
              _enabled = v;
            }),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              key: const Key('gain-since'),
              initialValue: _since,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Versé à partir de'),
              items: [for (final m in months) DropdownMenuItem(value: m, child: Text(monthLabel(m)))],
              onChanged: (m) => setState(() => _since = m ?? _since),
            ),
          ),
          const SizedBox(height: 10),
          Text('PJ actifs uniquement (ni PNJ, ni brouillons). Préparé par l’application, versé par un conteur.', style: t.bodySmall),
        ]),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Paliers selon l’ancienneté'),
          const SizedBox(height: 10),
          for (final (i, r) in _rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 80, child: Text('Palier ${i + 1}', style: t.titleSmall)),
                if (i == _rows.length - 1)
                  const SizedBox(width: 150, child: Text('Ensuite, sans limite'))
                else
                  field(Key('tier-$i-years'), r.years, 'Pendant (ans)', 150),
                field(Key('tier-$i-xp'), r.xp, 'Gain (XP)', 110),
                field(Key('tier-$i-every'), r.every, 'Tous les (mois)', 130),
                SizedBox(width: 130, child: Text(perYear(r), style: t.bodySmall)),
                if (_rows.length > 1)
                  IconButton(
                    tooltip: 'Retirer le palier ${i + 1}',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _rows.removeAt(i).dispose();
                      if (i == _rows.length) _rows.last.years.clear();
                    }),
                  ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('tier-add'),
              onPressed: () => setState(() {
                _rows.last.years.text = '1';
                _rows.add(_TierRow(XpTier(null, int.tryParse(_rows.last.xp.text) ?? 1, int.tryParse(_rows.last.every.text) ?? 1)));
              }),
              child: const Text('+ Ajouter un palier'),
            ),
          ),
          if (error != null) Text(error, style: const TextStyle(color: AppColors.linkHover)),
          if (tiers != null)
            Wrap(spacing: 18, runSpacing: 6, children: [
              for (final y in [1, 3, 6, 8, 10])
                Text('Après $y ${y == 1 ? 'an' : 'ans'} : ${gainOver(tiers, y * 12)} XP', style: t.bodyMedium),
            ]),
        ]),
      ),
      const SizedBox(height: 16),
      Text('Les changements s’appliquent aux versements futurs ; l’XP déjà versée ne change pas.', style: t.bodySmall),
      if (_saved?.updatedByName != null)
        Text('Dernière modification par ${_saved!.updatedByName} le ${formatDay(_saved!.updatedAt)}.', style: t.bodySmall),
      const SizedBox(height: 12),
      Wrap(spacing: 12, alignment: WrapAlignment.end, children: [
        TextButton(onPressed: () => setState(() => _load(_saved!)), child: const Text('Annuler')),
        FilledButton(
          onPressed: tiers == null || creation == null || _busy ? null : () => _save(tiers, creation),
          child: const Text('Enregistrer'),
        ),
      ]),
    ]);
  }
}
