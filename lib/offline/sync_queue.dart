import '../characters/character.dart';
import '../core/dates.dart' show formatDay;
import '../events/story_event.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show hourText, shortDay;
import '../morality/sin.dart';
import 'device.dart' show pendingLossText;

/// Un document suivi avec son état d'envoi (`hasPendingWrites`).
typedef Tracked<T> = ({T doc, bool pending});

enum QueueState {
  pending('En attente'),
  sent('Envoyé'),
  conflict('Conflit');

  const QueueState(this.label);
  final String label;
}

/// Ligne de la file de synchronisation (C-HorsLigne, sous-projet 8d).
class QueueLine {
  const QueueLine({required this.at, required this.byName, required this.label, required this.sheetName, required this.path, required this.state});

  /// Heure du serveur à la création ; null tant qu'elle n'est pas confirmée.
  final DateTime? at;
  final String byName;
  final String label;
  final String sheetName;

  /// Onglet de la fiche où la saisie se fait.
  final String path;
  final QueueState state;
}

const noGameText = 'Aucune partie en cours';
const preparedText = 'Partie préparée sur cet appareil.';
const prepareFailedText = 'Préparation impossible : vérifiez le réseau et réessayez.';
const allSentText = 'Tout est envoyé.';
const syncLaterText = 'Pas de réseau : les saisies partiront dès son retour.';
const emptyQueueText = 'Aucune saisie depuis le gel.';
const cacheNote = 'Ce que vous ouvrez sur cet appareil reste aussi dans son cache.';
const playersNote = 'Les appareils des joueurs ne reçoivent que leurs propres fiches, sans notes ni événements secrets.';
const notPreparedGameText = 'Cette partie n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau.';
const resolveRefusedText = 'Enregistrement refusé : réessayez.';
const canDo = ['Consulter les fiches figées et le référentiel', 'Saisir péchés, événements et gorgées'];
const cannotDo = 'Pas de modification de la fiche, de validation de demande ni d’XP : elles attendent le réseau';

String remorseText(Remorse r) => switch (r) {
      Remorse.success => 'remords réussi',
      Remorse.failed => 'remords échoué',
      Remorse.none => 'sans remords',
    };

String sinLabel(Sin s) => 'Péché niveau ${s.level} · ${remorseText(s.remorse)}';

/// Une gorgée écrit aussi un événement « Lien de sang » : la file la montre par lui.
String eventLabel(StoryEvent e) => 'Événement · ${e.title}';

/// Saisie de la partie : en attente (pas encore d'heure), ou créée depuis le gel.
bool sinceFreeze(DateTime? at, Game g) => at == null || !at.isBefore(g.frozenAt);

/// Péchés du jour de la partie et événements créés depuis le gel (ou modifiés hors ligne), pour les fiches figées.
/// En attente d'abord, puis du plus récent au plus ancien.
List<QueueLine> queueLines(
  Game g,
  Map<String, Character> sheets,
  Map<String, List<Tracked<Sin>>> sins,
  Map<String, List<Tracked<StoryEvent>>> events,
  Set<String> conflictIds,
) {
  final day = dayOf(g.date);
  final lines = <QueueLine>[
    for (final id in g.sheetIds) ...[
      for (final s in sins[id] ?? const <Tracked<Sin>>[])
        if (dayOf(s.doc.date) == day)
          QueueLine(
            at: s.doc.createdAt,
            byName: s.doc.byName,
            label: sinLabel(s.doc),
            sheetName: sheets[id]?.name ?? '—',
            path: '/conteur/fiches/$id/moralite',
            state: conflictIds.contains(s.doc.id)
                ? QueueState.conflict
                : s.pending
                    ? QueueState.pending
                    : QueueState.sent,
          ),
      for (final e in events[id] ?? const <Tracked<StoryEvent>>[])
        if (e.pending || sinceFreeze(e.doc.createdAt, g))
          QueueLine(
            at: e.doc.createdAt,
            byName: e.doc.byName,
            label: eventLabel(e.doc),
            sheetName: sheets[id]?.name ?? '—',
            path: '/conteur/fiches/$id/evenements',
            state: e.pending ? QueueState.pending : QueueState.sent,
          ),
    ],
  ];
  int rank(QueueLine l) => l.state == QueueState.pending ? 0 : 1;
  // Sans heure : la plus récente (2^52 tient dans un entier JavaScript).
  int time(QueueLine l) => l.at?.millisecondsSinceEpoch ?? (1 << 52);
  lines.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : time(b).compareTo(time(a));
  });
  return lines;
}

int pendingCount(List<QueueLine> lines) => lines.where((l) => l.state == QueueState.pending).length;

String lineHour(DateTime? at) => at == null ? '—' : hourText(at);

/// Libellé du compteur des conflits.
String conflictLabel(int n) => n > 1 ? 'conflits' : 'conflit';

/// « Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 21h02 ».
String headerLine(Game g, DateTime? preparedAt, DateTime? lastSync) => [
      'Partie du ${shortDay(g.date)}',
      if (preparedAt != null) 'préparée sur cet appareil le ${formatDay(preparedAt)} à ${hourText(preparedAt)}',
      if (lastSync != null) 'dernière synchronisation à ${hourText(lastSync)}',
    ].join(' · ');

String conflictText(Sin a, Sin b) =>
    '${a.byName} et ${b.byName} ont saisi chacun un péché de niveau ${a.level} le ${formatDay(a.date)} S’agit-il du même péché ?';

String conflictHead(Sin s) => s.createdAt == null ? '${s.byName} · en attente' : '${s.byName} · ${hourText(s.createdAt!)}';

String traitsText(int n) => '+$n ${n > 1 ? 'traits' : 'trait'} de Bête';

String keepText(Sin s) => 'Même péché : garder celui de ${s.byName}';

String sheetCountText(int n) => n > 1 ? '$n fiches' : '$n fiche';

String wipeConfirmText({required bool pending}) =>
    'Effacer les données de cet appareil ? Vous restez connecté.${pending ? ' $pendingLossText' : ''}';
