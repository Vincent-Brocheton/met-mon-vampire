import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bond_rules.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart' show Actor;
import 'package:portail_met/events/story_event.dart';

final today = DateTime(2026, 9, 27);

Character person(String id, String name, {CharacterKind kind = CharacterKind.pnj, String? player, String? clan}) =>
    Character(id: id, name: name, kind: kind, playerUid: player, status: CharacterStatus.active)..clan = clan;

Character lucie() => person('luc', 'Lucie Arnaud', kind: CharacterKind.pj, player: 'zoe', clan: 'Malkavien');
Character octave() => person('oct', 'Octave Marchetti', clan: 'Ventrue');
Character agathe() => person('aga', 'Sœur Agathe', clan: 'Malkavien');
Character lemaire() => person('lem', 'Dr Lemaire')..ghoul = GhoulState(domitorId: 'luc', domitorName: 'Lucie Arnaud', bond: 3);
Character bastien() => person('bas', 'Bastien Roche', kind: CharacterKind.pj, player: 'kar', clan: 'Brujah');
Character jonas() => person('jon', 'Jonas Ferrand', clan: 'Brujah');
List<Character> cast() => [lucie(), octave(), agathe(), lemaire(), bastien(), jonas()];

/// Lien enregistré : niveau, dernière gorgée, dernier contact (la gorgée par défaut).
Bond link(Character r, Character t, int level, DateTime drink, {DateTime? contact, bool known = true}) => bondBetween(r, t, drink)
  ..level = level
  ..lastContact = contact ?? drink
  ..known = known
  ..stored = true;

Bond octLuc() => link(octave(), lucie(), 2, DateTime(2026, 9, 20));
Bond lucLem() => link(lucie(), lemaire(), 3, DateTime(2026, 9, 1), contact: DateTime(2026, 9, 26));
Bond agaBas() => link(agathe(), bastien(), 1, DateTime(2025, 10, 3));
Bond octJon() => link(octave(), jonas(), 1, DateTime(2026, 7, 11), known: false);

void main() {
  test('mois du calendrier, pastilles', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    expect([bondDots(0), bondDots(2), bondDots(3)], ['○○○', '●●○', '●●●']);
  });

  test('niveau effectif : la veille, rien ; le jour même, changé (Review Focus 4)', () {
    final one = link(octave(), lucie(), 1, DateTime(2026, 9, 20));
    expect(effectiveLevel(one, DateTime(2027, 9, 19)), 1);
    expect(effectiveLevel(one, DateTime(2027, 9, 20)), 0);
    expect(effectiveLevel(octLuc(), DateTime(2027, 3, 19)), 2);
    expect(effectiveLevel(octLuc(), DateTime(2027, 3, 20)), 0);
    expect(effectiveLevel(lucLem(), DateTime(2026, 11, 30)), 3);
    expect(effectiveLevel(lucLem(), DateTime(2026, 12, 1)), 2);
    expect(effectiveLevel(lucLem(), DateTime(2027, 3, 25)), 2);
    expect(effectiveLevel(lucLem(), DateTime(2027, 3, 26)), 0);
    final endOfMonth = link(octave(), lucie(), 3, DateTime(2026, 11, 30));
    expect(nextChange(endOfMonth, today)!.at, DateTime(2027, 2, 28));
    expect(nextChange(link(octave(), lucie(), 0, today), today), isNull);
  });

  test('échéance : phrases, proche à 30 jours', () {
    expect(dueText(lucLem(), today), 'Redescend à ●● le 1er déc.');
    expect(dueText(octLuc(), today), 'S’efface le 20 mars 2027 sans contact');
    expect(dueText(link(octave(), lucie(), 0, today), today), '');
    expect(daysUntil(today, DateTime(2026, 10, 3)), 6);
    expect(dueSoon(agaBas(), today), isTrue);
    expect(dueSoon(octLuc(), today), isFalse);
  });

  test('gorgée : plafonnée, nouveau lien, liens moindres effacés', () {
    expect(drinkOutcome(octLuc(), [octLuc()], today, 3).level, 3);
    expect(drinkOutcome(octLuc(), [octLuc()], today, 3).erased, isEmpty);
    expect(drinkOutcome(bondBetween(octave(), lucie(), today), const [], today, 1).level, 1);
    final agaLuc = link(agathe(), lucie(), 1, DateTime(2026, 9, 1));
    final out = drinkOutcome(octLuc(), [octLuc(), agaLuc], today, 1);
    expect(out.refusal, isNull);
    expect(out.level, 3);
    expect([for (final e in out.erased) '${e.id}:${e.level}'], ['aga_luc:0']);
    expect(drinkOutcome(link(octave(), lucie(), 1, today), [agaLuc], today, 1).erased, isEmpty);
  });

  test('gorgée refusée : lien complet ailleurs ; un lien complet expiré ne bloque pas (Review Focus 2)', () {
    final agaFull = link(agathe(), lucie(), 3, DateTime(2026, 9, 25));
    final out = drinkOutcome(octLuc(), [octLuc(), agaFull], today, 1);
    expect(out.refusal, 'Lucie Arnaud est déjà lié complètement à Sœur Agathe.');
    expect(drinkWrite(octLuc(), [octLuc(), agaFull], today, 1, true), isNull);
    final expired = link(agathe(), lucie(), 3, DateTime(2026, 1, 1));
    expect(effectiveLevel(expired, today), 0);
    expect(drinkOutcome(octLuc(), [octLuc(), expired], today, 1).refusal, isNull);
    expect(drinkOutcome(octLuc(), [octLuc(), expired], today, 1).erased, isEmpty);
  });

  test('dates qui ne reculent pas, contact sans raviver (Review Focus 1)', () {
    final past = drunk(octLuc(), DateTime(2026, 9, 10), 3, true);
    expect(past.lastDrink, DateTime(2026, 9, 20));
    expect(past.lastContact, DateTime(2026, 9, 20));
    expect(drunk(octLuc(), today, 3, false).lastDrink, today);
    expect(drunk(octLuc(), today, 3, false).known, isFalse);
    final gone = link(octave(), lucie(), 1, DateTime(2025, 1, 1));
    expect(contacted(gone, today).level, 0);
    final c = contacted(lucLem(), DateTime(2026, 12, 5));
    expect(c.level, 2);
    expect(c.lastContact, DateTime(2026, 12, 5));
    expect(contacted(lucLem(), DateTime(2026, 9, 10)).lastContact, DateTime(2026, 9, 26));
    // Lien enregistré dont le contact (26 sept.) suit la gorgée (1er sept.) : une gorgée entre les deux n'antidate pas le contact.
    final between = drunk(lucLem(), DateTime(2026, 9, 15), 3, true);
    expect(between.lastDrink, DateTime(2026, 9, 15));
    expect(between.lastContact, DateTime(2026, 9, 26));
  });

  test('lien de niveau 3 dont les deux paliers sont passés : effacé, sans échéance', () {
    final b = lucLem();
    expect(effectiveLevel(b, DateTime(2027, 3, 26)), 0);
    expect(nextChange(b, DateTime(2027, 3, 26)), isNull);
    expect(dueText(b, DateTime(2027, 3, 26)), '');
    expect(dueSoon(b, DateTime(2027, 3, 26)), isFalse);
    expect(activeBonds([b], DateTime(2027, 3, 26)), isEmpty);
  });

  test('écriture d’une gorgée : lien, événement du lié', () {
    final w = drinkWrite(octLuc(), [octLuc()], today, 1, false)!;
    expect(w.after.level, 3);
    expect(w.event.type, EventType.bond);
    expect(w.event.title, 'Boit le sang de Octave Marchetti · ●●●');
    expect(w.event.visibility, EventVisibility.staff);
    expect(w.event.auto, isTrue);
    expect((w.event.year, w.event.month, w.event.day), (2026, 9, 27));
    expect(drinkWrite(octLuc(), [octLuc()], today, 1, true)!.event.visibility, EventVisibility.player);
    expect(EventType.bond.label, 'Lien de sang');
  });

  test('aperçu d’une gorgée', () {
    expect(drinkPreview(octLuc(), [octLuc()], today, 1), [
      'Lien envers Octave Marchetti : ●●○ → ●●●',
      'Lien complet. Les liens moindres de Lucie Arnaud envers d’autres vampires sont effacés : aucun.',
      'Sans nouvelle gorgée, il redescendra à ●● le 27 déc. 2026.',
    ]);
    expect(drinkPreview(bondBetween(octave(), lucie(), today), const [], today, 1), [
      'Lien envers Octave Marchetti : ○○○ → ●○○',
      'Sans contact, il s’effacera le 27 sept. 2027.',
    ]);
    final agaLuc = link(agathe(), lucie(), 2, DateTime(2026, 9, 1));
    expect(drinkPreview(octLuc(), [octLuc(), agaLuc], today, 1)[1],
        'Lien complet. Les liens moindres de Lucie Arnaud envers d’autres vampires sont effacés : Sœur Agathe.');
    final agaFull = link(agathe(), lucie(), 3, DateTime(2026, 9, 25));
    expect(drinkPreview(octLuc(), [agaFull], today, 1), ['Lucie Arnaud est déjà lié complètement à Sœur Agathe.']);
  });

  test('contrôles', () {
    expect(bondChecks(regnantId: null, thrallId: null, day: null), ['Choisissez qui donne son sang', 'Choisissez qui boit', 'Date invalide']);
    expect(bondChecks(regnantId: 'a', thrallId: 'a', day: today), ['Une fiche ne peut pas se lier elle-même']);
    expect(bondChecks(regnantId: 'a', thrallId: 'b', day: today), isEmpty);
    // Revue finale : une gorgée datée du futur gèlerait le lien (les dates ne reculent jamais).
    expect(bondChecks(regnantId: 'a', thrallId: 'b', day: DateTime(2026, 9, 28), today: today), ['Date invalide']);
    expect(bondChecks(regnantId: 'a', thrallId: 'b', day: today, today: today), isEmpty);
  });

  test('gorgée : les liens effacés portent les joueurs actuels des fiches (revue finale)', () {
    final agaLuc = link(agathe(), lucie(), 2, DateTime(2026, 9, 1))..thrallPlayerUid = 'ancien';
    final w = drinkWrite(octLuc(), [octLuc(), agaLuc], today, 1, true)!;
    expect(w.erased.single.thrallPlayerUid, 'ancien');
    final cur = withCurrentPlayers(w, (id) => cast().where((c) => c.id == id).firstOrNull);
    expect(cur.erased.single.thrallPlayerUid, 'zoe');
    expect(cur.erased.single.level, 0);
    expect(withCurrentPlayers(w, (_) => null).erased.single.thrallPlayerUid, 'ancien');
  });

  test('fiches : étiquette, lien recopié, goule', () {
    expect([partyTag(octave()), partyTag(lemaire()), partyTag(person('z', 'Z')), partyTag(lucie())],
        ['PNJ · Ventrue', 'Goule · PNJ', 'PNJ', 'PJ · Malkavien']);
    final b = bondBetween(lucie(), lemaire(), today);
    expect((b.id, b.ghoul, b.level, b.stored, b.regnantPlayerUid, b.thrallPlayerUid), ('luc_lem', true, 0, false, 'zoe', null));
    expect(bondBetween(octave(), lucie(), today).ghoul, isFalse);
    final r = refreshed(octLuc(), octave()..name = 'Octave M.', lucie());
    expect((r.regnantName, r.level, r.stored), ('Octave M.', 2, true));
  });

  test('goule à dater', () {
    expect(ghoulBondToDate(lemaire(), const []), 3);
    expect(ghoulBondToDate(lemaire(), [lucLem()]), 0);
    expect(ghoulBondToDate(lucie(), const []), 0);
    final d = datedGhoulBond(lemaire(), lucie(), today);
    expect((d.id, d.level, d.known, d.regnantKnows, d.ghoul), ('luc_lem', 3, true, true, true));
    expect(d.lastDrink, today);
  });

  test('liste de la chronique : actifs triés, filtres, compteurs', () {
    final gone = link(octave(), lucie(), 1, DateTime(2025, 1, 1));
    final active = activeBonds([octJon(), octLuc(), agaBas(), lucLem(), gone], today);
    expect([for (final b in active) b.id], ['aga_bas', 'luc_lem', 'oct_luc', 'oct_jon']);
    expect([for (final b in active) if (bondMatches(b, BondFilter.full, '', today)) b.id], ['luc_lem']);
    expect([for (final b in active) if (bondMatches(b, BondFilter.soon, '', today)) b.id], ['aga_bas']);
    expect([for (final b in active) if (bondMatches(b, BondFilter.unknown, '', today)) b.id], ['oct_jon']);
    expect([for (final b in active) if (bondMatches(b, BondFilter.pjThrall, '', today)) b.id], ['aga_bas', 'oct_luc']);
    expect([for (final b in active) if (bondMatches(b, BondFilter.all, ' JONAS ', today)) b.id], ['oct_jon']);
    expect(bondStats(active, today), (active: 4, full: 1, soon: 1, unknown: 1));
  });

  test('liste de la chronique : à échéance égale, départage par identifiant du lien', () {
    final d = DateTime(2026, 9, 20);
    final oct = link(octave(), lucie(), 1, d);
    final aga = link(agathe(), lucie(), 1, d);
    expect([for (final b in activeBonds([oct, aga], today)) b.id], ['aga_luc', 'oct_luc']);
    expect([for (final b in activeBonds([aga, oct], today)) b.id], ['aga_luc', 'oct_luc']);
  });

  test('lignes du conte et du joueur', () {
    expect(staffLine(octLuc(), today), 'Dernière gorgée le 20 sept. · S’efface le 20 mars 2027 sans contact');
    expect(staffLine(lucLem(), today), 'Dernière gorgée le 1er sept. · Redescend à ●● le 1er déc.');
    expect(sufferedLine(octLuc(), today), '2 gorgées · dernière le 20 sept.');
    expect(sufferedLine(agaBas(), today), 'Une gorgée · dernière le 3 oct. 2025');
    expect(sufferedLine(lucLem(), today), 'Lien complet · dernière le 1er sept.');
    expect([sufferedDelay(agaBas(), today), sufferedDelay(octLuc(), today), sufferedDelay(lucLem(), today)], [
      'Disparaît après un an sans le voir ni lui parler.',
      'Disparaît après six mois sans le voir ni lui parler.',
      'Redescend après trois mois sans boire son sang.',
    ]);
    expect(exertedLine(lucLem(), today), 'Dernière gorgée le 1er sept. · à renforcer avant le 1er déc.');
    expect(exertedLine(octJon(), today), 'Dernière gorgée le 11 juil. · s’efface le 11 juil. 2027 sans contact');
  });

  test('document : aller-retour, clés permises, création seulement à la première écriture', () {
    final back = Bond.fromMap(octLuc().toMap());
    expect((back.id, back.level, back.known, back.stored, back.thrallPlayerUid), ('oct_luc', 2, true, true, 'zoe'));
    expect(back.lastDrink, DateTime(2026, 9, 20));
    const by = Actor('lea', 'Léa G.');
    expect(bondData(bondBetween(octave(), lucie(), today), by).keys.toSet(), {
      'regnantId', 'regnantName', 'regnantPlayerUid', 'thrallId', 'thrallName', 'thrallPlayerUid', 'ghoul', 'level',
      'lastDrink', 'lastContact', 'known', 'regnantKnows', 'byUid', 'byName', 'updatedAt', 'createdAt',
    });
    expect(bondData(octLuc(), by).containsKey('createdAt'), isFalse);
  });
}
