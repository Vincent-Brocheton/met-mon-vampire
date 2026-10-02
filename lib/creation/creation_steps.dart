import 'package:flutter/material.dart';

import '../characters/character.dart';
import '../characters/edit_widgets.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rules/creation_rules.dart';
import '../rules/met_lists.dart';

const stepIntro = [
  'Qui est votre personnage ? Donnez-lui un nom, un concept et un archétype. Le récit complet se rédige à la dernière étape.',
  'Votre personnage commence avec 30 XP. Vous les dépenserez au fil des étapes suivantes.',
  'Le clan fixe vos trois disciplines en clan. Un clan peu commun ou rare coûte un atout.',
  'Classez les trois catégories : 7 points pour la primaire, 5 pour la secondaire, 3 pour la tertiaire. Choisissez ensuite un focus par catégorie.',
  'Une compétence à 4, deux à 3, trois à 2, quatre à 1. Artisanat, Représentation et Sciences demandent un domaine précis.',
  'Trois points dans un historique, deux dans un autre, un dans un troisième. Sans aucun point de Génération, le personnage est un mortel.',
  'Choisissez la discipline en clan qui reçoit 2 points ; les deux autres en reçoivent 1.',
  'Les atouts se paient en XP, 7 points au plus (rareté de clan comprise). Les handicaps rapportent de l’XP, 7 au plus.',
  'Dépensez l’XP restante. Les coûts dépendent de votre génération ; ils sont calculés automatiquement.',
  'Les traits dérivés sont calculés automatiquement. Ajoutez le récit du personnage, puis soumettez la fiche au conte.',
];

/// Contenu de l'étape [step] ; [changed] après chaque modification de [c].
Widget creationStep(int step, Character c, VoidCallback changed) => switch (step) {
      1 => _Inspiration(c, changed),
      2 => _InitialXp(c),
      3 => _ClanStep(c, changed),
      4 => _AttributesStep(c, changed),
      5 => _SkillsStep(c, changed),
      _ => Text('Étape $step', key: const Key('step-todo')),
    };

/// Points gratuits cliquables ; [bought] points achetés affichés en plus.
class DotPicker extends StatelessWidget {
  const DotPicker({super.key, required this.label, required this.value, required this.max, required this.onChanged, this.bought = 0});

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final int bought;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= max; i++)
          IconButton(
            tooltip: '$label : $i',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value == i ? i - 1 : i),
            icon: Icon(i <= value ? Icons.circle : Icons.circle_outlined, size: 14, color: AppColors.gold),
          ),
        if (bought > 0) Text('+$bought', style: const TextStyle(color: AppColors.goldLight, fontSize: 13)),
      ]);
}

Widget _section(BuildContext context, String title, List<Widget> children) => Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title.isNotEmpty) ...[SectionTitle(title), const SizedBox(height: 12)],
        for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: 14), w],
      ]),
    );

class _Inspiration extends StatelessWidget {
  const _Inspiration(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    void set(void Function() f) {
      f();
      changed();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(context, '', [
        TextFieldRow(label: 'Nom du personnage', value: c.name, onChanged: (v) => set(() => c.name = v ?? '')),
        ChoiceField(label: 'Secte', value: c.sect, options: sects, onChanged: (v) => set(() => c.sect = v)),
        TextFieldRow(label: 'Concept — en une phrase', value: c.concept, onChanged: (v) => set(() => c.concept = v)),
        ChoiceField(label: 'Archétype', value: c.archetype, options: archetypes, onChanged: (v) => set(() => c.archetype = v)),
      ]),
      const SizedBox(height: 20),
      _section(context, 'Trois questions pour vous guider — facultatif', [
        TextFieldRow(label: 'Qui étiez-vous avant l’Étreinte ?', value: c.inspirationBefore, maxLines: 2, onChanged: (v) => set(() => c.inspirationBefore = v)),
        TextFieldRow(label: 'Pourquoi avez-vous été étreint ?', value: c.inspirationEmbrace, maxLines: 2, onChanged: (v) => set(() => c.inspirationEmbrace = v)),
        TextFieldRow(label: 'Qui êtes-vous devenu ?', value: c.inspirationBecame, maxLines: 2, onChanged: (v) => set(() => c.inspirationBecame = v)),
      ]),
    ]);
  }
}

class _InitialXp extends StatelessWidget {
  const _InitialXp(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = budgetOf(c);
    Widget card(String title, String value, String hint) => SizedBox(
          width: 240,
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionTitle(title),
              const SizedBox(height: 6),
              Text(value, style: t.displayMedium?.copyWith(color: AppColors.gold)),
              Text(hint, style: t.bodySmall),
            ]),
          ),
        );
    const rules = [
      'Les handicaps choisis à l’étape 8 rapportent de l’XP en plus, 7 au maximum.',
      'Un clan peu commun ou rare se paie en atouts avec cette XP.',
      'La Génération ne s’achète qu’à la création.',
      'À la fin, 5 XP au plus peuvent être mis de côté ; le surplus est perdu.',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 16, runSpacing: 16, children: [
        card('XP de départ', '$startingXp', 'Pour tous les personnages'),
        card('Bonus du conte', '${c.xpBonus}', 'Fixé par un conteur'),
        card('Handicaps', '+ ${b.flaws}', 'Jusqu’à 7 XP, à l’étape 8'),
      ]),
      const SizedBox(height: 20),
      _section(context, 'À savoir', [for (final r in rules) Text('• $r', style: t.bodyMedium)]),
    ]);
  }
}

class _ClanStep extends StatelessWidget {
  const _ClanStep(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget card(ClanInfo k) {
      final selected = c.clan == k.name;
      return SizedBox(
        width: 220,
        child: Material(
          color: selected ? AppColors.navActive : AppColors.card,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setClan(c, k.name);
              changed();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.name, style: t.headlineSmall),
                const SizedBox(height: 4),
                Text(k.disciplines.isEmpty ? '3 disciplines communes au choix' : k.disciplines.join(' · '), style: t.bodySmall),
              ]),
            ),
          ),
        ),
      );
    }

    Widget group(ClanRarity r, String title, String cost) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [SectionTitle(title), const SizedBox(width: 12), Text(cost, style: t.bodySmall)]),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [for (final k in clans.where((k) => k.rarity == r)) card(k)]),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      group(ClanRarity.common, 'Clans communs', 'Gratuit'),
      const SizedBox(height: 20),
      group(ClanRarity.uncommon, 'Clans peu communs', 'Atout Clan peu commun · 2 points'),
      const SizedBox(height: 20),
      group(ClanRarity.rare, 'Clans rares', 'Atout Clan rare · 4 points, avec l’accord du conte'),
      const SizedBox(height: 20),
      TextFieldRow(
        label: 'Lignée — facultatif, se paie en atout',
        value: c.lineage,
        onChanged: (v) {
          c.lineage = v;
          changed();
        },
      ),
    ]);
  }
}

class _AttributesStep extends StatelessWidget {
  const _AttributesStep(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    const ranks = ['Primaire · 7', 'Secondaire · 5', 'Tertiaire · 3'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(context, 'Catégorie', [
        for (var i = 0; i < 3; i++)
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 130, child: Text(ranks[i])),
            for (final cat in AttrCategory.values)
              ChoiceChip(
                key: Key('rank-$i-${cat.name}'),
                label: Text(cat.label),
                selected: c.attributeRanks[i] == cat,
                selectedColor: AppColors.navActive,
                onSelected: (_) {
                  for (var j = 0; j < 3; j++) {
                    if (c.attributeRanks[j] == cat) c.attributeRanks[j] = null;
                  }
                  c.attributeRanks[i] = cat;
                  changed();
                },
              ),
          ]),
      ]),
      const SizedBox(height: 20),
      _section(context, 'Focus', [
        for (final cat in AttrCategory.values)
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 130, child: Text('${cat.label} · ${c.attributes[cat]!.value}')),
            for (final f in focuses[cat]!)
              ChoiceChip(
                label: Text(f),
                selected: c.attributes[cat]!.focus == f,
                selectedColor: AppColors.navActive,
                onSelected: (_) {
                  c.attributes[cat]!.focus = f;
                  changed();
                },
              ),
          ]),
      ]),
    ]);
  }
}

/// Liste à niveaux gratuits (compétences, historiques) avec précision par ligne.
class _FreeLevels extends StatelessWidget {
  const _FreeLevels({
    required this.c,
    required this.kind,
    required this.names,
    required this.max,
    required this.noteLabel,
    required this.needsNote,
    required this.changed,
  });

  final Character c;
  final String kind;
  final List<String> names;
  final int max;
  final String noteLabel;
  final bool Function(String) needsNote;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final list = kind == Buy.skill ? c.skills : c.backgrounds;
    final all = [...names, for (final t in list) if (!names.contains(t.name)) t.name];
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final name in all)
          Container(
            key: ValueKey(name),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyMedium)),
                DotPicker(
                  label: name,
                  value: freeLevelOf(c, kind, name),
                  max: max,
                  bought: purchasedCount(c, kind, name),
                  onChanged: (v) {
                    setFreeLevel(c, kind, name, v);
                    changed();
                  },
                ),
              ]),
              if (levelOf(c, kind, name) > 0 && needsNote(name))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFieldRow(
                    label: '$noteLabel de $name',
                    value: list.firstWhere((t) => t.name == name).note,
                    onChanged: (v) {
                      list.firstWhere((t) => t.name == name).note = v;
                      changed();
                    },
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

Widget _slotChips(BuildContext context, List<int> slots, List<int> placed) => Wrap(spacing: 10, runSpacing: 10, children: [
      for (final level in slots.toSet())
        Builder(builder: (context) {
          final expected = slots.where((s) => s == level).length;
          final actual = placed.where((p) => p == level).length;
          final ok = actual == expected;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: ok ? AppColors.border : AppColors.gold),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${'●' * level}  $actual / $expected',
              style: TextStyle(color: ok ? AppColors.success : AppColors.goldLight, fontWeight: FontWeight.w600),
            ),
          );
        }),
    ]);

class _SkillsStep extends StatelessWidget {
  const _SkillsStep(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _slotChips(context, skillSlots, [for (final s in c.skills) freeLevelOf(c, Buy.skill, s.name)]),
        const SizedBox(height: 16),
        _FreeLevels(
          c: c,
          kind: Buy.skill,
          names: skillNames,
          max: 4,
          noteLabel: 'Domaine',
          needsNote: domainSkills.contains,
          changed: changed,
        ),
      ]);
}
