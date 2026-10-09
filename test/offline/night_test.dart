import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/offline/night.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show ghoulState;
import '../games/game_rules_test.dart' show frozenGame;

/// Isaure en partie : 12 de sang, 6 de volonté, santé 3 · 3 · 3.
Character player() => sample()
  ..blood = 12
  ..willpower = 6;

void main() {
  final l = NightLimits.of(player());

  test('maxima : sang, volonté, santé ; goule à 5 de Vitae ; santé illisible à 3', () {
    expect(l.blood, 12);
    expect(l.willpower, 6);
    expect(l.health, [3, 3, 3]);
    expect(l.vitae, isFalse);
    final g = NightLimits.of(player()..ghoul = ghoulState());
    expect(g.blood, 5);
    expect(g.vitae, isTrue);
    expect(NightLimits.of(player()..health = '4 · x').health, [4, 3, 3]);
  });

  test('coche jusqu’à la case, décoche la dernière, reste dans les bornes', () {
    var n = toggle(const Night(), NightTrack.blood, 3, l);
    expect(n.blood, 3);
    n = toggle(n, NightTrack.blood, 3, l);
    expect(n.blood, 2);
    n = toggle(n, NightTrack.blood, 1, l);
    expect(n.blood, 1);
    n = toggle(n, NightTrack.hurt, 2, l);
    expect(n.health, [0, 2, 0]);
    expect(toggle(n, NightTrack.willpower, 9, l).willpower, 6);
  });

  test('version figée corrigée : une valeur au-delà est ramenée au maximum à la prochaine coche (Review Focus 2)', () {
    final small = NightLimits.of(player()..blood = 4);
    final n = toggle(const Night(blood: 10, health: [5, 0, 0]), NightTrack.willpower, 1, small);
    expect(n.blood, 4);
    expect(n.health, [3, 0, 0]);
    expect(n.willpower, 1);
  });

  test('annuler : les cases reviennent, les notes restent (Review Focus 3)', () {
    const before = Night(blood: 2);
    final now = Night(blood: 5, health: const [1, 0, 0], notes: [NightNote('Inès', DateTime(2026, 10, 3, 22))]);
    final back = undoTo(now, before);
    expect(back.blood, 2);
    expect(back.health, [0, 0, 0]);
    expect(back.notes.single.text, 'Inès');
  });

  test('notes : vide refusée, coupée à 500 caractères, 100 au plus', () {
    final at = DateTime(2026, 10, 3, 22, 15);
    expect(addNote(const Night(), '   ', at), isNull);
    expect(addNote(const Night(), ' Inès Morel ', at)!.notes.single.text, 'Inès Morel');
    expect(addNote(const Night(), 'x' * 600, at)!.notes.single.text.length, 500);
    var n = const Night();
    for (var i = 0; i < 101; i++) {
      n = addNote(n, 'note $i', at)!;
    }
    expect(n.notes.length, 100);
    expect(n.notes.first.text, 'note 1');
  });

  test('aller-retour Firestore', () {
    final n = Night(blood: 3, willpower: 1, health: const [2, 0, 0], notes: [NightNote('Inès', DateTime(2026, 10, 3, 22, 15))]);
    final back = Night.fromMap({...n.toMap(), 'at': Timestamp.fromDate(DateTime(2026, 10, 3, 23))});
    expect(back.blood, 3);
    expect(back.willpower, 1);
    expect(back.health, [2, 0, 0]);
    expect(back.notes.single.text, 'Inès');
    expect(back.notes.single.at, DateTime(2026, 10, 3, 22, 15));
    expect(back.at, DateTime(2026, 10, 3, 23));
    expect(Night.fromMap(const {}).health, [0, 0, 0]);
  });

  test('textes', () {
    expect(spentText(3, 12), '3 / 12 · reste 9');
    final g = frozenGame();
    expect(versionLine(g, null), 'Version figée du 29 sept.');
    expect(versionLine(g, DateTime(2026, 10, 3, 18)), 'Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h');
    expect(nightSummary(const Night(blood: 3, willpower: 1, health: [2, 0, 0]), l), 'Sang 3 / 12 · Volonté 1 / 6 · Santé 2 · 0 · 0');
    expect(nightSummary(const Night(), NightLimits.of(player()..ghoul = ghoulState())), 'Vitae 0 / 5 · Volonté 0 / 6 · Santé 0 · 0 · 0');
    expect(firstName('Isaure de Valcourt'), 'Isaure');
    expect(sentText(true), 'Des saisies attendent le réseau.');
    expect(sentText(false), 'Tout est envoyé.');
    expect(noteLine(NightNote('Inès', DateTime(2026, 10, 3, 22, 15))), '22h15 · Inès');
  });
}
