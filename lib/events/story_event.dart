import 'package:cloud_firestore/cloud_firestore.dart';

/// Couleur de pastille d'un type d'événement.
enum EventTone { blood, title, moral, life, plot }

/// Types d'événements (sous-projet 7a) ; le nom est la valeur stockée, contrôlée par les règles.
enum EventType {
  diablerie('Diablerie', EventTone.blood),
  titleGained('Titre obtenu', EventTone.title),
  titleLost('Titre perdu', EventTone.title),
  sectChange('Changement de secte', EventTone.plot),
  pathAdopted('Voie adoptée', EventTone.moral),
  bloodHunt('Chasse de sang', EventTone.plot),
  torpor('Torpeur', EventTone.life),
  awakening('Réveil', EventTone.life),
  finalDeath('Mort ultime', EventTone.life),
  embrace('Étreinte', EventTone.life),
  sheet('Fiche', EventTone.life),
  intrigue('Intrigue', EventTone.plot),
  renown('Renommée', EventTone.plot),
  other('Autre', EventTone.plot);

  const EventType(this.label, this.tone);
  final String label;
  final EventTone tone;

  static EventType parse(String? s) => values.where((t) => t.name == s).firstOrNull ?? other;
}

/// Qui voit l'événement. Pour l'instant, `public` est vu comme `player` (journal public : sous-projet 10).
enum EventVisibility {
  public,
  player,
  staff;

  static EventVisibility parse(String? s) => values.where((v) => v.name == s).firstOrNull ?? staff;
}

/// Événement marquant d'une fiche (`characters/{id}/events/{e}`). Date à précision variable : année, puis mois et jour facultatifs.
class StoryEvent {
  StoryEvent({
    required this.id,
    this.type = EventType.other,
    this.title = '',
    this.description = '',
    required this.year,
    this.month,
    this.day,
    this.visibility = EventVisibility.player,
    this.auto = false,
    this.byName = '',
    this.createdAt,
  });

  /// Nouvel événement saisi par le conte : année en cours, visible par le joueur.
  factory StoryEvent.blank(DateTime now) => StoryEvent(id: '', year: now.year);

  factory StoryEvent.fromMap(String id, Map<String, dynamic> m) => StoryEvent(
        id: id,
        type: EventType.parse(m['type'] as String?),
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        year: (m['year'] as num?)?.toInt() ?? 0,
        month: (m['month'] as num?)?.toInt(),
        day: (m['day'] as num?)?.toInt(),
        visibility: EventVisibility.parse(m['visibility'] as String?),
        auto: m['auto'] == true,
        byName: m['byName'] as String? ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  final String id;
  EventType type;
  String title;
  String description;
  int year;
  int? month;
  int? day;
  EventVisibility visibility;
  bool auto;
  String byName;

  /// Null tant que l'écriture n'est pas confirmée par le serveur.
  final DateTime? createdAt;

  /// Champs écrits à chaque enregistrement (mois et jour toujours présents, null si absents).
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'description': description,
        'year': year,
        'month': month,
        'day': day,
        'visibility': visibility.name,
        'auto': auto,
      };

  StoryEvent copy() => StoryEvent(
        id: id,
        type: type,
        title: title,
        description: description,
        year: year,
        month: month,
        day: day,
        visibility: visibility,
        auto: auto,
        byName: byName,
        createdAt: createdAt,
      );
}

/// Document d'un nouvel événement : exactement les clés permises par les règles.
Map<String, dynamic> newEventData(StoryEvent e, String byUid, String byName) {
  final now = FieldValue.serverTimestamp();
  return {...e.toMap(), 'byUid': byUid, 'byName': byName, 'createdAt': now, 'updatedAt': now};
}
