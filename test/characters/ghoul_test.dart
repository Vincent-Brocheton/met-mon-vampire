import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';

import 'character_test.dart' show sample;

GhoulState ghoulState() => GhoulState(
      domitorId: 'x',
      domitorName: 'Isaure de Valcourt',
      domitorClan: 'Toreador',
      domitorDisciplines: [const DomitorDiscipline('Auspex', 3), const DomitorDiscipline('Présence', 2)],
      bond: 1,
      vitae: 4,
      lastDrink: DateTime(2026, 9, 26),
    );

/// Goule en brouillon, joueuse u2.
Character mila() => Character(id: 'g', name: 'Mila Ferreira', kind: CharacterKind.pj, playerUid: 'u2', playerName: 'Inès T.')
  ..ghoul = ghoulState();

void main() {
  test('clé tardive : absente sur un vampire, aller-retour sur une goule (Review Focus 1)', () {
    expect(sample().toMap().containsKey('ghoul'), isFalse);
    expect(sample().laterKeys().containsKey('ghoul'), isFalse);
    final m = mila();
    final back = Character.fromMap('g', m.toMap());
    expect(back.toMap()['ghoul'], m.toMap()['ghoul']);
    expect([for (final d in back.ghoul!.domitorDisciplines) (d.name, d.level)], [('Auspex', 3), ('Présence', 2)]);
    expect(back.clone().ghoul!.vitae, 4);
    expect(m.laterKeys()['ghoul'], m.toMap()['ghoul']);
    expect(ghoulLine(m.ghoul!), 'Goule de Isaure de Valcourt · clan du domitor : Toreador');
  });

  test('copie du domitor', () {
    final g = GhoulState.of(sample());
    expect((g.domitorId, g.domitorName, g.domitorClan), ('x', 'Isaure de Valcourt', 'Toreador'));
    expect([for (final d in g.domitorDisciplines) (d.name, d.level)], [('Auspex', 3)]);
  });

  test('ligne « Goule » : valeurs par défaut, puis celle du référentiel', () {
    const rb = Rulebook();
    final row = rb.ghoulRow();
    expect((row.blood, row.bloodPerTurn, row.techniqueCost, row.eldersAllowed), (10, 1, 0, false));
    expect(row.traitFactor, rb.gen(GenRank.neonate).traitFactor);
    expect(rb.rowFor(mila()).blood, 10);
    expect(rb.rowFor(sample()).blood, rb.gen(GenRank.ancilla).blood);
    final own = Rulebook({
      'generations': [
        RuleEntry(name: 'Goule', data: {'rank': ghoulRank, 'blood': 8, 'bloodPerTurn': 1, 'traitFactor': 2}),
      ],
    });
    expect((own.ghoulRow().blood, own.ghoulRow().traitFactor), (8, 2));
    expect(own.gen(GenRank.ancilla).blood, rb.gen(GenRank.ancilla).blood, reason: 'les autres rangs gardent leurs valeurs de base');
  });

  test('résumé des changements d’une goule', () {
    final a = mila();
    final b = a.clone();
    b.ghoul!
      ..vitae = 5
      ..bond = 2
      ..lastDrink = DateTime(2026, 10, 2)
      ..domitorDisciplines = [const DomitorDiscipline('Auspex', 4)];
    expect(describeChanges(a, b), [
      'Vitae 4 → 5',
      'Lien de sang 1 → 2',
      'Gorgée du ${formatDay(DateTime(2026, 10, 2))}',
      'Disciplines du domitor recopiées',
    ]);
  });
}
