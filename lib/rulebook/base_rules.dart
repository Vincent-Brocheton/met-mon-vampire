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
      'allies' => [
          _e('Double expertise', {'effect': 'L’allié couvre un second domaine de la liste.', 'condition': 'Tout niveau'}),
          _e('Contact', {'effect': 'Il donne des informations pendant la partie.', 'condition': 'Tout niveau'}),
          _e('Nocturne', {'effect': 'Il peut agir pendant les parties.', 'condition': 'Tout niveau'}),
          _e('Influent', {'effect': 'Il mène des actions d’influence : Influence 2, 4 ou 5 prend 1, 2 ou 3 spécialisations.', 'condition': '1 à 3 fois'}),
          _e('Expert', {'effect': 'Une action d’un niveau supérieur dans son domaine d’influence.', 'condition': 'Si Influent'}),
          _e('Remplaçable', {'effect': 'Retour en 2 mois au lieu de X mois (X = niveau de l’allié).', 'condition': 'Si Influent'}),
          _e('Ressource', {'effect': 'Double les ressources récupérées par une action d’influence.', 'condition': 'Si Influent'}),
          _e('Sécurité', {'effect': 'Double le niveau nécessaire aux actions d’attaque contre lui.', 'condition': 'Si Influent'}),
        ],
      _ => const [],
    };
