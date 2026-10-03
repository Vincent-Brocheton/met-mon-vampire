import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/xp/xp_gain.dart';
import 'package:portail_met/xp/xp_settings.dart';

import '../characters/character_test.dart' show sample;

Character pj(String id, DateTime activated, {String? through, CharacterStatus status = CharacterStatus.active, CharacterKind kind = CharacterKind.pj}) =>
    Character(id: id, name: id, kind: kind, status: status)
      ..decidedAt = activated
      ..gainedThrough = through;

const on = XpSettings(monthlyEnabled: true, gainSince: '2026-01');

void main() {
  test('paliers par défaut et cumuls', () {
    expect([for (final a in [1, 36, 37, 72, 73, 96, 97, 98, 99]) gainAt(defaultTiers, a)], [3, 3, 2, 2, 1, 1, 1, 0, 1]);
    expect([for (final y in [1, 3, 6, 8, 10]) gainOver(defaultTiers, y * 12)], [36, 108, 180, 204, 216]);
    expect([tierAt(defaultTiers, 36), tierAt(defaultTiers, 37), tierAt(defaultTiers, 500)], [0, 1, 3]);
  });

  test('activée le 31 : rien ce mois-là, un gain le suivant (Review Focus 2)', () {
    expect(monthlyGain([pj('a', DateTime(2026, 10, 31))], on, DateTime(2026, 10, 31)), isEmpty);
    final d = monthlyGain([pj('a', DateTime(2026, 9, 30))], on, DateTime(2026, 10, 1, 12)).single;
    expect(d.months, ['2026-10']);
    expect((d.xp, d.through, d.tier), (3, '2026-10', 0));
  });

  test('rattrapage, déjà versé, premier mois de versement', () {
    final catchUp = monthlyGain([pj('a', DateTime(2026, 6, 15), through: '2026-07')], on, DateTime(2026, 10, 2)).single;
    expect(catchUp.months, ['2026-08', '2026-09', '2026-10']);
    expect(catchUp.xp, 9);
    const since = XpSettings(monthlyEnabled: true, gainSince: '2026-10');
    final first = monthlyGain([pj('a', DateTime(2026, 6, 15))], since, DateTime(2026, 10, 2)).single;
    expect(first.months, ['2026-10']);
    expect(first.xp, 3);
    expect(monthlyGain([pj('a', DateTime(2026, 6, 15), through: '2026-10')], on, DateTime(2026, 10, 2)), isEmpty);
  });

  test('exclues : gain désactivé, fiche retirée, PNJ, brouillon', () {
    final now = DateTime(2026, 10, 2);
    expect(monthlyGain([pj('a', DateTime(2026, 1, 1))], const XpSettings(gainSince: '2026-01'), now), isEmpty);
    expect(monthlyGain([pj('a', DateTime(2026, 1, 1), status: CharacterStatus.retired)], on, now), isEmpty);
    expect(monthlyGain([pj('a', DateTime(2026, 1, 1), kind: CharacterKind.pnj)], on, now), isEmpty);
    expect(monthlyGain([pj('a', DateTime(2026, 1, 1), status: CharacterStatus.draft)], on, now), isEmpty);
  });

  test('mois sans gain : le versement avance quand même (Review Focus 3)', () {
    const everyOther = XpSettings(monthlyEnabled: true, gainSince: '2026-01', tiers: [XpTier(null, 1, 2)]);
    final d = monthlyGain([pj('a', DateTime(2026, 8, 10), through: '2026-09')], everyOther, DateTime(2026, 10, 5)).single;
    expect(d.months, ['2026-10']);
    expect((d.xp, d.through), (0, '2026-10'));
  });

  test('mois en UTC : le même pour tous les appareils (petits défauts)', () {
    expect(monthKey(DateTime.utc(2026, 10, 31, 23, 30).toLocal()), '2026-10');
  });

  test('palier « tous les 0 mois » écrit hors de l’application : ramené à 1 (petits défauts)', () {
    final s = XpSettings.fromMap({'monthlyEnabled': true, 'gainSince': '2026-01', 'tiers': [{'months': null, 'xp': 2, 'every': 0}]});
    expect(s.tiers.single.every, 1);
    expect(gainAt(s.tiers, 5), 2);
  });

  test('libellés de mois', () {
    expect(monthLabel('2026-10'), 'oct. 2026');
    expect(monthRange(['2026-09', '2026-10']), 'sept.–oct. 2026');
    expect(monthRange(['2026-12', '2027-01']), 'déc. 2026–janv. 2027');
    expect(keyOfIndex(monthIndex('2027-01') - 1), '2026-12');
  });

  test('gainedThrough : lu, cloné, jamais écrit par toMap', () {
    final c = Character.fromMap('x', {...sample().toMap(), 'gainedThrough': '2026-10'});
    expect(c.gainedThrough, '2026-10');
    expect(c.clone().gainedThrough, '2026-10');
    expect(c.toMap().containsKey('gainedThrough'), isFalse);
  });

  test('paramètres : aller-retour, défauts', () {
    expect(XpSettings.fromMap(null).tiers.length, 4);
    const s = XpSettings(monthlyEnabled: true, gainSince: '2026-10', tiers: [XpTier(12, 2, 1), XpTier(null, 1, 3)]);
    expect(XpSettings.fromMap(s.toMap()).toMap(), s.toMap());
  });
}
