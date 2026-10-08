import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/events/event_rules.dart';
import 'package:portail_met/events/story_event.dart';

import '../characters/character_test.dart' show sample;

StoryEvent ev(String title, {int year = 2026, int? month, int? day, EventVisibility v = EventVisibility.player, DateTime? created, String description = ''}) =>
    StoryEvent(id: '', title: title, description: description, year: year, month: month, day: day, visibility: v, createdAt: created);

void main() {
  test('date selon sa précision', () {
    expect(formatEventDate(ev('a', year: 1974)), '1974');
    expect(formatEventDate(ev('a', month: 9)), 'sept. 2026');
    expect(formatEventDate(ev('a', month: 9, day: 20)), '20 sept. 2026');
  });

  test('chronologie : du plus récent au plus ancien, dates partielles après (Review Focus 2)', () {
    final l = [ev('2026'), ev('sept', month: 9), ev('20 sept', month: 9, day: 20), ev('1974', year: 1974), ev('oct', month: 10)]
      ..sort(compareEvents);
    expect([for (final e in l) e.title], ['oct', '20 sept', 'sept', '2026', '1974']);
  });

  test('égalité de date : le plus récemment créé d’abord, un événement en cours d’écriture en tête', () {
    final l = [ev('ancien', created: DateTime(2026, 1, 1)), ev('récent', created: DateTime(2026, 2, 1)), ev('en cours')]..sort(compareEvents);
    expect([for (final e in l) e.title], ['en cours', 'récent', 'ancien']);
  });

  test('contrôles du formulaire', () {
    expect(eventChecks(ev('Nommée Harpie', month: 3, day: 14)), isEmpty);
    expect(eventChecks(ev(' ')), ['Titre obligatoire']);
    expect(eventChecks(ev('x' * 81)), ['Titre : 80 caractères au plus']);
    expect(eventChecks(ev('a', year: 0)), ['Année invalide']);
    expect(eventChecks(ev('a', month: 13)), ['Mois invalide']);
    expect(eventChecks(ev('a', month: 2, day: 32)), ['Jour invalide']);
    expect(eventChecks(ev('a', day: 5)), ['Jour sans mois']);
    expect(eventChecks(ev('a', description: 'x' * 2001)), ['Description : 2000 caractères au plus']);
  });

  test('visibilité et libellés', () {
    final secret = ev('a', v: EventVisibility.staff);
    expect((visibleTo(secret, staff: true), visibleTo(secret, staff: false)), (true, false));
    expect(visibleTo(ev('a', v: EventVisibility.public), staff: false), isTrue);
    expect([for (final v in EventVisibility.values) visibilityLabel(v, staff: true)], ['Public', 'Joueur et conte', 'Conte seul']);
    expect(visibilityLabel(EventVisibility.player, staff: false), 'Vous et le conte');
    expect(sourceLabel(ev('a')..byName = 'Marc'), 'Saisi par Marc');
    expect(sourceLabel(ev('a')..auto = true), 'Automatique');
  });

  test('événements automatiques : fiche validée, étreinte', () {
    final now = DateTime(2026, 10, 12);
    final v = validatedEvent(sample(), now);
    expect((v.type, v.title, v.description, v.year, v.month, v.day, v.visibility, v.auto),
        (EventType.sheet, 'Fiche validée', 'Entrée en jeu de Isaure de Valcourt.', 2026, 10, 12, EventVisibility.player, true));
    expect(embraceEvent(sample()..sire = 'Octave Marchetti', now).title, 'Étreinte par Octave Marchetti');
    final bare = embraceEvent(sample()..sire = null, now);
    expect((bare.type, bare.title, bare.auto, bare.visibility), (EventType.embrace, 'Étreinte', true, EventVisibility.player));
  });

  test('aller-retour et données écrites : exactement les clés permises par les règles', () {
    final e = ev('Chasse', month: 8, description: 'Au musée.');
    final back = StoryEvent.fromMap('e1', e.toMap());
    expect((back.id, back.type, back.title, back.description, back.year, back.month, back.day, back.visibility, back.auto),
        ('e1', EventType.other, 'Chasse', 'Au musée.', 2026, 8, null, EventVisibility.player, false));
    final d = newEventData(e, 'lea', 'Léa');
    expect(d.keys.toSet(), {'type', 'title', 'description', 'year', 'month', 'day', 'visibility', 'auto', 'byUid', 'byName', 'createdAt', 'updatedAt'});
    expect((d['type'], d['visibility'], d['day'], d['byUid']), ('other', 'player', null, 'lea'));
    expect(EventType.parse('inconnu'), EventType.other);
    expect(StoryEvent.blank(DateTime(2026, 10, 12)).year, 2026);
  });
}
