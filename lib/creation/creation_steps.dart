import 'dart:math';

import 'package:flutter/material.dart';

import '../characters/character.dart';
import '../characters/edit_widgets.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rule_hint.dart';
import '../rulebook/rulebook.dart';
import '../rules/creation_rules.dart';
import '../rules/met_lists.dart' show focuses;

/// Introduction de l'étape [step], selon les valeurs de création de la chronique.
String stepIntroOf(int step, CreationValues v, {bool ghoul = false}) {
  final a = v.attributeSlots, d = v.disciplineSlots;
  return switch (step) {
    3 when ghoul => 'Une goule n’a pas de clan : elle sert son domitor, dont elle tire ses disciplines.',
    6 when ghoul => 'Répartissez vos points gratuits : ${v.backgroundSlots.join(' / ')}. Une goule n’a pas de Génération.',
    7 when ghoul => 'Répartissez $ghoulDisciplinePoints points entre les disciplines de votre domitor, sans dépasser son niveau. '
        'Elles ne s’achètent pas avec l’XP.',
    1 => 'Qui est votre personnage ? Donnez-lui un nom, un concept et un archétype. Le récit complet se rédige à la dernière étape.',
    2 => 'Votre personnage commence avec ${v.startingXp + v.defaultBonus} XP. Vous les dépenserez au fil des étapes suivantes.',
    3 => 'Le clan fixe vos trois disciplines en clan. Un clan peu commun ou rare coûte un atout.',
    4 => 'Classez les trois catégories : ${a[0]} points pour la primaire, ${a[1]} pour la secondaire, ${a[2]} pour la tertiaire. '
        'Choisissez ensuite un focus par catégorie.',
    5 => 'Répartissez vos points gratuits : ${slotsText(v.skillSlots)}. Certaines compétences demandent un domaine précis.',
    6 => 'Répartissez vos points gratuits : ${v.backgroundSlots.join(' / ')}. Sans aucun point de Génération, le personnage est un mortel.',
    7 => 'Choisissez la discipline en clan qui reçoit ${d[0]} points ; les deux autres en reçoivent ${d[1]} et ${d[2]}.',
    8 => 'Les atouts se paient en XP, $maxMeritPoints points au plus (rareté de clan comprise). '
        'Les handicaps rapportent de l’XP, ${v.maxFlawXp} au plus.',
    9 => 'Dépensez l’XP restante. Les coûts dépendent de votre génération ; ils sont calculés automatiquement.',
    _ => 'Les traits dérivés sont calculés automatiquement. Ajoutez le récit du personnage, puis soumettez la fiche au conte.',
  };
}

/// Contenu de l'étape [step] ; [changed] après chaque modification de [c].
Widget creationStep(int step, Character c, VoidCallback changed, {Rulebook rb = const Rulebook()}) => switch (step) {
      1 => _Inspiration(c, rb, changed),
      2 => _InitialXp(c, rb),
      3 => c.ghoul != null ? _GhoulClanStep(c) : _ClanStep(c, rb, changed),
      4 => _AttributesStep(c, rb, changed),
      5 => _SkillsStep(c, rb, changed),
      6 => _BackgroundsStep(c, rb, changed),
      7 => c.ghoul != null ? _GhoulDisciplinesStep(c, changed) : _DisciplinesStep(c, rb, changed),
      8 => _MeritsStep(c, rb, changed),
      9 => _PurchasesStep(c, rb, changed),
      _ => _FinishStep(c, changed),
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

String _approval(Rulebook rb, String cat, String name) => rb.find(cat, name)?.state == RuleState.approval ? ' · accord du conte' : '';

class _Inspiration extends StatelessWidget {
  const _Inspiration(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    void set(void Function() f) {
      f();
      changed();
    }

    // Un PJ ne choisit pas une secte réservée aux PNJ.
    final sects = [
      for (final e in rb.offered('sects'))
        if (c.kind != CharacterKind.pj || rb.playable(e.name) != 'npcOnly') e.name,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(context, '', [
        TextFieldRow(label: 'Nom du personnage', value: c.name, onChanged: (v) => set(() => c.name = v ?? '')),
        ChoiceField(label: 'Secte', value: c.sect, options: sects, onChanged: (v) => set(() => c.sect = v)),
        TextFieldRow(label: 'Concept — en une phrase', value: c.concept, onChanged: (v) => set(() => c.concept = v)),
        ChoiceField(label: 'Archétype', value: c.archetype, options: rb.offeredNames('archetypes'), onChanged: (v) => set(() => c.archetype = v)),
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
  const _InitialXp(this.c, this.rb);
  final Character c;
  final Rulebook rb;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = budgetOf(c, rb: rb);
    final v = rb.creation;
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
    final rules = [
      'Les handicaps choisis à l’étape 8 rapportent de l’XP en plus, ${v.maxFlawXp} au maximum.',
      'Un clan peu commun ou rare se paie en atouts avec cette XP.',
      'La Génération ne s’achète qu’à la création.',
      'À la fin, ${v.maxSetAside} XP au plus peuvent être mis de côté ; le surplus est perdu.',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 16, runSpacing: 16, children: [
        card('XP de départ', '${b.start}', 'Pour tous les personnages'),
        card('Bonus du conte', '${c.xpBonus}', 'Fixé par un conteur'),
        card('Handicaps', '+ ${b.flaws}', 'Jusqu’à ${v.maxFlawXp} XP, à l’étape 8'),
      ]),
      const SizedBox(height: 20),
      _section(context, 'À savoir', [for (final r in rules) Text('• $r', style: t.bodyMedium)]),
    ]);
  }
}

/// Étape 3 d'une goule : son domitor, en lecture.
class _GhoulClanStep extends StatelessWidget {
  const _GhoulClanStep(this.c);
  final Character c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _section(context, 'Domitor', [
      Text(ghoulLine(c.ghoul!), style: t.titleMedium),
      const SizedBox(height: 6),
      Text('Le domitor est choisi par le conte. Ses disciplines sont celles que vous pourrez apprendre.', style: t.bodySmall),
    ]);
  }
}

/// Étape 7 d'une goule : 5 points entre les disciplines du domitor, au plus son niveau.
class _GhoulDisciplinesStep extends StatelessWidget {
  const _GhoulDisciplinesStep(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = c.disciplines.fold<int>(0, (s, d) => s + d.level);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$total / $ghoulDisciplinePoints points', style: t.titleMedium?.copyWith(color: AppColors.gold)),
      const SizedBox(height: 12),
      for (final own in c.ghoul!.domitorDisciplines)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Text('${own.name} (domitor : ${own.level})', style: t.titleMedium)),
              DotPicker(
                label: own.name,
                value: c.disciplines.where((d) => d.name == own.name).firstOrNull?.level ?? 0,
                max: own.level,
                onChanged: (v) {
                  setGhoulDiscipline(c, own.name, v);
                  changed();
                },
              ),
            ]),
          ),
        ),
      if (c.ghoul!.domitorDisciplines.isEmpty) Text('Le domitor n’a aucune discipline recopiée : demandez au conte.', style: t.bodyMedium),
    ]);
  }
}

class _ClanStep extends StatelessWidget {
  const _ClanStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget card(RuleEntry k) {
      final selected = c.clan == k.name;
      final disciplines = rb.clanDisciplines(k.name);
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
              setClan(c, k.name, rb: rb);
              changed();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.name, style: t.headlineSmall),
                const SizedBox(height: 4),
                Text(disciplines.isEmpty ? '3 disciplines communes au choix' : disciplines.join(' · '), style: t.bodySmall),
                RuleHint(k, maxLines: 3),
              ]),
            ),
          ),
        ),
      );
    }

    // Rareté lue pour la secte du personnage ; un clan interdit pour elle n'est pas proposé.
    final clans = [for (final k in rb.offered('clans')) if (rb.rarity(k.name, c.sect) != 'forbidden') k];
    Widget group(String rarity, String title, String cost) {
      final list = [for (final k in clans) if (rb.rarity(k.name, c.sect) == rarity) k];
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [SectionTitle(title), const SizedBox(width: 12), Text(cost, style: t.bodySmall)]),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [for (final k in list) card(k)]),
        ]),
      );
    }

    final bloodlines = [
      for (final r in (rb.find('clans', c.clan)?.data['bloodlines'] as List?) ?? const [])
        if (r is Map && r['name'] != null) r,
    ];
    String bloodline(Map r) {
      final merit = r['merit'];
      if (merit is! String || merit.isEmpty) return '${r['name']}';
      return '${r['name']} (${rb.cost('merits', merit) ?? '?'} points)';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      group('common', 'Clans communs', 'Gratuit'),
      group('uncommon', 'Clans peu communs', 'Atout Clan peu commun · 2 points'),
      group('rare', 'Clans rares', 'Atout Clan rare · 4 points, avec l’accord du conte'),
      TextFieldRow(
        label: 'Lignée — facultatif, se paie en atout',
        value: c.lineage,
        onChanged: (v) {
          c.lineage = v;
          changed();
        },
      ),
      if (bloodlines.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Lignées du clan : ${[for (final r in bloodlines) bloodline(r)].join(' · ')}', style: t.bodySmall),
      ],
    ]);
  }
}

class _AttributesStep extends StatelessWidget {
  const _AttributesStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final s = rb.creation.attributeSlots;
    final ranks = ['Primaire · ${s[0]}', 'Secondaire · ${s[1]}', 'Tertiaire · ${s[2]}'];
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
    required this.rb,
    required this.kind,
    required this.names,
    required this.max,
    required this.noteLabel,
    required this.needsNote,
    required this.changed,
  });

  final Character c;
  final Rulebook rb;
  final String kind;
  final List<String> names;
  final int max;
  final String noteLabel;
  final bool Function(String) needsNote;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final list = kind == Buy.skill ? c.skills : c.backgrounds;
    final cat = kind == Buy.skill ? 'skills' : 'backgrounds';
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
                Expanded(child: Text('$name${_approval(rb, cat, name)}', style: Theme.of(context).textTheme.bodyMedium)),
                DotPicker(
                  label: name,
                  value: freeLevelOf(c, kind, name),
                  max: max,
                  bought: purchasedCount(c, kind, name),
                  onChanged: (v) {
                    setFreeLevel(c, kind, name, v, rb: rb);
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
  const _SkillsStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final slots = rb.creation.skillSlots;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _slotChips(context, slots, [for (final s in c.skills) freeLevelOf(c, Buy.skill, s.name)]),
      const SizedBox(height: 16),
      _FreeLevels(
        c: c,
        rb: rb,
        kind: Buy.skill,
        names: rb.offeredNames('skills'),
        max: slots.reduce(max),
        noteLabel: 'Domaine',
        needsNote: (n) => rb.domainMode(n) != 'none',
        changed: changed,
      ),
    ]);
  }
}

class _BackgroundsStep extends StatelessWidget {
  const _BackgroundsStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rank = rankFor(c);
    final row = rank == null ? null : rb.gen(rank);
    final slots = rb.creation.backgroundSlots;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _slotChips(context, slots, [for (final b in c.backgrounds) freeLevelOf(c, Buy.background, b.name)]),
      const SizedBox(height: 16),
      _FreeLevels(
        c: c,
        rb: rb,
        kind: Buy.background,
        names: [for (final n in rb.offeredNames('backgrounds')) if (c.ghoul == null || n != generationName) n],
        max: slots.reduce(max),
        noteLabel: 'Précisions',
        needsNote: (n) => n != generationName && rb.backgroundAsk(n) != null,
        changed: changed,
      ),
      const SizedBox(height: 20),
      if (c.ghoul != null)
        _section(context, 'Sang', [Text('Goule · Sang ${rb.ghoulRow().blood}, ${rb.ghoulRow().bloodPerTurn} par tour', style: t.bodyMedium)])
      else
        _section(context, 'Génération', [
        Text(
          rank == null || row == null
              ? 'Aucun point de Génération : le personnage serait un mortel.'
              : '${rank.label} · Sang ${row.blood}, ${row.bloodPerTurn} par tour',
          style: t.bodyMedium,
        ),
        if (row != null)
          DropdownButtonFormField<int?>(
            key: const Key('generation-number'),
            initialValue: row.numbers.contains(c.genNumber) ? c.genNumber : null,
            decoration: const InputDecoration(labelText: 'Génération'),
            items: [for (final n in row.numbers) DropdownMenuItem<int?>(value: n, child: Text('${n}e'))],
            onChanged: (n) {
              c.genNumber = n;
              changed();
            },
          ),
        Text('Monter en Génération se paie en XP à l’étape 9 et n’est plus possible ensuite.', style: t.bodySmall),
      ]),
    ]);
  }
}

class _DisciplinesStep extends StatelessWidget {
  const _DisciplinesStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final slots = rb.creation.disciplineSlots;
    // Clan sans disciplines propres (Caïtiff) : trois disciplines communes au choix.
    final choose = rb.find('clans', c.clan) != null && rb.clanDisciplines(c.clan).isEmpty;
    final inClan = c.disciplines.where((d) => d.inClan).toList();
    final first = inClan.where((d) => freeLevelOf(c, Buy.discipline, d.name) == slots[0]).map((d) => d.name).firstOrNull;
    void pickFirst(String name) {
      final rest = slots.skip(1).iterator;
      for (final d in inClan) {
        setDisciplineFree(c, d.name, d.name == name ? slots[0] : (rest.moveNext() ? rest.current : 0));
      }
      changed();
    }

    final outFactor = rb.gen(rankFor(c) ?? GenRank.neonate).outOfClanFactor;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.clan == null) Text('Choisissez d’abord un clan (étape 3).', style: t.bodyMedium),
      if (choose)
        _section(context, 'Trois disciplines communes', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final name in rb.commonDisciplines())
              FilterChip(
                label: Text(name),
                selected: inClan.any((d) => d.name == name),
                onSelected: (on) {
                  if (on && inClan.length < 3) {
                    c.disciplines.removeWhere((d) => d.name == name);
                    c.disciplines.add(Discipline(name, 0, inClan: true));
                  } else if (!on) {
                    c.disciplines.removeWhere((d) => d.name == name && purchasedCount(c, Buy.discipline, name) == 0);
                  }
                  changed();
                },
              ),
          ]),
        ]),
      const SizedBox(height: 16),
      for (final d in inClan)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(d.name, style: t.titleMedium)),
                Text('●' * d.level, style: const TextStyle(color: AppColors.gold, letterSpacing: 2)),
                const SizedBox(width: 12),
                ChoiceChip(
                  key: Key('two-${d.name}'),
                  label: Text('${slots[0]} points gratuits'),
                  selected: first == d.name,
                  selectedColor: AppColors.navActive,
                  onSelected: (_) => pickFirst(d.name),
                ),
              ]),
              TextFieldRow(
                label: 'Pouvoirs de ${d.name}',
                value: d.powers.join(', '),
                onChanged: (v) {
                  d.powers = [for (final p in (v ?? '').split(',')) if (p.trim().isNotEmpty) p.trim()];
                  changed();
                },
              ),
            ]),
          ),
        ),
      Text(
        'Des points en plus s’achètent à l’étape 9 : en clan, nouveau niveau × 3 ; hors clan, jusqu’à $maxOutOfClanDots points '
        'dans une discipline commune, nouveau niveau × $outFactor.',
        style: t.bodySmall,
      ),
    ]);
  }
}

class _MeritsStep extends StatelessWidget {
  const _MeritsStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = rb.creation;
    final b = budgetOf(c, rb: rb);
    final rarity = rb.rarityCost(c.clan, c.sect);
    final lineage = lineageCost(c, rb: rb);
    Widget column(String title, String counter, List<Trait> chosen, String cat, String key) {
      // Proposés à la création, avec une valeur.
      final catalog = {
        for (final e in rb.offered(cat))
          if (e.data['atCreation'] == true && rb.cost(cat, e.name) != null) e.name: rb.cost(cat, e.name)!,
      };
      final remaining = catalog.entries.where((e) => !chosen.any((m) => nameKey(m.name) == nameKey(e.key))).toList();
      final merits = title == 'Atouts';
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: SectionTitle(title)), Text(counter, style: t.labelMedium)]),
          const SizedBox(height: 10),
          if (merits && rarity > 0) Text('Rareté du clan · $rarity points', style: t.bodyMedium),
          if (merits && lineage > 0) Text('Lignée ${c.lineage} · $lineage points', style: t.bodyMedium),
          if (chosen.isEmpty && !(merits && rarity + lineage > 0)) Text('Aucun pour l’instant', style: t.bodySmall),
          for (final m in chosen)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${m.name} · ${m.level}', style: t.bodyMedium)),
                IconButton(
                  tooltip: 'Retirer ${m.name}',
                  onPressed: () {
                    chosen.remove(m);
                    changed();
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ]),
              RuleHint(rb.find(cat, m.name), maxLines: 3),
            ]),
          const SizedBox(height: 8),
          // Clé par taille de liste : le menu repart vide après chaque ajout.
          KeyedSubtree(
            key: ValueKey('$key-${chosen.length}'),
            child: DropdownButtonFormField<String>(
              key: Key(key),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ajouter…'),
              items: [
                for (final e in remaining) DropdownMenuItem(value: e.key, child: Text('${e.key} (${e.value})${_approval(rb, cat, e.key)}')),
              ],
              onChanged: (name) {
                if (name == null) return;
                chosen.add(Trait(name, catalog[name]!));
                changed();
              },
            ),
          ),
        ]),
      );
    }

    final merits = column('Atouts', '${b.merits} / $maxMeritPoints points', c.merits, 'merits', 'add-merit');
    final flaws = column('Handicaps', '${b.flawsTaken} / ${v.maxFlawXp} XP', c.flaws, 'flaws', 'add-flaw');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: merits),
          const SizedBox(width: 20),
          Expanded(child: flaws),
        ])
      else ...[merits, const SizedBox(height: 20), flaws],
      const SizedBox(height: 12),
      Text(
        'Avec l’accord du conte, un joueur peut prendre plus de ${v.maxFlawXp} points de handicaps, '
        'mais n’en tire jamais plus de ${v.maxFlawXp} XP.',
        style: t.bodySmall,
      ),
    ]);
  }
}

class _PurchasesStep extends StatefulWidget {
  const _PurchasesStep(this.c, this.rb, this.changed);
  final Character c;
  final Rulebook rb;
  final VoidCallback changed;

  @override
  State<_PurchasesStep> createState() => _PurchasesStepState();
}

class _PurchasesStepState extends State<_PurchasesStep> {
  String _kind = Buy.skill;
  String? _name;

  static const _kinds = {
    Buy.attribute: 'Attribut',
    Buy.skill: 'Compétence',
    Buy.background: 'Historique',
    Buy.discipline: 'Discipline',
    Buy.ritual: 'Rituel',
    Buy.technique: 'Technique',
    Buy.elderPower: 'Pouvoir d’ancien',
    Buy.humanity: 'Humanité',
  };

  String? get _cat => switch (_kind) {
        Buy.skill => 'skills',
        Buy.background => 'backgrounds',
        Buy.discipline => 'disciplines',
        Buy.ritual => 'rituals',
        Buy.technique => 'techniques',
        Buy.elderPower => 'elderPowers',
        _ => null,
      };

  Map<String, String> _names(Character c, Rulebook rb) => switch (_kind) {
        Buy.attribute => {for (final a in AttrCategory.values) a.name: a.label},
        Buy.skill => {for (final s in {...rb.offeredNames('skills'), ...c.skills.map((s) => s.name)}) s: s},
        Buy.background => {for (final b in {...rb.offeredNames('backgrounds'), ...c.backgrounds.map((b) => b.name)}) b: b},
        Buy.discipline => {
            for (final d in {...c.disciplines.where((d) => d.inClan).map((d) => d.name), ...rb.commonDisciplines()}) d: d,
          },
        Buy.ritual => {
            for (final e in rb.offered('rituals'))
              if (e.data['atCreation'] == true && levelOf(c, Buy.ritual, e.name) == 0)
                e.name: '${e.name} (niveau ${rb.ritualLevel(e.name)})${_approval(rb, 'rituals', e.name)}',
          },
        Buy.technique => {
            for (final e in rb.offered('techniques'))
              if (levelOf(c, Buy.technique, e.name) == 0) e.name: '${e.name}${_approval(rb, 'techniques', e.name)}',
          },
        Buy.elderPower => {
            for (final e in rb.offered('elderPowers'))
              if (levelOf(c, Buy.elderPower, e.name) == 0) e.name: '${e.name}${_approval(rb, 'elderPowers', e.name)}',
          },
        _ => {humanityName: humanityName},
      };

  String _label(Purchase p) => switch (p.kind) {
        Buy.attribute => 'Attribut · ${AttrCategory.values.byName(p.name).label}',
        Buy.skill => 'Compétence · ${p.name}',
        Buy.background => 'Historique · ${p.name}',
        Buy.discipline => '${p.name} (${isInClan(widget.c, p.name, rb: widget.rb) ? 'en clan' : 'hors clan'})',
        Buy.ritual => 'Rituel · ${p.name}',
        Buy.technique => 'Technique · ${p.name}',
        Buy.elderPower => 'Pouvoir d’ancien · ${p.name}',
        _ => p.name,
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final rb = widget.rb;
    final t = Theme.of(context).textTheme;
    final names = _names(c, rb);
    final rank = rankFor(c) ?? GenRank.neonate;
    final row = creationRow(c, rb: rb);
    final ghoul = c.ghoul != null;
    final cat = _cat;
    void buy() {
      final name = _name;
      if (name == null) return;
      final error = addPurchase(c, _kind, name, rb: rb);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else if (_kind == Buy.ritual || _kind == Buy.technique || _kind == Buy.elderPower) {
        _name = null; // appris : il quitte la liste
      }
      widget.changed();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(context, '', [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              key: const Key('buy-kind'),
              isExpanded: true,
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final e in _kinds.entries) if (ghoulPurchaseError(c, e.key, '') == null) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (k) => setState(() {
                _kind = k ?? _kind;
                _name = _kind == Buy.humanity ? humanityName : null;
              }),
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              key: Key('buy-name-$_kind'),
              isExpanded: true,
              // Un rituel, une technique ou un pouvoir acheté sort de la liste : plus de sélection.
              initialValue: names.containsKey(_name) ? _name : null,
              decoration: const InputDecoration(labelText: 'Élément'),
              items: [for (final e in names.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (n) => setState(() => _name = n),
            ),
          ),
          FilledButton(onPressed: _name == null ? null : buy, child: const Text('Ajouter')),
        ]),
        if (cat != null && _name != null) RuleHint(rb.find(cat, _name)),
      ]),
      const SizedBox(height: 20),
      _section(context, 'Achats', [
        if (c.purchases.isEmpty) Text('Aucun achat.', style: t.bodySmall),
        for (final (i, p) in c.purchases.indexed)
          Row(children: [
            Expanded(child: Text(_label(p), style: t.bodyMedium)),
            Text('→ ${'●' * p.toLevel}', style: const TextStyle(color: AppColors.gold)),
            const SizedBox(width: 16),
            SizedBox(width: 60, child: Text('${purchaseCost(c, p.kind, p.name, p.toLevel, rb: rb)} XP', textAlign: TextAlign.right)),
            IconButton(
              tooltip: 'Retirer l’achat',
              onPressed: () {
                final error = removePurchase(c, i, rb: rb);
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
                widget.changed();
              },
              icon: const Icon(Icons.close, size: 18),
            ),
          ]),
        Text('Total dépensé : ${budgetOf(c, rb: rb).purchases} XP en achats, ${budgetOf(c, rb: rb).merits} en atouts', style: t.titleMedium),
      ]),
      const SizedBox(height: 20),
      _section(context, ghoul ? 'Coûts pour une goule' : 'Coûts ${rank.label}', [
        for (final (k, v) in [
          ('Attribut', '3 XP'),
          ('Compétence, historique', 'Niveau × ${row.traitFactor}'),
          ('Discipline en clan', ghoul ? 'Jamais en XP' : 'Niveau × 3'),
          ('Hors clan (communes, $maxOutOfClanDots points au plus)', ghoul ? 'Jamais en XP' : 'Niveau × ${row.outOfClanFactor}'),
          ('Génération', ghoul ? 'Interdite' : 'Niveau × 2'),
          ('Humanité', '10 XP le point, 6 au plus'),
          ('Rituel', 'Niveau × ${rb.ritualCostPerLevel}'),
          ('Technique', ghoul ? 'Jamais en XP' : (row.techniqueCost == 0 ? 'Interdite à ce rang' : '${row.techniqueCost} XP')),
          ('Pouvoir d’ancien', ghoul ? 'Jamais en XP' : (row.eldersAllowed ? 'Selon le pouvoir' : 'Interdit à ce rang')),
        ])
          Row(children: [Expanded(child: Text(k, style: t.bodyMedium)), Text(v, style: t.bodyMedium)]),
      ]),
    ]);
  }
}

class _FinishStep extends StatelessWidget {
  const _FinishStep(this.c, this.changed);
  final Character c;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget derived(String k, String v, String s) => SizedBox(
          width: 200,
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionTitle(k),
              const SizedBox(height: 4),
              Text(v, style: t.titleMedium),
              Text(s, style: t.bodySmall),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        derived('Sang', '${c.blood} · ${c.bloodPerTurn} par tour', c.genRank?.label ?? '—'),
        derived('Volonté', '${c.willpower}', 'Valeur normale'),
        derived('Santé', c.health, 'Sain · Blessé · Incapacité'),
        derived('Humanité', '${c.humanity}', 'Moralité de départ'),
      ]),
      const SizedBox(height: 20),
      _section(context, '', [
        TextFieldRow(
          label: 'Sire',
          value: c.sire,
          onChanged: (v) {
            c.sire = v;
            changed();
          },
        ),
        TextFieldRow(
          label: 'Récit du personnage — visible par vous et le conte',
          value: c.story,
          maxLines: 8,
          onChanged: (v) {
            c.story = v;
            changed();
          },
        ),
      ]),
    ]);
  }
}
