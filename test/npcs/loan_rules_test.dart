import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/npcs/loan_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';

import '../characters/character_test.dart' show sample;

/// PNJ prêté à Camille du 28 sept. au 17 oct. 2026.
NpcLoan octave({String id = 'l1'}) => NpcLoan(
      id: id,
      characterId: 'x',
      characterName: 'Isaure de Valcourt',
      playerUid: 'u1',
      playerName: 'Camille R.',
      from: DateTime(2026, 9, 28),
      until: endOfDay(DateTime(2026, 10, 17)),
      personality: 'Courtois, patient.',
      goals: 'Obtenir le soutien de la Primogène.',
      limits: 'Pas de Domination sur un PJ.',
      version: 1,
      sheetAt: DateTime(2026, 9, 28, 20),
    );

void main() {
  test('dates : saisie JJ/MM/AAAA, fin de journée', () {
    expect(parseDay('17/10/2026'), DateTime(2026, 10, 17));
    expect(parseDay(' 1/2/2026 '), DateTime(2026, 2, 1));
    expect(parseDay('31/02/2026'), isNull);
    expect(parseDay('demain'), isNull);
    expect(endOfDay(DateTime(2026, 10, 17, 8)), DateTime(2026, 10, 17, 23, 59, 59));
    expect(startOfDay(DateTime(2026, 10, 17, 8)), DateTime(2026, 10, 17));
  });

  test('état du prêt et jours restants', () {
    final l = octave();
    expect(loanState(l, DateTime(2026, 9, 27)), LoanState.upcoming);
    expect(loanState(l, DateTime(2026, 10, 17, 23)), LoanState.active);
    expect(loanState(l, DateTime(2026, 10, 18)), LoanState.ended);
    expect(loanState(l.copy()..revokedAt = DateTime(2026, 10, 1), DateTime(2026, 10, 2)), LoanState.revoked);
    expect(daysLeft(l, DateTime(2026, 9, 28, 21)), 19);
    expect(daysLeft(l, DateTime(2026, 10, 17, 1)), 0);
  });

  test('copie résumée : identité, attributs, 7 meilleures compétences, disciplines, sang (Review Focus 4)', () {
    final c = sample()
      ..title = 'Harpie'
      ..story = 'Secret'
      ..merits = [Trait('Chanceux', 2)]
      ..skills = [for (var i = 1; i <= 9; i++) Trait('C$i', i % 5 + 1)]
      ..blood = 12
      ..willpower = 6;
    final s = sheetCopy(c, LoanMode.summary);
    for (final k in ['story', 'merits', 'flaws', 'backgrounds']) {
      expect(s.containsKey(k), isFalse, reason: k);
    }
    expect((s['name'], s['title'], s['blood'], s['willpower']), ('Isaure de Valcourt', 'Harpie', 12, 6));
    expect((s['skills'] as List).length, 7);
    final back = Character.fromMap('x', s);
    expect(back.attributes[AttrCategory.social]!.value, c.attributes[AttrCategory.social]!.value);
    expect(back.disciplines.single.name, 'Auspex');
    expect(sheetCopy(c, LoanMode.full)['story'], 'Secret');
  });

  test('aller-retour et avertissements (Review Focus 5)', () {
    final l = octave();
    expect(NpcLoan.fromMap('l1', l.toMap()).toMap(), l.toMap());
    final now = DateTime(2026, 10, 1);
    final npc = sample()..updatedAt = DateTime(2026, 9, 30);
    final other = octave(id: 'l2')
      ..playerUid = 'u2'
      ..playerName = 'Julien P.';
    expect(loanWarnings(l, loans: [l, other], npc: npc, now: now), [
      'Déjà confié à Julien P. jusqu’au ${formatDayForTest(other.until)}',
      'Copie du ${formatDayForTest(l.sheetAt!)} : mettre à jour',
    ]);
    npc.status = CharacterStatus.dead;
    expect(loanWarnings(l.copy()..sheetAt = null, loans: const [], npc: npc, now: now), ['Le PNJ est une fiche retirée ou morte']);
    final backwards = l.copy()..until = DateTime(2026, 9, 1);
    expect(loanWarnings(backwards, loans: const [], npc: null, now: now), ['La fin précède le début']);
  });
}

String formatDayForTest(DateTime d) => formatLoanDay(d);
