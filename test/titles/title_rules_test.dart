import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/titles/court_entry.dart';
import 'package:portail_met/titles/title_rules.dart';

final rbTitles = Rulebook({
  'titles': [
    RuleEntry(name: 'Prince', data: {'sect': 'Camarilla', 'count': 'Unique', 'public': true, 'onSheet': true}),
    RuleEntry(name: 'Sénéchal', data: {'sect': 'Camarilla', 'count': 'Unique', 'under': 'Prince', 'public': true, 'onSheet': true}),
    RuleEntry(name: 'Harpie', data: {'sect': 'Camarilla', 'count': 'Illimité', 'under': 'Sénéchal', 'public': true, 'onSheet': true}),
    RuleEntry(name: 'Primogène', data: {'sect': 'Camarilla', 'count': 'Un par clan', 'public': true, 'onSheet': true}),
    RuleEntry(name: 'Limier', data: {'sect': 'Camarilla', 'count': '2', 'public': true, 'onSheet': true}),
    RuleEntry(name: 'Main du Prince', data: {'sect': 'Camarilla', 'count': 'Unique', 'public': false, 'onSheet': false}),
    RuleEntry(name: 'Baron', data: {'sect': 'Anarchs', 'count': 'Illimité', 'public': true, 'onSheet': true, 'npcOnly': true}),
    RuleEntry(name: 'Confident', data: {'sect': 'Toutes', 'count': 'Illimité', 'public': false, 'onSheet': true}),
    RuleEntry(name: 'Ancien titre', state: RuleState.forbidden, data: {'count': 'Illimité'}),
  ],
}, const CreationValues(), const {});

Character _pc(String id, String name, {String clan = 'Toreador', String? title, CharacterStatus status = CharacterStatus.active, CharacterKind kind = CharacterKind.pj}) =>
    Character(id: id, name: name, kind: kind, playerUid: kind == CharacterKind.pj ? 'u-$id' : null, status: status)
      ..clan = clan
      ..sect = 'Camarilla'
      ..title = title;

Character lucie() => _pc('luc', 'Lucie Arnaud', clan: 'Malkavian');
Character octave() => _pc('oct', 'Octave Marchetti', clan: 'Ventrue', title: 'Sénéchal', kind: CharacterKind.pnj)..titleSince = DateTime(2019, 3, 1);
Character agathe() => _pc('aga', 'Sœur Agathe', clan: 'Malkavian', title: 'Primogène', kind: CharacterKind.pnj);
Character bastien() => _pc('bas', 'Bastien', clan: 'Brujah', title: 'Prince', status: CharacterStatus.dead);

List<String> errors(String? title, Character c, List<Character> all) => titleChecks(title, c, all, rbTitles, since: DateTime(2026, 3, 1)).errors;

void main() {
  final all = [lucie(), octave(), agathe(), bastien()];

  test('référentiel : informations, options sans interdit, nombre', () {
    final p = titleInfo(rbTitles, 'primogène')!;
    expect((p.name, p.perClan, p.max), ('Primogène', true, null));
    expect(titleInfo(rbTitles, 'Prince')!.max, 1);
    expect(titleInfo(rbTitles, 'Limier')!.max, 2);
    expect(titleInfo(rbTitles, 'Harpie')!.max, isNull);
    expect(titleInfo(rbTitles, 'Inconnu'), isNull);
    expect(titleOptions(rbTitles), isNot(contains('Ancien titre')));
    expect(titleOptions(rbTitles).first, 'Prince');
  });

  test('détenteurs : fiches actives seulement (Review Focus 4)', () {
    expect([for (final c in titleHolders('Prince', all)) c.name], isEmpty);
    expect([for (final c in titleHolders('sénéchal', all)) c.name], ['Octave Marchetti']);
    expect(errors('Prince', lucie(), all), isEmpty);
  });

  test('contrôles : unique, par clan, nombre fixe, PNJ, hors référentiel, date (Review Focus 1)', () {
    expect(errors('Sénéchal', lucie(), all), ['Sénéchal est déjà tenu par Octave Marchetti.']);
    expect(errors('Sénéchal', octave(), all), isEmpty, reason: 'son propre titre ne le bloque pas');
    expect(errors('Primogène', lucie(), all), ['Primogène est déjà tenu pour le clan Malkavian par Sœur Agathe.']);
    expect(errors('Primogène', lucie()..clan = 'Toreador', all), isEmpty);
    final limiers = [...all, _pc('a', 'Ana', title: 'Limier'), _pc('b', 'Ben', title: 'Limier')];
    expect(errors('Limier', lucie(), limiers), ['Limier : 2 détenteurs au plus (Ana, Ben).']);
    expect(errors('Baron', lucie(), all), ['Baron est réservé aux PNJ.']);
    expect(errors('Ancien titre', lucie(), all), ['Ancien titre : pas un titre de la chronique.']);
    expect(errors('Inconnu', lucie(), all), ['Inconnu : pas un titre de la chronique.']);
    expect(titleChecks('Harpie', lucie(), all, rbTitles, since: null).errors, ['Date invalide']);
    expect(titleChecks(null, lucie()..title = 'Harpie', all, rbTitles, since: null).errors, isEmpty, reason: 'retirer ne demande pas de date');
  });

  test('avertissements : secte, fiche sans clan', () {
    final w = titleChecks('Baron', _pc('n', 'Nadia', kind: CharacterKind.pnj), all, rbTitles, since: DateTime(2026)).warnings;
    expect(w, ['Baron relève de Anarchs ; la fiche est Camarilla.']);
    expect(titleChecks('Confident', lucie(), all, rbTitles, since: DateTime(2026)).warnings, isEmpty);
    expect(titleChecks('Primogène', lucie()..clan = null, all, rbTitles, since: DateTime(2026)).warnings,
        ['Fiche sans clan : le contrôle par clan ne s’applique pas.']);
  });

  test('visibilité, événements, historique (Review Focus 2)', () {
    expect(titleVisibility(titleInfo(rbTitles, 'Harpie')), EventVisibility.public);
    expect(titleVisibility(titleInfo(rbTitles, 'Confident')), EventVisibility.player);
    expect(titleVisibility(titleInfo(rbTitles, 'Main du Prince')), EventVisibility.staff);
    final before = lucie()..title = 'Main du Prince';
    final after = withTitle(before, 'Harpie', DateTime(2026, 3, 1));
    expect((after.title, after.titleSince), ('Harpie', DateTime(2026, 3, 1)));
    final ev = titleEvents(before, after, DateTime(2026, 3, 1), rbTitles, now: DateTime(2026, 5, 2));
    expect([for (final e in ev) (e.type, e.title, e.visibility, e.year, e.month, e.day, e.auto)], [
      (EventType.titleLost, 'Perd le titre de Main du Prince', EventVisibility.staff, 2026, 5, 2, true),
      (EventType.titleGained, 'Obtient le titre de Harpie', EventVisibility.public, 2026, 3, 1, true),
    ]);
    expect(titleEvents(after, after, DateTime(2026, 3, 1), rbTitles), isEmpty);
    final removed = withTitle(after, null, DateTime(2026, 4, 1));
    expect((removed.title, removed.titleSince), (null, null));
    expect(describeChanges(before, after), containsAll(['Titre : Main du Prince → Harpie', 'Titre depuis le 1 mars']));
  });

  test('fiche : clé tardive titleSince', () {
    final c = lucie()..titleSince = DateTime(2026, 3, 1);
    expect(Character.fromMap('luc', c.toMap()).titleSince, DateTime(2026, 3, 1));
    expect(lucie().toMap().containsKey('titleSince'), isFalse);
    expect(lucie().laterKeys().containsKey('titleSince'), isTrue);
  });

  test('Cour : entrée publique seulement, copie à jour, libellés', () {
    final h = lucie()
      ..title = 'Harpie'
      ..titleSince = DateTime(2026, 3, 1);
    final e = courtEntry(h, rbTitles)!;
    expect((e.characterId, e.name, e.title, e.sect, e.under, e.since), ('luc', 'Lucie Arnaud', 'Harpie', 'Camarilla', 'Sénéchal', DateTime(2026, 3, 1)));
    expect(CourtEntry.fromMap('luc', e.toMap()).toMap(), e.toMap());
    expect(courtEntry(h.clone()..title = 'Confident', rbTitles), isNull);
    expect(courtEntry(h.clone()..title = 'Main du Prince', rbTitles), isNull);
    expect(courtEntry(lucie(), rbTitles), isNull);
    expect(courtOutdated(h, e, rbTitles), isFalse);
    expect(courtOutdated(h, null, rbTitles), isTrue);
    expect(courtOutdated(h.clone()..name = 'Lucie A.', e, rbTitles), isTrue);
    expect(courtOutdated(lucie(), null, rbTitles), isFalse);
    expect(sinceText(DateTime(2026, 3, 1)), 'depuis mars 2026');
    expect(holdersLabel('Harpie', all, perClan: false, clans: 8), 'Vacant');
    expect(holdersLabel('Sénéchal', all, perClan: false, clans: 8), 'Octave Marchetti (PNJ)');
    expect(holdersLabel('Primogène', [...all, _pc('z', 'Zoé', clan: 'Brujah', title: 'Primogène')], perClan: true, clans: 8), '2 / 8 clans');
  });

  test('Cour : groupes par secte, hiérarchie en retrait', () {
    CourtEntry entry(String id, String title, String sect, String under) =>
        CourtEntry(characterId: id, name: id, title: title, sect: sect, under: under, since: null);
    final groups = courtGroups([
      entry('c', 'Harpie', 'Camarilla', 'Sénéchal'),
      entry('j', 'Baron', 'Anarchs', ''),
      entry('a', 'Prince', 'Camarilla', ''),
      entry('d', 'Harpie', 'Camarilla', 'Sénéchal'),
      entry('b', 'Sénéchal', 'Camarilla', 'Prince'),
    ], rbTitles);
    expect([for (final g in groups) g.sect], ['Camarilla', 'Anarchs']);
    expect([for (final t in groups.first.titles) (t.title, t.depth, t.holders.length)], [('Prince', 0, 1), ('Sénéchal', 1, 1), ('Harpie', 2, 2)]);
  });

  test('titre caché : visibleTitle, résumé neutre, fiche vue du joueur (I1)', () {
    final hidden = lucie()..title = 'Main du Prince';
    expect(visibleTitle(hidden, rbTitles), isNull);
    expect(visibleTitle(lucie()..title = 'Harpie', rbTitles), 'Harpie');
    expect(playerView(hidden, rbTitles).title, isNull);
    expect(playerView(hidden, null).title, isNull);
    expect(hidden.title, 'Main du Prince');
    final after = withTitle(hidden, 'Harpie', DateTime(2026, 3, 1));
    expect(titleSummary(hidden, after, rbTitles), ['Titre modifié (réservé à l’équipe)']);
    expect(titleSummary(after, withTitle(after, null, null), rbTitles), ['Titre : Harpie → (vide)']);
    expect(titleSummary(lucie(), after, rbTitles), containsAll(['Titre : (vide) → Harpie', 'Titre depuis le 1 mars']));
  });

  test('Cour : ni fiche morte ni titre retiré du référentiel (I3)', () {
    expect(courtEntry(octave()..title = 'Harpie', rbTitles), isNotNull);
    expect(courtEntry(octave()..title = 'Harpie'..status = CharacterStatus.dead, rbTitles), isNull);
    expect(courtEntry(octave()..title = 'Ancien titre', rbTitles), isNull);
  });
}
