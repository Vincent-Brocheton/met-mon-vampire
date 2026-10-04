import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';
import '../characters/describe_changes.dart';

enum RequestStatus {
  draft('Brouillon'),
  pending('En attente'),
  changes('À compléter'),
  accepted('Validée'),
  rejected('Refusée'),
  cancelled('Annulée');

  const RequestStatus(this.label);
  final String label;

  /// Envoyée et pas encore tranchée : son XP est réservée.
  bool get open => this == pending || this == changes;

  /// Le joueur peut encore la modifier.
  bool get editable => this == draft || open;
}

enum XpKind {
  attribute('Attribut'),
  skill('Compétence'),
  background('Historique'),
  discipline('Discipline'),
  merit('Atout'),
  ritual('Rituel'),
  technique('Technique'),
  elderPower('Pouvoir d’ancien'),
  humanity('Humanité'),
  flawBuyback('Rachat d’un handicap'),
  servant('Serviteur');

  const XpKind(this.label);
  final String label;
}

/// Pastilles pour les traits ; chiffre pour attributs, Humanité, atouts et handicaps.
String levelText(XpKind k, int n) => switch (k) {
      XpKind.skill || XpKind.background || XpKind.discipline || XpKind.servant => dots(n),
      XpKind.ritual || XpKind.technique || XpKind.elderPower => n > 0 ? 'appris' : '—',
      _ => '$n',
    };

/// Un achat : un niveau d'un trait (atout : sa valeur ; rachat : la valeur du handicap vers 0).
class XpItem {
  const XpItem(this.kind, this.name, this.fromLevel, this.toLevel, this.cost, {this.note});

  factory XpItem.fromMap(Map<String, dynamic> m) => XpItem(
        XpKind.values.asNameMap()[m['kind']] ?? XpKind.skill,
        m['name'] as String? ?? '',
        (m['fromLevel'] as num?)?.toInt() ?? 0,
        (m['toLevel'] as num?)?.toInt() ?? 0,
        (m['cost'] as num?)?.toInt() ?? 0,
        note: m['note'] as String?,
      );

  final XpKind kind;
  final String name;
  final int fromLevel, toLevel, cost;
  final String? note;

  /// Un nom d'attribut inconnu (demande écrite hors de l'application) reste affiché tel quel.
  String get displayName => kind == XpKind.attribute ? AttrCategory.values.asNameMap()[name]?.label ?? name : name;

  String get label => switch (kind) {
        XpKind.humanity => 'Humanité',
        XpKind.flawBuyback => 'Rachat · $name',
        _ => '${kind.label} · $displayName',
      };

  Map<String, dynamic> toMap() =>
      {'kind': kind.name, 'name': name, 'fromLevel': fromLevel, 'toLevel': toLevel, 'cost': cost, 'note': note};
}

/// Message du fil joueur ↔ conte. La date est en millisecondes (voir nowMs).
class XpMessage {
  const XpMessage(this.byUid, this.byName, this.at, this.text);

  factory XpMessage.fromMap(Map<String, dynamic> m) => XpMessage(
        m['byUid'] as String? ?? '',
        m['byName'] as String? ?? '',
        DateTime.fromMillisecondsSinceEpoch((m['atMs'] as num?)?.toInt() ?? 0),
        m['text'] as String? ?? '',
      );

  final String byUid;
  final String byName;
  final DateTime at;
  final String text;

  Map<String, dynamic> toMap() => {'byUid': byUid, 'byName': byName, 'atMs': at.millisecondsSinceEpoch, 'text': text};
}

class XpRequest {
  XpRequest({
    this.id = '',
    required this.characterId,
    required this.characterName,
    required this.playerUid,
    required this.playerName,
    this.status = RequestStatus.draft,
    List<XpItem>? items,
    this.justification = '',
    List<XpMessage>? thread,
    this.version = 0,
    this.createdAt,
    this.submittedAt,
    this.decidedAt,
    this.decidedByUid,
  })  : items = items ?? [],
        thread = thread ?? [];

  factory XpRequest.forCharacter(Character c) =>
      XpRequest(characterId: c.id, characterName: c.name, playerUid: c.playerUid ?? '', playerName: c.playerName ?? '');

  factory XpRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) => XpRequest.fromMap(d.id, d.data()!);

  factory XpRequest.fromMap(String id, Map<String, dynamic> m) {
    DateTime? date(Object? v) => (v as Timestamp?)?.toDate();
    List<Map<String, dynamic>> maps(Object? v) =>
        [for (final e in (v as List?) ?? const []) Map<String, dynamic>.from(e as Map)];
    return XpRequest(
      id: id,
      characterId: m['characterId'] as String? ?? '',
      characterName: m['characterName'] as String? ?? '',
      playerUid: m['playerUid'] as String? ?? '',
      playerName: m['playerName'] as String? ?? '',
      status: RequestStatus.values.asNameMap()[m['status']] ?? RequestStatus.draft,
      items: maps(m['items']).map(XpItem.fromMap).toList(),
      justification: m['justification'] as String? ?? '',
      thread: maps(m['thread']).map(XpMessage.fromMap).toList(),
      version: (m['version'] as num?)?.toInt() ?? 0,
      createdAt: date(m['createdAt']),
      submittedAt: date(m['submittedAt']),
      decidedAt: date(m['decidedAt']),
      decidedByUid: m['decidedByUid'] as String?,
    );
  }

  final String id;
  final String characterId;
  String characterName;
  final String playerUid;
  String playerName;
  RequestStatus status;
  List<XpItem> items;
  String justification;
  List<XpMessage> thread;
  int version;
  DateTime? createdAt, submittedAt, decidedAt;
  String? decidedByUid;

  int get total => items.fold(0, (s, i) => s + i.cost);

  /// Date affichée : envoi, à défaut création.
  DateTime? get date => submittedAt ?? createdAt;

  /// « Linguistique ●●, Mental 6 · 9 XP » : niveau final de chaque trait.
  String get summary {
    final last = <String, XpItem>{};
    for (final i in items) {
      last['${i.kind.name}/${i.name}'] = i;
    }
    final parts = [
      for (final i in last.values)
        switch (i.kind) {
          XpKind.merit => 'Atout ${i.name}',
          XpKind.flawBuyback => 'Rachat ${i.name}',
          XpKind.humanity => 'Humanité ${i.toLevel}',
          XpKind.attribute => '${i.displayName} ${i.toLevel}',
          _ => '${i.name} ${dots(i.toLevel)}',
        },
    ];
    return '${parts.isEmpty ? 'Demande vide' : parts.join(', ')} · $total XP';
  }

  /// Champs écrits par le joueur. Les dates, la version et la décision viennent du dépôt.
  Map<String, dynamic> toMap() => {
        'characterId': characterId,
        'characterName': characterName,
        'playerUid': playerUid,
        'playerName': playerName,
        'status': status.name,
        'items': [for (final i in items) i.toMap()],
        'total': total,
        'justification': justification,
        'thread': [for (final m in thread) m.toMap()],
      };

  XpRequest clone() => XpRequest.fromMap(id, toMap())
    ..version = version
    ..createdAt = createdAt
    ..submittedAt = submittedAt
    ..decidedAt = decidedAt
    ..decidedByUid = decidedByUid;
}
