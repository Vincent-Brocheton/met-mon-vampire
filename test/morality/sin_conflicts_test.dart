import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/morality/morality_rules.dart';
import 'package:portail_met/morality/sin.dart';

Sin s(String id, String by, {int level = 2, DateTime? day, DateTime? at, bool locked = false, bool distinct = false}) => Sin(
      id: id,
      date: day ?? DateTime(2026, 10, 3),
      level: level,
      byUid: by,
      byName: by,
      createdAt: at,
      lossApplied: locked,
      distinct: distinct,
    );

void main() {
  test('même jour, même niveau, deux auteurs : un conflit, le plus ancien d’abord', () {
    final c = conflicts([s('a', 'marc', at: DateTime(2026, 10, 3, 22, 47)), s('b', 'lea', at: DateTime(2026, 10, 3, 22, 44))]);
    expect(c, hasLength(1));
    expect(c.single.$1.id, 'b');
    expect(c.single.$2.id, 'a');
  });

  test('même auteur, autre niveau, autre jour : pas de conflit', () {
    expect(conflicts([s('a', 'lea'), s('b', 'lea')]), isEmpty);
    expect(conflicts([s('a', 'lea'), s('b', 'marc', level: 3)]), isEmpty);
    expect(conflicts([s('a', 'lea'), s('b', 'marc', day: DateTime(2026, 10, 4))]), isEmpty);
  });

  test('péché verrouillé, marqué distinct ou sans auteur : pas de conflit', () {
    expect(conflicts([s('a', 'lea', locked: true), s('b', 'marc')]), isEmpty);
    expect(conflicts([s('a', 'lea', distinct: true), s('b', 'marc')]), isEmpty);
    expect(conflicts([s('a', ''), s('b', 'marc')]), isEmpty);
  });

  test('trois péchés : une seule paire, chaque péché une fois', () {
    final c = conflicts([
      s('a', 'lea', at: DateTime(2026, 10, 3, 22)),
      s('b', 'marc', at: DateTime(2026, 10, 3, 22, 5)),
      s('c', 'marc', at: DateTime(2026, 10, 3, 22, 10)),
    ]);
    expect(c, hasLength(1));
    expect(c.single.$1.id, 'a');
    expect(c.single.$2.id, 'b');
  });

  test('péché en attente (sans heure du serveur) : apparié après les péchés envoyés', () {
    final c = conflicts([s('p', 'marc'), s('a', 'lea', at: DateTime(2026, 10, 3, 22))]);
    expect(c.single.$1.id, 'a');
    expect(c.single.$2.id, 'p');
  });

  test('toMap : « distinct » écrit seulement s’il est vrai', () {
    expect(s('a', 'lea').toMap().containsKey('distinct'), isFalse);
    expect((s('a', 'lea')..distinct = true).toMap()['distinct'], isTrue);
  });

  test('fromMap : auteur, création et « distinct » ; copy les garde', () {
    final sin = Sin.fromMap('a', {
      'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'level': 2,
      'byUid': 'lea',
      'byName': 'Léa G.',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 3, 22, 44)),
      'distinct': true,
    });
    expect(sin.byUid, 'lea');
    expect(sin.createdAt, DateTime(2026, 10, 3, 22, 44));
    expect(sin.distinct, isTrue);
    final copy = sin.copy();
    expect(copy.byUid, 'lea');
    expect(copy.createdAt, DateTime(2026, 10, 3, 22, 44));
    expect(copy.distinct, isTrue);
    expect(Sin.fromMap('b', const {}).distinct, isFalse);
  });
}
