import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/print/print_sheet.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show ghoulState;
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;

/// Fiche complète : Isaure de Valcourt, Harpie, avec allié et goule.
Character full() => sample()
  ..archetype = 'Architecte'
  ..title = 'Harpie'
  ..blood = 12
  ..bloodPerTurn = 2
  ..willpower = 6
  ..humanity = 5
  ..concept = 'Cantatrice lyrique devenue faiseuse de réputations.'
  ..story = 'Soprano admirée de l’opéra municipal.'
  ..allies = [Ally('a1', 'Maëlle Garnier', level: 1, type: 'Critique', domain: 'Média')]
  ..servants = [Servant('s1', 'Mila Ferreira', ServantKind.human, 2)];

final _now = DateTime(2026, 10, 17, 15);

PrintSheet printed({
  Character? c,
  PrintVersion version = PrintVersion.current,
  bool frozen = false,
  List<Item> items = const [],
  List<Place> places = const [],
  List<Bond> bonds = const [],
  int reserved = 0,
  String chronicle = 'Nuits de Lyon',
}) =>
    printSheet(
      c ?? full(),
      version: version,
      game: frozen ? frozenGame() : null,
      now: _now,
      rb: rbTitles,
      items: items,
      places: places,
      bonds: bonds,
      reserved: reserved,
      chronicle: chronicle,
    );

Bond bond({required String regnant, required String thrall, String regnantName = '', String thrallName = '', int level = 1, bool known = true, bool regnantKnows = true}) => Bond(
      regnantId: regnant,
      regnantName: regnantName,
      thrallId: thrall,
      thrallName: thrallName,
      level: level,
      lastDrink: DateTime(2026, 8, 2),
      lastContact: DateTime(2026, 8, 2),
      known: known,
      regnantKnows: regnantKnows,
    );

void main() {
  test('en-tête, cartouche, rappel, fichier et pied de page : version figée', () {
    final s = printed(version: PrintVersion.frozen, frozen: true);
    expect(s.name, 'Isaure de Valcourt');
    expect(s.identity, 'Toreador · Camarilla · Ancilla, 10e génération · Architecte');
    expect(s.people, 'Joueur : Camille R. · Titre : Harpie · Sire : inconnu');
    expect(s.stamp, ['Version figée', 'Partie du samedi 3 oct. 2026', 'Figée le 29 sept. à 20h']);
    expect(s.reminder, 'Version figée · partie du samedi 3 oct. 2026');
    expect(s.fileName, 'Isaure de Valcourt – partie du 2026-10-03.pdf');
    expect(s.footer, 'Isaure de Valcourt · Camille R. · Nuits de Lyon');
  });

  test('version actuelle pendant un gel : non valable en jeu', () {
    final s = printed(frozen: true);
    expect(s.stamp, ['Version actuelle', 'Non valable en jeu']);
    expect(s.reminder, 'Version actuelle · non valable en jeu');
    expect(s.fileName, 'Isaure de Valcourt – 2026-10-17.pdf');
  });

  test('hors gel, ou version figée demandée sans gel : version du jour (Review Focus 3)', () {
    for (final s in [printed(), printed(version: PrintVersion.frozen)]) {
      expect(s.stamp, ['Version du 17 oct. 2026']);
      expect(s.reminder, 'Version du 17 oct. 2026');
      expect(s.fileName, 'Isaure de Valcourt – 2026-10-17.pdf');
    }
  });

  test('titre caché au joueur : absent, même pour le conte (Review Focus 1)', () {
    final s = printed(c: full()..title = 'Main du Prince');
    expect(s.people, 'Joueur : Camille R. · Titre : aucun · Sire : inconnu');
    expect(s.morality.last.label, 'Titre');
    expect(s.morality.last.value, 'Aucun');
  });

  test('attributs, compétences, disciplines, atouts et handicaps', () {
    final s = printed();
    expect([for (final a in s.attributes) a.name], ['Physique', 'Social', 'Mental']);
    expect(s.attributes[1].value, 7);
    expect(s.attributes[1].focus, 'Charisme');
    expect(s.attributes[0].focus, '—');
    expect(s.skills.single.label, 'Représentation');
    expect(s.skills.single.detail, 'chant lyrique');
    expect(s.skills.single.dots, 4);
    final d = s.disciplines.single;
    expect(d.label, 'Auspex');
    expect(d.detail, 'Sens exacerbés');
    expect(d.dots, 3);
    expect(d.value, 'en clan');
    expect(s.meritsTitle, 'Atouts · 1');
    expect(s.flawsTitle, 'Handicaps · 2');
    expect(s.flaws.single.label, 'Curiosité');
    expect(s.flaws.single.value, '2');
  });

  test('à cocher en jeu : sang, volonté, santé, moralité, traits', () {
    final s = printed();
    expect([for (final g in s.gauges) g.label], [
      'Sang · 12',
      'Volonté · 6',
      'Santé',
      'Humanité · 5 Normale',
      'Traits de Bête ce soir',
      'Traits de dérangement',
    ]);
    expect(s.gauges[0].boxes, 12);
    expect(s.gauges[0].note, '2 par tour');
    expect(s.gauges[1].boxes, 6);
    expect(s.gauges[2].groups, [('Sain', 3), ('Blessé', 3), ('Incapacité', 3)]);
    expect(s.gauges[3].boxes, 6);
    expect(s.gauges[3].filled, 5);
    expect(s.gauges[3].round, isTrue);
    expect(s.gauges[4].boxes, 5);
    expect(s.gauges[4].note, 'à 5, perte d’un point');
    expect(s.gauges[5].boxes, 3);
  });

  test('santé : lue dans le champ, 3 par défaut', () {
    expect(healthGroups('2 · 4'), [('Sain', 2), ('Blessé', 4), ('Incapacité', 3)]);
    expect(healthGroups('n’importe quoi'), [('Sain', 3), ('Blessé', 3), ('Incapacité', 3)]);
  });

  test('fiche de goule : domitor dans l’en-tête, vitae au lieu du sang', () {
    final s = printed(c: full()..ghoul = ghoulState());
    expect(s.identity, contains('Goule de '));
    expect(s.identity, isNot(contains('génération')));
    expect(s.gauges.first.label, 'Vitae');
    expect(s.gauges.first.boxes, 5);
  });

  test('historiques, alliés, serviteurs', () {
    final s = printed();
    expect([for (final r in s.backgrounds) r.label], ['Ressources', 'Allié · Maëlle Garnier', 'Goule humaine · Mila Ferreira']);
    expect(s.backgrounds[0].detail, '4 500 € par mois');
    expect(s.backgrounds[0].dots, 3);
    expect(s.backgrounds[1].detail, 'Critique · Média');
    expect(s.backgrounds[2].dots, 2);
  });

  test('moralité, dérangements', () {
    final s = printed(c: full()..derangements = [Derangement('d1', 'Paranoïa')]);
    expect(s.morality[0].label, 'Humanité');
    expect(s.morality[0].value, '5 · Normale');
    expect(s.morality[1].value, 'Paranoïa');
    expect(s.morality[2].value, 'Harpie');
  });

  test('liens de sang : seulement ceux connus du joueur (Review Focus 2)', () {
    final s = printed(bonds: [
      bond(regnant: 'oct', regnantName: 'Octave Marchetti', thrall: 'x', level: 1),
      bond(regnant: 'cel', regnantName: 'Céleste', thrall: 'x', level: 2, known: false),
      bond(regnant: 'x', thrall: 'mil', thrallName: 'Mila Ferreira', level: 3),
      bond(regnant: 'x', thrall: 'jon', thrallName: 'Jonas', level: 1, regnantKnows: false),
      bond(regnant: 'pau', regnantName: 'Paul', thrall: 'x', level: 0),
    ]);
    expect([for (final r in s.bonds) r.label], ['Envers Octave Marchetti', 'Mila Ferreira, lié à vous']);
    expect(s.bonds[0].dots, 1);
    expect(s.bonds[0].dotsMax, 3);
    expect(s.bonds[1].dots, 3);
  });

  test('équipement et lieux', () {
    final s = printed(
      items: [Item(name: 'Canne-épée', qualities: ['Dissimulable', 'Antique'])],
      places: [Place(name: 'Le salon de l’Opéra', rank: 2, qualities: [PlaceQuality('Luxe'), PlaceQuality('Salle', 2)])],
    );
    expect(s.items.single.label, 'Canne-épée');
    expect(s.items.single.detail, 'Dissimulable, Antique');
    expect(s.places.single.label, 'Le salon de l’Opéra');
    expect(s.places.single.detail, 'Standard, Luxe, Salle ×2');
    expect(s.places.single.dots, 2);
  });

  test('expérience, avec ou sans XP réservée', () {
    expect(printed().xp, [('Initiale', '33'), ('Gagnée', '33'), ('Dépensée', '46'), ('Disponible', '20')]);
    expect(printed(reserved: 12).xp.last, ('Disponible', '20 · dont 12 réservés'));
  });

  test('concept, récit, pied de page sans nom de chronique', () {
    final s = printed(chronicle: '');
    expect(s.concept, 'Cantatrice lyrique devenue faiseuse de réputations.');
    expect(s.story, 'Soprano admirée de l’opéra municipal.');
    expect(s.footer, 'Isaure de Valcourt · Camille R.');
  });

  test('blocs vides : « Aucun »', () {
    final s = printed(c: Character(id: 'e', name: 'Vide', kind: CharacterKind.pj, status: CharacterStatus.active));
    for (final rows in [s.skills, s.disciplines, s.merits, s.flaws, s.backgrounds, s.bonds, s.items, s.places]) {
      expect(rows.single.label, 'Aucun');
    }
    expect(s.morality[1].value, 'Aucun');
    expect(s.people, 'Joueur : PNJ · Titre : aucun · Sire : inconnu');
    expect(s.identity, '');
  });
}
