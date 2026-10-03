# Référentiel — Plan B (moteurs branchés) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** la création et la dépense d'XP lisent le référentiel des règles. Cela couvre :
- les éléments et leurs états ;
- la rareté par secte, les sectes jouables ;
- les domaines, les historiques, les générations ;
- les valeurs de création modifiables par les conteurs.

Une catégorie vide garde les valeurs de base du code.

**Architecture :**
- **`Rulebook`** (`lib/rulebook/rulebook.dart`) est pur. Il réunit les éléments du référentiel, avec repli catégorie par catégorie sur `baseEntries`, et les valeurs de création (`CreationValues`, rangées dans `chronicle/xp`, clé `creation`).
- **Paramètre `rb`.** Les fonctions de `creation_rules.dart` et de `xp_rules.dart` reçoivent `{Rulebook rb = const Rulebook()}`. Les tests existants gardent les valeurs de base, et les écrans passent le référentiel lu par `rulebookProvider`.
- **`rulebookProvider`** vaut null pendant le chargement : les écrans attendent.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-03-referentiel-design.md`, sections « Valeurs de création », « Côté joueur » et « Moteurs : `Rulebook` ».

## Global Constraints

- **Contraintes des plans précédents :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-b.md <N> [test|impl]` ;
  - textes en français, couleurs dans `AppColors` ;
  - `build_runner` après tout fichier `part` ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branche `referentiel-b`, créée depuis `main`.
- **Écarts assumés avec la spec** (à reporter dans le journal) :
  - **Points bonus d'attribut :** reportés au plan C. Ils ajoutent un champ de fiche (`attributeBonus`) et une tolérance des règles Firestore ; le plan C fait déjà ce travail pour les rituels, techniques et pouvoirs d'anciens. Le plan B ne touche ni aux fiches ni à `firestore.rules`.
  - **`rb` est un paramètre nommé facultatif** (valeurs de base par défaut) plutôt qu'obligatoire, pour ne pas réécrire 66 appels dans les tests. Risque : un appel d'écran qui oublie `rb` calcule avec les valeurs de base. La tâche 6 vérifie chaque appel par une recherche.
  - **`defaultBonus` (« bonus de départ par défaut »)** s'ajoute à l'XP de départ de chaque fiche en création. Le bonus propre à une fiche (`xpBonus`) ne s'écrit que par un conteur ; les règles interdisent au joueur de le poser.
  - **Une case à cocher décochée n'est pas enregistrée** : elle se lit comme fausse. Un atout sans `atCreation` n'est donc pas proposé à la création, et sans `withXp` il n'est pas proposé à l'XP. Les valeurs de base cochent les deux.
  - **Réglages de catégorie** (`rules/{cat}`, par exemple `archetypes.freeAllowed`) : non lus par les moteurs du plan B.
- **Pas de changement des règles Firestore.** `chronicle/xp` s'écrit déjà par `managesAccounts()`, et la clé `creation` y entre sans changement.

## Review Focus

1. **Référentiel à moitié rempli** (atouts saisis, clans vides) : la création fonctionne avec les clans de base. Le test est à la tâche 2.
2. **Clan rendu « interdit » pour la secte alors que des fiches l'ont :** erreur au contrôle suivant, la fiche n'est pas modifiée. Le test est à la tâche 2.
3. **Valeurs de création changées alors qu'une fiche est soumise :** la validation signale « Valeurs calculées incohérentes ». Le conteur la renvoie au joueur, qui la réenregistre. Le test est à la tâche 2.
4. **Coût d'un atout changé après l'envoi d'une demande d'XP :** la validation est bloquée, avec un message qui donne les deux valeurs. Le test est à la tâche 3.
5. **Référentiel en cours de chargement :** les écrans attendent au lieu de calculer avec les valeurs de base. En cas d'erreur de lecture, ils utilisent les valeurs de base. Les tests sont aux tâches 1 et 2.

## Structure des fichiers

```
lib/rulebook/rulebook.dart            CreationValues, GenRow, Rulebook, slotsText
lib/rulebook/rulebook_provider.dart   rulebookProvider
lib/rulebook/rule_hint.dart           RuleHint (badge « Accord du conte » + règle affichée aux joueurs)
lib/xp/xp_settings.dart               + creation
lib/rules/creation_rules.dart         moteur de création sur Rulebook ; stateCheck, lineageCost, capFor
lib/xp/xp_rules.dart                  moteur d'XP sur Rulebook ; noteSpec, ruleCategoryOf
lib/creation/creation_steps.dart      listes, rareté, domaines, générations, valeurs de création
lib/creation/creation_screen.dart, lib/creation/validation_screen.dart
lib/xp/spend_screen.dart, lib/xp/request_review.dart, lib/xp/xp_repository.dart (decide)
lib/xp/xp_settings_screen.dart        valeurs de création éditables
lib/characters/character_edit_screen.dart, lib/characters/characters_list_screen.dart
test/fakes.dart                       baseRulebook, FakeXpRepository (decide, lastSettings)
```

---

### Task 1 : `Rulebook` et valeurs de création

**Files :**
- Create : `lib/rulebook/rulebook.dart`, `lib/rulebook/rulebook_provider.dart`.
- Modify : `lib/xp/xp_settings.dart`, `lib/rules/met_lists.dart` (commentaire).
- Test : `test/rulebook/rulebook_test.dart`.

**Interfaces :**
- Consumes : `baseEntries`, `RuleEntry`, `RuleState`, `nameKey`, `GenRank`, `allRuleEntriesProvider`, `xpSettingsProvider`.
- Produces :
  - `slotsText(List<int>)` ;
  - `CreationValues` : `attributeSlots`, `skillSlots`, `backgroundSlots`, `disciplineSlots`, `startingXp`, `maxFlawXp`, `maxSetAside`, `defaultBonus` ; `fromMap`, `toMap` ;
  - `GenRow` : `numbers`, `blood`, `bloodPerTurn`, `attributeBonus`, `skillCap`, `traitFactor`, `outOfClanFactor`, `techniqueCost`, `eldersAllowed`, `eldersLimit` ;
  - `Rulebook([Map<String, List<RuleEntry>> entries, CreationValues creation])`, constructeur `const`, avec ses recherches :
    - éléments : `all`, `find`, `offered`, `offeredNames`, `cost` ;
    - clans et sectes : `clanDisciplines`, `defaultSect`, `rarity`, `rarityCost`, `lineageMerit`, `playable` ;
    - disciplines : `isCommon`, `commonDisciplines` ;
    - compétences : `domainMode`, `skillCap` ;
    - historiques : `backgroundCap`, `backgroundAsk`, `backgroundScale`, `backgroundApproval` ;
    - générations : `gen`.
  - `rulebookProvider` (`Rulebook?`) ;
  - `XpSettings.creation`.

- [ ] **Step 1 : extraire le test, le lancer, il doit échouer**

Run : `git switch referentiel-b` (créée avec le plan), puis `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-b.md 1 test`, puis `flutter test test/rulebook/rulebook_test.dart`.

Expected : échec au chargement.

<!-- file: test/rulebook/rulebook_test.dart -->
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/rulebook/rules_repository.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_settings.dart';

void main() {
  test('valeurs de base', () {
    const rb = Rulebook();
    expect(rb.cost('merits', 'chanceux'), 2);
    expect(rb.clanDisciplines('Tremere'), ['Auspex', 'Domination', 'Thaumaturgie']);
    expect(rb.rarity('Lasombra', 'Camarilla'), 'rare');
    expect(rb.rarity('Lasombra', 'Sabbat'), 'rare', reason: 'secte absente : celle par défaut');
    expect(rb.rarityCost('Giovanni', 'Camarilla'), 2);
    expect(rb.commonDisciplines(), contains('Auspex'));
    expect(rb.isCommon('Thaumaturgie'), isFalse);
    expect(rb.domainMode('Artisanat'), 'perDot');
    expect(rb.domainMode('Bagarre'), 'none');
    expect(rb.gen(GenRank.ancilla).blood, 12);
    expect(rb.gen(GenRank.ancilla).traitFactor, 2);
    expect(rb.gen(GenRank.neonate).numbers, [13, 12, 11]);
    expect(rb.gen(GenRank.pretender).eldersAllowed, isTrue);
    expect(rb.playable('Camarilla'), 'all');
    expect(rb.defaultSect, 'Camarilla');
    expect(rb.skillCap('Bagarre', null), 5);
  });

  test('repli catégorie par catégorie, états proposés', () {
    final rb = Rulebook({
      'merits': [
        RuleEntry(name: 'Mécène', state: RuleState.approval, data: {'cost': 3}),
        RuleEntry(name: 'Secret', state: RuleState.draft, data: {'cost': 1}),
      ],
    });
    expect(rb.find('merits', 'Chanceux'), isNull);
    expect(rb.find('clans', 'Tremere'), isNotNull);
    expect(rb.offeredNames('merits'), ['Mécène']);
    expect(rb.cost('merits', 'mécène'), 3);
  });

  test('rareté par secte, lignée, générations du référentiel', () {
    final rb = Rulebook({
      'clans': [
        RuleEntry(name: 'Tremere', data: {
          'disciplines': ['Auspex', 'Domination', 'Thaumaturgie'],
          'rarity': {'Sabbat': 'common', 'Camarilla': 'forbidden'},
          'bloodlines': [
            {'name': 'Telyav', 'merit': 'Lignée Telyav'},
          ],
        }),
      ],
      'merits': [RuleEntry(name: 'Lignée Telyav', data: {'cost': 2})],
      'generations': [
        RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'traitFactor': 3, 'numbers': ['10']}),
      ],
    });
    expect(rb.rarity('Tremere', 'Camarilla'), 'forbidden');
    expect(rb.rarity('Tremere', 'Sabbat'), 'common');
    expect(rb.rarity('Tremere', 'Anarchs'), 'forbidden', reason: 'secte absente : celle par défaut');
    expect(rb.rarityCost('Tremere', 'Camarilla'), 0);
    expect(rb.lineageMerit('Tremere', ' telyav '), ('Lignée Telyav', 2));
    expect(rb.lineageMerit('Tremere', 'Inconnue'), isNull);
    final ancilla = rb.gen(GenRank.ancilla);
    expect((ancilla.traitFactor, ancilla.numbers, ancilla.blood, ancilla.eldersAllowed), (3, [10], 12, false));
    expect(rb.gen(GenRank.neonate).traitFactor, 1, reason: 'rang absent : valeurs de base');
  });

  test('valeurs de création : défauts, invalides, aller-retour', () {
    expect(slotsText([4, 3, 3, 2, 2, 2, 1, 1, 1, 1]), '4 / 3-3 / 2-2-2 / 1-1-1-1');
    const d = CreationValues();
    expect((d.attributeSlots, d.startingXp, d.maxFlawXp, d.maxSetAside, d.defaultBonus), ([7, 5, 3], 30, 7, 5, 0));
    final bad = CreationValues.fromMap({'attributeSlots': [7, 5], 'skillSlots': [4, 'x'], 'startingXp': -1, 'maxFlawXp': 6});
    expect((bad.attributeSlots, bad.skillSlots, bad.startingXp, bad.maxFlawXp), ([7, 5, 3], d.skillSlots, 30, 6));
    const custom = CreationValues(attributeSlots: [8, 5, 3], startingXp: 35, defaultBonus: 2);
    expect(CreationValues.fromMap(custom.toMap()).toMap(), custom.toMap());
    const s = XpSettings(creation: custom);
    expect(XpSettings.fromMap(s.toMap()).creation.toMap(), custom.toMap());
    expect(XpSettings.fromMap(const {}).creation.startingXp, 30);
  });

  test('provider : null pendant le chargement, valeurs de base si la lecture échoue (Review Focus 5)', () async {
    final entries = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(entries.close);
    final container = ProviderContainer(overrides: [
      allRuleEntriesProvider.overrideWith((ref) => entries.stream),
      xpSettingsProvider.overrideWith((ref) => Stream.value(const XpSettings(creation: CreationValues(startingXp: 35)))),
    ]);
    addTearDown(container.dispose);
    container.listen(rulebookProvider, (_, _) {});
    expect(container.read(rulebookProvider), isNull);
    await container.read(xpSettingsProvider.future);
    entries.addError(Exception('lecture refusée'));
    await Future<void>.delayed(Duration.zero);
    final rb = container.read(rulebookProvider);
    expect(rb, isNotNull);
    expect(rb!.creation.startingXp, 35);
    expect(rb.clanDisciplines('Tremere'), ['Auspex', 'Domination', 'Thaumaturgie']);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-b.md 1 impl`.

<!-- file: lib/rulebook/rulebook.dart -->
```dart
import 'dart:math';

import '../characters/character.dart';
import 'base_rules.dart';
import 'rule_entry.dart';

/// « 4 / 3-3 / 2-2-2 / 1-1-1-1 » : valeurs égales consécutives groupées.
String slotsText(List<int> slots) {
  final groups = <List<int>>[];
  for (final s in slots) {
    if (groups.isNotEmpty && groups.last.first == s) {
      groups.last.add(s);
    } else {
      groups.add([s]);
    }
  }
  return [for (final g in groups) g.join('-')].join(' / ');
}

int? _count(Object? v) => switch (v) {
      final num n when n >= 0 => n.toInt(),
      _ => null,
    };

/// Valeurs de création (`chronicle/xp`, clé `creation`).
class CreationValues {
  const CreationValues({
    this.attributeSlots = const [7, 5, 3],
    this.skillSlots = const [4, 3, 3, 2, 2, 2, 1, 1, 1, 1],
    this.backgroundSlots = const [3, 2, 1],
    this.disciplineSlots = const [2, 1, 1],
    this.startingXp = 30,
    this.maxFlawXp = 7,
    this.maxSetAside = 5,
    this.defaultBonus = 0,
  });

  /// Valeur absente ou invalide : celle par défaut.
  factory CreationValues.fromMap(Map<String, dynamic>? m) {
    const d = CreationValues();
    if (m == null) return d;
    List<int> slots(String key, List<int> fallback, {int? length}) {
      final raw = m[key];
      if (raw is! List) return fallback;
      final v = [for (final x in raw) if (x is num && x > 0) x.toInt()];
      final ok = v.isNotEmpty && v.length == raw.length && (length == null || v.length == length);
      return ok ? v : fallback;
    }

    return CreationValues(
      attributeSlots: slots('attributeSlots', d.attributeSlots, length: 3),
      skillSlots: slots('skillSlots', d.skillSlots),
      backgroundSlots: slots('backgroundSlots', d.backgroundSlots),
      disciplineSlots: slots('disciplineSlots', d.disciplineSlots, length: 3),
      startingXp: _count(m['startingXp']) ?? d.startingXp,
      maxFlawXp: _count(m['maxFlawXp']) ?? d.maxFlawXp,
      maxSetAside: _count(m['maxSetAside']) ?? d.maxSetAside,
      defaultBonus: _count(m['defaultBonus']) ?? d.defaultBonus,
    );
  }

  /// Primaire, secondaire, tertiaire.
  final List<int> attributeSlots;
  final List<int> skillSlots;
  final List<int> backgroundSlots;

  /// La discipline choisie, puis les deux autres.
  final List<int> disciplineSlots;
  final int startingXp;
  final int maxFlawXp;
  final int maxSetAside;

  /// Ajouté à l'XP de départ de chaque fiche en création.
  final int defaultBonus;

  Map<String, dynamic> toMap() => {
        'attributeSlots': attributeSlots,
        'skillSlots': skillSlots,
        'backgroundSlots': backgroundSlots,
        'disciplineSlots': disciplineSlots,
        'startingXp': startingXp,
        'maxFlawXp': maxFlawXp,
        'maxSetAside': maxSetAside,
        'defaultBonus': defaultBonus,
      };
}

/// Ligne du tableau des générations pour un rang.
class GenRow {
  const GenRow({
    required this.numbers,
    required this.blood,
    required this.bloodPerTurn,
    required this.attributeBonus,
    required this.skillCap,
    required this.traitFactor,
    required this.outOfClanFactor,
    required this.techniqueCost,
    required this.eldersAllowed,
    required this.eldersLimit,
  });

  /// Nombre absent ou invalide : celui de [base]. Case décochée (clé absente) : fausse.
  factory GenRow.fromData(Map<String, dynamic> d, GenRow base) {
    int n(String key, int fallback) => _count(d[key]) ?? fallback;
    final numbers = [for (final x in (d['numbers'] as List?) ?? const []) ?int.tryParse('$x')];
    return GenRow(
      numbers: numbers.isEmpty ? base.numbers : numbers,
      blood: n('blood', base.blood),
      bloodPerTurn: n('bloodPerTurn', base.bloodPerTurn),
      attributeBonus: n('attributeBonus', base.attributeBonus),
      skillCap: n('skillCap', base.skillCap),
      traitFactor: n('traitFactor', base.traitFactor),
      outOfClanFactor: n('outOfClanFactor', base.outOfClanFactor),
      techniqueCost: n('techniqueCost', base.techniqueCost),
      eldersAllowed: d['eldersAllowed'] == true,
      eldersLimit: n('eldersLimit', base.eldersLimit),
    );
  }

  static const zero = GenRow(
    numbers: [],
    blood: 0,
    bloodPerTurn: 0,
    attributeBonus: 0,
    skillCap: 5,
    traitFactor: 1,
    outOfClanFactor: 4,
    techniqueCost: 0,
    eldersAllowed: false,
    eldersLimit: 0,
  );

  final List<int> numbers;
  final int blood;
  final int bloodPerTurn;
  final int attributeBonus;
  final int skillCap;

  /// Compétences et historiques : nouveau niveau × [traitFactor].
  final int traitFactor;

  /// Disciplines hors clan : nouveau niveau × [outOfClanFactor].
  final int outOfClanFactor;
  final int techniqueCost;
  final bool eldersAllowed;
  final int eldersLimit;
}

/// Données de règles lues par la création et l'XP. Une catégorie vide prend ses valeurs de base.
class Rulebook {
  const Rulebook([this._entries = const {}, this.creation = const CreationValues()]);

  final Map<String, List<RuleEntry>> _entries;
  final CreationValues creation;

  static final _base = <String, List<RuleEntry>>{};
  static final _indexes = Expando<Map<String, Map<String, RuleEntry>>>();
  static final _baseRows = {
    for (final e in baseEntries('generations')) GenRank.values.byName(e.data['rank'] as String): GenRow.fromData(e.data, GenRow.zero),
  };

  List<RuleEntry> all(String cat) {
    final own = _entries[cat];
    return own != null && own.isNotEmpty ? own : _base.putIfAbsent(cat, () => baseEntries(cat));
  }

  /// Élément de ce nom (sans tenir compte de la casse ni des espaces), quel que soit son état.
  RuleEntry? find(String cat, String? name) {
    if (name == null) return null;
    final index = (_indexes[this] ??= {}).putIfAbsent(cat, () => {for (final e in all(cat)) nameKey(e.name): e});
    return index[nameKey(name)];
  }

  /// Proposés aux joueurs : disponibles ou sur accord du conte.
  List<RuleEntry> offered(String cat) => [for (final e in all(cat)) if (e.state.offered) e];

  List<String> offeredNames(String cat) => [for (final e in offered(cat)) e.name];

  int? _int(String cat, String? name, String key) => _count(find(cat, name)?.data[key]);

  /// Valeur en points (atouts, handicaps).
  int? cost(String cat, String name) => _int(cat, name, 'cost');

  List<String> clanDisciplines(String? clan) => [for (final d in (find('clans', clan)?.data['disciplines'] as List?) ?? const []) '$d'];

  String? get defaultSect => all('sects').where((e) => e.data['isDefault'] == true).firstOrNull?.name;

  /// 'common', 'uncommon', 'rare' ou 'forbidden' pour la secte ; à défaut, la rareté de la secte par défaut.
  String rarity(String? clan, String? sect) {
    final m = find('clans', clan)?.data['rarity'];
    if (m is! Map) return 'common';
    String? at(String? s) => s == null ? null : [for (final e in m.entries) if (nameKey('${e.key}') == nameKey(s)) '${e.value}'].firstOrNull;
    return at(sect) ?? at(defaultSect) ?? 'common';
  }

  /// Atout de rareté du clan pour la secte (0 si commun ou interdit).
  int rarityCost(String? clan, String? sect) => switch (rarity(clan, sect)) {
        'uncommon' => 2,
        'rare' => 4,
        _ => 0,
      };

  /// Atout de la lignée [lineage] du clan et sa valeur, ou null.
  (String, int)? lineageMerit(String? clan, String? lineage) {
    if (lineage == null || lineage.trim().isEmpty) return null;
    final rows = (find('clans', clan)?.data['bloodlines'] as List?) ?? const [];
    final row = rows.whereType<Map>().where((r) => nameKey('${r['name'] ?? ''}') == nameKey(lineage)).firstOrNull;
    final merit = row?['merit'];
    if (merit is! String || merit.isEmpty) return null;
    return (merit, cost('merits', merit) ?? 0);
  }

  bool isCommon(String discipline) => find('disciplines', discipline)?.data['common'] == true;

  /// Disciplines achetables hors clan à la création.
  List<String> commonDisciplines() => [for (final e in offered('disciplines')) if (e.data['common'] == true) e.name];

  /// 'perDot', 'multiple', 'optional' ou 'none'.
  String domainMode(String skill) => switch (find('skills', skill)?.data['domainMode']) {
        final String m => m,
        _ => 'none',
      };

  /// Plafond de la compétence, borné par celui du rang.
  int skillCap(String skill, GenRank? rank) => min(_int('skills', skill, 'cap') ?? 5, gen(rank ?? GenRank.neonate).skillCap);

  int backgroundCap(String name) => _int('backgrounds', name, 'cap') ?? 5;

  /// 'monthly', 'people', 'specialties', 'text', ou null (aucune précision demandée).
  String? backgroundAsk(String name) => switch (find('backgrounds', name)?.data['ask']) {
        final String a => a,
        _ => null,
      };

  List<String> backgroundScale(String name) => [for (final x in (find('backgrounds', name)?.data['scale'] as List?) ?? const []) '$x'];

  bool backgroundApproval(String name) => find('backgrounds', name)?.data['approvalRequired'] == true;

  /// 'all', 'pjOnApproval' ou 'npcOnly'.
  String playable(String? sect) => switch (find('sects', sect)?.data['playable']) {
        final String p => p,
        _ => 'all',
      };

  /// Ligne du rang ; rang absent du référentiel : valeurs de base.
  GenRow gen(GenRank rank) {
    final base = _baseRows[rank]!;
    final e = all('generations').where((e) => e.data['rank'] == rank.name).firstOrNull;
    return e == null ? base : GenRow.fromData(e.data, base);
  }
}
```

<!-- file: lib/rulebook/rulebook_provider.dart -->
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../xp/xp_repository.dart';
import 'rulebook.dart';
import 'rules_repository.dart';

part 'rulebook_provider.g.dart';

/// Référentiel des moteurs : null tant que le référentiel ou les valeurs de création chargent.
/// Lecture en erreur : valeurs de base, la création reste possible.
@riverpod
Rulebook? rulebook(Ref ref) {
  final entries = ref.watch(allRuleEntriesProvider);
  final settings = ref.watch(xpSettingsProvider);
  bool waiting(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;
  if (waiting(entries) || waiting(settings)) return null;
  return Rulebook(entries.value ?? const {}, settings.value?.creation ?? const CreationValues());
}
```

Dans `lib/xp/xp_settings.dart` :
- ajouter `import '../rulebook/rulebook.dart';` ;
- dans le constructeur, après `this.tiers = defaultTiers,`, ajouter `this.creation = const CreationValues(),` ;
- dans `fromMap`, après `tiers: tiers.isEmpty ? defaultTiers : tiers,`, ajouter :
  `creation: CreationValues.fromMap(m['creation'] is Map ? Map<String, dynamic>.from(m['creation'] as Map) : null),` ;
- après `final List<XpTier> tiers;`, ajouter :
  ```dart

    /// Valeurs de création (référentiel, sous-projet 5).
    final CreationValues creation;
  ```
- dans `toMap`, après la ligne `'tiers': …,`, ajouter `'creation': creation.toMap(),`.

Dans `lib/rules/met_lists.dart`, remplacer le commentaire `/// Listes de règles de base (Mind's Eye Theatre). Éditables au sous-projet 5.` par `/// Listes de règles de base (Mind's Eye Theatre) : valeurs de base du référentiel (baseEntries).`

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter test test/rulebook test/xp/xp_gain_test.dart`, puis `flutter analyze`.

Expected : tous les tests passent, l'analyseur est propre.

- [ ] **Step 3 : commit**

```
git add lib test
git commit -m "feat: référentiel — Rulebook, repli sur les valeurs de base, valeurs de création" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : moteur de création et écrans de création sur le référentiel

**Files :**
- Replace : `lib/rules/creation_rules.dart`, `lib/creation/creation_steps.dart`.
- Create : `lib/rulebook/rule_hint.dart`.
- Modify :
  - `lib/creation/creation_screen.dart`, `lib/creation/validation_screen.dart`, `lib/xp/xp_settings_screen.dart` ;
  - `test/fakes.dart`, `test/creation/creation_rules_test.dart`, `test/creation/creation_steps_test.dart`, `test/creation/creation_screen_test.dart`, `test/creation/validation_screen_test.dart`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - ces fonctions de `creation_rules.dart` reçoivent `{Rulebook rb = const Rulebook()}` : `isInClan`, `purchaseCost`, `capFor`, `lineageCost`, `budgetOf`, `addPurchase`, `removePurchase`, `setClan`, `setFreeLevel`, `applyDerived`, `creationChecks` ;
  - `stateCheck(rb, cat, noun, name, step) → Check?` ;
  - `Budget` gagne `start` (XP de départ et bonus par défaut) et `setAsideCap` ;
  - les constantes `startingXp`, `maxFlawXp`, `maxSetAside`, `attributeSlots`, `skillSlots`, `backgroundSlots` et `disciplineSlots` disparaissent ; on lit `rb.creation` ;
  - `creationStep(step, c, changed, {rb})` et `stepIntroOf(step, CreationValues)` ;
  - `RuleHint(entry, {maxLines})` ;
  - `baseRulebook` (override de test).

- [ ] **Step 1 : tests du moteur (échec attendu)**

Dans `test/creation/creation_rules_test.dart` :
- ajouter les imports `package:portail_met/rulebook/base_rules.dart`, `package:portail_met/rulebook/rule_entry.dart` et `package:portail_met/rulebook/rulebook.dart` ;
- dans `valid()`, juste après `setFreeLevel(c, Buy.background, generationName, 1);`, ajouter la ligne ci-dessous (les historiques demandent maintenant une précision) :
  `for (final b in c.backgrounds) { if (b.name != generationName) b.note = 'Précisé'; }`
- ajouter, avant la dernière accolade de `main()`, le groupe suivant :

```dart
  group('référentiel', () {
    List<String> blockingWith(Character c, Rulebook rb) => [
          for (final k in creationChecks(c, rb: rb))
            if (k.level == CheckLevel.todo || k.level == CheckLevel.error) k.text,
        ];
    List<String> warnings(Character c, Rulebook rb) => [for (final k in creationChecks(c, rb: rb)) if (k.level == CheckLevel.warn) k.text];

    /// Catégorie de base, avec [edit] appliqué à l'élément [name].
    List<RuleEntry> tweak(String cat, String name, void Function(RuleEntry) edit) {
      final list = baseEntries(cat);
      edit(list.firstWhere((e) => e.name == name));
      return list;
    }

    test('référentiel à moitié rempli : clans et compétences de base (Review Focus 1)', () {
      final rb = Rulebook({
        'merits': [RuleEntry(name: 'Mécène', data: {'cost': 3, 'atCreation': true})],
      });
      final c = valid();
      applyDerived(c, rb: rb);
      expect(blockingWith(c, rb), isEmpty);
      c.merits = [Trait('Chanceux', 2)];
      expect(warnings(c, rb), contains('Atout Chanceux hors liste : à confirmer par le conte'));
    });

    test('états : accord du conte, interdit, hors liste', () {
      final skills = [
        for (final e in baseEntries('skills'))
          if (e.name != 'Vigilance')
            (e..state = switch (e.name) {'Occultisme' => RuleState.approval, 'Érudition' => RuleState.forbidden, _ => e.state}),
      ];
      final rb = Rulebook({'skills': skills});
      final c = valid();
      expect(warnings(c, rb), containsAll(['Occultisme : accord du conte nécessaire', 'Compétence Vigilance hors liste : à confirmer par le conte']));
      expect(blockingWith(c, rb), ['Érudition est interdit dans la chronique']);
    });

    test('clan interdit pour la secte : erreur, fiche inchangée (Review Focus 2)', () {
      final rb = Rulebook({'clans': tweak('clans', 'Tremere', (e) => e.data['rarity'] = {'Camarilla': 'forbidden'})});
      final c = valid();
      final before = c.toMap();
      expect(blockingWith(c, rb), ['Clan Tremere : interdit pour la secte Camarilla']);
      expect(c.toMap(), before);
    });

    test('rareté lue pour la secte de la fiche', () {
      final rb = Rulebook({'clans': tweak('clans', 'Lasombra', (e) => e.data['rarity'] = {'Camarilla': 'rare', 'Sabbat': 'common'})});
      final c = valid();
      setClan(c, 'Lasombra', rb: rb);
      expect(budgetOf(c, rb: rb).merits, 4);
      c.sect = 'Sabbat';
      expect(budgetOf(c, rb: rb).merits, 0);
      c.sect = 'Anarchs';
      expect(budgetOf(c, rb: rb).merits, 4, reason: 'secte absente : celle par défaut');
    });

    test('atout de lignée compté une seule fois', () {
      final rb = Rulebook({
        'clans': tweak('clans', 'Tremere', (e) => e.data['bloodlines'] = [
              {'name': 'Telyav', 'merit': 'Lignée Telyav'},
            ]),
        'merits': [RuleEntry(name: 'Lignée Telyav', data: {'cost': 2, 'atCreation': true})],
      });
      final c = valid()..lineage = 'telyav';
      expect(budgetOf(c, rb: rb).merits, 2);
      c.merits = [Trait('Lignée Telyav', 2)];
      expect(budgetOf(c, rb: rb).merits, 2);
    });

    test('sectes jouables', () {
      final rb = Rulebook({
        'sects': [
          RuleEntry(name: 'Camarilla', data: {'playable': 'all', 'isDefault': true}),
          RuleEntry(name: 'Sabbat', data: {'playable': 'npcOnly'}),
          RuleEntry(name: 'Anarchs', data: {'playable': 'pjOnApproval'}),
        ],
      });
      expect(blockingWith(valid()..sect = 'Sabbat', rb), ['Secte Sabbat : réservée aux PNJ']);
      expect(warnings(valid()..sect = 'Anarchs', rb), contains('Secte Anarchs : PJ sur accord du conte'));
      expect(blockingWith(valid()..sect = 'Sabbat'..kind = CharacterKind.pnj, rb), isEmpty);
    });

    test('domaines selon la compétence', () {
      final multiple = Rulebook({'skills': tweak('skills', 'Occultisme', (e) => e.data['domainMode'] = 'multiple')});
      expect(blockingWith(valid(), multiple), ['Précisez le domaine de Occultisme']);
      final optional = Rulebook({'skills': tweak('skills', 'Occultisme', (e) => e.data['domainMode'] = 'optional')});
      expect(blockingWith(valid(), optional), isEmpty);
    });

    test('historiques : précision, plafond, barème', () {
      final backgrounds = tweak('backgrounds', 'Ressources', (e) => e.data.addAll({'ask': 'monthly', 'scale': ['500 €', '1 000 €']}));
      backgrounds.firstWhere((e) => e.name == 'Alliés').data['cap'] = 2;
      final rb = Rulebook({'backgrounds': backgrounds});
      final c = valid();
      expect(blockingWith(c, rb), ['Alliés : 2 au plus']);
      expect(warnings(c, rb), contains('Ressources : montant hors barème, à valider par le conte'));
      final resources = c.backgrounds.firstWhere((t) => t.name == 'Ressources');
      resources.note = '1 000 €';
      expect(warnings(c, rb), isNot(contains('Ressources : montant hors barème, à valider par le conte')));
      resources.note = null;
      expect(blockingWith(c, rb), contains('Précisez Ressources'));
    });

    test('générations : coûts, Sang et plafonds du référentiel', () {
      final rb = Rulebook({
        'generations': [
          RuleEntry(name: 'Neonate', data: {'rank': 'neonate', 'numbers': ['12'], 'blood': 11, 'traitFactor': 2, 'outOfClanFactor': 5, 'skillCap': 4}),
        ],
      });
      final c = valid();
      applyDerived(c, rb: rb);
      expect((c.blood, c.bloodPerTurn, c.genNumber), (11, 1, 12));
      expect(purchaseCost(c, Buy.skill, 'Informatique', 3, rb: rb), 6);
      expect(addPurchase(c, Buy.discipline, 'Présence', rb: rb), isNull);
      expect(c.purchases.last.cost, 5);
      expect(addPurchase(c, Buy.skill, 'Occultisme', rb: rb), 'Plafond atteint (4).');
      final other = valid()..genNumber = 13;
      applyDerived(other, rb: rb);
      expect(other.genNumber, isNull);
    });

    test('valeurs de création ; fiche soumise avant le changement (Review Focus 3)', () {
      const values = CreationValues(attributeSlots: [8, 5, 3], startingXp: 35, defaultBonus: 2, maxSetAside: 3);
      const rb = Rulebook({}, values);
      expect(blockingWith(valid(), rb), contains('Valeurs calculées incohérentes : réenregistrez la fiche depuis l’application'));
      final c = valid();
      applyDerived(c, rb: rb);
      final b = budgetOf(c, rb: rb);
      expect((b.total, b.setAside, c.xpInitial), (40, 3, 40));
      expect(c.attributes[AttrCategory.mental]!.value, 8);
      expect(creationChecks(c, rb: rb).map((k) => k.text), contains('Attributs répartis 8 / 5 / 3, un focus chacun'));
      expect(blockingWith(c, rb), isEmpty);
    });

    test('disciplines communes lues dans le référentiel', () {
      final rb = Rulebook({'disciplines': tweak('disciplines', 'Présence', (e) => e.data['common'] = false)});
      expect(addPurchase(valid(), Buy.discipline, 'Présence', rb: rb), contains('communes'));
    });
  });
```

Run : `flutter test test/creation/creation_rules_test.dart`.

Expected : échec à la compilation (paramètre `rb` inconnu).

- [ ] **Step 2 : moteur de création**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-b.md 2 impl` (écrit `creation_rules.dart`, `creation_steps.dart` et `rule_hint.dart`).

<!-- file: lib/rules/creation_rules.dart -->
```dart
import 'dart:math';

import '../characters/character.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';

const maxMeritPoints = 7;
const maxOutOfClanDots = 3;
const generationName = 'Génération';
const humanityName = 'Humanité';

const creationSteps = [
  'Inspiration', 'XP initiale', 'Clan', 'Attributs', 'Compétences', 'Historiques', 'Disciplines',
  'Atouts & handicaps', 'Dépense d’XP', 'Finitions & récit',
];

/// Types d'achat de l'étape 9 (valeur de Purchase.kind).
abstract final class Buy {
  static const attribute = 'attribute';
  static const skill = 'skill';
  static const background = 'background';
  static const discipline = 'discipline';
  static const humanity = 'humanity';
}

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

Trait? _find(List<Trait> list, String name) {
  for (final t in list) {
    if (t.name == name) return t;
  }
  return null;
}

Discipline? _findD(List<Discipline> list, String name) {
  for (final d in list) {
    if (d.name == name) return d;
  }
  return null;
}

int purchasedCount(Character c, String kind, String name) =>
    c.purchases.where((p) => p.kind == kind && p.name == name).length;

int generationLevel(Character c) => _find(c.backgrounds, generationName)?.level ?? 0;

GenRank? rankFor(Character c) => switch (generationLevel(c)) {
      <= 0 => null,
      1 => GenRank.neonate,
      2 => GenRank.ancilla,
      _ => GenRank.pretender,
    };

int levelOf(Character c, String kind, String name) => switch (kind) {
      Buy.attribute => c.attributes[AttrCategory.values.byName(name)]!.value,
      Buy.skill => _find(c.skills, name)?.level ?? 0,
      Buy.background => _find(c.backgrounds, name)?.level ?? 0,
      Buy.discipline => _findD(c.disciplines, name)?.level ?? 0,
      Buy.humanity => 5 + purchasedCount(c, Buy.humanity, humanityName),
      _ => 0,
    };

int freeLevelOf(Character c, String kind, String name) => levelOf(c, kind, name) - purchasedCount(c, kind, name);

bool isInClan(Character c, String discipline, {Rulebook rb = const Rulebook()}) =>
    _findD(c.disciplines, discipline)?.inClan ?? rb.clanDisciplines(c.clan).contains(discipline);

/// Coût d'un achat au niveau [toLevel], selon le rang actuel (recalculé à chaque changement de Génération).
int purchaseCost(Character c, String kind, String name, int toLevel, {Rulebook rb = const Rulebook()}) {
  final row = rb.gen(rankFor(c) ?? GenRank.neonate);
  return switch (kind) {
    Buy.attribute => 3,
    Buy.skill => toLevel * row.traitFactor,
    Buy.background => toLevel * (name == generationName ? 2 : row.traitFactor),
    Buy.discipline => toLevel * (isInClan(c, name, rb: rb) ? 3 : row.outOfClanFactor),
    Buy.humanity => 10,
    _ => 0,
  };
}

/// Plafond d'un trait à la création.
int capFor(Character c, String kind, String name, {Rulebook rb = const Rulebook()}) => switch (kind) {
      Buy.attribute => 10,
      Buy.humanity => 6,
      Buy.background when name == generationName => 3,
      Buy.skill => rb.skillCap(name, rankFor(c)),
      Buy.background => rb.backgroundCap(name),
      _ => 5,
    };

/// Valeur de l'atout de lignée, s'il n'est pas déjà pris comme atout.
int lineageCost(Character c, {Rulebook rb = const Rulebook()}) {
  final m = rb.lineageMerit(c.clan, c.lineage);
  if (m == null || c.merits.any((t) => nameKey(t.name) == nameKey(m.$1))) return 0;
  return m.$2;
}

class Budget {
  const Budget({
    required this.start,
    required this.bonus,
    required this.flaws,
    required this.flawsTaken,
    required this.merits,
    required this.purchases,
    required this.setAsideCap,
  });

  /// XP de départ de la chronique, bonus de départ par défaut compris.
  final int start;
  final int bonus;

  /// XP rapportée par les handicaps (plafonnée).
  final int flaws;

  /// Points de handicaps pris (peuvent dépasser le plafond).
  final int flawsTaken;

  /// Points d'atouts, rareté de clan et atout de lignée compris.
  final int merits;
  final int purchases;

  /// XP qui peut être mise de côté à la fin de la création.
  final int setAsideCap;

  int get total => start + bonus + flaws;
  int get spent => merits + purchases;
  int get remaining => total - spent;
  int get setAside => remaining.clamp(0, setAsideCap);
  int get lost => remaining > setAsideCap ? remaining - setAsideCap : 0;
}

Budget budgetOf(Character c, {Rulebook rb = const Rulebook()}) {
  final v = rb.creation;
  final flaws = _sum(c.flaws.map((t) => t.level));
  return Budget(
    start: v.startingXp + v.defaultBonus,
    bonus: c.xpBonus,
    flaws: min(flaws, v.maxFlawXp),
    flawsTaken: flaws,
    merits: _sum(c.merits.map((t) => t.level)) + rb.rarityCost(c.clan, c.sect) + lineageCost(c, rb: rb),
    purchases: _sum(c.purchases.map((p) => purchaseCost(c, p.kind, p.name, p.toLevel, rb: rb))),
    setAsideCap: v.maxSetAside,
  );
}

void _setLevel(Character c, String kind, String name, int level, Rulebook rb) {
  switch (kind) {
    case Buy.attribute:
      c.attributes[AttrCategory.values.byName(name)]!.value = level;
    case Buy.skill || Buy.background:
      final list = kind == Buy.skill ? c.skills : c.backgrounds;
      final t = _find(list, name);
      if (level <= 0) {
        list.removeWhere((x) => x.name == name);
      } else if (t == null) {
        list.add(Trait(name, level));
      } else {
        t.level = level;
      }
    case Buy.discipline:
      final d = _findD(c.disciplines, name);
      if (d == null) {
        if (level > 0) c.disciplines.add(Discipline(name, level, inClan: isInClan(c, name, rb: rb)));
      } else if (level <= 0 && !d.inClan) {
        c.disciplines.remove(d);
      } else {
        d.level = level;
      }
    case Buy.humanity:
      c.humanity = level;
  }
}

/// Achète un niveau. Renvoie un message si l'achat est impossible.
String? addPurchase(Character c, String kind, String name, {Rulebook rb = const Rulebook()}) {
  final to = levelOf(c, kind, name) + 1;
  final cap = capFor(c, kind, name, rb: rb);
  if (to > cap) return 'Plafond atteint ($cap).';
  if (kind == Buy.discipline && !isInClan(c, name, rb: rb)) {
    if (!rb.isCommon(name)) {
      return 'Hors clan, seules les disciplines communes s’achètent à la création.';
    }
    final outOfClan = _sum(c.disciplines.where((d) => !d.inClan).map((d) => d.level));
    if (outOfClan + 1 > maxOutOfClanDots) return 'Hors clan : $maxOutOfClanDots points au plus à la création.';
  }
  final cost = purchaseCost(c, kind, name, to, rb: rb);
  _setLevel(c, kind, name, to, rb);
  c.purchases.add(Purchase(kind, name, to, cost));
  return null;
}

/// Retire un achat ; seulement le plus haut niveau acheté d'un trait.
String? removePurchase(Character c, int index, {Rulebook rb = const Rulebook()}) {
  final p = c.purchases[index];
  if (levelOf(c, p.kind, p.name) != p.toLevel) return 'Retirez d’abord l’achat de niveau supérieur.';
  c.purchases.removeAt(index);
  _setLevel(c, p.kind, p.name, p.toLevel - 1, rb);
  return null;
}

/// Choix du clan : disciplines en clan du clan ; les anciennes sont retirées, ou passent hors clan si achetées.
void setClan(Character c, String? name, {Rulebook rb = const Rulebook()}) {
  if (name == c.clan) return; // Caïtiff : ne pas effacer les disciplines déjà choisies
  c.clan = name;
  final own = rb.clanDisciplines(name);
  bool inNew(Discipline d) => own.contains(d.name);
  c.disciplines.removeWhere((d) => d.inClan && purchasedCount(c, Buy.discipline, d.name) == 0 && !inNew(d));
  for (final d in c.disciplines) {
    if (d.inClan && !inNew(d)) {
      // Hors clan, seuls les points achetés restent (pas de points gratuits).
      d
        ..inClan = false
        ..level = purchasedCount(c, Buy.discipline, d.name);
    }
  }
  for (final n in own) {
    final d = _findD(c.disciplines, n);
    if (d == null) {
      c.disciplines.add(Discipline(n, 0, inClan: true));
    } else {
      d.inClan = true;
    }
  }
}

/// Niveau gratuit d'une compétence ou d'un historique (le niveau final ajoute les achats).
void setFreeLevel(Character c, String kind, String name, int free, {Rulebook rb = const Rulebook()}) =>
    _setLevel(c, kind, name, free + purchasedCount(c, kind, name), rb);

void setDisciplineFree(Character c, String name, int free) {
  final d = _findD(c.disciplines, name);
  if (d != null) d.level = free + purchasedCount(c, Buy.discipline, name);
}

/// Les achats d'un trait occupent toujours les niveaux juste au-dessus de ses points gratuits,
/// même après un changement de niveau gratuit, de catégorie ou de clan.
void _renumberPurchases(Character c, Rulebook rb) {
  final seen = <String, int>{};
  for (var i = 0; i < c.purchases.length; i++) {
    final p = c.purchases[i];
    final key = '${p.kind}/${p.name}';
    final n = seen[key] = (seen[key] ?? 0) + 1;
    final to = freeLevelOf(c, p.kind, p.name) + n;
    if (to != p.toLevel) c.purchases[i] = Purchase(p.kind, p.name, to, purchaseCost(c, p.kind, p.name, to, rb: rb));
  }
}

/// Recalcule rang, Sang, Volonté, Humanité, Santé, attributs et compteurs d'XP.
void applyDerived(Character c, {Rulebook rb = const Rulebook()}) {
  final rank = rankFor(c);
  c.genRank = rank;
  final row = rank == null ? null : rb.gen(rank);
  if (row == null || !row.numbers.contains(c.genNumber)) c.genNumber = null;
  c
    ..blood = row?.blood ?? 0
    ..bloodPerTurn = row?.bloodPerTurn ?? 0
    ..willpower = 6
    ..humanity = levelOf(c, Buy.humanity, humanityName)
    ..health = '3 · 3 · 3';
  final slots = rb.creation.attributeSlots;
  for (final cat in AttrCategory.values) {
    final i = c.attributeRanks.indexOf(cat);
    c.attributes[cat]!.value = (i >= 0 ? slots[i] : 0) + purchasedCount(c, Buy.attribute, cat.name);
  }
  _renumberPurchases(c, rb);
  final b = budgetOf(c, rb: rb);
  c
    ..xpInitial = b.start + c.xpBonus + b.flaws
    ..xpSpent = b.spent
    ..xpEarned = b.setAside;
}

enum CheckLevel { ok, todo, warn, error }

class Check {
  const Check(this.step, this.level, this.text);
  final int step;
  final CheckLevel level;
  final String text;
}

/// État dans le référentiel d'un nom porté par la fiche : hors liste ou accord du conte (avertissement),
/// interdit ou brouillon (erreur) ; null si rien à signaler.
Check? stateCheck(Rulebook rb, String cat, String noun, String name, int step) {
  final e = rb.find(cat, name);
  if (e == null) return Check(step, CheckLevel.warn, '$noun $name hors liste : à confirmer par le conte');
  if (!e.state.offered) return Check(step, CheckLevel.error, '$name est interdit dans la chronique');
  if (e.state == RuleState.approval) return Check(step, CheckLevel.warn, '$name : accord du conte nécessaire');
  return null;
}

String _plural(int n, String one, String many) => n > 1 ? many : one;

void _slots(List<Check> out, int step, (String, String) noun, List<int> free, List<int> slots, String okText) {
  final placed = free.where((l) => l > 0).toList();
  final messages = <String>[];
  for (final level in slots.toSet()) {
    final expected = slots.where((s) => s == level).length;
    final actual = placed.where((l) => l == level).length;
    final pts = _plural(level, 'point', 'points');
    if (actual < expected) {
      final n = expected - actual;
      messages.add('il reste $n ${_plural(n, noun.$1, noun.$2)} à placer à $level $pts');
    } else if (actual > expected) {
      messages.add('trop de ${noun.$2} à $level $pts');
    }
  }
  if (placed.any((l) => !slots.contains(l))) messages.add('niveau gratuit non prévu');
  if (messages.isEmpty) {
    out.add(Check(step, CheckLevel.ok, okText));
  } else {
    final text = messages.join(', ');
    out.add(Check(step, CheckLevel.todo, '${text[0].toUpperCase()}${text.substring(1)}.'));
  }
}

/// Contrôles des maquettes (étapes 4 et 10, C4). Bloquants : todo et error.
List<Check> creationChecks(Character c, {Rulebook rb = const Rulebook()}) {
  final out = <Check>[];
  void add(int step, CheckLevel level, String text) => out.add(Check(step, level, text));
  void state(int step, String cat, String noun, String? name) {
    final k = name == null ? null : stateCheck(rb, cat, noun, name, step);
    if (k != null) out.add(k);
  }

  final v = rb.creation;

  final identity = [c.name, c.concept, c.archetype, c.sect].every((s) => (s ?? '').trim().isNotEmpty);
  add(1, identity ? CheckLevel.ok : CheckLevel.todo,
      identity ? 'Nom, concept, archétype et secte renseignés' : 'Renseignez le nom, le concept, l’archétype et la secte');
  state(1, 'archetypes', 'Archétype', c.archetype);
  state(1, 'sects', 'Secte', c.sect);
  if (c.kind == CharacterKind.pj && c.sect != null) {
    final playable = rb.playable(c.sect);
    if (playable == 'npcOnly') add(1, CheckLevel.error, 'Secte ${c.sect} : réservée aux PNJ');
    if (playable == 'pjOnApproval') add(1, CheckLevel.warn, 'Secte ${c.sect} : PJ sur accord du conte');
  }

  final clan = rb.find('clans', c.clan);
  if (c.clan == null) {
    add(3, CheckLevel.todo, 'Choisissez un clan');
  } else if (clan == null) {
    add(3, CheckLevel.warn, 'Clan ${c.clan} hors liste : à confirmer par le conte');
  } else {
    state(3, 'clans', 'Clan', c.clan);
    switch (rb.rarity(c.clan, c.sect)) {
      case 'forbidden':
        add(3, CheckLevel.error, 'Clan ${c.clan} : interdit pour la secte ${c.sect ?? 'choisie'}');
      case 'uncommon':
        add(3, CheckLevel.ok, 'Clan ${c.clan} : peu commun, atout de 2 points');
      case 'rare':
        add(3, CheckLevel.warn, 'Clan ${c.clan} : rare, atout de 4 points, accord du conte nécessaire');
      default:
        add(3, CheckLevel.ok, 'Clan ${c.clan} : commun, aucun atout de rareté');
    }
  }

  final ranked = c.attributeRanks.whereType<AttrCategory>().toSet().length == 3;
  final focused = AttrCategory.values.every((a) => (c.attributes[a]!.focus ?? '').isNotEmpty);
  final attributes = v.attributeSlots.join(' / ');
  add(4, ranked && focused ? CheckLevel.ok : CheckLevel.todo,
      ranked && focused ? 'Attributs répartis $attributes, un focus chacun' : 'Classez les attributs $attributes et choisissez un focus par catégorie');

  _slots(out, 5, ('compétence', 'compétences'), [for (final s in c.skills) freeLevelOf(c, Buy.skill, s.name)], v.skillSlots,
      'Compétences ${slotsText(v.skillSlots)}');
  for (final s in c.skills) {
    final mode = rb.domainMode(s.name);
    if ((mode == 'perDot' || mode == 'multiple') && (s.note ?? '').trim().isEmpty) add(5, CheckLevel.todo, 'Précisez le domaine de ${s.name}');
    state(5, 'skills', 'Compétence', s.name);
    final cap = rb.skillCap(s.name, rankFor(c));
    if (s.level > cap) add(5, CheckLevel.error, '${s.name} : $cap au plus');
  }

  _slots(out, 6, ('historique', 'historiques'), [for (final b in c.backgrounds) freeLevelOf(c, Buy.background, b.name)],
      v.backgroundSlots, 'Historiques ${v.backgroundSlots.join(' / ')}');
  for (final b in c.backgrounds) {
    if (b.name == generationName) continue;
    state(6, 'backgrounds', 'Historique', b.name);
    final note = (b.note ?? '').trim();
    final ask = rb.backgroundAsk(b.name);
    if (ask != null && note.isEmpty) add(6, CheckLevel.todo, 'Précisez ${b.name}');
    final scale = rb.backgroundScale(b.name);
    if (ask == 'monthly' && note.isNotEmpty && b.level >= 1 && b.level <= scale.length && nameKey(note) != nameKey(scale[b.level - 1])) {
      add(6, CheckLevel.warn, '${b.name} : montant hors barème, à valider par le conte');
    }
    if (rb.backgroundApproval(b.name)) add(6, CheckLevel.warn, '${b.name} : montant à valider par le conte');
    final cap = rb.backgroundCap(b.name);
    if (b.level > cap) add(6, CheckLevel.error, '${b.name} : $cap au plus');
  }
  if (generationLevel(c) == 0) {
    add(6, CheckLevel.error, 'Sans point de Génération, le personnage est un mortel');
  } else if (c.genNumber == null) {
    add(6, CheckLevel.todo, 'Choisissez la génération');
  }

  final inClan = c.disciplines.where((d) => d.inClan).toList();
  if (inClan.length != 3) {
    final choose = clan != null && rb.clanDisciplines(c.clan).isEmpty;
    add(7, CheckLevel.todo, choose ? 'Choisissez trois disciplines communes' : 'Trois disciplines en clan attendues');
  } else {
    _slots(out, 7, ('discipline en clan', 'disciplines en clan'), [for (final d in inClan) freeLevelOf(c, Buy.discipline, d.name)],
        v.disciplineSlots, 'Disciplines en clan ${v.disciplineSlots.join(' / ')}');
  }
  for (final d in c.disciplines) {
    state(7, 'disciplines', 'Discipline', d.name);
  }
  for (final d in c.disciplines.where((d) => !d.inClan)) {
    if (freeLevelOf(c, Buy.discipline, d.name) > 0) add(7, CheckLevel.error, '${d.name} hors clan : uniquement par achat');
    if (d.level > 0 && !rb.isCommon(d.name)) add(7, CheckLevel.error, '${d.name} hors clan : seules les disciplines communes à la création');
  }

  final b = budgetOf(c, rb: rb);
  if (b.merits > maxMeritPoints) {
    add(8, CheckLevel.error, 'Atouts : ${b.merits} / $maxMeritPoints points');
  } else {
    add(8, CheckLevel.ok, 'Atouts ${b.merits} / $maxMeritPoints · handicaps ${b.flawsTaken} / ${v.maxFlawXp} XP');
  }
  if (b.flawsTaken > v.maxFlawXp) add(8, CheckLevel.warn, 'Handicaps au-delà de ${v.maxFlawXp} : pas d’XP en plus');
  for (final (cat, noun, list) in [('merits', 'Atout', c.merits), ('flaws', 'Handicap', c.flaws)]) {
    for (final t in list) {
      state(8, cat, noun, t.name);
      final value = rb.cost(cat, t.name);
      if (value != null && value != t.level) add(8, CheckLevel.warn, '${t.name} : $value points dans le référentiel, ${t.level} sur la fiche');
    }
  }

  // Plafond du livre (p. 300) ; un brouillon d'avant ce plafond a pu aller au-delà.
  if (c.humanity > 6) add(9, CheckLevel.error, 'Humanité : 6 au plus.');
  if (b.remaining < 0) {
    add(9, CheckLevel.error, 'Budget dépassé de ${-b.remaining} XP');
  } else {
    add(9, CheckLevel.ok, '${b.spent} XP dépensés, ${b.setAside} mis de côté');
    if (b.lost > 0) add(9, CheckLevel.warn, '${b.lost} XP perdus (${v.maxSetAside} au plus mis de côté)');
  }

  // Les règles Firestore ne recalculent rien : une fiche écrite hors de l'application, ou calculée
  // avant un changement des valeurs de création, se voit ici (Review Focus 3).
  final derived = c.clone();
  applyDerived(derived, rb: rb);
  String stored(Character x) => [
        x.xpInitial, x.xpSpent, x.xpEarned, x.blood, x.bloodPerTurn, x.willpower, x.humanity, x.genRank,
        for (final a in AttrCategory.values) x.attributes[a]!.value,
        for (final p in x.purchases) '${p.toLevel}:${p.cost}',
      ].join('|');
  if (stored(derived) != stored(c)) {
    add(9, CheckLevel.error, 'Valeurs calculées incohérentes : réenregistrez la fiche depuis l’application');
  }

  if ((c.story ?? '').trim().isEmpty) add(10, CheckLevel.warn, 'Récit vide : quelques lignes aideront le conte');
  return out;
}

bool canSubmit(List<Check> checks) => checks.every((k) => k.level == CheckLevel.ok || k.level == CheckLevel.warn);

/// Coche d'une étape dans la navigation.
bool stepComplete(Character c, int step, List<Check> checks) => switch (step) {
      2 => c.step > 2,
      10 => canSubmit(checks),
      _ => checks.where((k) => k.step == step).every((k) => k.level == CheckLevel.ok || k.level == CheckLevel.warn),
    };
```

<!-- file: lib/rulebook/rule_hint.dart -->
```dart
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'rule_entry.dart';

/// Sous un élément choisi : « Accord du conte » et la règle affichée aux joueurs.
class RuleHint extends StatelessWidget {
  const RuleHint(this.entry, {super.key, this.maxLines});
  final RuleEntry? entry;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final approval = e?.state == RuleState.approval;
    if (e == null || (!approval && e.description.isEmpty)) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (approval) Text('Accord du conte', style: t.labelMedium?.copyWith(color: AppColors.goldLight)),
        if (e.description.isNotEmpty)
          Text(e.description, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: t.bodySmall),
      ]),
    );
  }
}
```

<!-- file: lib/creation/creation_steps.dart -->
```dart
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
String stepIntroOf(int step, CreationValues v) {
  final a = v.attributeSlots, d = v.disciplineSlots;
  return switch (step) {
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
      3 => _ClanStep(c, rb, changed),
      4 => _AttributesStep(c, rb, changed),
      5 => _SkillsStep(c, rb, changed),
      6 => _BackgroundsStep(c, rb, changed),
      7 => _DisciplinesStep(c, rb, changed),
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
        names: rb.offeredNames('backgrounds'),
        max: slots.reduce(max),
        noteLabel: 'Précisions',
        needsNote: (n) => n != generationName && rb.backgroundAsk(n) != null,
        changed: changed,
      ),
      const SizedBox(height: 20),
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
    Buy.humanity: 'Humanité',
  };

  String? get _cat => switch (_kind) {
        Buy.skill => 'skills',
        Buy.background => 'backgrounds',
        Buy.discipline => 'disciplines',
        _ => null,
      };

  Map<String, String> _names(Character c, Rulebook rb) => switch (_kind) {
        Buy.attribute => {for (final a in AttrCategory.values) a.name: a.label},
        Buy.skill => {for (final s in {...rb.offeredNames('skills'), ...c.skills.map((s) => s.name)}) s: s},
        Buy.background => {for (final b in {...rb.offeredNames('backgrounds'), ...c.backgrounds.map((b) => b.name)}) b: b},
        Buy.discipline => {
            for (final d in {...c.disciplines.where((d) => d.inClan).map((d) => d.name), ...rb.commonDisciplines()}) d: d,
          },
        _ => {humanityName: humanityName},
      };

  String _label(Purchase p) => switch (p.kind) {
        Buy.attribute => 'Attribut · ${AttrCategory.values.byName(p.name).label}',
        Buy.skill => 'Compétence · ${p.name}',
        Buy.background => 'Historique · ${p.name}',
        Buy.discipline => '${p.name} (${isInClan(widget.c, p.name, rb: widget.rb) ? 'en clan' : 'hors clan'})',
        _ => p.name,
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final rb = widget.rb;
    final t = Theme.of(context).textTheme;
    final names = _names(c, rb);
    final rank = rankFor(c) ?? GenRank.neonate;
    final row = rb.gen(rank);
    final cat = _cat;
    void buy() {
      final name = _name;
      if (name == null) return;
      final error = addPurchase(c, _kind, name, rb: rb);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
              items: [for (final e in _kinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
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
              initialValue: _name,
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
      _section(context, 'Coûts ${rank.label}', [
        for (final (k, v) in [
          ('Attribut', '3 XP'),
          ('Compétence, historique', 'Niveau × ${row.traitFactor}'),
          ('Discipline en clan', 'Niveau × 3'),
          ('Hors clan (communes, $maxOutOfClanDots points au plus)', 'Niveau × ${row.outOfClanFactor}'),
          ('Génération', 'Niveau × 2'),
          ('Humanité', '10 XP le point, 6 au plus'),
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
```

- [ ] **Step 3 : écrans et fake**

**`lib/creation/creation_screen.dart` :**
- ajouter les imports `../rulebook/rulebook.dart` et `../rulebook/rulebook_provider.dart` ;
- dans `_changed()`, remplacer `applyDerived(_c!);` par `applyDerived(_c!, rb: ref.read(rulebookProvider) ?? const Rulebook());` ;
- dans `build`, après `final me = ref.watch(currentUserProvider).value;`, ajouter `final rb = ref.watch(rulebookProvider);` ;
- remplacer `if (me == null) return const Center(child: CircularProgressIndicator());` par `if (me == null || rb == null) return const Center(child: CircularProgressIndicator());` ;
- retirer les deux `applyDerived(_c!);` des branches `if (_c == null)` et `else if (!_saving …)`. Après ce bloc, avant `final c = _c!;`, ajouter :
  ```dart
        // Le référentiel ou les valeurs de création ont pu changer : les valeurs calculées suivent.
        applyDerived(_c!, rb: rb);
  ```
- `creationChecks(c)` devient `creationChecks(c, rb: rb)` ;
- `Text(stepIntro[_step - 1], …)` devient `Text(stepIntroOf(_step, rb.creation), …)` ;
- `creationStep(_step, c, _changed)` devient `creationStep(_step, c, _changed, rb: rb)` ;
- `_BudgetPanel(c)` devient `_BudgetPanel(c, rb)`. Dans la classe :
  - constructeur `const _BudgetPanel(this.c, this.rb);`, champ `final Rulebook rb;` ;
  - `budgetOf(c)` devient `budgetOf(c, rb: rb)` ;
  - le texte `'$startingXp de départ · …'` devient `'${b.start} de départ · ${b.bonus} bonus · ${b.flaws} via handicaps · ${b.spent} dépensé'` ;
  - le texte `'5 XP au plus peuvent être mis de côté à la fin de la création.'` devient `'${rb.creation.maxSetAside} XP au plus peuvent être mis de côté à la fin de la création.'`.

**`lib/creation/validation_screen.dart` :**
- ajouter l'import `../rulebook/rulebook_provider.dart` ;
- dans `_creationDetail`, remplacer `final checks = creationChecks(selected);` par :
  ```dart
      final rb = ref.watch(rulebookProvider);
      if (rb == null) return const Center(child: CircularProgressIndicator());
      final checks = creationChecks(selected, rb: rb);
  ```

**`lib/xp/xp_settings_screen.dart`** (lecture seule ici ; l'édition vient à la tâche 4) :
- remplacer `import '../rules/creation_rules.dart' show maxFlawXp, maxSetAside, startingXp;` par `import '../rulebook/rulebook.dart';` ;
- remplacer les trois `const InfoRow(…)` du bloc « XP de création » par :
  ```dart
            InfoRow('XP de départ', '${(_saved?.creation ?? const CreationValues()).startingXp}'),
            InfoRow('Maximum via handicaps', '${(_saved?.creation ?? const CreationValues()).maxFlawXp}'),
            InfoRow('Maximum mis de côté', '${(_saved?.creation ?? const CreationValues()).maxSetAside}'),
  ```
  Si l'analyseur signale `prefer_const` sur `Column`, retirer le `const` du parent.

**`test/fakes.dart` :**
- ajouter les imports `package:portail_met/rulebook/rulebook.dart` et `package:portail_met/rulebook/rulebook_provider.dart` (ordre alphabétique) ;
- ajouter à la fin :
  ```dart
  /// Référentiel de base, sans Firestore.
  final baseRulebook = rulebookProvider.overrideWith((ref) => const Rulebook());
  ```

**Tests d'écrans :**
- dans `test/creation/validation_screen_test.dart`, après `overrides: [`, ajouter `baseRulebook,` ;
- dans `test/creation/creation_screen_test.dart` :
  - ajouter le paramètre `bool loading = false` à `pump`, et dans `overrides: [`, la ligne `rulebookProvider.overrideWith((ref) => loading ? null : const Rulebook()),` ;
  - ajouter les imports `package:portail_met/rulebook/rulebook.dart` et `package:portail_met/rulebook/rulebook_provider.dart` ;
  - ajouter le test :
  ```dart
    testWidgets('référentiel en chargement : la création attend (Review Focus 5)', (tester) async {
      await pump(tester, valid()..step = 1, loading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Suivant : XP initiale'), findsNothing);
    });
  ```
- dans `test/creation/creation_steps_test.dart` :
  - `pumpStep` reçoit `{Rulebook rb = const Rulebook()}` et appelle `creationStep(step, c, () { applyDerived(c, rb: rb); setState(() {}); }, rb: rb)` ;
  - ajouter les imports `package:portail_met/rulebook/base_rules.dart`, `package:portail_met/rulebook/rule_entry.dart` et `package:portail_met/rulebook/rulebook.dart` ;
  - ajouter le test :
  ```dart
    testWidgets('étape 3 : badge et règle du conte, clan interdit pour la secte absent', (tester) async {
      final clans = baseEntries('clans');
      clans.firstWhere((e) => e.name == 'Tremere')
        ..state = RuleState.approval
        ..description = 'Pyramide stricte.';
      clans.firstWhere((e) => e.name == 'Brujah').data['rarity'] = {'Camarilla': 'forbidden'};
      final c = Character(id: 'n', name: 'N', kind: CharacterKind.pj)..sect = 'Camarilla';
      await pumpStep(tester, 3, c, rb: Rulebook({'clans': clans}));
      expect(find.text('Accord du conte'), findsOneWidget);
      expect(find.text('Pyramide stricte.'), findsOneWidget);
      expect(find.text('Brujah'), findsNothing);
    });
  ```

- [ ] **Step 4 : tester, analyser**

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test test/creation test/rulebook`.

Expected : tous les tests passent, l'analyseur est propre. Les fichiers XP compilent : `xp_rules.dart` ne dépend que de `Check`, `CheckLevel`, `generationName`, `humanityName` et `maxMeritPoints`, toujours présents.

- [ ] **Step 5 : commit**

```
git add lib test
git commit -m "feat: création branchée sur le référentiel — états, rareté par secte, sectes jouables, domaines, historiques, générations, valeurs de création" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : moteur d'XP et écrans d'XP sur le référentiel

**Files :**
- Replace : `lib/xp/xp_rules.dart`.
- Modify :
  - `lib/xp/xp_repository.dart`, `lib/xp/spend_screen.dart`, `lib/xp/request_review.dart` ;
  - `test/fakes.dart`, `test/xp/xp_rules_test.dart`, `test/xp/spend_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2 (`stateCheck`, `lineageCost`).
- Produces :
  - ces fonctions reçoivent `{Rulebook rb = const Rulebook()}` : `inClan`, `costOf`, `ruleText`, `costTable`, `elementOptions`, `draftItem`, `meritPoints`, `itemError`, `wellFormed`, `requestChecks`, `recomputedTotal`, `applyRequest` ;
  - `capOf(c, kind, name, {rb})` remplace `capOf(kind)` ;
  - `noteSpec(kind, name, {rb}) → (String, bool)?` remplace `noteLabel` ;
  - `ruleCategoryOf(kind)` ;
  - `XpRepository.decide(…, {rb})`.

- [ ] **Step 1 : tests du moteur (échec attendu)**

Dans `test/xp/xp_rules_test.dart` :
- ajouter les imports `package:portail_met/rulebook/base_rules.dart`, `package:portail_met/rulebook/rule_entry.dart` et `package:portail_met/rulebook/rulebook.dart` ;
- remplacer l'aide `err` par :
  ```dart
  String? err(Character c, XpKind k, String name, {String? note, int usable = 100, List<XpItem>? items, Rulebook rb = const Rulebook()}) {
    final list = items ?? <XpItem>[];
    return itemError(c, list, draftItem(c, list, k, name, note: note, rb: rb), usable: usable, rb: rb);
  }
  ```
- ajouter, avant la dernière accolade de `main()` :

```dart
  group('référentiel', () {
    List<RuleEntry> tweak(String cat, String name, void Function(RuleEntry) edit) {
      final list = baseEntries(cat);
      edit(list.firstWhere((e) => e.name == name));
      return list;
    }

    test('coûts selon la ligne du rang', () {
      final rb = Rulebook({
        'generations': [RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'traitFactor': 3, 'outOfClanFactor': 5})],
      });
      final c = sample();
      expect(draftItem(c, const [], XpKind.skill, 'Linguistique', rb: rb).cost, 3);
      final domination = draftItem(c, const [], XpKind.discipline, 'Domination', rb: rb);
      expect(domination.cost, 5);
      expect(ruleText(c, domination, rb: rb), 'Hors clan · nouveau niveau × 5');
      expect(costTable(c, rb: rb), contains(('Compétence', 'Nouveau niveau × 3')));
    });

    test('états : élément interdit refusé, accord du conte signalé', () {
      final skills = [
        for (final e in baseEntries('skills'))
          (e..state = switch (e.name) {'Linguistique' => RuleState.forbidden, 'Bagarre' => RuleState.approval, _ => e.state}),
      ];
      final rb = Rulebook({'skills': skills});
      final c = sample();
      final options = elementOptions(c, XpKind.skill, rb: rb);
      expect(options, isNot(contains('Linguistique')));
      expect(options['Bagarre'], 'Bagarre · accord du conte');
      final forbidden = draftItem(c, const [], XpKind.skill, 'Linguistique', rb: rb);
      expect(itemError(c, const [], forbidden, usable: 100, rb: rb), 'Linguistique est interdit dans la chronique.');
      final r = req([draftItem(c, const [], XpKind.skill, 'Bagarre', rb: rb)]);
      expect(requestChecks(c, r, reservedOthers: 0, rb: rb).map((k) => k.text), contains('Bagarre : accord du conte nécessaire'));
    });

    test('domaines et plafonds du référentiel', () {
      final skills = tweak('skills', 'Bagarre', (e) => e.data['domainMode'] = 'optional');
      skills.firstWhere((e) => e.name == 'Représentation').data['cap'] = 4;
      final rb = Rulebook({'skills': skills});
      final c = sample();
      expect(noteSpec(XpKind.skill, 'Bagarre', rb: rb), ('Domaine', false));
      expect(noteSpec(XpKind.skill, 'Représentation', rb: rb), ('Domaine', true));
      expect(noteSpec(XpKind.skill, 'Esquive', rb: rb), isNull);
      expect(noteSpec(XpKind.background, 'Ressources', rb: rb), ('Détail du nouveau point', true));
      expect(err(c, XpKind.skill, 'Bagarre', rb: rb), isNull);
      expect(err(c, XpKind.skill, 'Représentation', note: 'opéra', rb: rb), 'Plafond atteint (4).');
    });

    test('atout : valeur du référentiel ; valeur changée après l’envoi (Review Focus 4)', () {
      final c = sample();
      final sent = req([draftItem(c, const [], XpKind.merit, 'Chanceux')]);
      final rb = Rulebook({'merits': tweak('merits', 'Chanceux', (e) => e.data['cost'] = 3)});
      expect(draftItem(c, const [], XpKind.merit, 'Chanceux', rb: rb).toLevel, 3);
      final errors = [for (final k in requestChecks(c, sent, reservedOthers: 0, rb: rb)) if (k.level == CheckLevel.error) k.text];
      expect(errors, ['Achat invalide : Atout · Chanceux vaut 3 points, la demande en compte 2']);
    });

    test('rareté par secte et disciplines du clan du référentiel', () {
      final clans = tweak('clans', 'Toreador', (e) => e.data
        ..['rarity'] = {'Camarilla': 'rare'}
        ..['disciplines'] = ['Auspex', 'Domination', 'Présence']);
      final rb = Rulebook({'clans': clans});
      final c = sample();
      expect(meritPoints(c, const [], rb: rb), 5);
      final after = applyRequest(c, [draftItem(c, const [], XpKind.discipline, 'Domination', rb: rb)], rb: rb);
      expect(after.disciplines.firstWhere((d) => d.name == 'Domination').inClan, isTrue);
      expect(after.xpSpent, c.xpSpent + 3);
    });
  });
```

Run : `flutter test test/xp/xp_rules_test.dart`.

Expected : échec à la compilation.

- [ ] **Step 2 : moteur d'XP**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-04-referentiel-b.md 3 impl`.

<!-- file: lib/xp/xp_rules.dart -->
```dart
import '../characters/character.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import '../rules/creation_rules.dart' show Check, CheckLevel, generationName, humanityName, lineageCost, maxMeritPoints, stateCheck;
import 'xp_request.dart';

Trait? _trait(List<Trait> list, String name) => list.where((t) => t.name == name).firstOrNull;

Discipline? _discipline(Character c, String name) => c.disciplines.where((d) => d.name == name).firstOrNull;

/// Niveau actuel du trait sur la fiche.
int levelNow(Character c, XpKind k, String name) => switch (k) {
      XpKind.attribute => c.attributes[AttrCategory.values.byName(name)]!.value,
      XpKind.skill => _trait(c.skills, name)?.level ?? 0,
      XpKind.background => _trait(c.backgrounds, name)?.level ?? 0,
      XpKind.discipline => _discipline(c, name)?.level ?? 0,
      XpKind.merit => _trait(c.merits, name)?.level ?? 0,
      XpKind.humanity => c.humanity,
      XpKind.flawBuyback => _trait(c.flaws, name)?.level ?? 0,
    };

/// Niveau après les achats déjà dans la demande.
int levelWith(Character c, List<XpItem> items, XpKind k, String name) {
  final last = items.where((i) => i.kind == k && i.name == name).lastOrNull;
  return last?.toLevel ?? levelNow(c, k, name);
}

GenRow _row(Character c, Rulebook rb) => rb.gen(c.genRank ?? GenRank.neonate);

bool inClan(Character c, String discipline, {Rulebook rb = const Rulebook()}) =>
    _discipline(c, discipline)?.inClan ?? rb.clanDisciplines(c.clan).contains(discipline);

/// Catégorie du référentiel d'un type d'achat.
String? ruleCategoryOf(XpKind k) => switch (k) {
      XpKind.skill => 'skills',
      XpKind.background => 'backgrounds',
      XpKind.discipline => 'disciplines',
      XpKind.merit => 'merits',
      XpKind.flawBuyback => 'flaws',
      _ => null,
    };

/// Coût au barème actuel de la fiche.
int costOf(Character c, XpItem i, {Rulebook rb = const Rulebook()}) => switch (i.kind) {
      XpKind.attribute => 3,
      XpKind.skill || XpKind.background => i.toLevel * _row(c, rb).traitFactor,
      XpKind.discipline => i.toLevel * (inClan(c, i.name, rb: rb) ? 3 : _row(c, rb).outOfClanFactor),
      XpKind.merit => i.toLevel,
      XpKind.humanity => 10,
      XpKind.flawBuyback => 2 * i.fromLevel,
    };

String ruleText(Character c, XpItem i, {Rulebook rb = const Rulebook()}) => switch (i.kind) {
      XpKind.attribute => '3 XP par point',
      XpKind.skill || XpKind.background => 'Nouveau niveau × ${_row(c, rb).traitFactor}',
      XpKind.discipline =>
        inClan(c, i.name, rb: rb) ? 'En clan · nouveau niveau × 3' : 'Hors clan · nouveau niveau × ${_row(c, rb).outOfClanFactor}',
      XpKind.merit => 'Sa valeur en XP',
      XpKind.humanity => '10 XP le point, 6 au plus',
      XpKind.flawBuyback => '2 × sa valeur',
    };

/// Tableau « Coûts pour un … » (J-XP).
List<(String, String)> costTable(Character c, {Rulebook rb = const Rulebook()}) {
  final row = _row(c, rb);
  return [
    ('Attribut', '3 XP par point'),
    ('Compétence', 'Nouveau niveau × ${row.traitFactor}'),
    ('Historique', 'Nouveau niveau × ${row.traitFactor}'),
    ('Discipline en clan', 'Nouveau niveau × 3'),
    ('Discipline hors clan', 'Nouveau niveau × ${row.outOfClanFactor}'),
    ('Atout', 'Sa valeur en XP'),
    ('Humanité', '10 XP le point, 6 au plus'),
    ('Rachat d’un handicap', '2 × sa valeur'),
  ];
}

int capOf(Character c, XpKind k, String name, {Rulebook rb = const Rulebook()}) => switch (k) {
      XpKind.attribute => 10,
      XpKind.humanity => 6,
      XpKind.skill => rb.skillCap(name, c.genRank),
      XpKind.background => rb.backgroundCap(name),
      _ => 5,
    };

/// Précision demandée pour un nouveau point : (libellé, obligatoire), ou null.
(String, bool)? noteSpec(XpKind k, String name, {Rulebook rb = const Rulebook()}) => switch (k) {
      XpKind.background => ('Détail du nouveau point', true),
      XpKind.skill => switch (rb.domainMode(name)) {
          'perDot' || 'multiple' => ('Domaine', true),
          'optional' => ('Domaine', false),
          _ => null,
        },
      _ => null,
    };

/// Éléments proposés pour un type : valeur → libellé. Brouillons et interdits ne sont pas proposés.
Map<String, String> elementOptions(Character c, XpKind k, {Rulebook rb = const Rulebook()}) {
  String label(String cat, String n, [String suffix = '']) =>
      '$n$suffix${rb.find(cat, n)?.state == RuleState.approval ? ' · accord du conte' : ''}';
  return switch (k) {
    XpKind.attribute => {for (final a in AttrCategory.values) a.name: a.label},
    XpKind.skill => {for (final n in {...c.skills.map((t) => t.name), ...rb.offeredNames('skills')}) n: label('skills', n)},
    XpKind.background => {
        for (final n in {...c.backgrounds.map((t) => t.name), ...rb.offeredNames('backgrounds')})
          if (n != generationName) n: label('backgrounds', n),
      },
    XpKind.discipline => {
        for (final n in {...c.disciplines.map((d) => d.name), ...rb.clanDisciplines(c.clan), ...rb.commonDisciplines()})
          n: label('disciplines', n),
      },
    XpKind.merit => {
        for (final e in rb.offered('merits'))
          if (e.data['withXp'] == true && rb.cost('merits', e.name) != null && !c.merits.any((m) => nameKey(m.name) == nameKey(e.name)))
            e.name: label('merits', e.name, ' (${rb.cost('merits', e.name)})'),
      },
    XpKind.humanity => {humanityName: humanityName},
    XpKind.flawBuyback => {for (final f in c.flaws) f.name: '${f.name} (${f.level})'},
  };
}

/// Le prochain achat pour ce trait, sans contrôle.
XpItem draftItem(Character c, List<XpItem> items, XpKind k, String name, {String? note, Rulebook rb = const Rulebook()}) {
  final from = levelWith(c, items, k, name);
  final to = switch (k) {
    XpKind.merit => rb.cost('merits', name) ?? 0,
    XpKind.flawBuyback => 0,
    _ => from + 1,
  };
  final n = (note ?? '').trim();
  final draft = XpItem(k, name, from, to, 0, note: n.isEmpty ? null : n);
  return XpItem(k, name, from, to, costOf(c, draft, rb: rb), note: draft.note);
}

/// Points d'atouts : fiche, rareté du clan pour la secte, atout de lignée et atouts déjà dans la demande.
int meritPoints(Character c, List<XpItem> items, {Rulebook rb = const Rulebook()}) =>
    c.merits.fold(0, (s, m) => s + m.level) +
    rb.rarityCost(c.clan, c.sect) +
    lineageCost(c, rb: rb) +
    items.where((i) => i.kind == XpKind.merit).fold(0, (s, i) => s + i.toLevel);

/// Message si [item] ne peut pas s'ajouter à la demande ; null sinon.
String? itemError(Character c, List<XpItem> items, XpItem item, {required int usable, Rulebook rb = const Rulebook()}) {
  if (item.kind == XpKind.background && item.name == generationName) {
    return 'La Génération ne s’achète qu’à la création.';
  }
  final cat = ruleCategoryOf(item.kind);
  final entry = cat == null ? null : rb.find(cat, item.name);
  // Racheter un handicap interdit reste possible.
  if (entry != null && !entry.state.offered && item.kind != XpKind.flawBuyback) return '${item.name} est interdit dans la chronique.';
  switch (item.kind) {
    case XpKind.merit:
      if (item.fromLevel > 0) return 'Atout déjà pris.';
      if (item.toLevel == 0) return 'Atout inconnu : à demander au conte.';
      if (entry?.data['withXp'] != true) return 'Cet atout ne s’achète pas avec l’XP gagnée.';
      if (meritPoints(c, items, rb: rb) + item.toLevel > maxMeritPoints) {
        return 'Atouts : $maxMeritPoints points au plus, rareté de clan comprise.';
      }
    case XpKind.flawBuyback:
      if (item.fromLevel == 0) return 'Handicap déjà racheté.';
    default:
      final cap = capOf(c, item.kind, item.name, rb: rb);
      if (item.toLevel > cap) return 'Plafond atteint ($cap).';
  }
  final spec = noteSpec(item.kind, item.name, rb: rb);
  if (spec != null && spec.$2 && item.note == null) {
    return spec.$1 == 'Domaine' ? 'Précisez le domaine.' : 'Précisez le détail du nouveau point.';
  }
  final left = usable - items.fold(0, (s, i) => s + i.cost);
  if (item.cost > left) return 'XP libre insuffisante : ${item.cost} requis, $left restant après les achats déjà ajoutés.';
  return null;
}

/// Retire l'achat [index] ; seulement le plus haut niveau d'un trait.
String? removeItem(List<XpItem> items, int index) {
  final i = items[index];
  if (items.skip(index + 1).any((x) => x.kind == i.kind && x.name == i.name)) {
    return 'Retirez d’abord le niveau supérieur.';
  }
  items.removeAt(index);
  return null;
}

/// XP réservée par les demandes ouvertes de la fiche, sauf [exceptId].
int reservedBy(List<XpRequest> requests, String characterId, {String? exceptId}) => requests
    .where((r) => r.characterId == characterId && r.status.open && r.id != exceptId)
    .fold(0, (s, r) => s + r.total);

/// Total au barème actuel de la fiche (le rang a pu changer depuis l'envoi).
int recomputedTotal(Character c, List<XpItem> items, {Rulebook rb = const Rulebook()}) => items.fold(0, (s, i) => s + costOf(c, i, rb: rb));

/// Un achat a la forme produite par draftItem (un niveau, ou la valeur de l'atout, ou un rachat vers 0).
/// Les règles Firestore ne vérifient rien de cela : une demande écrite hors de l'application passe par ici.
bool wellFormed(XpItem i, {Rulebook rb = const Rulebook()}) => switch (i.kind) {
      XpKind.attribute => AttrCategory.values.asNameMap().containsKey(i.name) && i.toLevel == i.fromLevel + 1,
      XpKind.merit => i.fromLevel == 0 && rb.cost('merits', i.name) == i.toLevel,
      XpKind.flawBuyback => i.toLevel == 0 && i.fromLevel > 0,
      _ => i.toLevel == i.fromLevel + 1,
    };

String _gap(XpItem i, int expected) =>
    'La fiche a changé : ${i.displayName} est à ${levelText(i.kind, expected)} (demande faite depuis ${levelText(i.kind, i.fromLevel)})';

/// Ce qui empêche le joueur d'envoyer sa demande (brouillon rouvert, fiche changée, XP réservée ailleurs).
List<String> sendProblems(Character c, List<XpItem> items, {required int usable}) {
  final out = <String>[];
  final seen = <XpItem>[];
  for (final i in items) {
    final expected = levelWith(c, seen, i.kind, i.name);
    if (expected != i.fromLevel) out.add('${_gap(i, expected)}. Retirez cet achat puis ajoutez-le de nouveau.');
    seen.add(i);
  }
  final total = items.fold<int>(0, (s, i) => s + i.cost);
  if (total > usable) out.add('XP libre insuffisante : $total requis, $usable disponible.');
  return out;
}

/// Contrôles affichés au conteur avant de valider (C-Validation). Erreur = validation impossible.
List<Check> requestChecks(Character c, XpRequest r, {required int reservedOthers, Rulebook rb = const Rulebook()}) {
  final out = <Check>[
    if (c.status != CharacterStatus.active) const Check(0, CheckLevel.error, 'La fiche n’est plus active : refusez la demande.'),
  ];
  final seen = <XpItem>[];
  final stated = <String>{};
  for (final i in r.items) {
    if (!wellFormed(i, rb: rb)) {
      // Atout dont la valeur a changé dans le référentiel depuis l'envoi (Review Focus 4).
      final value = i.kind == XpKind.merit && i.fromLevel == 0 ? rb.cost('merits', i.name) : null;
      out.add(Check(
          0,
          CheckLevel.error,
          value != null
              ? 'Achat invalide : ${i.label} vaut $value points, la demande en compte ${i.toLevel}'
              : 'Achat invalide : ${i.label} (${levelText(i.kind, i.fromLevel)} → ${levelText(i.kind, i.toLevel)})'));
      seen.add(i);
      continue;
    }
    final expected = levelWith(c, seen, i.kind, i.name);
    if (expected != i.fromLevel) out.add(Check(0, CheckLevel.error, _gap(i, expected)));
    final cost = costOf(c, i, rb: rb);
    if (cost != i.cost) out.add(Check(0, CheckLevel.warn, 'Coût recalculé : $cost XP au lieu de ${i.cost} (${i.label})'));
    if (i.kind != XpKind.merit && i.kind != XpKind.flawBuyback) {
      final cap = capOf(c, i.kind, i.name, rb: rb);
      if (i.toLevel > cap) out.add(Check(0, CheckLevel.error, 'Plafond dépassé : ${i.label} ($cap au plus)'));
    }
    final cat = ruleCategoryOf(i.kind);
    if (cat != null && i.kind != XpKind.flawBuyback && stated.add('$cat/${i.name}')) {
      final k = stateCheck(rb, cat, i.kind.label, i.name, 0);
      if (k != null) out.add(k);
    }
    // Livre de base p. 108 : avec l'XP gagnée, toute discipline hors clan demande un professeur.
    if (i.kind == XpKind.discipline && !inClan(c, i.name, rb: rb)) {
      out.add(Check(0, CheckLevel.warn, 'Professeur nécessaire : ${i.name} hors clan, à confirmer par le conte'));
    }
    seen.add(i);
  }
  if (meritPoints(c, r.items, rb: rb) > maxMeritPoints) {
    out.add(Check(0, CheckLevel.error, 'Atouts : plus de $maxMeritPoints points, rareté de clan comprise'));
  }
  final after = c.xpAvailable - reservedOthers - recomputedTotal(c, r.items, rb: rb);
  if (after < 0) out.add(Check(0, CheckLevel.warn, 'Dette après validation : ${-after} XP'));
  if (out.isEmpty) out.add(const Check(0, CheckLevel.ok, 'Niveaux et coûts conformes à la fiche'));
  return out;
}

/// La fiche après la demande : niveaux, atouts, handicaps, Humanité et XP dépensée (barème actuel).
Character applyRequest(Character c, List<XpItem> items, {Rulebook rb = const Rulebook()}) {
  final n = c.clone();
  for (final i in items) {
    switch (i.kind) {
      case XpKind.attribute:
        n.attributes[AttrCategory.values.byName(i.name)]!.value = i.toLevel;
      case XpKind.skill || XpKind.background || XpKind.merit:
        final list = switch (i.kind) {
          XpKind.skill => n.skills,
          XpKind.background => n.backgrounds,
          _ => n.merits,
        };
        final t = _trait(list, i.name);
        if (t == null) {
          list.add(Trait(i.name, i.toLevel, note: i.note));
        } else {
          t.level = i.toLevel;
          if (i.note != null) t.note = [?t.note, i.note!].join(' · ');
        }
      case XpKind.discipline:
        final d = _discipline(n, i.name);
        if (d == null) {
          n.disciplines.add(Discipline(i.name, i.toLevel, inClan: inClan(c, i.name, rb: rb)));
        } else {
          d.level = i.toLevel;
        }
      case XpKind.humanity:
        n.humanity = i.toLevel;
      case XpKind.flawBuyback:
        n.flaws.removeWhere((t) => t.name == i.name);
    }
  }
  n.xpSpent += recomputedTotal(c, items, rb: rb);
  return n;
}
```

- [ ] **Step 3 : dépôt, écrans et fake**

**`lib/xp/xp_repository.dart` :**
- ajouter l'import `../rulebook/rulebook.dart` ;
- la signature devient `Future<void> decide(XpRequest r, Character c, RequestStatus to, String comment, Actor by, {Rulebook rb = const Rulebook()})` ;
- `applyRequest(c, r.items)` devient `applyRequest(c, r.items, rb: rb)`.

**`test/fakes.dart`** (FakeXpRepository) :
- la signature de `decide` reçoit le même `{Rulebook rb = const Rulebook()}`.

**`lib/xp/request_review.dart` :**
- ajouter les imports `../rulebook/rulebook.dart` et `../rulebook/rulebook_provider.dart` ;
- `_decide(Character c, RequestStatus to)` devient `_decide(Character c, RequestStatus to, Rulebook rb)`, et l'appel `decide(widget.r, c, to, _comment.text, by)` devient `decide(widget.r, c, to, _comment.text, by, rb: rb)` ;
- chaque appel `_decide(c, RequestStatus.x)` du fichier devient `_decide(c, RequestStatus.x, rb)`. Avec sed : `s/_decide(c, \(RequestStatus\.[a-zA-Z]*\))/_decide(c, \1, rb)/g` ;
- dans `build`, au début du rappel de `characterRequestsProvider` (avant `final reservedOthers = …`), ajouter :
  ```dart
          final rb = ref.watch(rulebookProvider);
          if (rb == null) return const Center(child: CircularProgressIndicator());
  ```
- les appels du même rappel prennent `rb` :
  - `requestChecks(c, r, reservedOthers: reservedOthers, rb: rb)` ;
  - `recomputedTotal(c, r.items, rb: rb)` ;
  - `costOf(c, i, rb: rb)` ;
  - `ruleText(c, i, rb: rb)`.

**`lib/xp/spend_screen.dart` :**
- ajouter les imports `../rulebook/rule_hint.dart`, `../rulebook/rulebook.dart` et `../rulebook/rulebook_provider.dart` ;
- dans `build`, juste avant `return asyncView(ref.watch(myRequestsProvider), …`, ajouter :
  ```dart
        final rb = ref.watch(rulebookProvider);
        if (rb == null) return const Center(child: CircularProgressIndicator());
  ```
- `_body(context, c, requests)` devient `_body(context, c, requests, rb)`, avec la signature `Widget _body(BuildContext context, Character c, List<XpRequest> requests, Rulebook rb)` ;
- dans `_body` :
  - `draftItem(c, r.items, _kind, name, note: _note.text)` devient `draftItem(c, r.items, _kind, name, note: _note.text, rb: rb)` ;
  - `itemError(c, r.items, item, usable: usable)` devient `itemError(c, r.items, item, usable: usable, rb: rb)` ;
  - `elementOptions(c, _kind)` devient `elementOptions(c, _kind, rb: rb)` ;
  - `final label = name == null ? null : noteLabel(_kind, name);` devient `final spec = name == null ? null : noteSpec(_kind, name, rb: rb);` ;
  - les deux `ruleText(c, …)` prennent `rb: rb`, et `costTable(c)` devient `costTable(c, rb: rb)` ;
  - le bloc `if (label != null) ...[ … TextField(… labelText: '$label (obligatoire)' …) ]` devient `if (spec != null) ...[`, avec `labelText: '${spec.$1} (${spec.$2 ? 'obligatoire' : 'facultatif'})'` ;
  - juste après le `Wrap` du choix (avant `if (_kind == XpKind.flawBuyback)`), ajouter :
    ```dart
            if (name != null && ruleCategoryOf(_kind) != null) RuleHint(rb.find(ruleCategoryOf(_kind)!, name)),
    ```

**`test/xp/spend_screen_test.dart` :**
- ajouter les imports :
  - `package:portail_met/rulebook/base_rules.dart` ;
  - `package:portail_met/rulebook/rule_entry.dart` ;
  - `package:portail_met/rulebook/rulebook.dart` ;
  - `package:portail_met/rulebook/rulebook_provider.dart` ;
- `pump` reçoit `Rulebook rb = const Rulebook()`, et `overrides: [` reçoit `rulebookProvider.overrideWith((ref) => rb),` ;
- ajouter le test :
```dart
  testWidgets('élément en accord du conte : badge, règle du conte, domaine facultatif', (tester) async {
    final skills = baseEntries('skills');
    skills.firstWhere((e) => e.name == 'Bagarre')
      ..state = RuleState.approval
      ..description = 'Combat à mains nues.'
      ..data['domainMode'] = 'optional';
    await pump(tester, rb: Rulebook({'skills': skills}));
    await choose(tester, const ValueKey('xp-name-skill'), 'Bagarre · accord du conte');
    expect(find.text('Accord du conte'), findsOneWidget);
    expect(find.text('Combat à mains nues.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Domaine (facultatif)'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Ajouter à la demande')).onPressed, isNotNull);
  });
```

- [ ] **Step 4 : tester, analyser**

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 5 : commit**

```
git add lib test
git commit -m "feat: XP branchée sur le référentiel — états, coûts du rang, domaines, plafonds, atouts, rareté par secte" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : valeurs de création modifiables

**Files :** Modify `lib/xp/xp_settings_screen.dart`, `test/fakes.dart`, `test/xp/xp_settings_screen_test.dart`.

**Interfaces :**
- Consumes : `CreationValues`, `slotsText`, `XpSettings.creation`.
- Produces : le bloc « XP de création » éditable, avec les clés `creation-<champ>`.

- [ ] **Step 1 : test (échec attendu)**

Dans `test/fakes.dart` (FakeXpRepository) :
- ajouter le champ `XpSettings? lastSettings;` ;
- dans `saveSettings`, enregistrer `lastSettings = s;` en plus de l'appel existant. Écrire la méthode en corps de bloc.

Dans `test/xp/xp_settings_screen_test.dart`, ajouter :

```dart
  testWidgets('valeurs de création modifiables, contrôlées', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byKey(const Key('creation-startingXp')), '35');
    await tester.enterText(find.byKey(const Key('creation-attributeSlots')), '8 / 5 / 3');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(repo.lastSettings!.creation.startingXp, 35);
    expect(repo.lastSettings!.creation.attributeSlots, [8, 5, 3]);
    expect(repo.lastSettings!.creation.skillSlots, const CreationValues().skillSlots);
    await tester.enterText(find.byKey(const Key('creation-disciplineSlots')), '2 / 1');
    await tester.pump();
    expect(find.text('Disciplines en clan : trois valeurs, par exemple 2 / 1 / 1.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer')).onPressed, isNull);
  });
```

Il faut aussi l'import `package:portail_met/rulebook/rulebook.dart`.

Run : `flutter test test/xp/xp_settings_screen_test.dart`.

Expected : échec (la clé `creation-startingXp` est introuvable).

- [ ] **Step 2 : écran**

Dans `lib/xp/xp_settings_screen.dart` :

1. **Champs d'état.** Dans `_XpSettingsScreenState`, après `bool _busy = false;`, ajouter :
```dart
  static const _creationKeys = [
    'startingXp', 'defaultBonus', 'maxFlawXp', 'maxSetAside', 'attributeSlots', 'skillSlots', 'backgroundSlots', 'disciplineSlots',
  ];
  final _creation = {for (final k in _creationKeys) k: TextEditingController()};
```
2. **Libération.** Dans `dispose()`, avant `super.dispose();`, ajouter :
```dart
    for (final c in _creation.values) {
      c.dispose();
    }
```
3. **Chargement.** À la fin de `_load(XpSettings s)`, ajouter :
```dart
    final v = s.creation;
    _creation['startingXp']!.text = '${v.startingXp}';
    _creation['defaultBonus']!.text = '${v.defaultBonus}';
    _creation['maxFlawXp']!.text = '${v.maxFlawXp}';
    _creation['maxSetAside']!.text = '${v.maxSetAside}';
    _creation['attributeSlots']!.text = v.attributeSlots.join(' / ');
    _creation['skillSlots']!.text = slotsText(v.skillSlots);
    _creation['backgroundSlots']!.text = v.backgroundSlots.join(' / ');
    _creation['disciplineSlots']!.text = v.disciplineSlots.join(' / ');
```
4. **Analyse de la saisie.** Après `_parse()`, ajouter :
```dart
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
```
5. **Enregistrement.**
   - `Future<void> _save(List<XpTier> tiers)` devient `Future<void> _save(List<XpTier> tiers, CreationValues creation)` ;
   - l'appel devient `saveSettings(XpSettings(monthlyEnabled: _enabled, gainSince: _since, tiers: tiers, creation: creation), by)`.
6. **Début de `_body`.** Après `final (tiers, error) = _parse();`, ajouter `final (creation, creationError) = _parseCreation();`. Après la fonction `field`, ajouter :
```dart
    Widget slotField(String key, String label) => SizedBox(
          width: 230,
          child: TextField(
            key: Key('creation-$key'),
            controller: _creation[key],
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
        );
```
7. **Bloc « XP de création ».** Le `Panel` du bloc (de `const SectionTitle('XP de création')` jusqu'au texte « Modifiables avec le référentiel des règles (à venir). ») devient :
```dart
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
```
8. **Bouton « Enregistrer ».** Il devient :
```dart
        FilledButton(
          onPressed: tiers == null || creation == null || _busy ? null : () => _save(tiers, creation),
          child: const Text('Enregistrer'),
        ),
```
9. **Imports.** Si `InfoRow` n'est plus utilisé, l'analyseur le signalera ; retirer alors l'import devenu inutile.

- [ ] **Step 3 : tester, analyser**

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent. Si un test existant ne trouve plus « Enregistrer » à l'écran, agrandir sa fenêtre de test (`physicalSize`) ; ne pas changer l'écran.

- [ ] **Step 4 : commit**

```
git add lib test
git commit -m "feat: valeurs de création modifiables dans les paramètres d’expérience" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : listes de l'édition des fiches (C3) et des filtres

**Files :**
- Modify : `lib/characters/character_edit_screen.dart`, `lib/characters/characters_list_screen.dart`.
- Tests : `test/characters/character_edit_test.dart`, `test/characters/edit_fixes_test.dart`, `test/characters/characters_list_test.dart`.

**Interfaces :**
- Consumes : `rulebookProvider`, `Rulebook.all`, `Rulebook.gen`.
- Produces : C3 et les filtres proposent tous les noms du référentiel, quel que soit l'état. Le conteur peut saisir n'importe quel élément.

- [ ] **Step 1 : test (échec attendu)**

Dans `test/characters/characters_list_test.dart` :
- ajouter les imports `package:portail_met/rulebook/rule_entry.dart`, `package:portail_met/rulebook/rulebook.dart` et `package:portail_met/rulebook/rulebook_provider.dart` ;
- dans `overrides: [`, ajouter :
  ```dart
          rulebookProvider.overrideWith((ref) => Rulebook({
                'clans': [RuleEntry(name: 'Ishtarri'), RuleEntry(name: 'Toreador')],
              })),
  ```
- ajouter un test qui ouvre le menu « Clan » du filtre et y trouve « Ishtarri ». Écrire ce test dans le style de ceux du fichier : même fonction de montage, même façon d'ouvrir un menu.

Dans `test/characters/character_edit_test.dart` et `test/characters/edit_fixes_test.dart`, après `overrides: [`, ajouter `baseRulebook,`.

Run : `flutter test test/characters`.

Expected : le nouveau test échoue (« Ishtarri » absent).

- [ ] **Step 2 : écrans**

**`lib/characters/character_edit_screen.dart`** (`_Editor`, ConsumerWidget) :
- ajouter les imports `../rulebook/rulebook.dart` et `../rulebook/rulebook_provider.dart`. Retirer `../rules/met_lists.dart` s'il n'est plus utilisé ;
- au début de `build`, ajouter :
  ```dart
      final rb = ref.watch(rulebookProvider) ?? const Rulebook();
      List<String> names(String cat) => [for (final e in rb.all(cat)) e.name];
  ```
- remplacements :
  - `options: [for (final k in clans) k.name]` devient `options: names('clans')` ;
  - `options: sects` devient `options: names('sects')` ;
  - `options: archetypes` devient `options: names('archetypes')` ;
  - `!(generationNumbers[g] ?? const []).contains(c.genNumber)` devient `!rb.gen(g).numbers.contains(c.genNumber)` ;
  - `generationNumbers[c.genRank]!` devient `rb.gen(c.genRank!).numbers` ;
  - `options: skillNames` devient `options: names('skills')` ;
  - `options: backgroundNames` devient `options: names('backgrounds')` ;
  - `options: allDisciplines` devient `options: names('disciplines')` ;
  - `options: baseMerits.keys.toList()` devient `options: names('merits')` ;
  - `options: baseFlaws.keys.toList()` devient `options: names('flaws')`.

**`lib/characters/characters_list_screen.dart` :**
- `_Filters` reçoit deux champs `final List<String> sects;` et `final List<String> clans;`, requis dans son constructeur ;
- dans `_Filters.build`, remplacer `select('Secte', filter.sect, sects, …)` par `select('Secte', filter.sect, this.sects, …)`, et `[for (final c in clans) c.name]` par `this.clans` ;
- dans `_CharactersListScreenState.build`, ajouter `final rb = ref.watch(rulebookProvider) ?? const Rulebook();`. Chaque construction de `_Filters(` reçoit `sects: [for (final e in rb.all('sects')) e.name], clans: [for (final e in rb.all('clans')) e.name],` ;
- imports : ajouter `../rulebook/rulebook.dart` et `../rulebook/rulebook_provider.dart` ; retirer `../rules/met_lists.dart` s'il n'est plus utilisé.

- [ ] **Step 3 : tester, analyser**

Run : `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add lib test
git commit -m "feat: édition des fiches et filtres alimentés par le référentiel" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : vérification des appels, revue, déploiement (avec accord)

- [ ] **Vérifier que chaque appel d'écran passe `rb` :**

  ```
  grep -nE "(creationChecks|budgetOf|purchaseCost|addPurchase|removePurchase|applyDerived|setClan|setFreeLevel|isInClan|costOf|ruleText|costTable|elementOptions|draftItem|itemError|requestChecks|recomputedTotal|applyRequest|meritPoints|noteSpec|capOf)\(" lib --include=*.dart | grep -v "rb: rb\|rb)" | grep -v "^lib/rules/creation_rules.dart\|^lib/xp/xp_rules.dart"
  ```

  Chaque ligne restante est un oubli, sauf une ligne qui passe `rb` sur la ligne suivante. Corriger, puis relancer `flutter test`.
- [ ] Revue finale de la branche, corrections Critical et Important avec un test chacune.
- [ ] Avec l'accord de l'utilisateur :
  - `flutter build web --release` ;
  - `firebase deploy --only hosting --project met-mon-vampire` (pas de changement des règles) ;
  - puis fusion de `referentiel-b` dans `main`.
