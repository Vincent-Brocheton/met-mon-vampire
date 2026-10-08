import '../characters/character.dart';
import '../events/story_event.dart';
import '../npcs/loan_rules.dart' show formatLoanDay;
import '../rulebook/rulebook.dart';
import 'sin.dart';

/// Catégorie du référentiel : voies d'illumination (maximum, hiérarchie des péchés).
const pathsCat = 'paths';

const humanityLabel = 'Humanité';

/// Échelle de moralité, niveaux 1 à 6.
const moralityScale = ['Horrible', 'Bestiale', 'Insensible', 'Distante', 'Normale', 'Sainte'];

/// Hiérarchie des péchés de l'Humanité, et d'une voie qui n'en a pas.
const defaultSinLevels = ['Blesser gravement autrui', 'Séquelles durables', 'Tuer', 'Meurtres multiples', 'Actes odieux, diablerie'];

/// Traits de Bête d'une soirée qui font perdre un point.
const lossThreshold = 5;

String moralityName(Character c) => (c.path ?? '').trim().isEmpty ? humanityLabel : c.path!.trim();

/// Maximum de la voie : 6 pour l'Humanité, `maxMorality` sinon (6 si vide ou voie inconnue).
int pathMax(Rulebook rb, String? path) {
  if ((path ?? '').trim().isEmpty) return 6;
  final m = rb.find(pathsCat, path)?.data['maxMorality'];
  return m is num && m >= 1 ? m.toInt() : 6;
}

int moralityMax(Character c, Rulebook rb) => pathMax(rb, c.path);

String moralityLabel(int n) => n <= 0 ? 'Wassail' : moralityScale[n.clamp(1, moralityScale.length) - 1];

/// Hiérarchie des péchés de la voie (10 niveaux au plus), ou celle par défaut.
List<String> sinLevels(Character c, Rulebook rb) {
  if ((c.path ?? '').trim().isEmpty) return defaultSinLevels;
  final own = [
    for (final x in (rb.find(pathsCat, c.path)?.data['sins'] as List?) ?? const [])
      if ('$x'.trim().isNotEmpty) '$x'.trim(),
  ];
  return own.isEmpty ? defaultSinLevels : own.take(10).toList();
}

/// Traits de Bête d'un péché : son niveau, moins 1 si le remords est réussi, jamais négatif.
int sinTraits(Sin s) => (s.level - (s.remorse == Remorse.success ? 1 : 0)).clamp(0, 99);

int eveningTraits(Iterable<Sin> sins) => sins.fold(0, (t, s) => t + sinTraits(s));

/// Soirées, de la plus récente à la plus ancienne, avec leurs péchés dans l'ordre reçu.
List<(DateTime, List<Sin>)> eveningsOf(List<Sin> sins) {
  final by = <DateTime, List<Sin>>{};
  for (final s in sins) {
    (by[dayOf(s.date)] ??= []).add(s);
  }
  final days = by.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final d in days) (d, by[d]!)];
}

/// La soirée atteint le seuil et sa perte n'est pas encore appliquée (une seule perte par soirée).
bool lossDue(List<Sin> evening) => eveningTraits(evening) >= lossThreshold && !evening.any((s) => s.lossApplied);

/// La fiche après le changement de voie ; la valeur est ramenée au maximum de la nouvelle voie.
Character changePath(Character c, Rulebook rb, String? path) {
  final p = (path ?? '').trim();
  final n = c.clone()..path = p.isEmpty ? null : p;
  n.humanity = n.humanity.clamp(0, pathMax(rb, n.path));
  return n;
}

/// La fiche après la perte d'un point, jamais sous 0.
Character loseOne(Character c) => c.clone()..humanity = c.humanity > 0 ? c.humanity - 1 : 0;

List<String> sinChecks(Sin s, Character c, Rulebook rb) {
  final n = sinLevels(c, rb).length;
  return [
    if (s.level < 1 || s.level > n) 'Niveau de 1 à $n',
    if (s.what.length > 500) 'Ce qui s’est passé : 500 caractères au plus',
    if (s.date.year < 1900 || s.date.year > 9999) 'Date invalide',
  ];
}

String _of(String name) => RegExp(r'^[aeiouyhAEIOUYHÉÈÊÀÂÎÔÛéèêàâîôû]').hasMatch(name) ? 'd’$name' : 'de $name';

String _clamp80(String t) => t.length <= 80 ? t : '${t.substring(0, 79)}…';

StoryEvent _auto(EventType type, String title, DateTime d) => StoryEvent(
      id: '',
      type: type,
      title: _clamp80(title),
      year: d.year,
      month: d.month,
      day: d.day,
      visibility: EventVisibility.player,
      auto: true,
    );

/// « Voie adoptée », écrit avec le changement de voie.
StoryEvent pathEvent(Character after, DateTime now) =>
    _auto(EventType.pathAdopted, after.path == null ? 'Revient à l’Humanité' : 'Adopte ${after.path}', now);

/// « Moralité », écrit avec la perte, daté de la soirée.
StoryEvent lossEvent(Character before, Character after, DateTime evening) => _auto(
      EventType.morality,
      '${moralityName(after)} ${before.humanity} → ${after.humanity}, ${moralityLabel(after.humanity)}',
      evening,
    )..description = 'Traits de Bête de la soirée.';

String lossMessage(Character c, List<Sin> evening) {
  final to = c.humanity > 0 ? c.humanity - 1 : 0;
  return '${eveningTraits(evening)} traits de Bête atteints : ${c.name} perd un point ${_of(moralityName(c))} '
      '(${c.humanity} → $to, ${moralityLabel(to)}).';
}

/// Motif de la modification tracée de la fiche.
String lossReason(DateTime evening) => 'Traits de Bête : soirée du ${formatLoanDay(evening)}';
