import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/journal/journal_rules.dart';
import 'package:portail_met/rulebook/rule_entry.dart';

RawHistory h(String kind, {String col = 'characters', String id = 'c1', DateTime? at, String by = 'Marc D.', List<String> summary = const ['Force : 3 → 4'], String reason = ''}) =>
    RawHistory(col: col, parentId: id, at: at ?? DateTime(2026, 10, 1, 20), byName: by, kind: kind, summary: summary, reason: reason);

JournalLine line(JournalCat cat, DateTime at, {String who = 'Marc D.'}) => JournalLine(cat: cat, at: at, who: who, action: 'A', target: 'T', detail: 'D');

const names = {'characters/c1': 'Mila Ferreira', 'places/p1': 'Le salon de l’Opéra'};

Game game(DateTime date, {DateTime? lifted}) => Game(
      id: 'g1',
      date: date,
      frozenAt: date.subtract(const Duration(days: 4)).add(const Duration(hours: 20)),
      until: date.add(const Duration(days: 1, hours: 6)),
      byUid: 'marc',
      liftedAt: lifted,
      liftedByUid: lifted == null ? null : 'lea',
    );

void main() {
  group('historiques', () {
    test('fiche : action selon le type, détail et motif, lien vers l’historique', () {
      final x = historyLines([h('edit', reason: 'Erreur de saisie')], names).single;
      expect(x.cat, JournalCat.sheets);
      expect(x.action, 'Modification');
      expect(x.target, 'Mila Ferreira');
      expect(x.detail, 'Force : 3 → 4 ; Motif : Erreur de saisie');
      expect(x.link, '/conteur/fiches/c1/historique');
      expect(x.who, 'Marc D.');
      expect(historyLines([h('embrace')], names).single.action, 'Étreinte');
      expect(historyLines([h('validation')], names).single.action, 'Validation');
      expect(historyLines([h('inconnu')], names).single.action, 'Modification');
    });

    test('soumission et retrait du joueur : exclus (Review Focus 1)', () {
      expect(historyLines([h('submission'), h('withdrawal')], names), isEmpty);
    });

    test('XP : attribution, dépense, correction, bonus', () {
      final lines = historyLines([h('award'), h('xp'), h('correction'), h('bonus')], names);
      expect([for (final x in lines) x.action], ['XP attribuée', 'Dépense d’XP', 'Correction d’XP', 'Bonus du conte']);
      expect(lines.every((x) => x.cat == JournalCat.xp), isTrue);
    });

    test('gain mensuel : une ligne par motif et auteur, malgré un lot par fiche (Review Focus 2)', () {
      final lines = historyLines([
        h('gain', id: 'c1', at: DateTime(2026, 10, 1, 6, 0, 1), reason: 'Gain mensuel · oct. 2026'),
        h('gain', id: 'c2', at: DateTime(2026, 10, 1, 6, 0, 3), reason: 'Gain mensuel · oct. 2026'),
        h('gain', id: 'c3', at: DateTime(2026, 9, 1, 6), reason: 'Gain mensuel · sept. 2026'),
      ], names);
      expect([for (final x in lines) x.target], ['2 fiches', '1 fiche']);
      expect(lines.first.at, DateTime(2026, 10, 1, 6, 0, 3));
      expect(lines.first.action, 'Gain mensuel');
      expect(lines.first.cat, JournalCat.xp);
      expect(lines.first.detail, 'XP ajoutée selon le palier de chaque fiche');
      expect(lines.first.link, isNull);
    });

    test('lieu : action « Lieu », lien vers la liste ; élément inconnu : nom par défaut, sans lien', () {
      final lines = historyLines([
        h('edit', col: 'places', id: 'p1', summary: ['Lieu créé']),
        h('edit', col: 'items', id: 'gone'),
        h('edit', col: 'characters', id: 'gone'),
      ], names);
      expect(lines[0].action, 'Lieu');
      expect(lines[0].target, 'Le salon de l’Opéra');
      expect(lines[0].detail, 'Lieu créé');
      expect(lines[0].link, '/conteur/lieux');
      expect(lines[1].action, 'Objet');
      expect(lines[1].target, 'Objet');
      expect(lines[1].link, isNull);
      expect(lines[2].target, 'Fiche');
      expect(lines[2].link, isNull);
    });

    test('auteur sans nom : « Inconnu »', () {
      expect(historyLines([h('edit', by: ' ')], names).single.who, 'Inconnu');
    });
  });

  test('wiki : version publiée, note ; page supprimée sans lien', () {
    final lines = versionLines([
      RawVersion(pageId: 'p1', n: 4, title: 'Présence', note: 'Coquilles', byName: 'Léa G.', at: DateTime(2026, 9, 25)),
      RawVersion(pageId: 'old', n: 1, title: 'Ancienne', note: '', byName: 'Léa G.', at: DateTime(2026, 9, 20)),
    ], {'p1'});
    expect(lines[0].cat, JournalCat.wiki);
    expect(lines[0].action, 'Wiki');
    expect(lines[0].target, 'Page « Présence »');
    expect(lines[0].detail, 'Version 4 publiée : Coquilles');
    expect(lines[0].link, '/conteur/wiki/edition/p1/historique');
    expect(lines[1].detail, 'Version 1 publiée');
    expect(lines[1].link, isNull);
  });

  test('parties : gel, puis levée', () {
    final lines = gameLines([game(DateTime(2026, 10, 3), lifted: DateTime(2026, 10, 3, 23))], {'marc': 'Marc D.', 'lea': 'Léa G.'});
    expect(lines[0].cat, JournalCat.sheets);
    expect(lines[0].action, 'Gel des fiches');
    expect(lines[0].target, 'Partie du 3 oct.');
    expect(lines[0].detail, 'Fiches figées jusqu’au 4 oct. à 06:00');
    expect(lines[0].who, 'Marc D.');
    expect(lines[0].link, '/conteur/gel');
    expect(lines[1].action, 'Gel levé');
    expect(lines[1].who, 'Léa G.');
    expect(lines[1].at, DateTime(2026, 10, 3, 23));
    expect(gameLines([game(DateTime(2026, 10, 3))], const {}).single.who, 'Inconnu');
  });

  test('fusion : période, tri du plus récent au plus ancien', () {
    final a = line(JournalCat.wiki, DateTime(2026, 9, 1));
    final b = line(JournalCat.rules, DateTime(2026, 10, 2));
    final c = line(JournalCat.xp, DateTime(2026, 8, 1));
    expect(mergeLines([[a, c], [b]], DateTime(2026, 9, 1)), [b, a]);
    expect(mergeLines([[a, c], [b]], null), [b, a, c]);
  });

  test('filtres : catégorie, auteur ; auteurs triés, sans doublon', () {
    final a = line(JournalCat.wiki, DateTime(2026, 9, 1), who: 'Léa G.');
    final b = line(JournalCat.rules, DateTime(2026, 9, 2));
    final c = line(JournalCat.wiki, DateTime(2026, 9, 3));
    expect(filterLines([a, b, c], cat: JournalCat.wiki), [a, c]);
    expect(filterLines([a, b, c], author: 'Marc D.'), [b, c]);
    expect(filterLines([a, b, c], cat: JournalCat.wiki, author: 'Marc D.'), [c]);
    expect(filterLines([a, b, c]), [a, b, c]);
    expect(authorsOf([a, b, c]), ['Léa G.', 'Marc D.']);
  });

  test('période : 30 jours, dernière partie jouée, tout', () {
    final now = DateTime(2026, 10, 13, 12);
    final games = [game(DateTime(2026, 10, 3)), game(DateTime(2026, 9, 5)), game(DateTime(2026, 10, 24))];
    expect(periodStart(JournalPeriod.days30, now, games), DateTime(2026, 9, 13));
    expect(lastGameDay(games, now), DateTime(2026, 10, 3));
    expect(periodStart(JournalPeriod.sinceGame, now, games), DateTime(2026, 10, 3));
    expect(lastGameDay([game(DateTime(2026, 10, 24))], now), isNull);
    expect(periodStart(JournalPeriod.sinceGame, now, const []), DateTime(2026, 9, 13));
    expect(periodStart(JournalPeriod.all, now, games), isNull);
  });

  test('date courte', () {
    expect(journalStamp(DateTime(2026, 9, 29, 20)), '29 sept. · 20:00');
  });

  test('CSV : en-tête, guillemets doublés, « ; » et retours à la ligne', () {
    final x = JournalLine(cat: JournalCat.wiki, at: DateTime(2026, 9, 25, 18, 40), who: 'Léa G.', action: 'Wiki', target: 'Page « Présence »', detail: 'Note ; « cité » "x"\nsuite');
    expect(toCsv([x]), 'Quand;Qui;Action;Sur;Détail\n2026-09-25 18:40;Léa G.;Wiki;Page « Présence »;"Note ; « cité » ""x""\nsuite"');
    expect(toCsv(const []), 'Quand;Qui;Action;Sur;Détail');
  });

  test('ligne stockée : lecture du document', () {
    final x = JournalLine.fromMap({
      'cat': 'rules',
      'action': 'Référentiel',
      'target': 'T',
      'detail': 'D',
      'link': '/x',
      'byName': '',
      'at': Timestamp.fromDate(DateTime(2026, 9, 24, 11, 5)),
    });
    expect(x.cat, JournalCat.rules);
    expect(x.who, 'Inconnu');
    expect(x.at, DateTime(2026, 9, 24, 11, 5));
    expect(x.action, 'Référentiel');
    expect(x.link, '/x');
    expect(JournalLine.fromMap({'cat': 'accounts', 'action': 'Rôle', 'target': '', 'detail': '', 'byName': 'Marc D.'}).link, isNull);
  });

  group('écritures du journal', () {
    test('référentiel : créée, changement d’état, modifiée, supprimée, import', () {
      final before = RuleEntry(id: 'm1', name: 'Vrai Brujah');
      final forbidden = RuleEntry(id: 'm1', name: 'Vrai Brujah', state: RuleState.forbidden);
      expect(ruleSaveNote('merits', null, before),
          (cat: JournalCat.rules, action: 'Référentiel', target: '« Vrai Brujah » · Atouts', detail: 'Créée', link: '/conteur/referentiel/merits'));
      expect(ruleSaveNote('merits', before, forbidden).detail, 'Disponible → Interdit');
      expect(ruleSaveNote('merits', before, RuleEntry(id: 'm1', name: 'Vrai Brujah', description: 'x')).detail, 'Modifiée');
      expect(ruleDeleteNote('merits', before), (cat: JournalCat.rules, action: 'Référentiel', target: '« Vrai Brujah » · Atouts', detail: 'Supprimée', link: null));
      expect(ruleImportNote('merits', 20), (cat: JournalCat.rules, action: 'Référentiel', target: 'Atouts', detail: 'Import : 20 entrées', link: '/conteur/referentiel/merits'));
      expect(ruleImportNote('merits', 1).detail, 'Import : 1 entrée');
    });

    test('comptes : rôle, invitation envoyée et annulée', () {
      const julien = AppUser(uid: 'j', displayName: 'Julien P.', email: 'j@ex.fr', role: Role.joueur);
      expect(roleNote(julien, Role.narrateur), (cat: JournalCat.accounts, action: 'Rôle', target: 'Julien P.', detail: 'Joueur → Narrateur', link: '/conteur/comptes'));
      expect(inviteNote(' Paul@Ex.fr ', Role.conteur), (cat: JournalCat.accounts, action: 'Invitation', target: 'paul@ex.fr', detail: 'Conteur', link: null));
      expect(inviteCancelNote('paul@ex.fr'), (cat: JournalCat.accounts, action: 'Invitation', target: 'paul@ex.fr', detail: 'Annulée', link: null));
    });

    test('document : clés exactes, auteur, heure du serveur, textes coupés aux limites des règles', () {
      final m = journalData((cat: JournalCat.rules, action: 'A' * 90, target: 'T', detail: 'D' * 310, link: null), const Actor('lea', 'Léa G.'));
      expect(m.keys, unorderedEquals(['cat', 'action', 'target', 'detail', 'byUid', 'byName', 'at']));
      expect(m['cat'], 'rules');
      expect((m['action'] as String).length, 80);
      expect((m['detail'] as String).length, 300);
      expect(m['byUid'], 'lea');
      expect(m['byName'], 'Léa G.');
      expect(m['at'], isA<FieldValue>());
      expect(journalData(roleNote(const AppUser(uid: 'j', displayName: 'J', email: 'j@ex.fr', role: Role.joueur), Role.disabled), const Actor('lea', 'Léa G.'))['link'], '/conteur/comptes');
    });
  });
}
