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
  const Rulebook([this._entries = const {}, this.creation = const CreationValues(), this.settings = const {}]);

  final Map<String, List<RuleEntry>> _entries;
  final CreationValues creation;

  /// Réglages des catégories (`rules/{cat}`), par exemple le coût par niveau des rituels.
  final Map<String, Map<String, dynamic>> settings;

  static final _base = <String, List<RuleEntry>>{};
  static final _indexes = Expando<Map<String, Map<String, RuleEntry>>>();
  static final _baseRows = {
    for (final e in baseEntries('generations')) GenRank.values.byName(e.data['rank'] as String): GenRow.fromData(e.data, GenRow.zero),
  };

  /// Éléments de la catégorie ; sans aucun élément proposé (vide, ou seulement brouillons et interdits) :
  /// les valeurs de base, pour que les joueurs aient toujours un choix.
  List<RuleEntry> all(String cat) {
    final own = _entries[cat];
    return own != null && own.any((e) => e.state.offered) ? own : _base.putIfAbsent(cat, () => baseEntries(cat));
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

  /// Secte par défaut ; aucune marquée : celle des valeurs de base (sinon un clan rare deviendrait gratuit).
  String? get defaultSect =>
      (all('sects').where((e) => e.data['isDefault'] == true).firstOrNull ??
              baseEntries('sects').where((e) => e.data['isDefault'] == true).firstOrNull)
          ?.name;

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

  /// Coût d'un rituel par niveau (réglage de la catégorie, 2 par défaut).
  int get ritualCostPerLevel => _count(settings['rituals']?['costPerLevel']) ?? 2;

  int ritualLevel(String name) => (_int('rituals', name, 'level') ?? 1).clamp(1, 5);

  String? ritualSchool(String name) => switch (find('rituals', name)?.data['school']) {
        final String s => s,
        _ => null,
      };

  /// Disciplines et voies d'une école : la leur, ou celle de leur discipline mère.
  List<String> schoolDisciplines(String school) {
    String? schoolOf(RuleEntry? e) => switch (e?.data['school']) {
          final String s => s,
          _ => null,
        };
    String? parent(RuleEntry e) => switch (e.data['parent']) {
          final String p => p,
          _ => null,
        };
    return [
      for (final e in all('disciplines'))
        if (schoolOf(e) == school || schoolOf(find('disciplines', parent(e))) == school) e.name,
    ];
  }

  bool hasPrerequisites(String technique) => ((find('techniques', technique)?.data['prerequisites'] as List?) ?? const []).isNotEmpty;

  /// Alternatives de prérequis : chaque ligne « Présence 2 + Auspex 1 » donne une liste (discipline, niveau).
  /// Une ligne illisible est ignorée.
  List<List<(String, int)>> techniquePrerequisites(String technique) {
    final out = <List<(String, int)>>[];
    for (final line in (find('techniques', technique)?.data['prerequisites'] as List?) ?? const []) {
      final parts = <(String, int)>[];
      var readable = true;
      for (final p in '$line'.split('+')) {
        final m = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(p.trim());
        if (m == null) {
          readable = false;
          break;
        }
        parts.add((m.group(1)!.trim(), int.parse(m.group(2)!)));
      }
      if (readable && parts.isNotEmpty) out.add(parts);
    }
    return out;
  }

  String? elderDiscipline(String name) => switch (find('elderPowers', name)?.data['discipline']) {
        final String d => d,
        _ => null,
      };

  int elderCost(String name, {required bool inClan}) =>
      _int('elderPowers', name, inClan ? 'costInClan' : 'costOutOfClan') ?? (inClan ? 18 : 24);

  /// Ligne du rang ; rang absent du référentiel (ou en brouillon, interdit) : valeurs de base.
  GenRow gen(GenRank rank) {
    final base = _baseRows[rank]!;
    final e = all('generations').where((e) => e.state.offered && e.data['rank'] == rank.name).firstOrNull;
    return e == null ? base : GenRow.fromData(e.data, base);
  }
}
