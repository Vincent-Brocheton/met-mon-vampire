import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/wiki/wiki_personal.dart';
import 'package:portail_met/wiki/wiki_rules.dart';

import 'wiki_rules_test.dart' show pagesZoe, rbWiki, sheet;

Character isaure() => sheet('Isaure')
  ..disciplines = [Discipline('Présence', 2, inClan: true)]
  ..merits = [Trait('Visage angélique', 1)]
  ..flaws = [Trait('Curiosité', 2)];

Character lucie() => sheet('Lucie')..disciplines = [Discipline('Présence', 1, inClan: true)];

void main() {
  final items = wikiIndex(rbWiki, pagesZoe(), staff: false);
  final pre = rbWiki.find('disciplines', 'Présence')!;
  WikiItem item(String id) => items.firstWhere((i) => i.id == id);

  test('fiches qui personnalisent : PJ actifs seulement', () {
    final sheets = [isaure(), sheet('morte', status: CharacterStatus.dead), sheet('pnj', kind: CharacterKind.pnj)];
    expect([for (final c in activeSheets(sheets)) c.id], ['Isaure']);
  });

  test('« Pour Isaure » : disciplines, clan, atouts, handicaps, chacun relié à sa page', () {
    final lines = mineLines(isaure(), items);
    expect([for (final l in lines) l.title], ['Présence', 'Toreador', 'Visage angélique', 'Curiosité']);
    expect([for (final l in lines) l.note], ['●● · vos 2 pouvoirs', 'votre clan', 'votre atout', 'votre handicap']);
    expect([for (final l in lines) l.item?.id], ['r_disciplines_pre', 'r_clans_tor', 'r_merits_vis', 'r_flaws_cur']);
    expect(mineLines(lucie(), items).first.note, '● · votre pouvoir');
    expect(itemFor('disciplines', 'Inconnue', items), isNull);
  });

  test('encadré : niveau, prochain pouvoir et son coût ; non apprise ; niveau 5 (Review Focus 5)', () {
    final s = nextStep(isaure(), pre, rbWiki);
    expect((s.heading, s.next), ('Isaure · Présence ●●', 'Prochain niveau : Envoûtement, 9 XP en clan.'));
    final none = nextStep(sheet('Agathe'), pre, rbWiki);
    expect((none.heading, none.next), ('Agathe · Présence : pas encore apprise', 'Prochain niveau : Fascination, 3 XP en clan.'));
    final top = nextStep(sheet('Ancienne')..disciplines = [Discipline('Présence', 5, inClan: true)], pre, rbWiki);
    expect((top.heading, top.next), ('Ancienne · Présence ●●●●●', null));
    final four = nextStep(sheet('Quatre')..disciplines = [Discipline('Présence', 3, inClan: true)], pre, rbWiki);
    expect(four.next, 'Prochain niveau : 12 XP en clan.');
  });

  test('pouvoirs : possédés jusqu’au niveau de la fiche, coût du niveau', () {
    final powers = disciplinePowers(pre);
    expect([for (final p in powers) owns(isaure(), p, 'Présence')], [true, true, false]);
    expect(powerCost(isaure(), powers[2], 'Présence', rbWiki), '9 XP en clan');
  });

  test('cartes et puce de la rubrique Disciplines', () {
    expect(cardMention(isaure(), item('r_disciplines_pre'), rbWiki), '●● · en clan');
    expect(cardMention(isaure(), item('r_disciplines_tha'), rbWiki), isNull);
    expect((inClanFor(isaure(), item('r_disciplines_pre'), rbWiki), inClanFor(isaure(), item('r_disciplines_tha'), rbWiki)), (true, false));
  });
}
