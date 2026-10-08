import 'package:cloud_firestore/cloud_firestore.dart';

enum CharacterKind {
  pj('PJ'),
  pnj('PNJ');

  const CharacterKind(this.label);
  final String label;
}

enum CharacterStatus {
  draft('Brouillon'),
  review('En validation'),
  active('Active'),
  retired('Retirée'),
  dead('Mort ultime'),
  rejected('Refusée');

  const CharacterStatus(this.label);
  final String label;

  /// Fiche jouée ou close : le conteur la modifie directement, avec motif (C3).
  bool get settled => this == active || this == retired || this == dead;
}

enum AttrCategory {
  physical('Physique'),
  social('Social'),
  mental('Mental');

  const AttrCategory(this.label);
  final String label;
}

enum GenRank {
  neonate('Neonate'),
  ancilla('Ancilla'),
  pretender('Pretender Elder');

  const GenRank(this.label);
  final String label;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
Map<String, dynamic> _map(Object? v) => v == null ? <String, dynamic>{} : Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List?) ?? const []) _map(e)];

/// Maintenant, à la milliseconde : le Web relit les horodatages sans microsecondes,
/// et une date relue puis réécrite doit rester égale (règles « inchangé »).
DateTime nowMs() => DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);

class Attribute {
  Attribute([this.value = 0, this.focus]);

  factory Attribute.fromMap(Map<String, dynamic> m) => Attribute(_int(m['value']), m['focus'] as String?);

  int value;
  String? focus;

  Map<String, dynamic> toMap() => {'value': value, 'focus': focus};
}

/// Compétence (note = domaine), historique (note = précisions), atout ou handicap (level = points).
class Trait {
  Trait(this.name, this.level, {this.note});

  factory Trait.fromMap(Map<String, dynamic> m) =>
      Trait(m['name'] as String? ?? '', _int(m['level']), note: m['note'] as String?);

  String name;
  int level;
  String? note;

  Map<String, dynamic> toMap() => {'name': name, 'level': level, 'note': note};
}

class Discipline {
  Discipline(this.name, this.level, {this.inClan = false, List<String>? powers}) : powers = powers ?? [];

  factory Discipline.fromMap(Map<String, dynamic> m) => Discipline(
        m['name'] as String? ?? '',
        _int(m['level']),
        inClan: m['inClan'] == true,
        powers: [for (final p in (m['powers'] as List?) ?? const []) p as String],
      );

  String name;
  int level;
  bool inClan;
  List<String> powers;

  Map<String, dynamic> toMap() => {'name': name, 'level': level, 'inClan': inClan, 'powers': powers};
}

/// Achat de l'étape 9 de la création (plan B).
class Purchase {
  Purchase(this.kind, this.name, this.toLevel, this.cost);

  factory Purchase.fromMap(Map<String, dynamic> m) =>
      Purchase(m['kind'] as String? ?? '', m['name'] as String? ?? '', _int(m['toLevel']), _int(m['cost']));

  final String kind;
  final String name;
  final int toLevel;
  final int cost;

  Map<String, dynamic> toMap() => {'kind': kind, 'name': name, 'toLevel': toLevel, 'cost': cost};
}

/// Rituel appris ; école et niveau recopiés du référentiel.
class Ritual {
  Ritual(this.name, this.school, this.level);

  factory Ritual.fromMap(Map<String, dynamic> m) => Ritual(m['name'] as String? ?? '', m['school'] as String? ?? '', _int(m['level']));

  final String name;
  final String school;
  final int level;

  Map<String, dynamic> toMap() => {'name': name, 'school': school, 'level': level};
}

/// Pouvoir d'ancien appris, et sa discipline.
class ElderPower {
  ElderPower(this.name, this.discipline);

  factory ElderPower.fromMap(Map<String, dynamic> m) => ElderPower(m['name'] as String? ?? '', m['discipline'] as String? ?? '');

  final String name;
  final String discipline;

  Map<String, dynamic> toMap() => {'name': name, 'discipline': discipline};
}

enum ServantKind {
  human('Goule humaine'),
  animal('Goule animale');

  const ServantKind(this.label);
  final String label;
}

/// Serviteur acheté comme un historique : la partie que l'XP touche. Le détail vit dans `servants/{id}`.
class Servant {
  Servant(this.id, this.name, this.kind, this.rank);

  factory Servant.fromMap(Map<String, dynamic> m) => Servant(
        m['id'] as String? ?? '',
        m['name'] as String? ?? '',
        ServantKind.values.asNameMap()[m['kind']] ?? ServantKind.human,
        _int(m['rank']),
      );

  final String id;
  String name;
  ServantKind kind;
  int rank;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'kind': kind.name, 'rank': rank};
}

/// Ancien historique, converti en serviteur sur les fiches jouées ou closes (sous-projet 6b).
const servantsBackground = 'Serviteurs';

int _servantSeq = 0;

/// Identifiant d'un nouveau serviteur : jamais réutilisé, même après une libération.
String newServantId(String characterId) =>
    '$characterId-s${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_servantSeq++}';

/// Allié de la chronique (sous-projet 6g) : remplace les historiques Influence, Alliés et Contacts.
/// Le suivi d'usage vit dans `allies/{id}`.
class Ally {
  Ally(this.id, this.name, {this.level = 1, this.type = '', this.domain = '', this.influence = 0, List<String>? specialties})
      : specialties = specialties ?? [];

  factory Ally.fromMap(Map<String, dynamic> m) => Ally(
        m['id'] as String? ?? '',
        m['name'] as String? ?? '',
        level: _int(m['level']),
        type: m['type'] as String? ?? '',
        domain: m['domain'] as String? ?? '',
        influence: _int(m['influence']),
        specialties: [for (final s in (m['specialties'] as List?) ?? const []) '$s'],
      );

  final String id;
  String name;
  int level;
  String type;
  String domain;

  /// 0, 2, 4 ou 5.
  int influence;
  List<String> specialties;

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'level': level, 'type': type, 'domain': domain, 'influence': influence, 'specialties': [...specialties]};

  Ally copy() => Ally.fromMap(toMap());
}

/// Anciens historiques que l'allié remplace : le conte les convertit (sous-projet 6g).
const legacyAllyBackgrounds = ['Alliés', 'Influence', 'Contacts'];

int _allySeq = 0;

/// Identifiant d'un nouvel allié : jamais réutilisé.
String newAllyId(String characterId) => '$characterId-a${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_allySeq++}';

/// Discipline du domitor, recopiée sur la fiche de sa goule.
class DomitorDiscipline {
  const DomitorDiscipline(this.name, this.level);

  factory DomitorDiscipline.fromMap(Map<String, dynamic> m) => DomitorDiscipline(m['name'] as String? ?? '', _int(m['level']));

  final String name;
  final int level;

  Map<String, dynamic> toMap() => {'name': name, 'level': level};
}

/// Goule jouée (sous-projet 6c) : copie du domitor, faite par le conte (le joueur ne lit pas sa fiche), et sang.
class GhoulState {
  GhoulState({
    required this.domitorId,
    required this.domitorName,
    this.domitorClan,
    this.domitorLineage,
    List<DomitorDiscipline>? domitorDisciplines,
    this.bond = 0,
    this.vitae = 0,
    this.lastDrink,
  }) : domitorDisciplines = domitorDisciplines ?? [];

  factory GhoulState.fromMap(Map<String, dynamic> m) => GhoulState(
        domitorId: m['domitorId'] as String? ?? '',
        domitorName: m['domitorName'] as String? ?? '',
        domitorClan: m['domitorClan'] as String?,
        domitorLineage: m['domitorLineage'] as String?,
        domitorDisciplines: _maps(m['domitorDisciplines']).map(DomitorDiscipline.fromMap).toList(),
        bond: _int(m['bond']),
        vitae: _int(m['vitae']),
        lastDrink: _date(m['lastDrink']),
      );

  /// Copie du clan et des disciplines du domitor.
  factory GhoulState.of(Character domitor) => GhoulState(
        domitorId: domitor.id,
        domitorName: domitor.name,
        domitorClan: domitor.clan,
        domitorLineage: domitor.lineage,
        // Base p. 296 : seulement les disciplines en clan du domitor, qu'il possède.
        domitorDisciplines: [for (final d in domitor.disciplines) if (d.level > 0 && d.inClan) DomitorDiscipline(d.name, d.level)],
      );

  String domitorId;
  String domitorName;
  String? domitorClan;
  String? domitorLineage;
  List<DomitorDiscipline> domitorDisciplines;
  int bond;
  int vitae;
  DateTime? lastDrink;

  Map<String, dynamic> toMap() => {
        'domitorId': domitorId,
        'domitorName': domitorName,
        'domitorClan': domitorClan,
        'domitorLineage': domitorLineage,
        'domitorDisciplines': [for (final d in domitorDisciplines) d.toMap()],
        'bond': bond,
        'vitae': vitae,
        'lastDrink': _ts(lastDrink),
      };
}

/// Amorce de PJ issue d'une étreinte (sous-projet 6d) : sire, clan et génération imposés.
class EmbraceState {
  const EmbraceState({required this.sireId, required this.sireName, required this.clan, required this.genNumber});

  factory EmbraceState.fromMap(Map<String, dynamic> m) => EmbraceState(
        sireId: m['sireId'] as String? ?? '',
        sireName: m['sireName'] as String? ?? '',
        clan: m['clan'] as String? ?? '',
        genNumber: _int(m['genNumber']),
      );

  final String sireId;
  final String sireName;
  final String clan;
  final int genNumber;

  Map<String, dynamic> toMap() => {'sireId': sireId, 'sireName': sireName, 'clan': clan, 'genNumber': genNumber};
}

/// « Goule de Isaure de Valcourt · clan du domitor : Toreador ».
String ghoulLine(GhoulState g) => 'Goule de ${g.domitorName}${g.domitorClan == null ? '' : ' · clan du domitor : ${g.domitorClan}'}';

/// Clés ajoutées au sous-projet 5 : écrites seulement si non vides ou déjà présentes dans le document lu.
/// Les règles à liste de clés fermée (soumission, bonus, décision) acceptent ainsi les fiches existantes.
const _laterKeys = ['rituals', 'techniques', 'elderPowers', 'attributeBonus', 'servants', 'allies', 'ghoul', 'embrace'];

/// Fiche de personnage. Mutable : l'édition travaille sur un [clone].
class Character {
  Character({
    required this.id,
    required this.name,
    required this.kind,
    this.playerUid,
    this.playerName,
    this.status = CharacterStatus.draft,
  });

  factory Character.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Character.fromMap(d.id, m)
      ..createdAt = _date(m['createdAt'])
      ..updatedAt = _date(m['updatedAt']);
  }

  factory Character.fromMap(String id, Map<String, dynamic> m) {
    final insp = _map(m['inspiration']);
    final gen = _map(m['generation']);
    final ranks = _map(m['attributeRanks']);
    final attrs = _map(m['attributes']);
    final creation = _map(m['creation']);
    AttrCategory? cat(Object? v) => AttrCategory.values.asNameMap()[v];
    return Character(
      id: id,
      name: m['name'] as String? ?? '',
      kind: CharacterKind.values.asNameMap()[m['kind']] ?? CharacterKind.pj,
      playerUid: m['playerUid'] as String?,
      playerName: m['playerName'] as String?,
      status: CharacterStatus.values.asNameMap()[m['status']] ?? CharacterStatus.draft,
    )
      ..concept = m['concept'] as String?
      ..archetype = m['archetype'] as String?
      ..clan = m['clan'] as String?
      ..lineage = m['lineage'] as String?
      ..sect = m['sect'] as String?
      ..sire = m['sire'] as String?
      ..title = m['title'] as String?
      ..story = m['story'] as String?
      ..inspirationBefore = insp['before'] as String?
      ..inspirationEmbrace = insp['embrace'] as String?
      ..inspirationBecame = insp['became'] as String?
      ..genRank = GenRank.values.asNameMap()[gen['rank']]
      ..genNumber = (gen['number'] as num?)?.toInt()
      ..attributeRanks = [cat(ranks['primary']), cat(ranks['secondary']), cat(ranks['tertiary'])]
      ..attributes = {for (final a in AttrCategory.values) a: Attribute.fromMap(_map(attrs[a.name]))}
      ..skills = _maps(m['skills']).map(Trait.fromMap).toList()
      ..backgrounds = _maps(m['backgrounds']).map(Trait.fromMap).toList()
      ..disciplines = _maps(m['disciplines']).map(Discipline.fromMap).toList()
      ..merits = _maps(m['merits']).map(Trait.fromMap).toList()
      ..flaws = _maps(m['flaws']).map(Trait.fromMap).toList()
      ..rituals = _maps(m['rituals']).map(Ritual.fromMap).toList()
      ..techniques = [for (final t in (m['techniques'] as List?) ?? const []) '$t']
      ..elderPowers = _maps(m['elderPowers']).map(ElderPower.fromMap).toList()
      ..servants = _maps(m['servants']).map(Servant.fromMap).toList()
      ..allies = _maps(m['allies']).map(Ally.fromMap).toList()
      ..ghoul = m['ghoul'] is Map ? GhoulState.fromMap(_map(m['ghoul'])) : null
      ..embrace = m['embrace'] is Map ? EmbraceState.fromMap(_map(m['embrace'])) : null
      ..attributeBonus = {for (final a in AttrCategory.values) a: _int(_map(m['attributeBonus'])[a.name])}
      ..storedKeys = {for (final k in _laterKeys) if (m.containsKey(k)) k}
      ..blood = _int(m['blood'])
      ..bloodPerTurn = _int(m['bloodPerTurn'])
      ..willpower = _int(m['willpower'])
      ..humanity = _int(m['humanity'])
      ..health = m['health'] as String? ?? '3 · 3 · 3'
      ..xpInitial = _int(m['xpInitial'])
      ..xpBonus = _int(m['xpBonus'])
      ..xpEarned = _int(m['xpEarned'])
      ..xpSpent = _int(m['xpSpent'])
      ..purchases = _maps(creation['purchases']).map(Purchase.fromMap).toList()
      ..step = (creation['step'] as num?)?.toInt() ?? 1
      ..submittedAt = _date(creation['submittedAt'])
      ..decidedAt = _date(creation['decidedAt'])
      ..decidedByUid = creation['decidedByUid'] as String?
      ..comment = creation['comment'] as String?
      ..version = _int(m['version'])
      ..lastHistoryId = m['lastHistoryId'] as String?
      ..gainedThrough = m['gainedThrough'] as String?
      .._convertServants();
  }

  final String id;
  String name;
  CharacterKind kind;
  String? playerUid;
  String? playerName;
  CharacterStatus status;
  String? concept, archetype, clan, lineage, sect, sire, title, story;
  String? inspirationBefore, inspirationEmbrace, inspirationBecame;
  GenRank? genRank;
  int? genNumber;

  /// Primaire, secondaire, tertiaire.
  List<AttrCategory?> attributeRanks = [null, null, null];
  Map<AttrCategory, Attribute> attributes = {for (final a in AttrCategory.values) a: Attribute()};
  List<Trait> skills = [];
  List<Trait> backgrounds = [];
  List<Discipline> disciplines = [];
  List<Trait> merits = [];
  List<Trait> flaws = [];
  List<Ritual> rituals = [];
  List<String> techniques = [];
  List<ElderPower> elderPowers = [];
  List<Servant> servants = [];
  List<Ally> allies = [];

  /// Fiche de goule jouée (sous-projet 6c) ; null pour un vampire.
  GhoulState? ghoul;

  /// Amorce de PJ issue d'une étreinte (sous-projet 6d) ; null sinon.
  EmbraceState? embrace;

  /// Lue avec l'ancien historique « Serviteurs », converti : la prochaine écriture le note dans l'historique.
  bool legacyServants = false;

  /// Points bonus de Génération placés : le plafond de la catégorie passe à 10 + ce nombre.
  Map<AttrCategory, int> attributeBonus = {for (final a in AttrCategory.values) a: 0};

  /// Clés tardives présentes dans le document lu (voir _laterKeys).
  Set<String> storedKeys = {};
  int blood = 0, bloodPerTurn = 0, willpower = 0, humanity = 0;
  String health = '3 · 3 · 3';
  int xpInitial = 0, xpBonus = 0, xpEarned = 0, xpSpent = 0;
  List<Purchase> purchases = [];
  int step = 1;
  DateTime? submittedAt, decidedAt;
  String? decidedByUid, comment;
  int version = 0;
  String? lastHistoryId;

  /// Dernier mois de gain mensuel versé ('aaaa-mm'). Écrit seulement par le versement (stageEdit, extra) :
  /// hors de toMap, car les règles à liste de clés fermée refuseraient une clé nouvelle sur les fiches existantes.
  String? gainedThrough;
  DateTime? createdAt, updatedAt;

  /// Clan et lignée dont le personnage paie la rareté : ceux du domitor pour une goule (Base p. 296).
  String? get bloodClan => ghoul?.domitorClan ?? clan;
  String? get bloodLineage => ghoul?.domitorLineage ?? lineage;

  /// Fiche de vampire active : sire ou domitor possible.
  bool get isActiveVampire => ghoul == null && status == CharacterStatus.active;

  int get xpAvailable => xpInitial + xpEarned - xpSpent;

  /// Les clés tardives, vides comprises. Pour les écritures qui peuvent tout changer (brouillon du joueur,
  /// édition du conte) : leur copie de travail survit à l'écriture et ignore qu'une clé a été écrite entre-temps.
  Map<String, dynamic> laterKeys() => {
        'rituals': [for (final r in rituals) r.toMap()],
        'techniques': [...techniques],
        'elderPowers': [for (final e in elderPowers) e.toMap()],
        'attributeBonus': {for (final e in attributeBonus.entries) e.key.name: e.value},
        'servants': [for (final s in servants) s.toMap()],
        'allies': [for (final a in allies) a.toMap()],
        if (ghoul != null) 'ghoul': ghoul!.toMap(),
        if (embrace != null) 'embrace': embrace!.toMap(),
      };

  /// Toutes les clés, nulles comprises (les règles comparent les clés modifiées).
  /// Sans createdAt / updatedAt, écrits par le dépôt.
  Map<String, dynamic> toMap() => {
        'name': name,
        'kind': kind.name,
        'playerUid': playerUid,
        'playerName': playerName,
        'status': status.name,
        'concept': concept,
        'archetype': archetype,
        'clan': clan,
        'lineage': lineage,
        'sect': sect,
        'sire': sire,
        'title': title,
        'story': story,
        'inspiration': {'before': inspirationBefore, 'embrace': inspirationEmbrace, 'became': inspirationBecame},
        'generation': {'rank': genRank?.name, 'number': genNumber},
        'attributeRanks': {
          'primary': attributeRanks[0]?.name,
          'secondary': attributeRanks[1]?.name,
          'tertiary': attributeRanks[2]?.name,
        },
        'attributes': {for (final e in attributes.entries) e.key.name: e.value.toMap()},
        'skills': [for (final t in skills) t.toMap()],
        'backgrounds': [for (final t in backgrounds) t.toMap()],
        'disciplines': [for (final d in disciplines) d.toMap()],
        'merits': [for (final t in merits) t.toMap()],
        'flaws': [for (final t in flaws) t.toMap()],
        if (rituals.isNotEmpty || storedKeys.contains('rituals')) 'rituals': [for (final r in rituals) r.toMap()],
        if (techniques.isNotEmpty || storedKeys.contains('techniques')) 'techniques': [...techniques],
        if (elderPowers.isNotEmpty || storedKeys.contains('elderPowers')) 'elderPowers': [for (final e in elderPowers) e.toMap()],
        if (attributeBonus.values.any((v) => v != 0) || storedKeys.contains('attributeBonus'))
          'attributeBonus': {for (final e in attributeBonus.entries) e.key.name: e.value},
        if (servants.isNotEmpty || storedKeys.contains('servants')) 'servants': [for (final s in servants) s.toMap()],
        if (allies.isNotEmpty || storedKeys.contains('allies')) 'allies': [for (final a in allies) a.toMap()],
        if (ghoul != null) 'ghoul': ghoul!.toMap(),
        if (embrace != null) 'embrace': embrace!.toMap(),
        'blood': blood,
        'bloodPerTurn': bloodPerTurn,
        'willpower': willpower,
        'humanity': humanity,
        'health': health,
        'xpInitial': xpInitial,
        'xpBonus': xpBonus,
        'xpEarned': xpEarned,
        'xpSpent': xpSpent,
        'creation': {
          'purchases': [for (final p in purchases) p.toMap()],
          'step': step,
          'submittedAt': _ts(submittedAt),
          'decidedAt': _ts(decidedAt),
          'decidedByUid': decidedByUid,
          'comment': comment,
        },
        'version': version,
        'lastHistoryId': lastHistoryId,
      };

  /// Fiche jouée ou close : l'historique « Serviteurs » devient un serviteur, enregistré à la prochaine écriture.
  void _convertServants() {
    if (!status.settled) return;
    final b = backgrounds.where((t) => t.name == servantsBackground).firstOrNull;
    if (b == null) return;
    backgrounds.remove(b);
    legacyServants = true;
    final note = (b.note ?? '').trim();
    final first = '$id-s1';
    servants.add(Servant(
      servants.any((s) => s.id == first) ? '$id-s${servants.length + 1}' : first,
      note.isEmpty ? 'Serviteur' : (note.length > 80 ? note.substring(0, 80) : note), // nom de la fiche détaillée : 80 au plus
      ServantKind.human,
      b.level.clamp(1, 5),
    ));
  }

  Character clone() => Character.fromMap(id, toMap())
    ..legacyServants = legacyServants
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..gainedThrough = gainedThrough;
}

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.at,
    required this.byName,
    required this.kind,
    required this.summary,
    required this.reason,
    this.xpInitial = 0,
    this.xpEarned = 0,
    this.xpSpent = 0,
  });

  factory HistoryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final x = _map(m['xpDelta']);
    return HistoryEntry(
      id: d.id,
      at: _date(m['at']),
      byName: m['byName'] as String? ?? '',
      kind: m['kind'] as String? ?? 'edit',
      summary: [for (final s in (m['summary'] as List?) ?? const []) s as String],
      reason: m['reason'] as String? ?? '',
      xpInitial: _int(x['initial']),
      xpEarned: _int(x['earned']),
      xpSpent: _int(x['spent']),
    );
  }

  final String id;
  final DateTime? at;
  final String byName;
  final String kind;
  final List<String> summary;
  final String reason;
  final int xpInitial, xpEarned, xpSpent;

  bool get touchesXp => xpInitial != 0 || xpEarned != 0 || xpSpent != 0;
}
