import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_filter.dart';
import 'package:portail_met/characters/describe_changes.dart';

Character base() => Character(
      id: 'x',
      name: 'Isaure',
      kind: CharacterKind.pj,
      playerName: 'Camille R.',
      status: CharacterStatus.active,
    )
      ..humanity = 5
      ..skills = [Trait('Mêlée', 1), Trait('Empathie', 2)]
      ..disciplines = [Discipline('Présence', 2, inClan: true)]
      ..merits = [Trait('Chanceux', 2)];

void main() {
  test('aucun changement', () => expect(describeChanges(base(), base()), isEmpty));

  test('points', () {
    final after = base()..disciplines.first.level = 3;
    expect(describeChanges(base(), after), ['Présence ●● → ●●●']);
  });

  test('ajout et retrait', () {
    final after = base()
      ..skills.removeWhere((s) => s.name == 'Mêlée')
      ..skills.add(Trait('Vigilance', 1));
    expect(describeChanges(base(), after), containsAll(['+ Vigilance ●', '− Mêlée ●']));
  });

  test('valeur chiffrée, statut, joueur, XP, texte, atout', () {
    final after = base()
      ..humanity = 4
      ..status = CharacterStatus.dead
      ..playerName = 'Paul V.'
      ..xpEarned = 33
      ..sire = 'Octave'
      ..merits.first.level = 1;
    expect(
      describeChanges(base(), after),
      containsAll([
        'Humanité 5 → 4',
        'Statut : Active → Mort ultime',
        'Joueur : Camille R. → Paul V.',
        'XP gagnée 0 → 33',
        'Sire : (vide) → Octave',
        'Atout Chanceux : 2 → 1',
      ]),
    );
  });

  test('xpDelta', () {
    final after = base()
      ..xpEarned = 3
      ..xpSpent = 6;
    expect(xpDelta(base(), after), {'initial': 0, 'earned': 3, 'spent': 6});
  });

  group('filterCharacters', () {
    final list = [
      Character(id: '1', name: 'Isaure', kind: CharacterKind.pj, playerName: 'Camille R.', status: CharacterStatus.active)
        ..clan = 'Toreador'
        ..sect = 'Camarilla',
      Character(id: '2', name: 'Élie Marceau', kind: CharacterKind.pj, playerName: 'Julien P.'),
      Character(id: '3', name: 'Armand', kind: CharacterKind.pj, status: CharacterStatus.dead),
      Character(id: '4', name: 'Sœur Agathe', kind: CharacterKind.pnj, status: CharacterStatus.active)..sect = 'Camarilla',
    ];
    List<String> ids(CharacterFilter f) => filterCharacters(list, f).map((c) => c.id).toList();

    test('par défaut : sans les fiches mortes ou retirées', () => expect(ids(const CharacterFilter()), ['1', '2', '4']));
    test('recherche sans accents ni casse, nom ou joueur', () {
      expect(ids(const CharacterFilter(query: 'ELIE')), ['2']);
      expect(ids(const CharacterFilter(query: 'camille')), ['1']);
      expect(ids(const CharacterFilter(query: 'soeur')), ['4']);
    });
    test('type, statut, secte', () {
      expect(ids(const CharacterFilter(kinds: {CharacterKind.pnj})), ['4']);
      expect(ids(const CharacterFilter(statuses: {CharacterStatus.dead})), ['3']);
      expect(ids(const CharacterFilter(sect: 'Camarilla')), ['1', '4']);
    });
  });
}
