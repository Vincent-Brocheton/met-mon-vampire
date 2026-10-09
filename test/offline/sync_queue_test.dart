import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/offline/sync_queue.dart';

import '../characters/character_test.dart' show sample;
import '../games/game_rules_test.dart' show frozenGame;

void main() {
  // Partie du samedi 3 oct., figée le 29 sept. à 20h.
  final g = frozenGame(sheetIds: const ['x']);
  final sheets = {'x': sample()};
  Sin sin(String id, {DateTime? at, int level = 2, Remorse remorse = Remorse.success, DateTime? day}) =>
      Sin(id: id, date: day ?? DateTime(2026, 10, 3), level: level, remorse: remorse, byUid: 'lea', byName: 'Léa G.', createdAt: at);
  StoryEvent ev(String title, DateTime? at) => StoryEvent(id: title, title: title, year: 2026, byName: 'Marc', createdAt: at);

  test('libellés des lignes', () {
    expect(sinLabel(sin('a')), 'Péché niveau 2 · remords réussi');
    expect(sinLabel(sin('a', remorse: Remorse.failed)), 'Péché niveau 2 · remords échoué');
    expect(sinLabel(sin('a', remorse: Remorse.none)), 'Péché niveau 2 · sans remords');
    expect(eventLabel(ev('Titre obtenu : Gardien de l’Élysée', null)), 'Événement · Titre obtenu : Gardien de l’Élysée');
  });

  test('depuis le gel : en attente, ou créé après le gel', () {
    expect(sinceFreeze(null, g), isTrue);
    expect(sinceFreeze(DateTime(2026, 9, 29, 19), g), isFalse);
    expect(sinceFreeze(DateTime(2026, 9, 29, 20), g), isTrue);
  });

  test('file : péchés du jour, événements depuis le gel, en attente d’abord, puis du plus récent au plus ancien (Review Focus 4)', () {
    final lines = queueLines(
      g,
      sheets,
      {
        'x': [
          (doc: sin('s1', at: DateTime(2026, 10, 3, 22, 41)), pending: false),
          (doc: sin('s2'), pending: true),
          (doc: sin('old', at: DateTime(2026, 9, 20, 22), day: DateTime(2026, 9, 20)), pending: false),
        ],
      },
      {
        'x': [
          (doc: ev('Récent', DateTime(2026, 10, 3, 22, 12)), pending: false),
          (doc: ev('Ancien', DateTime(2026, 9, 1)), pending: false),
          (doc: ev('Ancien modifié', DateTime(2026, 9, 1)), pending: true),
        ],
      },
      const {},
    );
    expect([for (final l in lines) l.label], [
      'Péché niveau 2 · remords réussi',
      'Événement · Ancien modifié',
      'Péché niveau 2 · remords réussi',
      'Événement · Récent',
    ]);
    expect([for (final l in lines) l.state], [QueueState.pending, QueueState.pending, QueueState.sent, QueueState.sent]);
    expect([for (final l in lines) l.path], [
      '/conteur/fiches/x/moralite',
      '/conteur/fiches/x/evenements',
      '/conteur/fiches/x/moralite',
      '/conteur/fiches/x/evenements',
    ]);
    expect(lines.first.sheetName, 'Isaure de Valcourt');
    expect(lines.first.byName, 'Léa G.');
    expect(lines[2].at, DateTime(2026, 10, 3, 22, 41));
    expect(pendingCount(lines), 2);
  });

  test('file : péché en conflit, fiche inconnue', () {
    final lines = queueLines(g, const {}, {
      'x': [(doc: sin('s1', at: DateTime(2026, 10, 3, 22)), pending: false)],
    }, const {}, {'s1'});
    expect(lines.single.state, QueueState.conflict);
    expect(lines.single.sheetName, '—');
    expect(pendingCount(lines), 0);
    expect([for (final s in QueueState.values) s.label], ['En attente', 'Envoyé', 'Conflit']);
  });

  test('textes', () {
    expect(lineHour(null), '—');
    expect(lineHour(DateTime(2026, 10, 3, 22, 47)), '22h47');
    expect(conflictLabel(1), 'conflit');
    expect(conflictLabel(2), 'conflits');
    expect(traitsText(1), '+1 trait de Bête');
    expect(traitsText(2), '+2 traits de Bête');
    expect(sheetCountText(1), '1 fiche');
    expect(sheetCountText(42), '42 fiches');
    final a = Sin(id: 'a', date: DateTime(2026, 10, 3), level: 2, byUid: 'lea', byName: 'Léa G.', createdAt: DateTime(2026, 10, 3, 22, 44));
    final b = Sin(id: 'b', date: DateTime(2026, 10, 3), level: 2, byUid: 'marc', byName: 'Marc');
    expect(conflictText(a, b), 'Léa G. et Marc ont saisi chacun un péché de niveau 2 le 3 oct. S’agit-il du même péché ?');
    expect(conflictHead(a), 'Léa G. · 22h44');
    expect(conflictHead(b), 'Marc · en attente');
    expect(keepText(a), 'Même péché : garder celui de Léa G.');
    expect(wipeConfirmText(pending: false), 'Effacer les données de cet appareil ? Vous restez connecté.');
    expect(wipeConfirmText(pending: true),
        'Effacer les données de cet appareil ? Vous restez connecté. Des saisies n’ont pas encore été envoyées : elles seront perdues.');
  });

  test('ligne d’en-tête', () {
    expect(headerLine(g, null, null), 'Partie du samedi 3 oct.');
    expect(headerLine(g, DateTime(2026, 10, 3, 17, 30), DateTime(2026, 10, 3, 21, 2)),
        'Partie du samedi 3 oct. · préparée sur cet appareil le 3 oct. à 17h30 · dernière synchronisation à 21h02');
  });
}
