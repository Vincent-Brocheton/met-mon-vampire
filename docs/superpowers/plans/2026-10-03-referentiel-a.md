# Référentiel — Plan A (référentiel éditable) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :**
- Les conteurs consultent et modifient les 18 catégories du référentiel dans l'application : ajouter, modifier, interdire, supprimer, avec une note réservée au conte.
- Ils chargent les valeurs de base et importent ou exportent des listes (CSV ou copier-coller depuis un tableur).
- Les moteurs de création et d'XP ne changent pas encore : c'est le plan B.

**Architecture :**
- `lib/rulebook/schema.dart` décrit les 18 catégories : leurs champs typés, leurs colonnes, leur filtre et leurs réglages.
- Un formulaire générique (`RuleFieldEditor`, `RuleEntryForm`) et un écran unique (`ReferentialScreen`) servent toutes les catégories.
- Les données vivent dans `rules/{cat}/entries/{id}`, avec la note dans `…/private/note` et les réglages dans `rules/{cat}`.
- Une seule requête sur toutes les collections `entries` alimente l'écran (`allRuleEntriesProvider`).
- Le CSV est pur et testé (`csv.dart`).

**Tech Stack :** inchangée. Le presse-papiers passe par `flutter/services.dart`.

**Spec :** `docs/superpowers/specs/2026-10-03-referentiel-design.md`.

## Global Constraints

- **Contraintes des plans précédents :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md <N> [test|impl]` ;
  - `JAVA_HOME` pour l'émulateur ;
  - couleurs dans `AppColors`, textes en français ;
  - `build_runner` après tout fichier `part` ;
  - analyseur propre, pas de `dart format` ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branche `referentiel-a`, créée depuis `main`.
- **Écarts assumés avec la spec** (à reporter tels quels dans le journal) :
  - **Pas de vue dédiée.** Le formulaire générique gère deux types de champ en plus :
    - « lignes » : les lignées d'un clan, les pouvoirs d'une discipline, les règles de base de l'équipement ;
    - « valeurs par secte » : la rareté d'un clan, le statut d'une voie.

    Un panneau « Paramètres de la catégorie » couvre les réglages (alliés, équipement, sang et chasse, rituels, archétypes). Les générations sont 3 éléments ordinaires. Coût : un rendu moins visuel que les maquettes, à affiner plus tard.
  - **Import / export par copier-coller.** L'export s'affiche avec un bouton « Copier » ; l'import se fait en collant du CSV (séparateur « ; ») ou des cellules de tableur (tabulations). Il n'y a pas de dépendance d'envoi de fichier.
  - **Une requête sur toutes les collections `entries`** (`collectionGroup('entries')`) au lieu d'une requête par catégorie.
  - **Le conflit d'écriture entre deux conteurs** se détecte dans l'application : `updatedAt` de l'élément ouvert est comparé à celui de la dernière version. Il n'y a pas de transaction.
  - **Les prérequis des techniques** se saisissent comme une liste d'alternatives en texte, par exemple « Présence 2 + Auspex 1 ». Le plan C les analysera.
- **Le plan A ne modifie ni les fiches ni les moteurs.**

## Review Focus

1. **Import qui modifie un élément utilisé par des fiches.** L'aperçu affiche « Modifié : X (utilisé par N fiches) ». Le test est à la tâche 5.
2. **Deux conteurs modifient le même élément.** « Modifié par X à l'instant » propose « Recharger » ou « Écraser ». Le test est à la tâche 5.
3. **Renommer ou supprimer un élément utilisé.** Une confirmation s'affiche, avec la proposition « Marquer Interdit ». Le test est à la tâche 5.
4. **CSV mal formé** (guillemets, point-virgule dans une cellule, retour à la ligne, tabulations). L'analyse doit être correcte et les erreurs précises. Les tests sont à la tâche 2.
5. **Un joueur qui lit la note du conte ou écrit dans le référentiel.** Les règles le refusent. Le test est à la tâche 3.

## Structure des fichiers

```
lib/rulebook/rule_entry.dart          RuleState, RuleEntry, nameKey
lib/rulebook/schema.dart              FieldType, RuleField, RuleCategory, ruleCategories (18), categoryById, displayValue
lib/rulebook/base_rules.dart          baseEntries(cat) depuis met_lists
lib/rulebook/usage.dart               usageCount(cat, name, chars)
lib/rulebook/csv.dart                 parseTable, columnsOf, exportCsv, previewImport, ImportPreview
lib/rulebook/rules_repository.dart    RulesRepository + allRuleEntriesProvider, allRuleSettingsProvider
lib/rulebook/rule_form.dart           RuleFieldEditor, RuleEntryForm
lib/rulebook/referential_screen.dart  ReferentialScreen (menu, liste, réglages, import / export, base, édition)
firestore.rules                       rules/{cat}, entries, private/note, groupe entries
rules_test/rulebook.test.js
test/fakes.dart                       FakeRulesRepository
test/rulebook/*.dart
```

---

### Task 1 : modèle, schémas des 18 catégories, valeurs de base, usage

**Files :** Create `lib/rulebook/rule_entry.dart`, `schema.dart`, `base_rules.dart`, `usage.dart`. Test : `test/rulebook/schema_test.dart`.

**Interfaces :**
- Consumes : `met_lists.dart` (`clans`, `ClanRarity`, `allDisciplines`, `commonDisciplines`, `skillNames`, `domainSkills`, `backgroundNames`, `archetypes`, `sects`, `baseMerits`, `baseFlaws`, `generationNumbers`, `bloodByRank`), `Character`, `GenRank`.
- Produces :
  - `RuleState` (`label`, `offered`) ;
  - `RuleEntry` (`id`, `name`, `vo`, `state`, `source`, `description`, `data`, `updatedAt`, `updatedByName`, `fromMap`, `toMap`, `copy`) ;
  - `nameKey` ;
  - `FieldType` { text, longText, number, choice, multi, flag, list, keyed, rows } ;
  - `RuleField(key, label, type, {options, keysFrom, rowFields, help})` ;
  - `RuleCategory(id, label, help, {fields, columns, filter, settings})` ;
  - `ruleCategories`, `categoryById`, `displayValue`, `baseEntries`, `usageCount`.

- [ ] **Step 1 : extraire le test, le lancer, il doit échouer**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 1 test`, puis `flutter test test/rulebook`.

Expected : échec au chargement.

<!-- file: test/rulebook/schema_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/rulebook/base_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/schema.dart';
import 'package:portail_met/rulebook/usage.dart';

import '../characters/character_test.dart' show sample;

void main() {
  test('20 catégories cohérentes', () {
    expect(ruleCategories.length, 20);
    expect(ruleCategories.map((c) => c.id).toSet().length, 20);
    for (final c in ruleCategories) {
      final keys = {for (final f in c.fields) f.key};
      expect(keys.containsAll(c.columns), isTrue, reason: c.id);
      if (c.filter != null) expect(keys, contains(c.filter), reason: c.id);
      for (final f in [...c.fields, ...c.settings]) {
        if (f.type == FieldType.choice || f.type == FieldType.multi) expect(f.options, isNotEmpty, reason: '${c.id}.${f.key}');
        if (f.type == FieldType.keyed) expect(categoryById(f.keysFrom!), isNotNull, reason: '${c.id}.${f.key}');
        if (f.type == FieldType.rows) expect(f.rowFields, isNotEmpty, reason: '${c.id}.${f.key}');
      }
    }
    expect(categoryById('inconnu'), isNull);
  });

  test('aller-retour d’un élément, nom normalisé', () {
    final e = RuleEntry(id: 'a', name: 'Chanceux', vo: 'Lucky', state: RuleState.approval, source: 'Livre de base, p. 250', data: {'cost': 2, 'atCreation': true});
    final back = RuleEntry.fromMap('a', e.toMap());
    expect(back.toMap(), e.toMap());
    final copy = e.copy()..data['cost'] = 3;
    expect(e.data['cost'], 2);
    expect(copy.data['cost'], 3);
    expect(nameKey('  Volonté   de FER '), 'volonté de fer');
    expect([for (final s in RuleState.values) if (s.offered) s], [RuleState.available, RuleState.approval]);
  });

  test('valeurs de base reprises du code', () {
    final merits = baseEntries('merits');
    expect(merits.firstWhere((e) => e.name == 'Chanceux').data['cost'], 2);
    final tremere = baseEntries('clans').firstWhere((e) => e.name == 'Tremere');
    expect(tremere.data['disciplines'], ['Auspex', 'Domination', 'Thaumaturgie']);
    expect((tremere.data['rarity'] as Map)['Camarilla'], 'common');
    expect((baseEntries('clans').firstWhere((e) => e.name == 'Lasombra').data['rarity'] as Map)['Camarilla'], 'rare');
    expect(baseEntries('generations').map((e) => e.data['rank']), ['neonate', 'ancilla', 'pretender']);
    expect(baseEntries('generations').last.data['techniqueCost'], 20);
    expect(baseEntries('archetypes').length, 20);
    expect(baseEntries('sects').where((e) => e.data['isDefault'] == true).single.name, 'Camarilla');
    expect(baseEntries('skills').firstWhere((e) => e.name == 'Artisanat').data['domainMode'], 'perDot');
    expect(baseEntries('disciplines').firstWhere((e) => e.name == 'Auspex').data['common'], isTrue);
    expect(baseEntries('titles'), isEmpty);
  });

  test('nombre de fiches qui portent un nom', () {
    final chars = [sample(), sample()..clan = 'Brujah'];
    expect(usageCount('merits', 'Visage angélique', chars), 2);
    expect(usageCount('clans', 'Toreador', chars), 1);
    expect(usageCount('skills', 'représentation', chars), 2);
    expect(usageCount('titles', 'Prince', chars), isNull);
  });

  test('affichage des valeurs', () {
    final merits = categoryById('merits')!;
    expect(displayValue(merits.fields.firstWhere((f) => f.key == 'type'), 'clan'), 'Clan');
    expect(displayValue(merits.fields.firstWhere((f) => f.key == 'atCreation'), true), 'Oui');
    expect(displayValue(merits.fields.firstWhere((f) => f.key == 'cost'), null), '—');
    final clans = categoryById('clans')!;
    expect(displayValue(clans.fields.firstWhere((f) => f.key == 'disciplines'), ['Auspex', 'Présence']), 'Auspex, Présence');
    expect(displayValue(clans.fields.firstWhere((f) => f.key == 'bloodlines'), [{'name': 'Ishtarri'}]), '1 ligne');
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 1 impl`.

<!-- file: lib/rulebook/rule_entry.dart -->
```dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum RuleState {
  available('Disponible'),
  approval('Accord du conte'),
  draft('Brouillon'),
  forbidden('Interdit');

  const RuleState(this.label);
  final String label;

  /// Proposé aux joueurs (le plan B lit cette propriété).
  bool get offered => this == available || this == approval;
}

/// Clé de comparaison des noms : sans casse ni espaces superflus (doublons, import).
String nameKey(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Élément du référentiel : `rules/{cat}/entries/{id}`.
class RuleEntry {
  RuleEntry({
    this.id = '',
    required this.name,
    this.vo,
    this.state = RuleState.available,
    this.source,
    this.description = '',
    Map<String, dynamic>? data,
    this.updatedAt,
    this.updatedByName,
  }) : data = data ?? {};

  factory RuleEntry.fromMap(String id, Map<String, dynamic> m) => RuleEntry(
        id: id,
        name: m['name'] as String? ?? '',
        vo: m['vo'] as String?,
        state: RuleState.values.asNameMap()[m['state']] ?? RuleState.available,
        source: m['source'] as String?,
        description: m['description'] as String? ?? '',
        data: m['data'] == null ? {} : Map<String, dynamic>.from(m['data'] as Map),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String name;
  String? vo;
  RuleState state;
  String? source;
  String description;

  /// Champs propres à la catégorie (voir schema.dart) : valeurs JSON seulement.
  Map<String, dynamic> data;
  final DateTime? updatedAt;
  final String? updatedByName;

  Map<String, dynamic> toMap() => {
        'name': name,
        'vo': vo,
        'state': state.name,
        'source': source,
        'description': description,
        'data': data,
      };

  /// Copie profonde (le formulaire modifie la copie, pas l'élément affiché).
  RuleEntry copy() => RuleEntry(
        id: id,
        name: name,
        vo: vo,
        state: state,
        source: source,
        description: description,
        data: Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map),
        updatedAt: updatedAt,
        updatedByName: updatedByName,
      );
}
```

<!-- file: lib/rulebook/schema.dart -->
```dart
/// Types de champ du formulaire générique.
enum FieldType { text, longText, number, choice, multi, flag, list, keyed, rows }

typedef Option = (String value, String label);

class RuleField {
  const RuleField(this.key, this.label, this.type, {this.options = const [], this.keysFrom, this.rowFields = const [], this.help});

  final String key;
  final String label;
  final FieldType type;

  /// choice, multi, keyed : valeurs permises.
  final List<Option> options;

  /// keyed : catégorie dont les noms servent de clés (ex. 'sects').
  final String? keysFrom;

  /// rows : champs de chaque ligne (types simples seulement).
  final List<RuleField> rowFields;
  final String? help;
}

class RuleCategory {
  const RuleCategory(this.id, this.label, this.help, {this.fields = const [], this.columns = const [], this.filter, this.settings = const []});

  final String id;
  final String label;
  final String help;
  final List<RuleField> fields;

  /// Champs affichés en colonnes dans la liste.
  final List<String> columns;

  /// Champ proposé en puces de filtre (choice ou multi).
  final String? filter;

  /// Réglages de la catégorie (`rules/{cat}`).
  final List<RuleField> settings;
}

const _meritTypes = [
  ('general', 'Général'),
  ('clan', 'Clan'),
  ('sect', 'Secte'),
  ('morality', 'Moralité'),
  ('rarity', 'Rareté et lignée'),
  ('chronicle', 'Chronique'),
];
const _schools = [('thaumaturgy', 'Thaumaturgie'), ('necromancy', 'Nécromancie'), ('abyss', 'Mysticisme de l’Abysse')];
const _rarities = [('common', 'Commun'), ('uncommon', 'Peu commun · 2 pts'), ('rare', 'Rare · 4 pts'), ('forbidden', 'Interdit')];
const _equipmentCategories = [('melee', 'Armes de mêlée'), ('ranged', 'Armes à distance'), ('armor', 'Protections'), ('gear', 'Matériel divers')];
const _bloodBlocks = [('resonance', 'Résonance du sang'), ('hunting', 'Chasse avancée'), ('territory', 'Territoires de chasse')];

List<RuleField> _traitFields(String limitLabel) => [
      const RuleField('cost', 'Coût (points)', FieldType.number),
      const RuleField('type', 'Catégorie', FieldType.choice, options: _meritTypes),
      const RuleField('restrictedTo', 'Réservé à', FieldType.text, help: 'Nom d’un clan, d’une lignée ou d’une secte'),
      const RuleField('atCreation', 'À la création', FieldType.flag),
      const RuleField('withXp', 'Avec l’XP gagnée', FieldType.flag),
      RuleField('countsInLimit', limitLabel, FieldType.flag),
    ];

final ruleCategories = <RuleCategory>[
  RuleCategory('merits', 'Atouts', 'Ce que les joueurs peuvent choisir à la création et acheter ensuite.',
      fields: _traitFields('Compte dans la limite de 7 points'), columns: const ['type', 'restrictedTo', 'cost'], filter: 'type'),
  RuleCategory('flaws', 'Handicaps', 'Ils rapportent des points d’XP, 7 au plus.',
      fields: _traitFields('Rapporte des points, dans la limite de 7'), columns: const ['type', 'restrictedTo', 'cost'], filter: 'type'),
  const RuleCategory('clans', 'Clans & lignées', 'La rareté se paie en atout à la création, selon la secte.',
      fields: [
        RuleField('disciplines', 'Disciplines de clan', FieldType.list),
        RuleField('rarity', 'Rareté par secte', FieldType.keyed, keysFrom: 'sects', options: _rarities),
        RuleField('weakness', 'Faiblesse, affichée sur la fiche', FieldType.longText),
        RuleField('bloodlines', 'Lignées', FieldType.rows, rowFields: [
          RuleField('name', 'Lignée', FieldType.text),
          RuleField('merit', 'Atout de lignée', FieldType.text),
        ]),
      ],
      columns: ['disciplines', 'rarity']),
  const RuleCategory('disciplines', 'Disciplines & pouvoirs', 'Communes ou propres ; les voies rattachées à une école de magie.',
      fields: [
        RuleField('common', 'Commune (achetable hors clan)', FieldType.flag),
        RuleField('school', 'École de magie', FieldType.choice, options: _schools),
        RuleField('parent', 'Discipline mère (pour une voie)', FieldType.text),
        RuleField('powers', 'Pouvoirs', FieldType.rows, rowFields: [
          RuleField('level', 'Niveau', FieldType.number),
          RuleField('name', 'Nom', FieldType.text),
          RuleField('vo', 'Nom VO', FieldType.text),
          RuleField('elder', 'Pouvoir d’ancien', FieldType.flag),
          RuleField('activation', 'Coût d’activation', FieldType.text),
          RuleField('test', 'Test', FieldType.text),
          RuleField('effect', 'Effet affiché aux joueurs', FieldType.longText),
        ]),
      ],
      columns: ['common', 'school'],
      filter: 'school'),
  const RuleCategory('rituals', 'Rituels', 'Achetés à part des voies. Coût : niveau du rituel × 2.',
      fields: [
        RuleField('school', 'École', FieldType.choice, options: _schools),
        RuleField('level', 'Niveau (1 à 5)', FieldType.number),
        RuleField('talisman', 'Peut être placé dans un talisman', FieldType.flag),
        RuleField('atCreation', 'À la création', FieldType.flag),
        RuleField('withXp', 'Avec l’XP gagnée', FieldType.flag),
      ],
      columns: ['school', 'level'],
      filter: 'school',
      settings: [RuleField('costPerLevel', 'Coût par niveau (XP)', FieldType.number)]),
  const RuleCategory('techniques', 'Techniques', 'Accès et coûts selon la génération.',
      fields: [
        RuleField('prerequisites', 'Prérequis (une alternative par ligne)', FieldType.list, help: 'Ex. « Présence 2 + Auspex 1 »'),
        RuleField('transformation', 'Transformation', FieldType.choice, options: [('none', 'Aucune'), ('minor', 'Mineure'), ('major', 'Majeure')]),
      ],
      columns: ['prerequisites']),
  const RuleCategory('elderPowers', 'Pouvoirs d’anciens', 'Cinq points dans la discipline ; hors clan, un professeur.',
      fields: [
        RuleField('discipline', 'Discipline', FieldType.text),
        RuleField('costInClan', 'Coût en clan (XP)', FieldType.number),
        RuleField('costOutOfClan', 'Coût hors clan (XP)', FieldType.number),
      ],
      columns: ['discipline']),
  const RuleCategory('skills', 'Compétences', 'Plafond de 5 points. Certaines demandent un domaine.',
      fields: [
        RuleField('domainMode', 'Domaines', FieldType.choice, options: [
          ('perDot', 'Un domaine par point'),
          ('multiple', 'Achetée plusieurs fois'),
          ('optional', 'Domaines facultatifs'),
          ('none', 'Sans domaine'),
        ]),
        RuleField('domains', 'Domaines proposés aux joueurs', FieldType.list),
        RuleField('cap', 'Plafond', FieldType.number),
      ],
      columns: ['domainMode', 'cap'],
      filter: 'domainMode'),
  const RuleCategory('generations', 'Générations', 'Valeurs vérifiées à chaque achat et à chaque validation.',
      fields: [
        RuleField('rank', 'Rang', FieldType.choice, options: [('neonate', 'Neonate'), ('ancilla', 'Ancilla'), ('pretender', 'Pretender Elder')]),
        RuleField('numbers', 'Générations (une par ligne)', FieldType.list),
        RuleField('blood', 'Sang', FieldType.number),
        RuleField('bloodPerTurn', 'Sang par tour', FieldType.number),
        RuleField('attributeBonus', 'Points bonus d’attribut', FieldType.number),
        RuleField('skillCap', 'Plafond des compétences', FieldType.number),
        RuleField('traitFactor', 'Compétences et historiques : nouveau niveau ×', FieldType.number),
        RuleField('outOfClanFactor', 'Disciplines hors clan : nouveau niveau ×', FieldType.number),
        RuleField('techniqueCost', 'Coût d’une technique (0 : interdit)', FieldType.number),
        RuleField('eldersAllowed', 'Pouvoirs d’anciens permis', FieldType.flag),
        RuleField('eldersLimit', 'Nombre de pouvoirs d’anciens', FieldType.number),
      ],
      columns: ['rank', 'numbers', 'blood']),
  const RuleCategory('backgrounds', 'Historiques', 'Ce que chaque historique demande au joueur de préciser.',
      fields: [
        RuleField('ask', 'Détail demandé', FieldType.choice, options: [
          ('monthly', 'Montant mensuel'),
          ('people', 'Liste de personnes'),
          ('specialties', 'Liste de spécialités'),
          ('text', 'Texte libre'),
        ]),
        RuleField('cap', 'Plafond', FieldType.number),
        RuleField('approvalRequired', 'Le montant est validé par le conte', FieldType.flag),
        RuleField('scale', 'Barème par niveau (un montant par ligne)', FieldType.list),
      ],
      columns: ['ask', 'cap']),
  const RuleCategory('allies', 'Alliés', 'Spécialisations des alliés ; règles générales dans les paramètres.',
      fields: [
        RuleField('effect', 'Effet', FieldType.longText),
        RuleField('condition', 'Condition', FieldType.text),
      ],
      columns: ['condition'],
      settings: [
        RuleField('maxLevel', 'Niveau maximum', FieldType.number),
        RuleField('returnAfter', 'Retour après usage', FieldType.text),
        RuleField('types', 'Types (un par ligne)', FieldType.list),
        RuleField('domains', 'Domaines (un par ligne)', FieldType.list),
      ]),
  const RuleCategory('archetypes', 'Archétypes', 'Sans effet mécanique : ils guident l’interprétation.',
      settings: [RuleField('freeAllowed', 'Archétypes libres autorisés, validés par le conte', FieldType.flag)]),
  const RuleCategory('sects', 'Sectes', 'Quelles sectes sont jouables.',
      fields: [
        RuleField('playable', 'Jouable', FieldType.choice, options: [
          ('all', 'PJ et PNJ'),
          ('pjOnApproval', 'PNJ, PJ sur accord'),
          ('npcOnly', 'PNJ seulement'),
        ]),
        RuleField('isDefault', 'Secte par défaut des nouvelles fiches', FieldType.flag),
      ],
      columns: ['playable', 'isDefault']),
  const RuleCategory('paths', 'Voies & moralité', 'Humanité par défaut ; une voie d’illumination s’achète comme atout de moralité.',
      fields: [
        RuleField('meritCost', 'Coût de l’atout', FieldType.number),
        RuleField('maxMorality', 'Moralité maximum', FieldType.number),
        RuleField('sins', 'Hiérarchie des péchés (un niveau par ligne)', FieldType.list),
        RuleField('sectStatus', 'Statut par secte', FieldType.keyed, keysFrom: 'sects', options: [
          ('accepted', 'Acceptée'),
          ('heretic', 'Hérétique'),
          ('none', 'Ni l’un ni l’autre'),
        ]),
        RuleField('changeNeedsApproval', 'Changement de voie soumis au conte', FieldType.flag),
      ],
      columns: ['meritCost', 'maxMorality']),
  const RuleCategory('derangements', 'Dérangements', 'Modèles de départ ; chaque joueur décrit le sien.',
      fields: [
        RuleField('type', 'Type', FieldType.choice, options: [
          ('belief', 'Croyance'),
          ('incapacity', 'Incapacité'),
          ('compulsion', 'Compulsion'),
          ('phobia', 'Phobie'),
          ('destruction', 'Destruction'),
          ('obsession', 'Obsession'),
        ]),
        RuleField('gameEffect', 'Effet de jeu', FieldType.longText),
        RuleField('asFlaw', 'Peut être pris comme handicap à la création', FieldType.flag),
        RuleField('byPower', 'Peut être infligé par un pouvoir', FieldType.flag),
      ],
      columns: ['type'],
      filter: 'type'),
  const RuleCategory('titles', 'Titres', 'Les charges de la chronique, sans coût en XP.',
      fields: [
        RuleField('sect', 'Secte', FieldType.text),
        RuleField('count', 'Nombre', FieldType.text, help: 'Illimité, Unique, Un par clan, ou un nombre'),
        RuleField('under', 'Placé sous', FieldType.text),
        RuleField('public', 'Titre public', FieldType.flag),
        RuleField('onSheet', 'Affiché sur la fiche du détenteur', FieldType.flag),
        RuleField('npcOnly', 'Réservé aux PNJ', FieldType.flag),
      ],
      columns: ['sect', 'count']),
  const RuleCategory('equipment', 'Équipement', 'Qualités d’objets ; règles de base par catégorie dans les paramètres.',
      fields: [
        RuleField('categories', 'Catégories', FieldType.multi, options: _equipmentCategories),
        RuleField('incompatible', 'Incompatible avec (une par ligne)', FieldType.list),
        RuleField('outsideLimit', 'Ne compte pas dans la limite de qualités', FieldType.flag),
        RuleField('resale', 'Valeur de revente', FieldType.text),
      ],
      columns: ['categories'],
      filter: 'categories',
      settings: [
        RuleField('rules', 'Règles de base par catégorie', FieldType.rows, rowFields: [
          RuleField('category', 'Catégorie', FieldType.choice, options: _equipmentCategories),
          RuleField('damage', 'Dégâts de base', FieldType.text),
          RuleField('hands', 'Mains', FieldType.number),
          RuleField('qualitiesNormal', 'Qualités, objet courant', FieldType.number),
          RuleField('qualitiesCheap', 'Qualités, bon marché', FieldType.number),
        ]),
      ]),
  const RuleCategory('placeQualities', 'Qualités de lieu', 'Une négative se cumule jusqu’à 3 fois ; une seule surnaturelle par lieu.',
      fields: [
        RuleField('family', 'Famille', FieldType.choice, options: [
          ('standard', 'Standard'),
          ('iconic', 'Iconique'),
          ('supernatural', 'Surnaturelle'),
          ('negative', 'Négative'),
          ('elysium', 'Élysée'),
        ]),
        RuleField('repeatable', 'Répétable (1 à 3)', FieldType.number),
        RuleField('placeTypes', 'Types de lieu autorisés', FieldType.multi, options: [('standard', 'Standard'), ('prestige', 'Prestige'), ('iconic', 'Iconique')]),
      ],
      columns: ['family', 'repeatable'],
      filter: 'family'),
  const RuleCategory('animalQualities', 'Qualités animales', 'Le total ne dépasse pas les points de Serviteurs de la goule.',
      fields: [
        RuleField('cost', 'Coût (points)', FieldType.number),
        RuleField('requires', 'Demande la qualité', FieldType.text),
      ],
      columns: ['cost']),
  const RuleCategory('blood', 'Sang & chasse', 'Règles optionnelles de l’extension ; chaque bloc s’active séparément.',
      fields: [
        RuleField('block', 'Bloc', FieldType.choice, options: _bloodBlocks),
        RuleField('effect', 'Effet', FieldType.longText),
        RuleField('linkedTo', 'Lié à', FieldType.text),
      ],
      columns: ['block'],
      filter: 'block',
      settings: [RuleField('enabled', 'Blocs activés', FieldType.multi, options: _bloodBlocks)]),
];

RuleCategory? categoryById(String id) => ruleCategories.where((c) => c.id == id).firstOrNull;

String _optionLabel(RuleField f, Object? v) => f.options.where((o) => o.$1 == v).firstOrNull?.$2 ?? '$v';

/// Valeur lisible d'un champ, pour les colonnes de la liste.
String displayValue(RuleField f, Object? v) {
  if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty) || (v is Map && v.isEmpty)) return '—';
  return switch (f.type) {
    FieldType.flag => v == true ? 'Oui' : 'Non',
    FieldType.choice => _optionLabel(f, v),
    FieldType.multi => [for (final x in v as List) _optionLabel(f, x)].join(', '),
    FieldType.list => (v as List).join(', '),
    FieldType.keyed => [for (final e in (v as Map).entries) '${e.key} : ${_optionLabel(f, e.value)}'].join(', '),
    FieldType.rows => switch ((v as List).length) { 1 => '1 ligne', final n => '$n lignes' },
    _ => '$v',
  };
}
```

<!-- file: lib/rulebook/base_rules.dart -->
```dart
import '../characters/character.dart';
import '../rules/met_lists.dart';
import 'rule_entry.dart';

RuleEntry _e(String name, [Map<String, dynamic> data = const {}]) => RuleEntry(name: name, data: {...data});

/// Valeurs de base, reprises des listes du code (`met_lists.dart`). Vide : la catégorie n'en a pas.
List<RuleEntry> baseEntries(String cat) => switch (cat) {
      'merits' => [
          for (final e in baseMerits.entries)
            _e(e.key, {'cost': e.value, 'type': 'general', 'atCreation': true, 'withXp': true, 'countsInLimit': true}),
        ],
      'flaws' => [
          for (final e in baseFlaws.entries) _e(e.key, {'cost': e.value, 'type': 'general', 'atCreation': true, 'countsInLimit': true}),
        ],
      'clans' => [
          for (final c in clans)
            _e(c.name, {
              'disciplines': [...c.disciplines],
              'rarity': {'Camarilla': c.rarity.name},
            }),
        ],
      'disciplines' => [
          for (final d in allDisciplines)
            _e(d, {
              'common': commonDisciplines.contains(d),
              if (d == 'Thaumaturgie') 'school': 'thaumaturgy',
              if (d == 'Nécromancie') 'school': 'necromancy',
              if (d == 'Obténébration') 'school': 'abyss',
            }),
        ],
      'skills' => [for (final s in skillNames) _e(s, {'domainMode': domainSkills.contains(s) ? 'perDot' : 'none', 'cap': 5})],
      'backgrounds' => [
          for (final b in backgroundNames)
            _e(b, {
              'ask': switch (b) { 'Ressources' => 'monthly', 'Génération' => 'text', 'Alliés' || 'Serviteurs' || 'Troupeau' => 'people', _ => 'specialties' },
              'cap': b == 'Génération' ? 3 : 5,
            }),
        ],
      'archetypes' => [for (final a in archetypes) _e(a)],
      'sects' => [for (final s in sects) _e(s, {'playable': 'all', 'isDefault': s == 'Camarilla'})],
      'generations' => [
          for (final (i, r) in GenRank.values.indexed)
            _e(r.label, {
              'rank': r.name,
              'numbers': [for (final n in generationNumbers[r]!) '$n'],
              'blood': bloodByRank[r]!.$1,
              'bloodPerTurn': bloodByRank[r]!.$2,
              'attributeBonus': i + 1,
              'skillCap': 5,
              'traitFactor': r == GenRank.neonate ? 1 : 2,
              'outOfClanFactor': 4,
              'techniqueCost': r == GenRank.pretender ? 20 : 12,
              'eldersAllowed': r == GenRank.pretender,
              'eldersLimit': r == GenRank.pretender ? 1 : 0,
            }),
        ],
      _ => const [],
    };
```

<!-- file: lib/rulebook/usage.dart -->
```dart
import '../characters/character.dart';
import 'rule_entry.dart';

/// Fiches qui portent ce nom ; null si la catégorie n'apparaît pas encore sur les fiches.
int? usageCount(String cat, String name, List<Character> chars) {
  final k = nameKey(name);
  bool has(Iterable<String> names) => names.any((n) => nameKey(n) == k);
  final bool Function(Character)? test = switch (cat) {
    'merits' => (c) => has(c.merits.map((t) => t.name)),
    'flaws' => (c) => has(c.flaws.map((t) => t.name)),
    'clans' => (c) => has([?c.clan]),
    'disciplines' => (c) => has(c.disciplines.map((d) => d.name)),
    'skills' => (c) => has(c.skills.map((t) => t.name)),
    'backgrounds' => (c) => has(c.backgrounds.map((t) => t.name)),
    'archetypes' => (c) => has([?c.archetype]),
    'sects' => (c) => has([?c.sect]),
    _ => null,
  };
  return test == null ? null : chars.where(test).length;
}
```

- [ ] **Step 3 : tester, analyser**

Run : `flutter test test/rulebook`, puis `flutter analyze`.

Expected : les 5 tests passent, l'analyseur est propre.

- [ ] **Step 4 : commit**

```
git add lib/rulebook test/rulebook
git commit -m "feat: référentiel — modèle, schémas des 18 catégories, valeurs de base" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : import / export CSV

**Files :** Create `lib/rulebook/csv.dart`. Test : `test/rulebook/csv_test.dart`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `parseTable(text) → List<List<String>>` (séparateur « ; » ou tabulation détecté sur la première ligne) ;
  - `columnsOf(cat)` ;
  - `exportCsv(cat, entries)` ;
  - `previewImport(cat, existing, text) → ImportPreview` (`news`, `updates`, `errors`, `warnings`).

- [ ] **Step 1 : extraire le test, le lancer, il doit échouer**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 2 test`, puis `flutter test test/rulebook/csv_test.dart`.

Expected : échec au chargement.

<!-- file: test/rulebook/csv_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/rulebook/csv.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/schema.dart';

void main() {
  final merits = categoryById('merits')!;
  final clans = categoryById('clans')!;

  test('lecture : guillemets, point-virgule et retour à la ligne dans une cellule (Review Focus 4)', () {
    final rows = parseTable('name;description\n"Chanceux";"Une chance ; insolente\nsur scène"\n\n"Dit ""non""";x\n');
    expect(rows, [
      ['name', 'description'],
      ['Chanceux', 'Une chance ; insolente\nsur scène'],
      ['Dit "non"', 'x'],
    ]);
  });

  test('collé depuis un tableur : tabulations', () {
    expect(parseTable('name\tstate\tcost\r\nChanceux\tavailable\t2'), [
      ['name', 'state', 'cost'],
      ['Chanceux', 'available', '2'],
    ]);
  });

  test('aller-retour : listes, cases, choix, valeurs par secte, lignes', () {
    final e = RuleEntry(name: 'Tremere', state: RuleState.approval, source: 'Livre de base, p. 52', data: {
      'disciplines': ['Auspex', 'Domination', 'Thaumaturgie'],
      'rarity': {'Camarilla': 'common', 'Sabbat': 'rare'},
      'weakness': 'Lien ; sang',
      'bloodlines': [
        {'name': 'Telyav', 'merit': 'Lignée Telyav'},
      ],
    });
    final p = previewImport(clans, const [], exportCsv(clans, [e]));
    expect(p.errors, isEmpty);
    expect(p.news.single.toMap(), e.toMap());
    final m = RuleEntry(name: 'Chanceux', data: {'cost': 2, 'type': 'general', 'atCreation': true, 'withXp': false});
    expect(previewImport(merits, const [], exportCsv(merits, [m])).news.single.toMap(), m.toMap());
  });

  test('aperçu : nouveaux, modifiés, erreurs, colonnes ignorées (Review Focus 1)', () {
    final existing = [RuleEntry(id: 'x1', name: 'Chanceux', data: {'cost': 2})];
    final p = previewImport(merits, existing, [
      'name;state;cost;type;couleur',
      '  chanceux ;available;3;clan;rouge',
      'Nouveau;Accord du conte;1;Général;',
      ';available;1;general;',
      'Faux;inconnu;1;general;',
      'Cher;available;beaucoup;general;',
      'Bizarre;available;1;cosmique;',
      'Nouveau;available;1;general;',
    ].join('\n'));
    expect(p.updates.single.id, 'x1');
    expect(p.updates.single.name, 'Chanceux');
    expect(p.updates.single.data['cost'], 3);
    expect(p.updates.single.data['type'], 'clan');
    expect(p.news.single.name, 'Nouveau');
    expect(p.news.single.state, RuleState.approval);
    expect(p.news.single.data['type'], 'general');
    expect(p.warnings, ['Colonne ignorée : couleur']);
    expect(p.errors, [
      'Ligne 4 : nom manquant',
      'Ligne 5 : état inconnu « inconnu »',
      'Ligne 6, cost : nombre attendu, « beaucoup »',
      'Ligne 7, type : valeur inconnue « cosmique »',
      'Ligne 8 : « Nouveau » apparaît deux fois',
    ]);
  });

  test('colonnes obligatoires', () {
    expect(previewImport(merits, const [], 'cost\n2').errors, ['Colonne « name » absente', 'Colonne « state » absente']);
    expect(previewImport(merits, const [], '').errors, ['Rien à importer']);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 2 impl`.

<!-- file: lib/rulebook/csv.dart -->
```dart
import 'dart:convert';

import 'rule_entry.dart';
import 'schema.dart';

const _common = ['name', 'vo', 'state', 'source', 'description'];

List<String> columnsOf(RuleCategory c) => [..._common, for (final f in c.fields) f.key];

/// Cellules d'un CSV (« ; ») ou d'un collage de tableur (tabulations, détectées sur la première ligne).
/// Guillemets doublés, séparateurs et retours à la ligne entre guillemets ; lignes vides ignorées.
List<List<String>> parseTable(String text) {
  final sep = text.split('\n').first.contains('\t') ? '\t' : ';';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch != '"') {
        cell.write(ch);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (ch == '"' && cell.isEmpty) {
      quoted = true;
    } else if (ch == sep) {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String _quote(String s) => s.contains(RegExp('[;"\n\t]')) ? '"${s.replaceAll('"', '""')}"' : s;

String _encode(RuleField f, Object? v) {
  if (v == null) return '';
  return switch (f.type) {
    FieldType.flag => v == true ? 'oui' : 'non',
    FieldType.multi || FieldType.list => (v as List).join(' | '),
    FieldType.keyed || FieldType.rows => jsonEncode(v),
    _ => '$v',
  };
}

String exportCsv(RuleCategory c, List<RuleEntry> entries) => [
      columnsOf(c).join(';'),
      for (final e in entries)
        [
          e.name,
          e.vo ?? '',
          e.state.name,
          e.source ?? '',
          e.description,
          for (final f in c.fields) _encode(f, e.data[f.key]),
        ].map(_quote).join(';'),
    ].join('\n');

String _choice(RuleField f, String s) {
  final t = s.trim().toLowerCase();
  final o = f.options.where((o) => o.$1.toLowerCase() == t || o.$2.toLowerCase() == t).firstOrNull;
  if (o == null) throw FormatException('valeur inconnue « ${s.trim()} »');
  return o.$1;
}

/// Valeur d'une cellule (null : vide) ; FormatException avec le motif lisible.
Object? _decode(RuleField f, String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  List<String> parts() => [for (final p in t.split('|')) if (p.trim().isNotEmpty) p.trim()];
  switch (f.type) {
    case FieldType.flag:
      if (['oui', 'yes', 'true', '1', 'x'].contains(t.toLowerCase())) return true;
      if (['non', 'no', 'false', '0'].contains(t.toLowerCase())) return false;
      throw FormatException('oui ou non attendu, « $t »');
    case FieldType.number:
      return int.tryParse(t) ?? (throw FormatException('nombre attendu, « $t »'));
    case FieldType.choice:
      return _choice(f, t);
    case FieldType.multi:
      return [for (final p in parts()) _choice(f, p)];
    case FieldType.list:
      return parts();
    case FieldType.keyed || FieldType.rows:
      Object? v;
      try {
        v = jsonDecode(t);
      } on FormatException {
        v = null;
      }
      if ((f.type == FieldType.keyed && v is Map) || (f.type == FieldType.rows && v is List)) return v;
      throw const FormatException('JSON attendu');
    case FieldType.text || FieldType.longText:
      return t;
  }
}

class ImportPreview {
  ImportPreview({this.news = const [], this.updates = const [], this.errors = const [], this.warnings = const []});
  final List<RuleEntry> news;

  /// Éléments existants (même nom), avec leur id.
  final List<RuleEntry> updates;
  final List<String> errors;
  final List<String> warnings;
}

ImportPreview previewImport(RuleCategory c, List<RuleEntry> existing, String text) {
  final rows = parseTable(text);
  if (rows.isEmpty) return ImportPreview(errors: ['Rien à importer']);
  final header = [for (final h in rows.first) h.trim()];
  final missing = [for (final k in ['name', 'state']) if (!header.contains(k)) 'Colonne « $k » absente'];
  if (missing.isNotEmpty) return ImportPreview(errors: missing);
  final known = columnsOf(c);
  final warnings = [for (final h in header) if (h.isNotEmpty && !known.contains(h)) 'Colonne ignorée : $h'];
  final byName = {for (final e in existing) nameKey(e.name): e};
  final news = <RuleEntry>[], updates = <RuleEntry>[], errors = <String>[];
  final seen = <String>{};
  for (final (i, row) in rows.skip(1).indexed) {
    final line = i + 2;
    String cell(String key) {
      final idx = header.indexOf(key);
      return idx < 0 || idx >= row.length ? '' : row[idx];
    }

    String? opt(String key) => cell(key).trim().isEmpty ? null : cell(key).trim();
    final name = cell('name').trim();
    if (name.isEmpty) {
      errors.add('Ligne $line : nom manquant');
      continue;
    }
    final stateText = cell('state').trim().toLowerCase();
    final state = RuleState.values.where((s) => s.name.toLowerCase() == stateText || s.label.toLowerCase() == stateText).firstOrNull;
    if (state == null) {
      errors.add(stateText.isEmpty ? 'Ligne $line : état manquant' : 'Ligne $line : état inconnu « ${cell('state').trim()} »');
      continue;
    }
    if (!seen.add(nameKey(name))) {
      errors.add('Ligne $line : « $name » apparaît deux fois');
      continue;
    }
    final old = byName[nameKey(name)];
    final data = <String, dynamic>{...?old?.data};
    String? error;
    for (final f in c.fields) {
      if (!header.contains(f.key)) continue;
      try {
        final v = _decode(f, cell(f.key));
        if (v == null) {
          data.remove(f.key);
        } else {
          data[f.key] = v;
        }
      } on FormatException catch (e) {
        error = 'Ligne $line, ${f.key} : ${e.message}';
        break;
      }
    }
    if (error != null) {
      errors.add(error);
      continue;
    }
    // Colonne absente : la valeur existante est gardée.
    (old == null ? news : updates).add(RuleEntry(
      id: old?.id ?? '',
      name: old?.name ?? name,
      vo: header.contains('vo') ? opt('vo') : old?.vo,
      state: state,
      source: header.contains('source') ? opt('source') : old?.source,
      description: header.contains('description') ? cell('description').trim() : (old?.description ?? ''),
      data: data,
    ));
  }
  return ImportPreview(news: news, updates: updates, errors: errors, warnings: warnings);
}
```

- [ ] **Step 3 : tester, analyser**

Run : `flutter test test/rulebook`, puis `flutter analyze`.

Expected : tous les tests passent, l'analyseur est propre.

- [ ] **Step 4 : commit**

```
git add lib/rulebook/csv.dart test/rulebook/csv_test.dart
git commit -m "feat: référentiel — import et export CSV avec aperçu" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : règles Firestore et dépôt

**Files :**
- Modify : `firestore.rules`, `test/fakes.dart`.
- Create : `lib/rulebook/rules_repository.dart`, `rules_test/rulebook.test.js`.

**Interfaces :**
- Consumes : les tâches 1 et 2 ; `firestoreProvider` (`auth/session_providers.dart`) ; `Actor`, `actorOf` (`characters/character_repository.dart`).
- Produces :
  - `RulesRepository` :
    - `watchAll() → Stream<Map<cat, List<RuleEntry>>>` (groupe `entries`, trié par nom) ;
    - `watchSettings() → Stream<Map<cat, Map>>` ;
    - `watchNote(cat, id) → Stream<String>` ;
    - `save(cat, entry, by, {note}) → Future<String>` (id) ;
    - `delete(cat, id)` ;
    - `saveSettings(cat, values, by)` ;
    - `importEntries(cat, entries, by)` ;
  - les providers `rulesRepositoryProvider`, `allRuleEntriesProvider` et `allRuleSettingsProvider` ;
  - `FakeRulesRepository` : `calls` reçoit `save:<cat>:<nom>:<état>`, `delete:<cat>:<id>`, `settings:<cat>` et `import:<cat>:<n>` ; `lastSaved`, `lastNote`.

- [ ] **Step 1 : extraire le test des règles, le lancer, il doit échouer**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 3 test`, puis, depuis `rules_test`, `JAVA_HOME=… npm test`.

Expected : les tests de `rulebook.test.js` échouent.

<!-- file: rules_test/rulebook.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, deleteDoc, collectionGroup, query } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: 'x@ex.fr', role });
    await setDoc(doc(db, 'rules/merits/entries/m1'), { name: 'Chanceux', state: 'available', data: { cost: 2 } });
    await setDoc(doc(db, 'rules/merits/entries/m1/private/note'), { text: 'Secret' });
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const entry = (uid, over) => ({ name: 'Volonté de fer', vo: null, state: 'available', source: null, description: '', data: { cost: 3 }, updatedByUid: uid, updatedByName: uid, ...over });

test('le référentiel se lit par tous, s’écrit par les conteurs (Review Focus 5)', async () => {
  await assertSucceeds(getDoc(doc(as('zoe'), 'rules/merits/entries/m1')));
  await assertSucceeds(getDocs(query(collectionGroup(as('zoe'), 'entries'))));
  await assertFails(setDoc(doc(as('zoe'), 'rules/merits/entries/n1'), entry('zoe')));
  await assertFails(setDoc(doc(as('julien'), 'rules/merits/entries/n1'), entry('julien')));
  await assertSucceeds(setDoc(doc(as('lea'), 'rules/merits/entries/n1'), entry('lea')));
  await assertSucceeds(deleteDoc(doc(as('lea'), 'rules/merits/entries/n1')));
  await assertFails(deleteDoc(doc(as('zoe'), 'rules/merits/entries/m1')));
});

test('élément invalide refusé', async () => {
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/entries/n2'), entry('lea', { name: '' })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/entries/n2'), entry('lea', { name: 'x'.repeat(81) })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/entries/n2'), entry('lea', { state: 'cosmique' })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/entries/n2'), entry('lea', { data: 'coût 3' })));
  await assertFails(setDoc(doc(as('lea'), 'rules/merits/entries/n2'), entry('lea', { updatedByUid: 'julien' })));
});

test('note du conte : cachée aux joueurs', async () => {
  await assertFails(getDoc(doc(as('zoe'), 'rules/merits/entries/m1/private/note')));
  await assertSucceeds(getDoc(doc(as('julien'), 'rules/merits/entries/m1/private/note')));
  await assertFails(setDoc(doc(as('julien'), 'rules/merits/entries/m1/private/note'), { text: 'x' }));
  await assertSucceeds(setDoc(doc(as('lea'), 'rules/merits/entries/m1/private/note'), { text: 'x' }));
});

test('réglages d’une catégorie', async () => {
  await assertFails(setDoc(doc(as('zoe'), 'rules/rituals'), { costPerLevel: 1 }));
  await assertSucceeds(setDoc(doc(as('lea'), 'rules/rituals'), { costPerLevel: 2 }));
  await assertSucceeds(getDoc(doc(as('zoe'), 'rules/rituals')));
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules`, juste avant `match /invitations/{email} {`, ajouter :

```
    // Référentiel des règles (sous-projet 5) : lu par tous, écrit par les conteurs.
    match /rules/{cat} {
      allow read: if signedIn();
      allow write: if managesAccounts();

      match /entries/{id} {
        allow read: if signedIn();
        allow delete: if managesAccounts();
        allow create, update: if managesAccounts()
          && request.resource.data.name is string
          && request.resource.data.name.size() > 0 && request.resource.data.name.size() <= 80
          && request.resource.data.state in ['available', 'approval', 'draft', 'forbidden']
          && request.resource.data.data is map
          && request.resource.data.updatedByUid == request.auth.uid;

        // Note réservée au conte : un document à part, Firestore ne cache pas un champ.
        match /private/{doc} {
          allow read: if isStaff();
          allow write: if managesAccounts();
        }
      }
    }

    // Toutes les catégories en une requête (écran du référentiel, moteurs du plan B).
    match /{path=**}/entries/{id} {
      allow read: if signedIn();
    }

```

Run : depuis `rules_test`, `JAVA_HOME=… npm test`.

Expected : `fail 0`.

- [ ] **Step 3 : dépôt et fake**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 3 impl` (écrit `lib/rulebook/rules_repository.dart`).

<!-- file: lib/rulebook/rules_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import 'rule_entry.dart';

part 'rules_repository.g.dart';

/// `rules/{cat}` (réglages), `rules/{cat}/entries/{id}`, `…/private/note`.
class RulesRepository {
  RulesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String cat) => _db.collection('rules').doc(cat).collection('entries');

  /// Toutes les catégories, par une requête sur le groupe `entries`, triées par nom.
  Stream<Map<String, List<RuleEntry>>> watchAll() => _db.collectionGroup('entries').snapshots().map((q) {
        final out = <String, List<RuleEntry>>{};
        for (final d in q.docs) {
          (out[d.reference.parent.parent!.id] ??= []).add(RuleEntry.fromMap(d.id, d.data()));
        }
        for (final list in out.values) {
          list.sort((a, b) => nameKey(a.name).compareTo(nameKey(b.name)));
        }
        return out;
      });

  Stream<Map<String, Map<String, dynamic>>> watchSettings() =>
      _db.collection('rules').snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  Stream<String> watchNote(String cat, String id) =>
      _entries(cat).doc(id).collection('private').doc('note').snapshots().map((d) => d.data()?['text'] as String? ?? '');

  Map<String, dynamic> _write(RuleEntry e, Actor by) => {
        ...e.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': by.uid,
        'updatedByName': by.name,
      };

  /// Crée (id vide) ou remplace l'élément ; [note] : note du conte (null : inchangée).
  Future<String> save(String cat, RuleEntry e, Actor by, {String? note}) async {
    final ref = e.id.isEmpty ? _entries(cat).doc() : _entries(cat).doc(e.id);
    final batch = _db.batch()..set(ref, _write(e, by));
    if (note != null) batch.set(ref.collection('private').doc('note'), {'text': note.trim()});
    await batch.commit();
    return ref.id;
  }

  Future<void> delete(String cat, String id) => (_db.batch()
        ..delete(_entries(cat).doc(id).collection('private').doc('note'))
        ..delete(_entries(cat).doc(id)))
      .commit();

  Future<void> saveSettings(String cat, Map<String, dynamic> values, Actor by) => _db.collection('rules').doc(cat).set({
        ...values,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByName': by.name,
      });

  /// Import ou valeurs de base : nouveaux (id vide) et modifiés, par lots de 400.
  Future<void> importEntries(String cat, List<RuleEntry> entries, Actor by) async {
    for (var i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(400)) {
        batch.set(e.id.isEmpty ? _entries(cat).doc() : _entries(cat).doc(e.id), _write(e, by));
      }
      await batch.commit();
    }
  }
}

@Riverpod(keepAlive: true)
RulesRepository rulesRepository(Ref ref) => RulesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<Map<String, List<RuleEntry>>> allRuleEntries(Ref ref) => ref.watch(rulesRepositoryProvider).watchAll();

@riverpod
Stream<Map<String, Map<String, dynamic>>> allRuleSettings(Ref ref) => ref.watch(rulesRepositoryProvider).watchSettings();
```

Dans `test/fakes.dart`, ajouter les imports `package:portail_met/rulebook/rule_entry.dart` et `package:portail_met/rulebook/rules_repository.dart`, et à la fin :

```dart
class FakeRulesRepository implements RulesRepository {
  final calls = <String>[];
  RuleEntry? lastSaved;
  String? lastNote;

  @override
  Stream<String> watchNote(String cat, String id) => Stream.value('');

  @override
  Future<String> save(String cat, RuleEntry e, Actor by, {String? note}) async {
    calls.add('save:$cat:${e.name}:${e.state.name}');
    lastSaved = e;
    lastNote = note;
    return e.id.isEmpty ? 'new-rule' : e.id;
  }

  @override
  Future<void> delete(String cat, String id) async => calls.add('delete:$cat:$id');

  @override
  Future<void> saveSettings(String cat, Map<String, dynamic> values, Actor by) async => calls.add('settings:$cat');

  @override
  Future<void> importEntries(String cat, List<RuleEntry> entries, Actor by) async => calls.add('import:$cat:${entries.length}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test`.

Expected : propre, et tous les tests passent.

- [ ] **Step 4 : commit**

```
git add firestore.rules rules_test/rulebook.test.js lib test/fakes.dart
git commit -m "feat: référentiel — règles Firestore et dépôt" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : formulaire générique

**Files :** Create `lib/rulebook/rule_form.dart`. Test : `test/rulebook/rule_form_test.dart`.

**Interfaces :**
- Consumes : la tâche 1.
- Produces :
  - `RuleFieldEditor(field, value, onChanged, {keyOptions, enabled, keyPrefix})` ;
  - `RuleEntryForm(category, entry, {keyOptions, existingNames, readOnly, note, usage, onSave(entry, note), onDelete})`.
  - **Clés des champs :**
    - `rf-name`, `rf-vo`, `rf-state`, `rf-source`, `rf-description`, `rf-note` ;
    - `rf-<champ>` ;
    - pour une ligne, `rf-<champ>-<i>-<sous-champ>` ; pour une valeur par secte, `rf-<champ>-<clé>` ;
    - boutons `rf-save`, `rf-delete`, `rf-<champ>-add`.

- [ ] **Step 1 : extraire le test, le lancer, il doit échouer**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 4 test`, puis `flutter test test/rulebook/rule_form_test.dart`.

Expected : échec au chargement.

<!-- file: test/rulebook/rule_form_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rule_form.dart';
import 'package:portail_met/rulebook/schema.dart';

void main() {
  Future<List<(RuleEntry, String)>> pump(WidgetTester tester, String cat, RuleEntry entry, {bool readOnly = false}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <(RuleEntry, String)>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RuleEntryForm(
            category: categoryById(cat)!,
            entry: entry,
            keyOptions: const {'sects': ['Camarilla', 'Sabbat']},
            existingNames: {nameKey('Chanceux')},
            readOnly: readOnly,
            note: 'Secret',
            onSave: (e, note) async => saved.add((e, note)),
          ),
        ),
      ),
    ));
    return saved;
  }

  testWidgets('édition d’un atout : nombre, choix, case, note', (tester) async {
    final saved = await pump(tester, 'merits', RuleEntry(id: 'm', name: 'Volonté de fer', data: {'cost': 3}));
    await tester.enterText(find.byKey(const Key('rf-cost')), '4');
    await tester.tap(find.byKey(const Key('rf-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('À la création'));
    await tester.enterText(find.byKey(const Key('rf-note')), 'À surveiller');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    final (e, note) = saved.single;
    expect(e.data, {'cost': 4, 'type': 'clan', 'atCreation': true});
    expect(note, 'À surveiller');
  });

  testWidgets('nom obligatoire, sans doublon', (tester) async {
    final saved = await pump(tester, 'merits', RuleEntry(name: ''));
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rf-name')), ' chanceux ');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    expect(find.text('Un élément porte déjà ce nom.'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('clan : liste, rareté par secte, lignées', (tester) async {
    final saved = await pump(tester, 'clans', RuleEntry(id: 'c', name: 'Tremere'));
    await tester.enterText(find.byKey(const Key('rf-disciplines')), 'Auspex\nDomination\n\nThaumaturgie');
    await tester.tap(find.byKey(const Key('rf-rarity-Sabbat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rare · 4 pts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-bloodlines-add')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rf-bloodlines-0-name')), 'Telyav');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pump();
    final e = saved.single.$1;
    expect(e.data['disciplines'], ['Auspex', 'Domination', 'Thaumaturgie']);
    expect(e.data['rarity'], {'Sabbat': 'rare'});
    expect(e.data['bloodlines'], [{'name': 'Telyav'}]);
  });

  testWidgets('lecture seule : pas de bouton', (tester) async {
    await pump(tester, 'merits', RuleEntry(id: 'm', name: 'Volonté de fer'), readOnly: true);
    expect(find.byKey(const Key('rf-save')), findsNothing);
    expect(tester.widget<TextFormField>(find.byKey(const Key('rf-name'))).enabled, isFalse);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 4 impl`.

<!-- file: lib/rulebook/rule_form.dart -->
```dart
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'rule_entry.dart';
import 'schema.dart';

/// Un champ du schéma. [value] est la valeur JSON actuelle ; [onChanged] reçoit null pour « vide ».
class RuleFieldEditor extends StatelessWidget {
  const RuleFieldEditor(this.field, this.value, this.onChanged, {super.key, this.keyOptions = const {}, this.enabled = true, this.keyPrefix = 'rf'});

  final RuleField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final Map<String, List<String>> keyOptions;
  final bool enabled;
  final String keyPrefix;

  String get _k => '$keyPrefix-${field.key}';

  List<DropdownMenuItem<String?>> get _items => [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        for (final o in field.options) DropdownMenuItem<String?>(value: o.$1, child: Text(o.$2)),
      ];

  @override
  Widget build(BuildContext context) {
    final f = field;
    final t = Theme.of(context).textTheme;
    InputDecoration deco([String? label]) => InputDecoration(labelText: label ?? f.label, helperText: f.help);
    switch (f.type) {
      case FieldType.text || FieldType.longText:
        return TextFormField(
          key: Key(_k),
          initialValue: value as String? ?? '',
          enabled: enabled,
          maxLines: f.type == FieldType.longText ? 3 : 1,
          decoration: deco(),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
        );
      case FieldType.number:
        return TextFormField(
          key: Key(_k),
          initialValue: value == null ? '' : '$value',
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: deco(),
          onChanged: (v) => onChanged(int.tryParse(v.trim())),
        );
      case FieldType.choice:
        return DropdownButtonFormField<String?>(
          key: Key(_k),
          initialValue: f.options.any((o) => o.$1 == value) ? value as String : null,
          isExpanded: true,
          decoration: deco(),
          items: _items,
          onChanged: enabled ? onChanged : null,
        );
      case FieldType.multi:
        final selected = [...(value as List?)?.cast<String>() ?? const <String>[]];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: t.labelMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in f.options)
              FilterChip(
                key: Key('$_k-${o.$1}'),
                label: Text(o.$2),
                selected: selected.contains(o.$1),
                onSelected: !enabled
                    ? null
                    : (on) {
                        final next = [for (final x in f.options) if (x.$1 == o.$1 ? on : selected.contains(x.$1)) x.$1];
                        onChanged(next.isEmpty ? null : next);
                      },
              ),
          ]),
        ]);
      case FieldType.flag:
        return CheckboxListTile(
          key: Key(_k),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(f.label),
          value: value == true,
          onChanged: enabled ? (v) => onChanged(v == true ? true : null) : null,
        );
      case FieldType.list:
        return TextFormField(
          key: Key(_k),
          initialValue: ((value as List?) ?? const []).join('\n'),
          enabled: enabled,
          minLines: 2,
          maxLines: null,
          decoration: deco('${f.label} — une valeur par ligne'),
          onChanged: (v) {
            final items = [for (final l in v.split('\n')) if (l.trim().isNotEmpty) l.trim()];
            onChanged(items.isEmpty ? null : items);
          },
        );
      case FieldType.keyed:
        final map = Map<String, dynamic>.from((value as Map?) ?? const {});
        final keys = keyOptions[f.keysFrom] ?? const <String>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(f.label, style: t.labelMedium),
          if (keys.isEmpty) Text('Aucune entrée dans « ${categoryById(f.keysFrom!)?.label ?? f.keysFrom} ».', style: t.bodySmall),
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(child: Text(k, style: t.bodyMedium)),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    key: Key('$_k-$k'),
                    initialValue: f.options.any((o) => o.$1 == map[k]) ? map[k] as String : null,
                    isExpanded: true,
                    items: _items,
                    onChanged: !enabled
                        ? null
                        : (v) {
                            final next = {...map};
                            if (v == null) {
                              next.remove(k);
                            } else {
                              next[k] = v;
                            }
                            onChanged(next.isEmpty ? null : next);
                          },
                  ),
                ),
              ]),
            ),
        ]);
      case FieldType.rows:
        final rows = [for (final r in (value as List?) ?? const []) Map<String, dynamic>.from(r as Map)];
        void set(List<Map<String, dynamic>> next) => onChanged(next.isEmpty ? null : next);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(f.label, style: t.labelMedium),
          for (final (i, row) in rows.indexed)
            Container(
              // La longueur dans la clé : retirer une ligne reconstruit les champs des suivantes.
              key: ValueKey('$_k-row-$i-${rows.length}'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final sub in f.rowFields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RuleFieldEditor(
                      sub,
                      row[sub.key],
                      (v) {
                        final next = [for (final r in rows) {...r}];
                        if (v == null) {
                          next[i].remove(sub.key);
                        } else {
                          next[i][sub.key] = v;
                        }
                        set(next);
                      },
                      enabled: enabled,
                      keyPrefix: '$_k-$i',
                    ),
                  ),
                if (enabled)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => set([for (final (j, r) in rows.indexed) if (j != i) r]),
                      child: const Text('Retirer la ligne'),
                    ),
                  ),
              ]),
            ),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(key: Key('$_k-add'), onPressed: () => set([...rows, <String, dynamic>{}]), child: const Text('+ Ajouter')),
            ),
        ]);
    }
  }
}

/// Panneau d'édition d'un élément, construit depuis le schéma de sa catégorie.
class RuleEntryForm extends StatefulWidget {
  const RuleEntryForm({
    super.key,
    required this.category,
    required this.entry,
    this.keyOptions = const {},
    this.existingNames = const {},
    this.readOnly = false,
    this.note = '',
    this.usage,
    required this.onSave,
    this.onDelete,
  });

  final RuleCategory category;
  final RuleEntry entry;
  final Map<String, List<String>> keyOptions;

  /// Noms (nameKey) des autres éléments de la catégorie.
  final Set<String> existingNames;
  final bool readOnly;
  final String note;

  /// Fiches qui portent ce nom (null : non suivi).
  final int? usage;
  final Future<void> Function(RuleEntry entry, String note) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<RuleEntryForm> createState() => _RuleEntryFormState();
}

class _RuleEntryFormState extends State<RuleEntryForm> {
  late final RuleEntry _e = widget.entry.copy();
  late final _note = TextEditingController(text: widget.note);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _e.name.trim();
    final error = name.isEmpty
        ? 'Le nom est obligatoire.'
        : name.length > 80
            ? 'Le nom fait 80 caractères au plus.'
            : widget.existingNames.contains(nameKey(name))
                ? 'Un élément porte déjà ce nom.'
                : null;
    setState(() {
      _error = error;
      _busy = error == null;
    });
    if (error != null) return;
    try {
      await widget.onSave(_e..name = name, _note.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ro = widget.readOnly;
    final usage = widget.usage;
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(_e.id.isEmpty ? 'Nouvel élément' : 'Modifier l’élément'),
      const SizedBox(height: 12),
      gap(TextFormField(
        key: const Key('rf-name'),
        initialValue: _e.name,
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Nom'),
        onChanged: (v) => _e.name = v,
      )),
      gap(TextFormField(
        key: const Key('rf-vo'),
        initialValue: _e.vo ?? '',
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Nom VO — pour retrouver la règle'),
        onChanged: (v) => _e.vo = v.trim().isEmpty ? null : v.trim(),
      )),
      gap(DropdownButtonFormField<RuleState>(
        key: const Key('rf-state'),
        initialValue: _e.state,
        decoration: const InputDecoration(labelText: 'État'),
        items: [for (final s in RuleState.values) DropdownMenuItem(value: s, child: Text(s.label))],
        onChanged: ro ? null : (s) => setState(() => _e.state = s ?? _e.state),
      )),
      for (final f in widget.category.fields)
        gap(RuleFieldEditor(
          f,
          _e.data[f.key],
          (v) => setState(() {
            if (v == null) {
              _e.data.remove(f.key);
            } else {
              _e.data[f.key] = v;
            }
          }),
          keyOptions: widget.keyOptions,
          enabled: !ro,
        )),
      gap(TextFormField(
        key: const Key('rf-description'),
        initialValue: _e.description,
        enabled: !ro,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Règle affichée aux joueurs', hintText: 'Résumé de l’effet, rédigé par le conte'),
        onChanged: (v) => _e.description = v.trim(),
      )),
      gap(TextFormField(
        key: const Key('rf-source'),
        initialValue: _e.source ?? '',
        enabled: !ro,
        decoration: const InputDecoration(labelText: 'Source', hintText: 'Livre de base, p. …'),
        onChanged: (v) => _e.source = v.trim().isEmpty ? null : v.trim(),
      )),
      gap(TextFormField(
        key: const Key('rf-note'),
        controller: _note,
        enabled: !ro,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note réservée au conte'),
      )),
      if (usage != null)
        Text('Présent sur $usage fiche${usage == 1 ? '' : 's'}. Changer une valeur ne modifie pas les fiches existantes.', style: t.bodySmall),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
      ],
      if (!ro) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(key: const Key('rf-save'), onPressed: _busy ? null : _save, child: const Text('Enregistrer'))),
          if (widget.onDelete != null) ...[
            const SizedBox(width: 10),
            TextButton(key: const Key('rf-delete'), onPressed: _busy ? null : widget.onDelete, child: const Text('Supprimer')),
          ],
        ]),
      ],
    ]);
  }
}
```

- [ ] **Step 3 : tester, analyser**

Run : `flutter test test/rulebook`, puis `flutter analyze`.

Expected : tous les tests passent, l'analyseur est propre.

- [ ] **Step 4 : commit**

```
git add lib/rulebook/rule_form.dart test/rulebook/rule_form_test.dart
git commit -m "feat: référentiel — formulaire générique piloté par le schéma" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : écran « Référentiel »

**Files :** Create `lib/rulebook/referential_screen.dart`. Modify `lib/router.dart`. Test : `test/rulebook/referential_screen_test.dart`.

**Interfaces :**
- Consumes :
  - les tâches 1 à 4 ;
  - `allCharactersProvider` et `currentUserProvider` ;
  - `PageBody`, `PageTitle`, `Panel`, `SectionTitle`, `EmptyState`, `asyncView`, `isWide`.
- Produces :
  - `ReferentialScreen({categoryId})` sur les routes `/conteur/referentiel` et `/conteur/referentiel/:cat` ;
  - les clés `ref-search`, `ref-new`, `ref-io`, `ref-base`, `import-text`, `import-analyse`, `import-summary`, `import-go`, `export-copy`.

- [ ] **Step 1 : extraire le test, le lancer, il doit échouer**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 5 test`, puis `flutter test test/rulebook/referential_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/rulebook/referential_screen_test.dart -->
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/rulebook/referential_screen.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rules_repository.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Map<String, List<RuleEntry>> data() => {
        'merits': [
          RuleEntry(id: 'm1', name: 'Chanceux', vo: 'Lucky', data: {'cost': 2, 'type': 'general'}, updatedAt: DateTime(2026, 9, 1)),
          RuleEntry(id: 'm2', name: 'Visage angélique', data: {'cost': 1, 'type': 'clan'}, updatedAt: DateTime(2026, 9, 1)),
          RuleEntry(id: 'm3', name: 'Volonté de fer', state: RuleState.forbidden, data: {'cost': 3}, updatedAt: DateTime(2026, 9, 1)),
        ],
      };

  Future<FakeRulesRepository> pump(WidgetTester tester, {String cat = 'merits', AppUser user = lea, Stream<Map<String, List<RuleEntry>>>? source}) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRulesRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        rulesRepositoryProvider.overrideWith((ref) => repo),
        allRuleEntriesProvider.overrideWith((ref) => source ?? Stream.value(data())),
        allRuleSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
      ],
      child: MaterialApp.router(
        theme: buildTheme(withFonts: false),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => Scaffold(body: ReferentialScreen(categoryId: cat))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('liste, recherche, filtre par état', (tester) async {
    await pump(tester);
    expect(find.text('Chanceux'), findsOneWidget);
    expect(find.text('Volonté de fer'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ref-search')), 'luck');
    await tester.pump();
    expect(find.text('Chanceux'), findsOneWidget);
    expect(find.text('Volonté de fer'), findsNothing);
    await tester.enterText(find.byKey(const Key('ref-search')), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Interdit'));
    await tester.pump();
    expect(find.text('Chanceux'), findsNothing);
    expect(find.text('Volonté de fer'), findsOneWidget);
  });

  testWidgets('modifier puis enregistrer', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rf-cost')), '3');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Chanceux:available']);
    expect(repo.lastSaved!.data['cost'], 3);
  });

  testWidgets('modifié par un autre conteur : recharger ou écraser (Review Focus 2)', (tester) async {
    final controller = StreamController<Map<String, List<RuleEntry>>>();
    addTearDown(controller.close);
    controller.add(data());
    final repo = await pump(tester, source: controller.stream);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    final changed = data();
    changed['merits']![0] = RuleEntry(id: 'm1', name: 'Chanceux', data: {'cost': 5}, updatedAt: DateTime(2026, 10, 2), updatedByName: 'Marc D.');
    controller.add(changed);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.text('Modifié par Marc D. à l’instant'), findsOneWidget);
    await tester.tap(find.text('Écraser'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Chanceux:available']);
    expect(repo.lastSaved!.data['cost'], 2);
  });

  testWidgets('supprimer un élément utilisé : marquer Interdit (Review Focus 3)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Visage angélique'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rf-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Utilisé par 1 fiche'), findsOneWidget);
    await tester.tap(find.text('Marquer Interdit'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Visage angélique:forbidden']);
  });

  testWidgets('renommer un élément utilisé : confirmation', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Visage angélique'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rf-name')), 'Visage de porcelaine');
    await tester.tap(find.byKey(const Key('rf-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 fiche porte l’ancien nom'), findsOneWidget);
    await tester.tap(find.text('Renommer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:merits:Visage de porcelaine:available']);
  });

  testWidgets('catégorie vide : charger les valeurs de base', (tester) async {
    final repo = await pump(tester, cat: 'archetypes');
    await tester.tap(find.byKey(const Key('ref-base')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['import:archetypes:20']);
  });

  testWidgets('import : aperçu puis écriture (Review Focus 1)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('ref-io')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-text')),
      'name;state;cost\nVisage angélique;available;2\nNouveau;available;1\n;available;1',
    );
    await tester.tap(find.byKey(const Key('import-analyse')));
    await tester.pumpAndSettle();
    expect(find.text('1 nouveau, 1 modifié, 1 ligne en erreur'), findsOneWidget);
    expect(find.text('Modifié : Visage angélique (utilisé par 1 fiche)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-go')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['import:merits:2']);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('ref-new')), findsNothing);
    await tester.tap(find.text('Chanceux'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rf-save')), findsNothing);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-03-referentiel-a.md 5 impl`.

<!-- file: lib/rulebook/referential_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'base_rules.dart';
import 'csv.dart';
import 'rule_entry.dart';
import 'rule_form.dart';
import 'rules_repository.dart';
import 'schema.dart';
import 'usage.dart';

String _plural(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

/// Référentiel : catégories, liste, réglages, import / export, édition.
class ReferentialScreen extends ConsumerStatefulWidget {
  const ReferentialScreen({super.key, this.categoryId = 'merits'});
  final String categoryId;

  @override
  ConsumerState<ReferentialScreen> createState() => _ReferentialScreenState();
}

class _ReferentialScreenState extends ConsumerState<ReferentialScreen> {
  /// Élément ouvert : id, '' pour un nouveau, null pour aucun.
  String? _selectedId;

  /// Version de l'élément à l'ouverture du formulaire (conflit entre conteurs).
  RuleEntry? _opened;
  int _formVersion = 0;
  RuleState? _stateFilter;
  String? _chip;
  final _search = TextEditingController();

  @override
  void didUpdateWidget(ReferentialScreen old) {
    super.didUpdateWidget(old);
    if (old.categoryId != widget.categoryId) {
      _selectedId = null;
      _opened = null;
      _stateFilter = null;
      _chip = null;
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(RuleEntry? e) => setState(() {
        _selectedId = e?.id ?? '';
        _opened = e;
        _formVersion++;
      });

  Actor? get _actor => actorOf(ref.read(currentUserProvider).value);

  Future<void> _save(RuleCategory cat, RuleEntry edited, String note, List<RuleEntry> current, List<Character> chars) async {
    final by = _actor;
    if (by == null) return;
    final opened = _opened;
    final latest = opened == null ? null : current.where((e) => e.id == opened.id).firstOrNull;
    if (opened != null && latest != null && latest.updatedAt != opened.updatedAt) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Modifié par ${latest.updatedByName ?? 'un autre conteur'} à l’instant'),
          content: const Text('Recharger pour voir sa version, ou écraser avec la vôtre ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Recharger')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Écraser')),
          ],
        ),
      );
      if (overwrite == null || !mounted) return;
      if (!overwrite) return _open(latest);
    }
    if (opened != null && nameKey(opened.name) != nameKey(edited.name)) {
      final used = usageCount(cat.id, opened.name, chars) ?? 0;
      if (used > 0) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text('Renommer « ${opened.name} » ?'),
            content: Text('${_plural(used, 'fiche porte', 'fiches portent')} l’ancien nom ; elles ne sont pas modifiées.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Renommer')),
            ],
          ),
        );
        if (ok != true || !mounted) return;
      }
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref.read(rulesRepositoryProvider).save(cat.id, edited, by, note: note);
      if (!mounted) return;
      setState(() {
        _selectedId = id;
        _opened = null;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Enregistré.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement impossible. Réessayez.')));
    }
  }

  Future<void> _delete(RuleCategory cat, RuleEntry e, List<Character> chars) async {
    final by = _actor;
    if (by == null) return;
    final used = usageCount(cat.id, e.name, chars) ?? 0;
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Supprimer « ${e.name} » ?'),
        content: Text(used > 0
            ? 'Utilisé par ${_plural(used, 'fiche', 'fiches')}, qui garderont ce nom. Vous pouvez plutôt le marquer Interdit.'
            : 'Cette suppression est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          if (used > 0) OutlinedButton(onPressed: () => Navigator.pop(d, 'forbid'), child: const Text('Marquer Interdit')),
          FilledButton(onPressed: () => Navigator.pop(d, 'delete'), child: const Text('Supprimer')),
        ],
      ),
    );
    final repo = ref.read(rulesRepositoryProvider);
    if (choice == 'forbid') {
      await repo.save(cat.id, e.copy()..state = RuleState.forbidden, by);
    } else if (choice == 'delete') {
      await repo.delete(cat.id, e.id);
      if (mounted) setState(() => _selectedId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Le référentiel est géré par les conteurs.');
    }
    final cat = categoryById(widget.categoryId);
    if (cat == null) {
      return const EmptyState(kind: EmptyKind.notFound, title: 'Catégorie inconnue', message: 'Choisissez une catégorie dans le menu.');
    }
    return asyncView(
      ref.watch(allRuleEntriesProvider),
      (all) => asyncView(
        ref.watch(allRuleSettingsProvider),
        (settings) => asyncView(
          ref.watch(allCharactersProvider),
          (chars) => _body(context, me, cat, all, settings, chars),
          onRetry: () => ref.invalidate(allCharactersProvider),
        ),
        onRetry: () => ref.invalidate(allRuleSettingsProvider),
      ),
      onRetry: () => ref.invalidate(allRuleEntriesProvider),
    );
  }

  Widget _body(BuildContext context, AppUser me, RuleCategory cat, Map<String, List<RuleEntry>> all,
      Map<String, Map<String, dynamic>> settings, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final readOnly = !me.role.managesAccounts;
    final entries = all[cat.id] ?? const <RuleEntry>[];
    final sectEntries = all['sects'] ?? const <RuleEntry>[];
    final keyOptions = {'sects': [for (final e in sectEntries.isEmpty ? baseEntries('sects') : sectEntries) e.name]};
    final filterField = cat.filter == null ? null : cat.fields.firstWhere((f) => f.key == cat.filter);
    final query = nameKey(_search.text);
    bool chipMatch(RuleEntry e) {
      final v = e.data[cat.filter];
      return _chip == null || v == _chip || (v is List && v.contains(_chip));
    }

    final shown = [
      for (final e in entries)
        if ((_stateFilter == null || e.state == _stateFilter) &&
            chipMatch(e) &&
            (query.isEmpty || nameKey(e.name).contains(query) || nameKey(e.vo ?? '').contains(query)))
          e,
    ];
    final selected = _selectedId == null ? null : (_selectedId!.isEmpty ? RuleEntry(name: '') : entries.where((e) => e.id == _selectedId).firstOrNull);

    final menu = Panel(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8), child: SectionTitle('Référentiel')),
        for (final c in ruleCategories)
          InkWell(
            onTap: () => context.go('/conteur/referentiel/${c.id}'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: c.id == cat.id ? AppColors.navActive : null,
              child: Row(children: [
                Expanded(child: Text(c.label, style: TextStyle(fontWeight: c.id == cat.id ? FontWeight.w600 : FontWeight.w400))),
                Text('${all[c.id]?.length ?? 0}', style: t.bodySmall),
              ]),
            ),
          ),
      ]),
    );

    final settingsPanel = cat.settings.isEmpty
        ? null
        : _SettingsPanel(
            key: ValueKey('settings-${cat.id}'),
            category: cat,
            values: settings[cat.id] ?? const {},
            readOnly: readOnly,
            onSave: (v) async {
              final by = _actor;
              if (by != null) await ref.read(rulesRepositoryProvider).saveSettings(cat.id, v, by);
            },
          );

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(
        cat.label,
        subtitle: cat.help,
        action: Wrap(spacing: 10, runSpacing: 10, children: [
          TextButton(
            key: const Key('ref-io'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ImportExportDialog(
                category: cat,
                entries: entries,
                chars: chars,
                readOnly: readOnly,
                onImport: (items) async {
                  final by = _actor;
                  if (by != null) await ref.read(rulesRepositoryProvider).importEntries(cat.id, items, by);
                },
              ),
            ),
            child: Text(readOnly ? 'Exporter' : 'Importer / exporter'),
          ),
          if (!readOnly) FilledButton(key: const Key('ref-new'), onPressed: () => _open(null), child: const Text('Nouvel élément')),
        ]),
      ),
      const SizedBox(height: 16),
      if (settingsPanel != null) ...[settingsPanel, const SizedBox(height: 16)],
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final s in [null, ...RuleState.values])
          ChoiceChip(
            label: Text(s?.label ?? 'Tous'),
            selected: _stateFilter == s,
            selectedColor: AppColors.navActive,
            onSelected: (_) => setState(() => _stateFilter = s),
          ),
        if (filterField != null) ...[
          const SizedBox(width: 12),
          for (final o in [null, ...filterField.options])
            ChoiceChip(
              label: Text(o?.$2 ?? 'Toutes'),
              selected: _chip == o?.$1,
              selectedColor: AppColors.navActive,
              onSelected: (_) => setState(() => _chip = o?.$1),
            ),
        ],
        SizedBox(
          width: 220,
          child: TextField(
            key: const Key('ref-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'Rechercher', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aucun élément dans cette catégorie.', style: t.bodyMedium),
                if (!readOnly && baseEntries(cat.id).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('ref-base'),
                    onPressed: () async {
                      final by = _actor;
                      if (by != null) await ref.read(rulesRepositoryProvider).importEntries(cat.id, baseEntries(cat.id), by);
                    },
                    child: Text('Charger les valeurs de base (${baseEntries(cat.id).length})'),
                  ),
                ],
              ]),
            )
          else if (shown.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('Aucun élément ne correspond.', style: t.bodyMedium)),
          for (final e in shown)
            InkWell(
              onTap: () => _open(e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: e.id == _selectedId ? AppColors.navActive : null,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 240,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.name, style: t.titleSmall),
                      if (e.vo != null) Text(e.vo!, style: t.bodySmall),
                    ]),
                  ),
                  for (final key in cat.columns)
                    SizedBox(
                      width: 150,
                      child: Text(displayValue(cat.fields.firstWhere((f) => f.key == key), e.data[key]),
                          style: t.bodySmall, overflow: TextOverflow.ellipsis),
                    ),
                  SizedBox(width: 60, child: Text('${usageCount(cat.id, e.name, chars) ?? '—'}', style: t.bodySmall)),
                  _StatePill(e.state),
                ]),
              ),
            ),
        ]),
      ),
    ]);

    Widget? form;
    if (selected != null) {
      final otherNames = {for (final e in entries) if (e.id != selected.id) nameKey(e.name)};
      Widget formWith(String note) => RuleEntryForm(
            key: ValueKey('${cat.id}/${selected.id}/$_formVersion'),
            category: cat,
            entry: _opened ?? selected,
            keyOptions: keyOptions,
            existingNames: otherNames,
            readOnly: readOnly,
            note: note,
            usage: selected.id.isEmpty ? null : usageCount(cat.id, selected.name, chars),
            onSave: (e, n) => _save(cat, e, n, entries, chars),
            onDelete: selected.id.isEmpty ? null : () => _delete(cat, selected, chars),
          );
      form = Panel(
        child: selected.id.isEmpty
            ? formWith('')
            : StreamBuilder<String>(
                key: ValueKey('note-${cat.id}/${selected.id}'),
                stream: ref.read(rulesRepositoryProvider).watchNote(cat.id, selected.id),
                builder: (_, snap) => snap.hasData ? formWith(snap.data!) : const Center(child: CircularProgressIndicator()),
              ),
      );
    }

    if (!isWide(context)) {
      if (form != null) {
        return PageBody(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => setState(() => _selectedId = null), child: const Text('← Retour à la liste')),
          ),
          form,
        ]);
      }
      return PageBody(children: [
        DropdownButtonFormField<String>(
          initialValue: cat.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Catégorie'),
          items: [for (final c in ruleCategories) DropdownMenuItem(value: c.id, child: Text('${c.label} · ${all[c.id]?.length ?? 0}'))],
          onChanged: (id) => context.go('/conteur/referentiel/$id'),
        ),
        const SizedBox(height: 16),
        list,
      ]);
    }
    return PageBody(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 240, child: menu),
        const SizedBox(width: 24),
        Expanded(child: list),
        if (form != null) ...[const SizedBox(width: 24), SizedBox(width: 420, child: form)],
      ]),
    ]);
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill(this.state);
  final RuleState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      RuleState.available => (AppColors.activeBg, AppColors.success),
      RuleState.approval => (AppColors.reviewBg, AppColors.goldLight),
      RuleState.draft => (AppColors.navActive, AppColors.textSecondary),
      RuleState.forbidden => (AppColors.deadBg, AppColors.linkHover),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(state.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Réglages de la catégorie (`rules/{cat}`), repliables.
class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({super.key, required this.category, required this.values, required this.readOnly, required this.onSave});
  final RuleCategory category;
  final Map<String, dynamic> values;
  final bool readOnly;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late final Map<String, dynamic> _v = {
    for (final f in widget.category.settings)
      if (widget.values[f.key] != null) f.key: widget.values[f.key],
  };

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          title: const Text('Paramètres de la catégorie'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final f in widget.category.settings)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RuleFieldEditor(
                  f,
                  _v[f.key],
                  (x) => setState(() {
                    if (x == null) {
                      _v.remove(f.key);
                    } else {
                      _v[f.key] = x;
                    }
                  }),
                  enabled: !widget.readOnly,
                  keyPrefix: 'rs',
                ),
              ),
            if (!widget.readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(onPressed: () => widget.onSave({..._v}), child: const Text('Enregistrer les paramètres')),
              ),
          ],
        ),
      );
}

class _ImportExportDialog extends StatefulWidget {
  const _ImportExportDialog({required this.category, required this.entries, required this.chars, required this.readOnly, required this.onImport});
  final RuleCategory category;
  final List<RuleEntry> entries;
  final List<Character> chars;
  final bool readOnly;
  final Future<void> Function(List<RuleEntry>) onImport;

  @override
  State<_ImportExportDialog> createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends State<_ImportExportDialog> {
  final _text = TextEditingController();
  ImportPreview? _preview;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = widget.category;
    final csv = exportCsv(cat, widget.entries);
    final p = _preview;
    final count = p == null ? 0 : p.news.length + p.updates.length;
    return AlertDialog(
      title: Text('${cat.label} — import et export'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const SectionTitle('Exporter'),
            const SizedBox(height: 6),
            Text('${_plural(widget.entries.length, 'élément', 'éléments')}, séparés par « ; » (ouvrable dans un tableur).', style: t.bodySmall),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
              child: SingleChildScrollView(child: SelectableText(csv, style: t.bodySmall)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('export-copy'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: csv));
                  messenger.showSnackBar(const SnackBar(content: Text('Copié.')));
                },
                child: const Text('Copier'),
              ),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: 12),
              const SectionTitle('Importer'),
              const SizedBox(height: 6),
              Text('Collez un CSV (« ; ») ou des cellules de tableur, avec la ligne d’en-tête. Colonnes : ${columnsOf(cat).join(', ')}.',
                  style: t.bodySmall),
              const SizedBox(height: 6),
              TextField(
                key: const Key('import-text'),
                controller: _text,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'name;state;…'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('import-analyse'),
                  onPressed: () => setState(() => _preview = previewImport(cat, widget.entries, _text.text)),
                  child: const Text('Analyser'),
                ),
              ),
              if (p != null) ...[
                Text(
                  '${_plural(p.news.length, 'nouveau', 'nouveaux')}, ${_plural(p.updates.length, 'modifié', 'modifiés')}, '
                  '${_plural(p.errors.length, 'ligne en erreur', 'lignes en erreur')}',
                  key: const Key('import-summary'),
                  style: t.titleSmall,
                ),
                for (final u in p.updates)
                  if (usageCount(cat.id, u.name, widget.chars) case final n? when n > 0)
                    Text('Modifié : ${u.name} (utilisé par ${_plural(n, 'fiche', 'fiches')})', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
                for (final w in p.warnings) Text(w, style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
                for (final e in p.errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
              ],
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        if (!widget.readOnly && p != null && count > 0)
          FilledButton(
            key: const Key('import-go'),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final nav = Navigator.of(context);
                    await widget.onImport([...p.news, ...p.updates]);
                    nav.pop();
                  },
            child: Text('Importer ${_plural(count, 'élément', 'éléments')}'),
          ),
      ],
    );
  }
}
```

Dans `lib/router.dart` :
- ajouter l'import `rulebook/referential_screen.dart` ;
- remplacer `page('/conteur/referentiel', soon('Référentiel des règles')),` par :

```dart
          page('/conteur/referentiel', const ReferentialScreen()),
          GoRoute(
            path: '/conteur/referentiel/:cat',
            builder: (_, s) => ReferentialScreen(categoryId: s.pathParameters['cat']!),
          ),
```

  Si `page(...)` enveloppe l'écran dans une transition ou un shell, utiliser la même forme pour la route `:cat` (une clé d'écran distincte n'est pas nécessaire : `didUpdateWidget` réinitialise la sélection).

- [ ] **Step 3 : tester, analyser**

Run : `flutter test`, puis `flutter analyze`.

Expected : tous les tests passent, l'analyseur est propre.

- [ ] **Step 4 : commit**

```
git add lib test
git commit -m "feat: écran du référentiel — liste, filtres, édition, réglages, import / export, valeurs de base" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : revue, puis déploiement (avec accord)

- [ ] Revue finale de la branche, corrections Critical et Important avec un test chacune.
- [ ] Avec l'accord de l'utilisateur :
  - depuis `rules_test`, `npm test` ;
  - `firebase deploy --only firestore --project met-mon-vampire` ;
  - `flutter build web --release` ;
  - `firebase deploy --only hosting --project met-mon-vampire` ;
  - puis fusion de `referentiel-a` dans `main`.
