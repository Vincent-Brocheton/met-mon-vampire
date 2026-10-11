import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_rules.dart';

final rbWiki = Rulebook({
  'disciplines': [
    RuleEntry(id: 'pre', name: 'Présence', vo: 'Presence', data: {
      'common': true,
      'powers': [
        {'level': 1, 'name': 'Fascination', 'vo': 'Awe', 'effect': 'Attire les regards.'},
        {'level': 3, 'name': 'Envoûtement', 'vo': 'Entrancement', 'effect': 'Rend la cible dévouée.'},
        {'level': 2, 'name': 'Regard terrifiant', 'vo': 'Dread Gaze', 'effect': ''},
      ],
    }),
    RuleEntry(id: 'tha', name: 'Thaumaturgie', data: {'common': false}),
    RuleEntry(id: 'old', name: 'Discipline oubliée', state: RuleState.draft),
  ],
  'clans': [
    RuleEntry(id: 'tor', name: 'Toreador', data: {'disciplines': ['Auspex', 'Célérité', 'Présence']}),
    RuleEntry(id: 'tre', name: 'Tremere', data: {'disciplines': ['Thaumaturgie']}),
  ],
  'sects': [RuleEntry(id: 'cam', name: 'Camarilla')],
  'merits': [RuleEntry(id: 'vis', name: 'Visage angélique', data: {'cost': 1, 'type': 'general'})],
  'flaws': [RuleEntry(id: 'cur', name: 'Curiosité', data: {'cost': 2})],
}, const CreationValues(), const {});

WikiPage pg(String id,
        {String title = '', String rubric = 'chronique', String audience = 'all', String body = '', String source = '', String? cat, String? entryId, int version = 1, DateTime? at}) =>
    WikiPage(
        id: id,
        title: title,
        rubric: rubric,
        audience: audience,
        body: body,
        source: source,
        cat: cat,
        entryId: entryId,
        version: version,
        updatedAt: at ?? DateTime(2026, 9, 1),
        updatedByName: 'Léa');

/// Toutes les pages publiées (ce que lit le conte).
List<WikiPage> pagesWiki() => [
      pg('r_disciplines_pre',
          title: 'Présence',
          rubric: 'disciplines',
          cat: 'disciplines',
          entryId: 'pre',
          source: 'MET : VTM, p. 120',
          at: DateTime(2026, 9, 25),
          body: '## Envoûtement\n\n§ Coûte un point de Sang.\n\n## Convocation\n\nVoir aussi [[La cour du Prince]] et [[Page cachée]].'),
      pg('cour', title: 'La cour du Prince', body: 'La cour se réunit à l’Opéra.', at: DateTime(2026, 9, 28)),
      pg('opera', title: 'Le salon de l’Opéra', audience: 'clan:toreador', body: 'Un salon *feutré*.', at: DateTime(2026, 9, 12)),
      pg('rue', title: 'La rue des Brujah', audience: 'clan:brujah', body: 'Le bar du port.'),
      pg('secret', title: 'Le sire de Lucie', audience: 'staff', body: 'Secret.'),
      pg('r_disciplines_gone', title: 'Ancienne', rubric: 'disciplines', cat: 'disciplines', entryId: 'gone', body: 'Texte.'),
    ];

/// Pages que Firestore renvoie à Zoé (Toreador, Camarilla).
List<WikiPage> pagesZoe() => [for (final p in pagesWiki()) if (p.audience == audienceAll || p.audience == 'clan:toreador') p];

List<WikiPage> draftsWiki() => [
      pg('r_disciplines_pre', title: 'Présence', rubric: 'disciplines', cat: 'disciplines', entryId: 'pre', body: 'Brouillon de Présence', version: 1),
      pg('neuve', title: 'Système de combat', rubric: 'systeme', version: 0),
    ];

Character sheet(String id,
        {String uid = 'zoe', String? clan = 'Toreador', String? sect = 'Camarilla', CharacterStatus status = CharacterStatus.active, CharacterKind kind = CharacterKind.pj}) =>
    Character(id: id, name: id, kind: kind, playerUid: uid, status: status)
      ..clan = clan
      ..sect = sect;

const zoeUser = AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur, wikiAudiences: ['clan:toreador', 'sect:camarilla']);
const leaUser = AppUser(uid: 'lea', displayName: 'Léa', email: 'l@ex.fr', role: Role.conteur);
const julienUser = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

void main() {
  test('accès : fiches actives du joueur, clan de sang et secte, sans doublon, triés', () {
    final ghoul = sheet('goule', clan: null, sect: 'Anarchs')..ghoul = GhoulState(domitorId: 'x', domitorName: 'Isaure', domitorClan: 'Brujah');
    expect(
        wikiAudiences([
          sheet('isaure'),
          sheet('bis'),
          ghoul,
          sheet('morte', clan: 'Ventrue', status: CharacterStatus.dead),
          sheet('brouillon', clan: 'Tremere', status: CharacterStatus.draft),
          sheet('pnj', clan: 'Lasombra', kind: CharacterKind.pnj),
        ]),
        ['clan:brujah', 'clan:toreador', 'sect:anarchs', 'sect:camarilla']);
    expect(wikiAudiences([sheet('x', clan: ' ', sect: null)]), isEmpty);
  });

  test('accès : seuls les comptes dont la liste change sont à écrire (Review Focus 3)', () {
    const max = AppUser(uid: 'max', displayName: 'Max', email: 'm@ex.fr', role: Role.joueur, wikiAudiences: ['clan:brujah']);
    final changes = audienceChanges([zoeUser, max, leaUser], [sheet('isaure'), sheet('lucie', uid: 'lea', clan: 'Malkavian')]);
    expect(changes.keys, ['max', 'lea']);
    expect(changes['max'], isEmpty);
    expect(changes['lea'], ['clan:malkavian', 'sect:camarilla']);
  });

  test('lecture et libellés de visibilité', () {
    expect(canRead('all', const [], staff: false), isTrue);
    expect(canRead('clan:toreador', const ['clan:toreador'], staff: false), isTrue);
    expect(canRead('clan:brujah', const ['clan:toreador'], staff: false), isFalse);
    expect(canRead('staff', const [], staff: false), isFalse);
    expect(canRead('staff', const [], staff: true), isTrue);
    expect(audienceLabel('clan:toreador', rbWiki), 'Clan Toreador');
    expect(audienceLabel('sect:camarilla', rbWiki), 'Secte Camarilla');
    expect(audienceLabel('staff', rbWiki), 'Conte seul');
    expect(audienceLabel('all', rbWiki), 'Tous');
    expect(audienceLabel('clan:inconnu', rbWiki), 'Clan inconnu');
    expect(reservedBanner('clan:toreador', rbWiki), 'Réservé au clan Toreador.');
    expect(reservedBanner('sect:camarilla', rbWiki), 'Réservé à la secte Camarilla.');
    expect(reservedBanner('all', rbWiki), isNull);
    expect([for (final o in audienceOptions(rbWiki)) o.$2], ['Tous les joueurs', 'Clan Toreador', 'Clan Tremere', 'Secte Camarilla', 'Le conte seul']);
    expect(audienceOptions(rbWiki)[1].$1, 'clan:toreador');
  });

  test('clés : identifiant de l’entrée, ou nom simplifié d’une valeur de base', () {
    expect(fold('Éléphant ÇA'), 'elephant ca');
    expect(rulePageId('disciplines', RuleEntry(id: 'pre', name: 'Présence')), 'r_disciplines_pre');
    expect(rulePageId('merits', RuleEntry(name: 'Visage angélique')), 'r_merits_base-visage-angelique');
    expect((rubricOfCat('flaws'), rubricById('inconnue').id, findRubric('inconnue')), ('atouts', chronicleRubric, null));
  });

  test('index joueur : entrées proposées, pages reçues ; ni brouillon du référentiel ni orpheline (Review Focus 1, 5)', () {
    final items = wikiIndex(rbWiki, pagesZoe(), staff: false);
    final ids = {for (final i in items) i.id};
    expect(ids, containsAll(['r_disciplines_pre', 'r_disciplines_tha', 'cour', 'opera', 'r_clans_tor']));
    expect(ids, isNot(contains('r_disciplines_old')));
    expect(ids, isNot(contains('r_disciplines_gone')));
    expect(ids, isNot(contains('rue')));
    final pre = items.firstWhere((i) => i.id == 'r_disciplines_pre');
    expect((pre.title, pre.rubric, pre.isRule, pre.written, pre.vo), ('Présence', 'disciplines', true, true, 'Presence'));
    final tha = items.firstWhere((i) => i.id == 'r_disciplines_tha');
    expect((tha.written, stateOf(tha), originLabel(tha)), (false, WikiState.empty, 'Fiche du référentiel'));
    expect(items.firstWhere((i) => i.id == 'opera').rubric, 'chronique');
  });

  test('index du conte : tout, orphelines et brouillons ; état et origine (Review Focus 5)', () {
    final items = wikiIndex(rbWiki, pagesWiki(), drafts: draftsWiki(), staff: true);
    WikiItem item(String id) => items.firstWhere((i) => i.id == id);
    expect(item('r_disciplines_old').entry?.state, RuleState.draft);
    final gone = item('r_disciplines_gone');
    expect((gone.orphan, originLabel(gone), gone.rubric, gone.isRule), (true, 'Entrée supprimée', 'disciplines', true));
    expect((stateOf(item('r_disciplines_pre')), item('r_disciplines_pre').audience), (WikiState.draft, 'all'));
    expect((stateOf(item('neuve')), originLabel(item('neuve')), item('neuve').rubric), (WikiState.draft, 'Page libre', 'systeme'));
    expect(stateOf(item('cour')), WikiState.published);
    expect(item('secret').audience, 'staff');
    expect(WikiState.empty.label, 'À rédiger');
  });

  test('avancement par rubrique : pages de règles rédigées', () {
    final p = progress(wikiIndex(rbWiki, pagesWiki(), staff: true));
    final d = p.firstWhere((x) => x.label == 'Disciplines');
    expect((d.done, d.total), (1, 3));
    expect(p.any((x) => x.total == 0), isFalse);
  });

  test('recherche : sans accents, titres d’abord, extrait (Review Focus 1)', () {
    final items = wikiIndex(rbWiki, pagesZoe(), staff: false);
    final ids = [for (final h in search(items, 'OPERA')) h.item.id];
    expect(ids.first, 'opera');
    expect(ids, contains('cour'));
    expect(search(items, 'opera').firstWhere((h) => h.item.id == 'cour').excerpt, contains('l’Opéra'));
    expect(search(items, 'envoutement').first.item.id, 'r_disciplines_pre');
    expect(search(items, 'brujah').any((h) => h.item.id == 'rue'), isFalse);
    expect(search(items, '  '), isEmpty);
  });

  test('liens : page visible de ce titre, sinon rien (Review Focus 1)', () {
    final items = wikiIndex(rbWiki, pagesZoe(), staff: false);
    expect(resolveLink('la cour du prince', items)?.id, 'cour');
    expect(resolveLink('La rue des Brujah', items), isNull);
    expect(resolveLink('Page cachée', items), isNull);
    expect(resolveLink('Présence', items)?.id, 'r_disciplines_pre');
  });

  test('données de l’entrée, pouvoirs triés, sous-titre, filtres, groupes', () {
    final pre = rbWiki.find('disciplines', 'Présence')!;
    expect([for (final l in dataLines('disciplines', pre)) l.$1], ['Commune (achetable hors clan)']);
    expect(dataLines('clans', rbWiki.find('clans', 'Toreador')!).first, ('Disciplines de clan', 'Auspex, Célérité, Présence'));
    expect([for (final p in disciplinePowers(pre)) p.level], [1, 2, 3]);
    final items = wikiIndex(rbWiki, pagesZoe(), staff: false);
    WikiItem item(String id) => items.firstWhere((i) => i.id == id);
    expect(itemSubtitle(item('r_disciplines_pre'), rbWiki), 'En clan : Toreador');
    expect(itemSubtitle(item('r_disciplines_tha'), rbWiki), 'En clan : Tremere');
    expect(itemSubtitle(item('cour'), rbWiki), '');
    expect([for (final f in rubricFilters(rubricById('disciplines'))) f.$1], ['Toutes', 'Communes', 'Propres à un clan']);
    expect([for (final f in rubricFilters(rubricById('atouts'))) f.$1], ['Toutes', 'Atouts', 'Handicaps']);
    expect(rubricFilters(rubricById('rituels')).length, 1);
    final communes = rubricFilters(rubricById('disciplines'))[1].$2;
    expect((communes(item('r_disciplines_pre')), communes(item('r_disciplines_tha'))), (true, false));
    expect((groupOf(item('cour')), groupOf(item('r_disciplines_pre'))), ('Pages du conte', 'Disciplines & pouvoirs'));
  });

  test('mis à jour récemment ; aperçu joueur', () {
    final items = wikiIndex(rbWiki, pagesWiki(), staff: true);
    expect([for (final i in recentlyUpdated(items, count: 2)) i.id], ['cour', 'r_disciplines_pre']);
    final preview = readerItems(rbWiki, pagesWiki(), staff: true, preview: true);
    expect(preview.any((i) => i.id == 'opera' || i.id == 'secret' || i.id == 'r_disciplines_old'), isFalse);
    expect(preview.any((i) => i.id == 'cour'), isTrue);
  });

  test('page : lecture d’un document publié ou d’un brouillon', () {
    final p = WikiPage.fromMap('x', {'title': 'T', 'rubric': 'systeme', 'audience': 'staff', 'body': 'B', 'source': 'S', 'version': 3});
    expect((p.title, p.rubric, p.audience, p.body, p.source, p.version, p.cat), ('T', 'systeme', 'staff', 'B', 'S', 3, null));
    expect(WikiPage.fromMap('x', {'baseVersion': 2}).version, 2);
    expect(pg('r', title: ' T ', cat: 'disciplines', entryId: 'pre').contentMap().keys,
        ['title', 'rubric', 'audience', 'body', 'source', 'cat', 'entryId']);
    expect(pg('c', title: ' T ').contentMap()['title'], 'T');
    expect(pg('c').contentMap().containsKey('cat'), isFalse);
  });
}
