import '../characters/character.dart';
import '../core/dates.dart';
import 'story_event.dart';

/// « 1974 », « sept. 2026 » ou « 20 sept. 2026 ».
String formatEventDate(StoryEvent e) {
  if (e.month == null) return '${e.year}';
  final m = '${monthAbbr(e.month!)} ${e.year}';
  return e.day == null ? m : '${e.day} $m';
}

/// Chronologie : du plus récent au plus ancien ; une partie absente de la date compte comme la plus petite.
/// À date égale, le plus récemment créé d'abord (un événement pas encore confirmé par le serveur en tête).
int compareEvents(StoryEvent a, StoryEvent b) {
  for (final (x, y) in [(a.year, b.year), (a.month ?? 0, b.month ?? 0), (a.day ?? 0, b.day ?? 0)]) {
    if (x != y) return y.compareTo(x);
  }
  final ca = a.createdAt, cb = b.createdAt;
  if (ca == cb) return 0;
  if (ca == null) return -1;
  if (cb == null) return 1;
  return cb.compareTo(ca);
}

/// Erreurs du formulaire ; les règles Firestore appliquent les mêmes bornes.
List<String> eventChecks(StoryEvent e) => [
      if (e.title.trim().isEmpty) 'Titre obligatoire',
      if (e.title.trim().length > 80) 'Titre : 80 caractères au plus',
      if (e.year < 1 || e.year > 9999) 'Année invalide',
      if (e.month != null && (e.month! < 1 || e.month! > 12)) 'Mois invalide',
      if (e.day != null && (e.day! < 1 || e.day! > 31)) 'Jour invalide',
      if (e.day != null && e.month == null) 'Jour sans mois',
      if (e.description.length > 2000) 'Description : 2000 caractères au plus',
    ];

/// L'équipe voit tout ; le joueur voit `public` et `player`.
bool visibleTo(StoryEvent e, {required bool staff}) => staff || e.visibility != EventVisibility.staff;

String visibilityLabel(EventVisibility v, {required bool staff}) => switch (v) {
      EventVisibility.public => 'Public',
      EventVisibility.player => staff ? 'Joueur et conte' : 'Vous et le conte',
      EventVisibility.staff => 'Conte seul',
    };

String sourceLabel(StoryEvent e) => e.auto ? 'Automatique' : 'Saisi par ${e.byName}';

StoryEvent _auto(EventType type, String title, String description, DateTime now) => StoryEvent(
      id: '',
      type: type,
      title: title,
      description: description,
      year: now.year,
      month: now.month,
      day: now.day,
      visibility: EventVisibility.player,
      auto: true,
    );

/// « Fiche validée », écrit avec la validation de la création.
StoryEvent validatedEvent(Character c, DateTime now) => _auto(EventType.sheet, 'Fiche validée', 'Entrée en jeu de ${c.name}.', now);

/// « Étreinte par `sire` », écrit sur la fiche étreinte.
StoryEvent embraceEvent(Character c, DateTime now) {
  final sire = (c.sire ?? '').trim();
  final title = sire.isEmpty ? 'Étreinte' : 'Étreinte par $sire';
  // Les règles refusent plus de 80 caractères : on tronque plutôt que de bloquer l'étreinte.
  return _auto(EventType.embrace, title.length > 80 ? '${title.substring(0, 79)}…' : title, '', now);
}
