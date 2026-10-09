import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/allies/allies_repository.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_edit_screen.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/servants/servants_repository.dart';

import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import 'character_test.dart' show sample;
import 'ghoul_test.dart' show ghoulState;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeCharacterRepository> pump(WidgetTester tester, Character c, {AppUser me = lea, Rulebook rb = const Rulebook(), FakeServantsRepository? servants, FakeItemsRepository? items, FakeAlliesRepository? allies, FakeBondsRepository? bonds, List<AppUser> users = const [lea], List<Game> games = const []}) async {
    tester.view.physicalSize = const Size(1440, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeCharacterRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rulebookProvider.overrideWith((ref) => rb),
        currentUserProvider.overrideWith((ref) => Stream.value(me)),
        allUsersProvider.overrideWith((ref) => Stream.value(users)),
        characterRepositoryProvider.overrideWith((ref) => repo),
        characterProvider('x').overrideWith((ref) => Stream.value(c)),
        noPlaces,
        noServantFiles,
        noItems,
        noAllyFiles,
        noNpcLoans,
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        allCharactersProvider.overrideWith((ref) => Stream.value([sample()])),
        servantsRepositoryProvider.overrideWith((ref) => servants ?? FakeServantsRepository()),
        itemsRepositoryProvider.overrideWith((ref) => items ?? FakeItemsRepository()),
        alliesRepositoryProvider.overrideWith((ref) => allies ?? FakeAlliesRepository()),
        bondsRepositoryProvider.overrideWith((ref) => bonds ?? FakeBondsRepository()),
        characterNotesProvider('x').overrideWith((ref) => Stream.value('')),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: const Scaffold(body: CharacterEditScreen(id: 'x'))),
    ));
    await tester.pump();
    return repo;
  }

  Character withHumanity() => sample()..humanity = 5;

  testWidgets('C3 : fiche figée, bandeau et XP verrouillée (sous-projet 8a, Review Focus 2)', (tester) async {
    final repo = await pump(tester, withHumanity(), games: [frozenGame(year: 2099)]);
    expect(find.text('Figée pour la partie du samedi 3 oct., jusqu’au dimanche 4 oct. à 6h : son XP ne peut pas changer.'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajouter un point : XP gagnée'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Fiche figée jusqu’au 4 oct. : l’XP ne peut pas changer.'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('C3 : fiche figée, une modification hors XP passe (sous-projet 8a)', (tester) async {
    final repo = await pump(tester, withHumanity(), games: [frozenGame(year: 2099)]);
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Correction');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveEdit:Correction']);
  });

  testWidgets('un point d’Humanité, motif obligatoire, enregistrement', (tester) async {
    final repo = await pump(tester, withHumanity());
    expect(find.textContaining('modification non enregistrée'), findsNothing);
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.pump();
    expect(find.text('1 modification non enregistrée'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Humanité 5 → 6'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.text('Indiquez un motif.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reason')), 'Correction');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveEdit:Correction']);
  });

  testWidgets('C3 : « Changer le titre » désactivé tant que des modifications ne sont pas enregistrées', (tester) async {
    await pump(tester, withHumanity());
    final btn = find.widgetWithText(TextButton, 'Changer le titre');
    expect(tester.widget<TextButton>(btn).onPressed, isNotNull);
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.pump();
    expect(tester.widget<TextButton>(btn).onPressed, isNull);
    expect(find.text('Enregistrez d’abord vos modifications.'), findsOneWidget);
  });

  testWidgets('fiche de PNJ : section « Prêts »', (tester) async {
    await pump(tester, sample()..kind = CharacterKind.pnj);
    await tester.pumpAndSettle();
    expect(find.text('PRÊTS'), findsOneWidget);
    expect(find.text('Jamais confié.'), findsOneWidget);
  });

  testWidgets('fiche de PJ : pas de section « Prêts »', (tester) async {
    await pump(tester, sample());
    await tester.pumpAndSettle();
    expect(find.text('PRÊTS'), findsNothing);
  });

  testWidgets('C3 : section « Équipement »', (tester) async {
    await pump(tester, sample());
    await tester.pumpAndSettle();
    expect(find.text('ÉQUIPEMENT'), findsOneWidget);
    expect(find.text('Aucun objet.'), findsOneWidget);
  });

  testWidgets('C3 : serviteur retiré, libération refusée : message (revue)', (tester) async {
    final servants = FakeServantsRepository()..releaseError = Exception('refus');
    await pump(tester, sample()..servants = [Servant('x-s1', 'Rex', ServantKind.animal, 2)], servants: servants);
    await tester.tap(find.byTooltip('Retirer Rex'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Libéré');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(servants.calls, ['release:x-s1']);
    expect(find.text('Rex : fiche du serviteur non mise à jour. Ouvrez-la dans « Goules et mortels » et enregistrez.'), findsOneWidget);
  });

  testWidgets('C3 : joueur changé, alliés refusés : le message indique le bon remède', (tester) async {
    const zoe = AppUser(uid: 'zoe', displayName: 'Zoé A.', email: 'z@ex.fr', role: Role.joueur);
    final allies = FakeAlliesRepository()..error = Exception('refus');
    await pump(tester, sample(), allies: allies, users: const [lea, zoe]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('c3-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zoé A.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Changement de joueuse');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('« Alliés en jeu »'), findsOneWidget);
    expect(find.textContaining('Goules et mortels'), findsNothing);
  });

  testWidgets('C3 : joueur changé, l’accès aux fiches des serviteurs suit (revue)', (tester) async {
    const zoe = AppUser(uid: 'zoe', displayName: 'Zoé A.', email: 'z@ex.fr', role: Role.joueur);
    final servants = FakeServantsRepository();
    final items = FakeItemsRepository();
    final allies = FakeAlliesRepository();
    final bonds = FakeBondsRepository();
    await pump(tester, sample()..servants = [Servant('x-s1', 'Rex', ServantKind.animal, 2)], servants: servants, items: items, allies: allies, bonds: bonds, users: const [lea, zoe]);
    await tester.pumpAndSettle(); // liste des joueurs reçue
    await tester.tap(find.byKey(const Key('c3-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zoé A.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reason')), 'Changement de joueuse');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(servants.calls, ['players:x-s1:zoe']);
    expect(items.calls, ['player:x:zoe']);
    expect(allies.calls, ['players:x:zoe']);
    expect(bonds.calls, ['player:x:zoe']);
  });

  testWidgets('C3 : ajouter un allié, enregistré avec le motif', (tester) async {
    final repo = await pump(tester, sample());
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Allié'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('+ Allié Nouvel allié ●'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reason')), 'Allié accordé en jeu');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveEdit:Allié accordé en jeu']);
    expect(repo.lastAfter!.allies.single.name, 'Nouvel allié');
  });

  /// Goule active dont le domitor est 'x' : ici la fiche elle-même, ce qui suffit à vérifier la recopie
  /// (Auspex 3 remplace Présence 2).
  Character ghoulSheet() => sample()
    ..ghoul = (ghoulState()..domitorDisciplines = [const DomitorDiscipline('Présence', 2)])
    ..clan = null
    ..humanity = 5;

  testWidgets('goule : Humanité qui ne baisse pas (Review Focus 5)', (tester) async {
    final repo = await pump(tester, ghoulSheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retirer un point : Humanité'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('L’Humanité d’une goule ne peut pas baisser.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.text('Rang de génération'), findsNothing, reason: 'revue : pas de génération pour une goule');
  });

  testWidgets('goule : gorgée et copie du domitor dans C3', (tester) async {
    final repo = await pump(tester, ghoulSheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ghoul-drink')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ghoul-refresh')));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Vitae 4 → 5'), findsOneWidget);
    expect(find.text('Disciplines du domitor recopiées'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reason')), 'Gorgée');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['saveEdit:Gorgée']);
  });

  testWidgets('C3 : pas d’étreinte pour une goule retirée (revue)', (tester) async {
    await pump(tester, ghoulSheet()..status = CharacterStatus.retired);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('c3-embrace')), findsNothing);
  });

  testWidgets('C3 : étreinte impossible tant que des changements ne sont pas enregistrés (revue)', (tester) async {
    await pump(tester, ghoulSheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ghoul-drink')));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('c3-embrace'))).onPressed, isNull);
  });

  testWidgets('C3 : étreindre une goule figée, message et aucune écriture (revue finale)', (tester) async {
    final repo = await pump(tester, ghoulSheet(), games: [frozenGame(year: 2099)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('c3-embrace')));
    await tester.pumpAndSettle();
    expect(find.textContaining('l’XP ne peut pas changer.'), findsOneWidget);
    expect(find.byKey(const Key('em-gen')), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('C3 : étreindre une goule, clé ghoul supprimée (Review Focus 1)', (tester) async {
    final repo = await pump(tester, ghoulSheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('c3-embrace')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('em-gen')), '11');
    await tester.enterText(find.byKey(const Key('em-reason')), 'Étreinte');
    await tester.pump();
    await tester.tap(find.byKey(const Key('em-confirm')));
    await tester.pumpAndSettle();
    expect((repo.lastKind, repo.lastAfter!.ghoul, repo.lastAfter!.clan), ('embrace', null, 'Toreador'));
    expect(repo.lastExtra!.containsKey('ghoul'), isTrue);
    final e = repo.lastEvents.single;
    expect((e.type, e.title, e.auto, e.visibility), (EventType.embrace, 'Étreinte par ${repo.lastAfter!.sire}', true, EventVisibility.player));
  });

  testWidgets('Annuler restaure exactement la fiche lue (Review Focus 5)', (tester) async {
    await pump(tester, withHumanity());
    await tester.tap(find.byTooltip('Ajouter un point : Humanité'));
    await tester.enterText(find.byKey(const Key('field-Sire')), 'Octave');
    await tester.pump();
    expect(find.text('2 modifications non enregistrées'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(find.textContaining('non enregistrée'), findsNothing);
    expect(find.text('Octave'), findsNothing);
  });

  testWidgets('valeur hors liste conservée dans le menu (Review Focus 4)', (tester) async {
    await pump(tester, withHumanity()..clan = 'Baali');
    expect(find.text('Baali'), findsOneWidget);
  });

  testWidgets('brouillon de PJ : lecture seule pour le conteur', (tester) async {
    await pump(tester, withHumanity()..status = CharacterStatus.draft);
    expect(find.textContaining('c’est au joueur de la remplir'), findsOneWidget);
    expect(find.byTooltip('Ajouter un point : Humanité'), findsNothing);
  });

  testWidgets('sa propre fiche : lecture seule (Review Focus 3)', (tester) async {
    await pump(tester, withHumanity()..playerUid = 'lea');
    expect(find.textContaining('votre propre fiche'), findsOneWidget);
    expect(find.byTooltip('Ajouter un point : Humanité'), findsNothing);
  });

  testWidgets('génération absente du référentiel ou en double : menu sans erreur (revue)', (tester) async {
    final rb = Rulebook({
      'generations': [
        RuleEntry(name: 'Ancilla', data: {'rank': 'ancilla', 'numbers': ['9', '9']}),
      ],
    });
    await pump(tester, sample()..genNumber = 10, rb: rb);
    expect(tester.takeException(), isNull);
    expect(find.text('Rang de génération'), findsOneWidget);
  });

  testWidgets('C3 : ajouter un rituel du référentiel', (tester) async {
    final rb = Rulebook({
      'rituals': [RuleEntry(name: 'Goût du sang', data: {'school': 'thaumaturgy', 'level': 1})],
    });
    await pump(tester, sample(), rb: rb);
    await tester.tap(find.byKey(const ValueKey('add-Rituels-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goût du sang').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirer Goût du sang'), findsOneWidget);
  });

  testWidgets('C3 : pas de doublon par « Autre… », points bonus bornés par le rang (revue)', (tester) async {
    final c = sample()..techniques = ['Regard ardent'];
    c.attributeBonus[AttrCategory.social] = 2;
    await pump(tester, c);
    await tester.tap(find.byKey(const ValueKey('add-Techniques-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autre…').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Regard ardent');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirer Regard ardent'), findsOneWidget);
    final add = find.ancestor(of: find.byTooltip('Ajouter un point : Points bonus Social'), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(add).onPressed, isNull, reason: 'Ancilla : 2 points bonus au plus');
  });

  testWidgets('C3 : bouton « Imprimer » (sous-projet 8b)', (tester) async {
    await pump(tester, withHumanity());
    expect(find.byKey(const Key('c3-print')), findsOneWidget);
  });
}
