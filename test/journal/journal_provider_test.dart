import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/allies/allies_repository.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/chronicle/chronicle_repository.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/journal/journal_repository.dart';
import 'package:portail_met/journal/journal_rules.dart';
import 'package:portail_met/places/places_repository.dart';
import 'package:portail_met/servants/servants_repository.dart';
import 'package:portail_met/wiki/wiki_page.dart';
import 'package:portail_met/wiki/wiki_repository.dart';

final since = DateTime(2026, 9, 13);

ProviderContainer container({bool historyFails = false}) => ProviderContainer(overrides: [
      journalHistoryProvider(since).overrideWith((ref) => historyFails
          ? Stream<List<RawHistory>>.error('index manquant')
          : Stream.value([
              RawHistory(col: 'characters', parentId: 'c1', at: DateTime(2026, 10, 1), byName: 'Marc D.', kind: 'edit', summary: const ['Force : 3 → 4'], reason: ''),
            ])),
      journalVersionsProvider(since).overrideWith(
          (ref) => Stream.value([RawVersion(pageId: 'p1', n: 2, title: 'Présence', note: '', byName: 'Léa G.', at: DateTime(2026, 10, 2))])),
      journalStoredProvider(since).overrideWith((ref) => Stream.value([
            JournalLine(cat: JournalCat.accounts, at: DateTime(2026, 10, 3), who: 'Marc D.', action: 'Rôle', target: 'Julien P.', detail: 'Joueur → Narrateur'),
          ])),
      gamesProvider.overrideWith((ref) => Stream.value([
            Game(id: 'g1', date: DateTime(2026, 10, 4), frozenAt: DateTime(2026, 10, 4, 20), until: DateTime(2026, 10, 5, 6), byUid: 'marc'),
            Game(id: 'g0', date: DateTime(2026, 8, 1), frozenAt: DateTime(2026, 8, 1, 20), until: DateTime(2026, 8, 2, 6), byUid: 'marc'),
          ])),
      allCharactersProvider.overrideWith(
          (ref) => Stream.value([Character(id: 'c1', name: 'Mila Ferreira', kind: CharacterKind.pj, playerUid: 'zoe', status: CharacterStatus.active)])),
      allPlacesProvider.overrideWith((ref) => Stream.value(const [])),
      allItemsProvider.overrideWith((ref) => Stream.value(const [])),
      allAllyFilesProvider.overrideWith((ref) => Stream.value(const [])),
      allServantFilesProvider.overrideWith((ref) => Stream.value(const [])),
      allUsersProvider.overrideWith((ref) => Stream.value(const [AppUser(uid: 'marc', displayName: 'Marc D.', email: 'm@ex.fr', role: Role.principal)])),
      wikiPagesProvider.overrideWith((ref) => Stream.value(<WikiPage>[])),
    ]);

Future<JournalFeed> read(ProviderContainer c) async {
  addTearDown(c.dispose);
  final sub = c.listen(journalProvider(since), (_, _) {});
  addTearDown(sub.close);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return c.read(journalProvider(since));
}

void main() {
  test('assemble les sources de la période, du plus récent au plus ancien, avec les noms', () async {
    final f = await read(container());
    expect([for (final l in f.lines) l.action], ['Gel des fiches', 'Rôle', 'Wiki', 'Modification']);
    expect(f.lines.first.who, 'Marc D.');
    expect(f.lines.last.target, 'Mila Ferreira');
    expect(f.lines[2].link, isNull);
    expect(f.partial, isFalse);
    expect(f.loading, isFalse);
  });

  test('source en erreur : les autres restent, le fil est marqué partiel (Review Focus 3)', () async {
    final f = await read(container(historyFails: true));
    expect([for (final l in f.lines) l.action], ['Gel des fiches', 'Rôle', 'Wiki']);
    expect(f.partial, isTrue);
  });
}
