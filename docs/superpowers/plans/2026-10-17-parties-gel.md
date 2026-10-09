# Parties et gel des fiches (sous-projet 8a) : plan d’implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** le conte fige d’un clic les fiches jouées avant une partie. Chaque fiche reçoit une version figée, et son XP ne bouge plus jusqu’à la levée (automatique à l’heure prévue, ou anticipée).

**Architecture :**
- **Modèle et calculs purs** dans `lib/games/` : `Game` (partie), `FrozenSheet` (version figée), `game_rules.dart` (fiches à figer, gel en cours, levée, comparaison, textes).
- **Dépôt `GamesRepository` :** figer en un lot (partie, pointeur `chronicle/freeze`, une version figée par fiche), lever, corriger une version figée.
- **Règles Firestore :** `games`, `chronicle/freeze`, `characters/{id}/frozen/{gameId}`, et le verrou d’XP dans `staffEdit`.
- **Écrans :**
  - « Gel des fiches » `/conteur/gel` ;
  - bandeaux sur la fiche (joueur et conte) et sur « Dépenser de l’XP » ;
  - XP verrouillée dans la validation des demandes, le gain mensuel, l’attribution, les corrections et l’édition C3.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-17-parties-gel-design.md`.

**Maquettes :** canvas https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planches `C-Figer.dc.html` et `J-Fiche.dc.html` (outil Artifact, `action: read`, `path: project/<planche>`).

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md <N> [test|impl]` (fichiers complets seulement ; les modifications de fichiers existants sont décrites et se font à la main) ;
  - textes en français, apostrophe typographique ’ dans les textes affichés ;
  - analyseur propre, pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - ne jamais commiter `bash.exe.stackdump`, `rules_test/bash.exe.stackdump`, `CLAUDE.md` ni `rules_test/firestore-debug.log`.
- **Branche :** `parties-gel`, déjà créée (la spec y est commitée).
- **Code généré :** `dart run build_runner build --delete-conflicting-outputs` après un nouveau `@riverpod`. Si des `.g.dart` sans rapport changent (empreintes seulement), les commiter avec la tâche.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Textes fixes :**
  - « Gel en cours · partie du samedi 3 octobre » ;
  - « Depuis le mardi 29 sept. à 20h, jusqu’au dimanche 4 oct. à 6h » ;
  - « Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct. » ;
  - « Figée pour la partie du samedi 3 oct., jusqu’au dimanche 4 oct. à 6h : son XP ne peut pas changer. » ;
  - « Fiche figée jusqu’au 4 oct. » et « Fiche figée jusqu’au 4 oct. : l’XP ne peut pas changer. » ;
  - « 42 fiches seront figées : 38 PJ actifs et 4 PNJ confiés. » ;
  - « 3 fiches figées : leur gain sera versé après le gel. » (singulier : « 1 fiche figée : son gain sera versé après le gel. ») ;
  - « 2 changements », « 1 changement », « Aucun », « Première version figée » ;
  - « Date de partie invalide », « Levée invalide », « La levée doit être dans le futur. » ;
  - « Un gel est déjà en cours. », « Enregistrement refusé : réessayez. » ;
  - « Aucun changement à reporter », « Votre propre fiche : un autre conteur doit la corriger. », « Aucun gel en cours. ».
- **Gel en cours :** `liftedAt == null` et l’heure précède `until`. Une fiche est figée si elle est dans `sheetIds` d’un gel en cours.
- **Lecture seule :** le narrateur voit l’écran du gel, sans bouton.
- **Leçons des lots précédents :**
  - lire un dépôt dans une action et non dans `build` ;
  - ne rien proposer tant que les données ne sont pas lues ;
  - rangées de boutons en `Wrap` (390 px) ;
  - un refus ne vide pas le formulaire ;
  - tout écran qui lit un nouveau provider oblige ses tests à le surcharger (ici `gamesProvider`).

## Écarts à la spec (décidés à l’écriture du plan)

- **Comparaison :** une fiche est comparée à sa version figée **au gel précédent** (le dernier gel figé avant celui-ci), pas à sa dernière version figée quelle qu’elle soit. Une fiche absente du gel précédent affiche « Première version figée ». Cela évite de lire toutes les versions figées de la chronique. La spec est mise à jour dans le même commit que ce plan.
- **Index :** la lecture des versions figées d’une partie interroge la collection `frozen` de toutes les fiches (`collectionGroup`, filtre `gameDate`). Il faut une exemption d’index dans `firestore.indexes.json`, déployée avec les règles.

## Review Focus

1. **Deux gels à la fois :** un second gel est refusé tant que le premier est en cours, y compris quand deux membres du conte cliquent ensemble. L’écran affiche « Un gel est déjà en cours. ». Tests : tâches 2 (règles) et 5 (écran).
2. **XP d’une fiche figée par un chemin détourné :** gain, attribution, validation, correction et édition C3 sont tous refusés par les règles, et chaque écran l’empêche avant d’écrire. Tests : tâche 2 (règles), tâches 3 et 4 (écrans).
3. **Fin du gel sans clic :** une fois `until` passé, les règles rendent l’XP modifiable et l’écran du gel revient au formulaire. Tests : tâches 1, 2 et 5.
4. **Lot d’une quarantaine de fiches :** le lot du gel passe les limites de lectures des règles avec 45 fiches. Test : tâche 2.
5. **Conte joueur d’un PJ :** sa fiche est figée comme les autres (la version figée s’écrit), mais il ne peut pas la corriger lui-même. Tests : tâches 2 et 5.

---

### Task 1 : modèle et calculs purs

**Files :**
- Create :
  - `lib/games/game.dart` ;
  - `lib/games/game_rules.dart`.
- Test : `test/games/game_rules_test.dart`.

**Interfaces :**
- Produces :
  - `Game({id, date, frozenAt, until, liftedAt, liftedByUid, byUid, sheetIds})`, `Game.fromMap(id, m)` ;
  - `FrozenSheet({characterId, gameId, sheet, version, gameDate, at, byUid, reason})`, `FrozenSheet.fromMap(characterId, gameId, m)`, getter `character` ;
  - `isRunning(Game, DateTime now)`, `runningGame(List<Game>, now)`, `frozenBy(List<Game>, String characterId, now)`, `previousGame(List<Game>, Game)` ;
  - `sheetsToFreeze(List<Character>, List<NpcLoan>, now)` ;
  - `defaultUntil(DateTime date)`, `parseTime(String)` → `(int, int)?`, `untilOf(date, day, time)`, `freezePlan(dateText, untilDay, untilTime, now)` → `FreezePlan` (`({DateTime? date, DateTime? until, String? error})`) ;
  - `changeCount(Character? before, Character after)` → `int?`, `changeLabel(int?)` ;
  - textes : `hourText`, `shortDay`, `dayAndHour`, `slashDay`, `gameTitle`, `gameSpanText`, `playerFreezeText`, `staffFreezeText`, `frozenUntilText`, `freezeCountText(List<Character>)`, `frozenGainText(int)` ;
  - dans le test, exportés : `frozenGame({id, year, sheetIds, liftedAt})` et `npc(id, {status})`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 1 test`, puis `flutter test test/games/game_rules_test.dart`.

Expected : échec de compilation (`game.dart` et `game_rules.dart` absents).

<!-- file: test/games/game_rules_test.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/game_rules.dart';
import 'package:portail_met/npcs/npc_loan.dart';

import '../characters/character_test.dart' show sample;

/// Partie de test : samedi 3 octobre, gel le mardi 29 septembre à 20h, levée le dimanche 4 octobre à 6h.
/// [year] 2099 pour les écrans qui lisent l'heure de l'appareil (le 3 octobre 2099 est aussi un samedi).
Game frozenGame({String id = 'g2', int year = 2026, List<String> sheetIds = const ['x'], DateTime? liftedAt}) => Game(
      id: id,
      date: DateTime(year, 10, 3),
      frozenAt: DateTime(year, 9, 29, 20),
      until: DateTime(year, 10, 4, 6),
      liftedAt: liftedAt,
      byUid: 'lea',
      sheetIds: sheetIds,
    );

Character npc(String id, {CharacterStatus status = CharacterStatus.active}) =>
    Character(id: id, name: 'Octave Marchetti', kind: CharacterKind.pnj, status: status);

void main() {
  test('partie et version figée lues depuis Firestore', () {
    final g = Game.fromMap('g2', {
      'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'frozenAt': Timestamp.fromDate(DateTime(2026, 9, 29, 20)),
      'until': Timestamp.fromDate(DateTime(2026, 10, 4, 6)),
      'liftedAt': null,
      'liftedByUid': null,
      'byUid': 'lea',
      'sheetIds': ['x', 'n1'],
    });
    expect(g.date, DateTime(2026, 10, 3));
    expect(g.until, DateTime(2026, 10, 4, 6));
    expect(g.liftedAt, isNull);
    expect(g.sheetIds, ['x', 'n1']);
    final s = FrozenSheet.fromMap('x', 'g2', {
      'sheet': sample().toMap(),
      'version': 4,
      'gameDate': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'at': null,
      'byUid': 'lea',
      'reason': null,
    });
    expect(s.character.name, 'Isaure de Valcourt');
    expect(s.character.id, 'x');
    expect(s.version, 4);
    expect(s.gameDate, DateTime(2026, 10, 3));
    expect(s.reason, isNull);
  });

  test('fiches à figer : PJ actifs et PNJ au prêt actif seulement', () {
    final now = DateTime(2026, 10, 2);
    NpcLoan loan(String id, {DateTime? until, DateTime? revokedAt}) =>
        NpcLoan(characterId: id, from: DateTime(2026, 10, 1), until: until ?? DateTime(2026, 10, 10), revokedAt: revokedAt);
    final sheets = [
      sample(),
      Character(id: 'd', name: 'Brouillon', kind: CharacterKind.pj, playerUid: 'u2'),
      Character.fromMap('m', {...sample().toMap(), 'status': 'dead'}),
      npc('n1'),
      npc('n2'),
      npc('n3'),
      npc('n4'),
      npc('n5', status: CharacterStatus.dead),
    ];
    final loans = [
      loan('n1'),
      loan('n3', until: DateTime(2026, 10, 1, 12)),
      loan('n4', revokedAt: DateTime(2026, 10, 1, 13)),
      loan('n5'),
    ];
    expect([for (final c in sheetsToFreeze(sheets, loans, now)) c.id], ['x', 'n1']);
  });

  test('gel en cours : avant la levée prévue, sans levée anticipée (Review Focus 3)', () {
    final g = frozenGame();
    expect(isRunning(g, DateTime(2026, 10, 4, 5, 59)), isTrue);
    expect(isRunning(g, DateTime(2026, 10, 4, 6)), isFalse);
    expect(isRunning(frozenGame(liftedAt: DateTime(2026, 10, 1)), DateTime(2026, 10, 2)), isFalse);
  });

  test('fiche figée : dans le gel en cours seulement', () {
    final now = DateTime(2026, 10, 2);
    final games = [frozenGame(id: 'g1', sheetIds: const ['y'], liftedAt: DateTime(2026, 10, 1)), frozenGame()];
    expect(frozenBy(games, 'x', now)?.id, 'g2');
    expect(frozenBy(games, 'y', now), isNull);
    expect(frozenBy(games, 'x', DateTime(2026, 10, 5)), isNull);
    expect(runningGame(games, now)?.id, 'g2');
    expect(runningGame(games, DateTime(2026, 10, 5)), isNull);
  });

  test('gel précédent : le dernier figé avant celui-ci', () {
    final a = Game(id: 'a', date: DateTime(2026, 7, 4), frozenAt: DateTime(2026, 7, 1), until: DateTime(2026, 7, 5));
    final b = Game(id: 'b', date: DateTime(2026, 8, 29), frozenAt: DateTime(2026, 8, 28, 20), until: DateTime(2026, 8, 30, 6));
    final c = frozenGame();
    expect(previousGame([c, b, a], c)?.id, 'b');
    expect(previousGame([a, c, b], c)?.id, 'b');
    expect(previousGame([c, b, a], a), isNull);
  });

  test('levée : par défaut le lendemain à 6h, sinon la saisie', () {
    final d = DateTime(2026, 10, 3);
    expect(defaultUntil(d), DateTime(2026, 10, 4, 6));
    expect(defaultUntil(DateTime(2026, 10, 31)), DateTime(2026, 11, 1, 6));
    expect(untilOf(d, '', ''), DateTime(2026, 10, 4, 6));
    expect(untilOf(d, '05/10/2026', ''), DateTime(2026, 10, 5, 6));
    expect(untilOf(d, '', '20h30'), DateTime(2026, 10, 4, 20, 30));
    expect(untilOf(d, '05/10/2026', '02:15'), DateTime(2026, 10, 5, 2, 15));
    expect(untilOf(d, '32/10/2026', ''), isNull);
    expect(untilOf(d, '', '25:00'), isNull);
  });

  test('heure : formes acceptées', () {
    expect(parseTime('6'), (6, 0));
    expect(parseTime('06:00'), (6, 0));
    expect(parseTime('20h'), (20, 0));
    expect(parseTime('20h30'), (20, 30));
    expect(parseTime(' 7:05 '), (7, 5));
    expect(parseTime('24:00'), isNull);
    expect(parseTime('7:60'), isNull);
    expect(parseTime('midi'), isNull);
  });

  test('nouveau gel : contrôles du formulaire', () {
    final now = DateTime(2026, 10, 1, 12);
    expect(freezePlan('xx', '', '', now).error, 'Date de partie invalide');
    expect(freezePlan('03/10/2026', 'demain', '', now).error, 'Levée invalide');
    expect(freezePlan('03/10/2026', '30/09/2026', '', now).error, 'La levée doit être dans le futur.');
    final ok = freezePlan('03/10/2026', '', '', now);
    expect(ok.error, isNull);
    expect(ok.date, DateTime(2026, 10, 3));
    expect(ok.until, DateTime(2026, 10, 4, 6));
  });

  test('changements depuis le gel précédent', () {
    final a = sample();
    expect(changeCount(a, sample()), 0);
    expect(changeLabel(changeCount(a, sample())), 'Aucun');
    expect(changeLabel(changeCount(a, sample()..humanity = 5)), '1 changement');
    expect(changeLabel(changeCount(a, sample()
      ..humanity = 5
      ..willpower = 4)), '2 changements');
    expect(changeCount(null, a), isNull);
    expect(changeLabel(null), 'Première version figée');
  });

  test('textes du gel', () {
    final g = frozenGame();
    expect(gameTitle(g), 'Gel en cours · partie du samedi 3 octobre');
    expect(gameSpanText(g), 'Depuis le mardi 29 sept. à 20h, jusqu’au dimanche 4 oct. à 6h');
    expect(playerFreezeText(g), 'Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct.');
    expect(staffFreezeText(g), 'Figée pour la partie du samedi 3 oct., jusqu’au dimanche 4 oct. à 6h : son XP ne peut pas changer.');
    expect(frozenUntilText(g), 'Fiche figée jusqu’au 4 oct.');
    expect(hourText(DateTime(2026, 10, 4, 20, 5)), '20h05');
    expect(shortDay(DateTime(2026, 10, 3)), 'samedi 3 oct.');
    expect(dayAndHour(DateTime(2026, 10, 4, 6)), 'dimanche 4 oct. à 6h');
    expect(slashDay(DateTime(2026, 10, 4)), '04/10/2026');
    // « mai » n'a pas de point d'abréviation : la phrase en reçoit un.
    final may = Game(date: DateTime(2026, 5, 2), frozenAt: DateTime(2026, 4, 28), until: DateTime(2026, 5, 3, 6));
    expect(playerFreezeText(may), 'Fiche figée pour la partie du samedi 2 mai. Vos demandes restent en file et seront traitées à partir du 3 mai.');
  });

  test('nombre de fiches à figer, gain retenu', () {
    final sheets = [for (var i = 0; i < 38; i++) sample(), for (var i = 0; i < 4; i++) npc('n$i')];
    expect(freezeCountText(sheets), '42 fiches seront figées : 38 PJ actifs et 4 PNJ confiés.');
    expect(freezeCountText([sample()]), '1 fiche sera figée : 1 PJ actif et 0 PNJ confié.');
    expect(frozenGainText(1), '1 fiche figée : son gain sera versé après le gel.');
    expect(frozenGainText(3), '3 fiches figées : leur gain sera versé après le gel.');
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 1 impl`.

<!-- file: lib/games/game.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();

/// Une partie (`games/{id}`) et le gel de ses fiches (sous-projet 8a).
class Game {
  const Game({
    this.id = '',
    required this.date,
    required this.frozenAt,
    required this.until,
    this.liftedAt,
    this.liftedByUid,
    this.byUid = '',
    this.sheetIds = const [],
  });

  /// L'heure du gel est celle du serveur : absente de l'écho local de l'écriture, on prend celle de l'appareil.
  factory Game.fromMap(String id, Map<String, dynamic> m) => Game(
        id: id,
        date: _date(m['date']) ?? DateTime(2000),
        frozenAt: _date(m['frozenAt']) ?? DateTime.now(),
        until: _date(m['until']) ?? DateTime(2000),
        liftedAt: _date(m['liftedAt']),
        liftedByUid: m['liftedByUid'] as String?,
        byUid: m['byUid'] as String? ?? '',
        sheetIds: [for (final s in (m['sheetIds'] as List?) ?? const []) '$s'],
      );

  final String id;

  /// Jour de la partie (minuit, heure locale).
  final DateTime date;
  final DateTime frozenAt;

  /// Levée prévue : le gel s'arrête seul à cette heure.
  final DateTime until;
  final DateTime? liftedAt;
  final String? liftedByUid;
  final String byUid;
  final List<String> sheetIds;
}

/// Version figée d'une fiche (`characters/{id}/frozen/{gameId}`).
class FrozenSheet {
  const FrozenSheet({
    required this.characterId,
    required this.gameId,
    required this.sheet,
    required this.version,
    required this.gameDate,
    this.at,
    this.byUid = '',
    this.reason,
  });

  factory FrozenSheet.fromMap(String characterId, String gameId, Map<String, dynamic> m) => FrozenSheet(
        characterId: characterId,
        gameId: gameId,
        sheet: m['sheet'] is Map ? Map<String, dynamic>.from(m['sheet'] as Map) : const {},
        version: (m['version'] as num?)?.toInt() ?? 0,
        gameDate: _date(m['gameDate']) ?? DateTime(2000),
        at: _date(m['at']),
        byUid: m['byUid'] as String? ?? '',
        reason: m['reason'] as String?,
      );

  final String characterId;
  final String gameId;

  /// La fiche au moment de la copie (`Character.toMap()`).
  final Map<String, dynamic> sheet;

  /// Version de la fiche copiée : la fiche actuelle en diffère si elle a changé depuis.
  final int version;
  final DateTime gameDate;
  final DateTime? at;
  final String byUid;

  /// Null pour la copie du gel ; le motif d'une correction urgente sinon.
  final String? reason;

  Character get character => Character.fromMap(characterId, sheet);
}
```

<!-- file: lib/games/game_rules.dart -->
```dart
import '../characters/character.dart';
import '../characters/describe_changes.dart';
import '../core/dates.dart';
import '../npcs/loan_rules.dart';
import '../npcs/npc_loan.dart';
import 'game.dart';

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// Gel en cours : ni levé, ni dépassé (les règles Firestore font le même calcul avec `request.time`).
bool isRunning(Game g, DateTime now) => g.liftedAt == null && now.isBefore(g.until);

Game? runningGame(List<Game> games, DateTime now) => games.where((g) => isRunning(g, now)).firstOrNull;

/// Gel en cours qui fige [characterId], ou null.
Game? frozenBy(List<Game> games, String characterId, DateTime now) =>
    games.where((g) => isRunning(g, now) && g.sheetIds.contains(characterId)).firstOrNull;

/// Dernier gel figé avant [g] : la référence de la comparaison.
Game? previousGame(List<Game> games, Game g) {
  Game? best;
  for (final x in games) {
    if (x.frozenAt.isBefore(g.frozenAt) && (best == null || x.frozenAt.isAfter(best.frozenAt))) best = x;
  }
  return best;
}

/// Fiches jouées à la partie : PJ actifs, et PNJ actifs dont un prêt est en cours.
List<Character> sheetsToFreeze(List<Character> sheets, List<NpcLoan> loans, DateTime now) {
  final lent = {for (final l in loans) if (loanState(l, now) == LoanState.active) l.characterId};
  return [
    for (final c in sheets)
      if (c.status == CharacterStatus.active && (c.kind == CharacterKind.pj || lent.contains(c.id))) c,
  ];
}

/// Levée par défaut : le lendemain de la partie à 6h.
DateTime defaultUntil(DateTime date) => DateTime(date.year, date.month, date.day + 1, 6);

/// « 6 », « 06:00 », « 20h », « 20h30 » ; null sinon.
(int, int)? parseTime(String text) {
  final m = RegExp(r'^(\d{1,2})(?:[:h](\d{2})?)?$').firstMatch(text.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2] ?? '0');
  return h < 24 && min < 60 ? (h, min) : null;
}

/// Levée choisie. Jour vide : le lendemain de la partie ; heure vide : 6h. Null si la saisie est invalide.
DateTime? untilOf(DateTime date, String day, String time) {
  final d = day.trim().isEmpty ? DateTime(date.year, date.month, date.day + 1) : parseDay(day);
  final t = time.trim().isEmpty ? (6, 0) : parseTime(time);
  if (d == null || t == null) return null;
  return DateTime(d.year, d.month, d.day, t.$1, t.$2);
}

typedef FreezePlan = ({DateTime? date, DateTime? until, String? error});

/// Contrôles du formulaire « Nouveau gel ».
FreezePlan freezePlan(String dateText, String untilDay, String untilTime, DateTime now) {
  final date = parseDay(dateText);
  if (date == null) return (date: null, until: null, error: 'Date de partie invalide');
  final until = untilOf(date, untilDay, untilTime);
  if (until == null) return (date: date, until: null, error: 'Levée invalide');
  if (!until.isAfter(now)) return (date: date, until: until, error: 'La levée doit être dans le futur.');
  return (date: date, until: until, error: null);
}

/// Nombre de changements entre deux versions figées ; null sans version précédente.
int? changeCount(Character? before, Character after) => before == null ? null : describeChanges(before, after).length;

String changeLabel(int? n) => switch (n) {
      null => 'Première version figée',
      0 => 'Aucun',
      1 => '1 changement',
      _ => '$n changements',
    };

String _two(int n) => n.toString().padLeft(2, '0');

String _weekday(DateTime d) => _weekdays[d.weekday - 1];

/// Termine une phrase : « 4 oct. » garde son point, « 3 mai » en reçoit un.
String _sentence(String s) => s.endsWith('.') ? s : '$s.';

/// « 6h », « 20h05 ».
String hourText(DateTime d) => d.minute == 0 ? '${d.hour}h' : '${d.hour}h${_two(d.minute)}';

/// « samedi 3 oct. ».
String shortDay(DateTime d) => '${_weekday(d)} ${formatDay(d)}';

/// « dimanche 4 oct. à 6h ».
String dayAndHour(DateTime d) => '${shortDay(d)} à ${hourText(d)}';

/// « 04/10/2026 ».
String slashDay(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String gameTitle(Game g) => 'Gel en cours · partie du ${_weekday(g.date)} ${g.date.day} ${_months[g.date.month - 1]}';

String gameSpanText(Game g) => 'Depuis le ${dayAndHour(g.frozenAt)}, jusqu’au ${dayAndHour(g.until)}';

/// Bandeau du joueur (J-Fiche, « Dépenser de l'XP »).
String playerFreezeText(Game g) =>
    'Fiche figée pour la partie du ${_sentence(shortDay(g.date))} Vos demandes restent en file et seront traitées à partir du ${_sentence(formatDay(g.until))}';

/// Bandeau du conte (C3).
String staffFreezeText(Game g) => 'Figée pour la partie du ${shortDay(g.date)}, jusqu’au ${dayAndHour(g.until)} : son XP ne peut pas changer.';

/// Raison d'un bouton ou d'une case désactivés.
String frozenUntilText(Game g) => 'Fiche figée jusqu’au ${formatDay(g.until)}';

String freezeCountText(List<Character> sheets) {
  final n = sheets.length;
  final pj = sheets.where((c) => c.kind == CharacterKind.pj).length;
  final npc = n - pj;
  return '${n == 1 ? '1 fiche sera figée' : '$n fiches seront figées'} : '
      '$pj ${pj > 1 ? 'PJ actifs' : 'PJ actif'} et $npc ${npc > 1 ? 'PNJ confiés' : 'PNJ confié'}.';
}

String frozenGainText(int n) =>
    n == 1 ? '1 fiche figée : son gain sera versé après le gel.' : '$n fiches figées : leur gain sera versé après le gel.';
```

- [ ] **Step 3 : vérification**

Run : `flutter test test/games/game_rules_test.dart`, puis `flutter analyze`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 4 : commit**

```
git add lib/games test/games
git commit -m "feat: gel des fiches — modèle de partie, version figée, calculs purs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : dépôt, règles Firestore, index, faux dépôt

**Files :**
- Create :
  - `lib/games/games_repository.dart` (et son `.g.dart` généré) ;
  - `rules_test/games.test.js` ;
  - `test/games/games_repository_test.dart`.
- Modify : `firestore.rules`, `firestore.indexes.json`, `test/fakes.dart`.

**Interfaces :**
- Consumes : la tâche 1 (`Game`, `FrozenSheet`).
- Produces :
  - `GamesRepository` : `watchAll()`, `watchSnapshots(String gameId, DateTime gameDate)`, `freeze(DateTime date, DateTime until, List<Character> sheets, Actor by)`, `lift(Game g, Actor by)`, `correct(Game g, Character c, String reason, Actor by)` ;
  - `snapshotData(Character c, DateTime gameDate, Actor by, String? reason)` ;
  - `gamesRepositoryProvider`, `gamesProvider` (`Stream<List<Game>>`), `gameSnapshotsProvider(String gameId, DateTime gameDate)` (`Stream<List<FrozenSheet>>`) ;
  - `FakeGamesRepository` : `calls` (`'freeze'`, `'lift:<gameId>'`, `'correct:<gameId>:<characterId>'`), `lastDate`, `lastUntil`, `lastSheetIds`, `lastReason`, `error` ;
  - `noGames` (surcharge de `gamesProvider` par une liste vide).

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 2 test`, puis les tests des règles, puis `flutter test test/games/games_repository_test.dart`.

Expected : les tests de `games.test.js` échouent (les autres passent) ; le test Dart ne compile pas (`games_repository.dart` absent).

<!-- file: rules_test/games.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, writeBatch, serverTimestamp, collection, collectionGroup, query, where, Timestamp,
} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const creation = { purchases: [], step: 1, submittedAt: null, decidedAt: null, decidedByUid: null, comment: null };
const char = (over) => ({
  name: 'Isaure', kind: 'pj', playerUid: 'zoe', playerName: 'Zoé', status: 'active', clan: null,
  xpEarned: 0, xpSpent: 0, creation, version: 1, lastHistoryId: 'h1', createdAt: new Date(), ...over,
});

const future = () => Timestamp.fromDate(new Date(Date.now() + 2 * 86400000));
const past = () => Timestamp.fromDate(new Date(Date.now() - 86400000));
const gameDate = Timestamp.fromDate(new Date(2030, 9, 3));

const game = (uid, over = {}) => ({
  date: gameDate, frozenAt: serverTimestamp(), until: future(), liftedAt: null, liftedByUid: null, byUid: uid, sheetIds: ['zoe-pj'], ...over,
});
const snap = (uid, over = {}) => ({ sheet: { name: 'Isaure' }, version: 1, gameDate, at: serverTimestamp(), byUid: uid, reason: null, ...over });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', max: 'principal', julien: 'narrateur', zoe: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/zoe-pj'), char({}));
    await setDoc(doc(db, 'characters/tom-pj'), char({ playerUid: 'tom', playerName: 'Tom' }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();

/** Gel g0 déjà en place (règles désactivées), avec le pointeur et deux versions figées. */
async function seed(over = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'games/g0'), {
      date: gameDate, frozenAt: Timestamp.now(), until: future(), liftedAt: null, liftedByUid: null, byUid: 'lea', sheetIds: ['zoe-pj'], ...over,
    });
    await setDoc(doc(db, 'chronicle/freeze'), { gameId: 'g0' });
    for (const id of ['zoe-pj', 'tom-pj']) {
      await setDoc(doc(db, `characters/${id}/frozen/g0`), { sheet: { name: id }, version: 1, gameDate, at: Timestamp.now(), byUid: 'lea', reason: null });
    }
  });
}

/** Le lot du gel, comme GamesRepository.freeze. */
function freeze(uid, gid, over = {}, sheets = ['zoe-pj']) {
  const db = as(uid);
  const b = writeBatch(db);
  b.set(doc(db, `games/${gid}`), game(uid, { sheetIds: sheets, ...over }));
  b.set(doc(db, 'chronicle/freeze'), { gameId: gid });
  for (const s of sheets) b.set(doc(db, `characters/${s}/frozen/${gid}`), snap(uid));
  return b.commit();
}

/** Modification tracée de la fiche par Léa (règle staffEdit). */
function edit(cid, change) {
  const db = as('lea');
  const b = writeBatch(db);
  b.update(doc(db, `characters/${cid}`), { ...change, version: 2, lastHistoryId: 'h2' });
  b.set(doc(db, `characters/${cid}/history/h2`), { at: serverTimestamp(), byUid: 'lea', kind: 'edit', reason: 'Motif', summary: [] });
  return b.commit();
}

test('figer : un conteur oui, ni narrateur ni joueur', async () => {
  await assertFails(freeze('zoe', 'g1'));
  await assertFails(freeze('julien', 'g1'));
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : le principal aussi', async () => {
  await assertSucceeds(freeze('max', 'g1'));
});

test('figer : heure du serveur, levée future, clés fermées, auteur', async () => {
  await assertFails(freeze('lea', 'g1', { frozenAt: Timestamp.fromDate(new Date()) }));
  await assertFails(freeze('lea', 'g1', { until: past() }));
  await assertFails(freeze('lea', 'g1', { note: 'x' }));
  await assertFails(freeze('lea', 'g1', { byUid: 'max' }));
  await assertFails(freeze('lea', 'g1', { liftedAt: serverTimestamp(), liftedByUid: 'lea' }));
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : refusé pendant un gel en cours (Review Focus 1)', async () => {
  await seed();
  await assertFails(freeze('lea', 'g1'));
  await assertFails(freeze('max', 'g1'));
});

test('figer : permis après une levée anticipée', async () => {
  await seed({ liftedAt: Timestamp.now(), liftedByUid: 'lea' });
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : permis une fois la levée prévue passée (Review Focus 3)', async () => {
  await seed({ until: past() });
  await assertSucceeds(freeze('lea', 'g1'));
});

test('figer : 45 fiches en un lot (Review Focus 4)', async () => {
  const many = Array.from({ length: 45 }, (_, i) => `s${i}`);
  await assertSucceeds(freeze('lea', 'g1', {}, many));
});

test('figer : la fiche du conteur est figée comme les autres (Review Focus 5)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'characters/lea-pj'), char({ playerUid: 'lea' })));
  await assertSucceeds(freeze('lea', 'g1', {}, ['zoe-pj', 'lea-pj']));
});

test('pointeur et parties : lus par tout connecté ; pointeur jamais écrit seul', async () => {
  await seed({ liftedAt: Timestamp.now(), liftedByUid: 'lea' });
  await assertSucceeds(getDoc(doc(as('zoe'), 'chronicle/freeze')));
  await assertSucceeds(getDocs(collection(as('zoe'), 'games')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'chronicle/freeze')));
  await assertFails(setDoc(doc(as('lea'), 'chronicle/freeze'), { gameId: 'g0' }));
  await assertFails(setDoc(doc(as('lea'), 'chronicle/freeze'), { gameId: 'nouveau' }));
});

test('lever : gel en cours, deux champs, par le conte', async () => {
  await seed();
  const lift = (uid, extra = {}) => updateDoc(doc(as(uid), 'games/g0'), { liftedAt: serverTimestamp(), liftedByUid: uid, ...extra });
  await assertFails(lift('julien'));
  await assertFails(lift('zoe'));
  await assertFails(lift('lea', { until: future() }));
  await assertFails(updateDoc(doc(as('lea'), 'games/g0'), { liftedAt: serverTimestamp(), liftedByUid: 'max' }));
  await assertSucceeds(lift('lea'));
  await assertFails(lift('lea'));
  await assertFails(deleteDoc(doc(as('lea'), 'games/g0')));
});

test('versions figées : lues par le joueur de la fiche et par l’équipe', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(as('zoe'), 'characters/zoe-pj/frozen/g0')));
  await assertFails(getDoc(doc(as('zoe'), 'characters/tom-pj/frozen/g0')));
  await assertSucceeds(getDoc(doc(as('julien'), 'characters/tom-pj/frozen/g0')));
  const q = (uid) => getDocs(query(collectionGroup(as(uid), 'frozen'), where('gameDate', '==', gameDate)));
  await assertSucceeds(q('julien'));
  await assertFails(q('zoe'));
});

test('versions figées : écrites par le conte, corrigées avec un motif, jamais supprimées', async () => {
  await seed();
  const ref = (uid) => doc(as(uid), 'characters/zoe-pj/frozen/g0');
  await assertFails(setDoc(ref('zoe'), snap('zoe', { reason: 'Erreur' })));
  await assertFails(setDoc(ref('julien'), snap('julien', { reason: 'Erreur' })));
  await assertFails(setDoc(ref('lea'), snap('lea')));
  await assertFails(setDoc(ref('lea'), snap('lea', { reason: '' })));
  await assertFails(setDoc(ref('lea'), snap('lea', { reason: 'Erreur', extra: 1 })));
  await assertSucceeds(setDoc(ref('lea'), snap('lea', { reason: 'Erreur de saisie' })));
  await assertFails(deleteDoc(ref('lea')));
  await assertFails(setDoc(doc(as('lea'), 'characters/zoe-pj/frozen/g5'), snap('lea', { reason: 'x' })));
  await assertSucceeds(setDoc(doc(as('lea'), 'characters/zoe-pj/frozen/g5'), snap('lea')));
});

test('verrou : l’XP d’une fiche figée ne change pas, le reste si (Review Focus 2)', async () => {
  await seed();
  await assertFails(edit('zoe-pj', { xpEarned: 3 }));
  await assertFails(edit('zoe-pj', { xpSpent: 3 }));
  await assertSucceeds(edit('zoe-pj', { clan: 'Toreador' }));
});

test('verrou : une fiche hors du gel garde son XP libre', async () => {
  await seed();
  await assertSucceeds(edit('tom-pj', { xpEarned: 3 }));
});

test('verrou : sans aucun gel', async () => {
  await assertSucceeds(edit('zoe-pj', { xpEarned: 3 }));
});

test('verrou : levé par anticipation', async () => {
  await seed({ liftedAt: Timestamp.now(), liftedByUid: 'lea' });
  await assertSucceeds(edit('zoe-pj', { xpEarned: 3 }));
});

test('verrou : levée prévue passée (Review Focus 3)', async () => {
  await seed({ until: past() });
  await assertSucceeds(edit('zoe-pj', { xpEarned: 3 }));
});
```

<!-- file: test/games/games_repository_test.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/games/games_repository.dart';

import '../characters/character_test.dart' show sample;

void main() {
  test('version figée : clés des règles, fiche complète, sans motif à la création', () {
    final m = snapshotData(sample(), DateTime(2026, 10, 3), const Actor('lea', 'Léa G.'), null);
    expect(m.keys.toSet(), {'sheet', 'version', 'gameDate', 'at', 'byUid', 'reason'});
    expect(m['version'], 4);
    expect(m['gameDate'], Timestamp.fromDate(DateTime(2026, 10, 3)));
    expect(m['byUid'], 'lea');
    expect(m['reason'], isNull);
    expect((m['sheet'] as Map)['name'], 'Isaure de Valcourt');
  });

  test('correction urgente : le motif est enregistré', () {
    final m = snapshotData(sample(), DateTime(2026, 10, 3), const Actor('lea', 'Léa G.'), 'Erreur de saisie');
    expect(m['reason'], 'Erreur de saisie');
  });
}
```

- [ ] **Step 2 : règles**

Dans `firestore.rules` :

1. Juste après la ligne `function histPath(id, h) { ... }`, ajouter :

```
    function freezePath() { return /databases/$(database)/documents/chronicle/freeze; }
    function gamePath(g) { return /databases/$(database)/documents/games/$(g); }
    // Gel en cours (sous-projet 8a) : ni levé, ni dépassé.
    function gameRunning(g) { return g.liftedAt == null && request.time < g.until; }
    function noGameRunning() {
      return !exists(freezePath()) || !gameRunning(get(gamePath(get(freezePath()).data.gameId)).data);
    }
```

2. Juste après le bloc `match /chronicle/xp { ... }`, ajouter :

```
    // Parties (sous-projet 8a) : le gel fige les fiches jouées. Lues par tous ; le conte fige et lève.
    match /games/{gid} {
      allow read: if signedIn();
      allow create: if managesAccounts()
        && request.resource.data.keys().hasOnly(['date', 'frozenAt', 'until', 'liftedAt', 'liftedByUid', 'byUid', 'sheetIds'])
        && request.resource.data.date is timestamp
        && request.resource.data.frozenAt == request.time
        && request.resource.data.until is timestamp && request.resource.data.until > request.time
        && request.resource.data.liftedAt == null && request.resource.data.liftedByUid == null
        && request.resource.data.byUid == request.auth.uid
        && request.resource.data.sheetIds is list
        && getAfter(freezePath()).data.gameId == gid
        && noGameRunning();
      allow update: if managesAccounts()
        && changedOnly(['liftedAt', 'liftedByUid'])
        && gameRunning(resource.data)
        && request.resource.data.liftedAt == request.time
        && request.resource.data.liftedByUid == request.auth.uid;
    }

    // Dernière partie figée : écrite seulement avec elle, dans le même lot.
    match /chronicle/freeze {
      allow read: if signedIn();
      allow create, update: if managesAccounts()
        && request.resource.data.keys().hasOnly(['gameId'])
        && request.resource.data.gameId is string
        && !exists(gamePath(request.resource.data.gameId))
        && existsAfter(gamePath(request.resource.data.gameId));
    }

    // Versions figées de toutes les fiches (écran du gel) : l'équipe seulement.
    match /{path=**}/frozen/{g} {
      allow read: if isStaff();
    }
```

3. Dans `match /characters/{id}`, dans `staffEdit(id)`, ajouter à la fin de l’expression (après la ligne `&& getAfter(histPath(...)).data.reason.size() > 0`, avant le `;`) :

```
          && xpUnlocked(id)
```

puis, juste après la fonction `staffEdit`, ajouter :

```
      // Fiche figée (sous-projet 8a) : pendant le gel, son XP ne change pas.
      function xpUnlocked(id) {
        return !exists(freezePath()) || xpUnlockedBy(get(gamePath(get(freezePath()).data.gameId)).data, id);
      }
      function xpUnlockedBy(g, id) {
        return !(id in g.sheetIds && gameRunning(g))
          || !request.resource.data.diff(resource.data).affectedKeys().hasAny(['xpEarned', 'xpSpent']);
      }
```

4. Dans `match /characters/{id}`, juste après le bloc `match /history/{h} { ... }`, ajouter :

```
      // Version figée de la fiche (sous-projet 8a) : lue comme la fiche ; écrite par le conte ; corrigée avec un motif.
      match /frozen/{gid} {
        function snapshotValid() {
          let d = request.resource.data;
          return d.keys().hasOnly(['sheet', 'version', 'gameDate', 'at', 'byUid', 'reason'])
            && d.sheet is map && d.version is int && d.gameDate is timestamp
            && d.at == request.time && d.byUid == request.auth.uid;
        }
        allow read: if signedIn()
          && (get(charPath(id)).data.get('playerUid', null) == request.auth.uid || isStaff());
        allow create: if managesAccounts() && snapshotValid() && request.resource.data.reason == null;
        allow update: if managesAccounts() && snapshotValid()
          && request.resource.data.reason is string && request.resource.data.reason.size() > 0;
      }
```

Dans `firestore.indexes.json`, remplacer `"fieldOverrides": []` par :

```json
  "fieldOverrides": [
    {
      "collectionGroup": "frozen",
      "fieldPath": "gameDate",
      "indexes": [
        { "order": "ASCENDING", "queryScope": "COLLECTION" },
        { "order": "DESCENDING", "queryScope": "COLLECTION" },
        { "arrayConfig": "CONTAINS", "queryScope": "COLLECTION" },
        { "order": "ASCENDING", "queryScope": "COLLECTION_GROUP" }
      ]
    }
  ]
```

Run : les tests des règles.

Expected : `fail 0`. Si le test des 45 fiches échoue sur une limite de lectures, le signaler au lieu de contourner : il faudra découper le lot.

- [ ] **Step 3 : dépôt, providers, faux dépôt**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 2 impl`.

<!-- file: lib/games/games_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import 'game.dart';

part 'games_repository.g.dart';

/// Parties (`games`), pointeur `chronicle/freeze` et versions figées `characters/{id}/frozen/{gameId}`.
class GamesRepository {
  GamesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('games');

  DocumentReference<Map<String, dynamic>> _snapshot(String characterId, String gameId) => _db.doc('characters/$characterId/frozen/$gameId');

  /// Toutes les parties, la plus récemment figée d'abord.
  Stream<List<Game>> watchAll() => _col.snapshots().map(
        (q) => [for (final d in q.docs) Game.fromMap(d.id, d.data())]..sort((a, b) => b.frozenAt.compareTo(a.frozenAt)),
      );

  /// Versions figées d'une partie, sur toutes les fiches (index `frozen.gameDate`, firestore.indexes.json).
  /// Deux parties peuvent tomber le même jour : on garde celles de [gameId].
  Stream<List<FrozenSheet>> watchSnapshots(String gameId, DateTime gameDate) => _db
      .collectionGroup('frozen')
      .where('gameDate', isEqualTo: Timestamp.fromDate(gameDate))
      .snapshots()
      .map((q) => [
            for (final d in q.docs)
              if (d.id == gameId) FrozenSheet.fromMap(d.reference.parent.parent!.id, d.id, d.data()),
          ]);

  /// Fige [sheets] en un lot : la partie, le pointeur et une version figée par fiche.
  // ponytail: un seul lot, plafond de 500 écritures (environ 497 fiches) ; découper le lot si la chronique grossit à ce point.
  Future<void> freeze(DateTime date, DateTime until, List<Character> sheets, Actor by) {
    final ref = _col.doc();
    final batch = _db.batch()
      ..set(ref, {
        'date': Timestamp.fromDate(date),
        'frozenAt': FieldValue.serverTimestamp(),
        'until': Timestamp.fromDate(until),
        'liftedAt': null,
        'liftedByUid': null,
        'byUid': by.uid,
        'sheetIds': [for (final c in sheets) c.id],
      })
      ..set(_db.doc('chronicle/freeze'), {'gameId': ref.id});
    for (final c in sheets) {
      batch.set(_snapshot(c.id, ref.id), snapshotData(c, date, by, null));
    }
    return batch.commit();
  }

  /// Levée anticipée (les règles exigent l'heure du serveur).
  Future<void> lift(Game g, Actor by) => _col.doc(g.id).update({'liftedAt': FieldValue.serverTimestamp(), 'liftedByUid': by.uid});

  /// Correction urgente : la fiche actuelle remplace la version figée, avec un motif.
  Future<void> correct(Game g, Character c, String reason, Actor by) => _snapshot(c.id, g.id).set(snapshotData(c, g.date, by, reason.trim()));
}

/// Données d'une version figée. Règles : clés fermées, heure du serveur, motif nul à la création et obligatoire ensuite.
Map<String, dynamic> snapshotData(Character c, DateTime gameDate, Actor by, String? reason) => {
      'sheet': c.toMap(),
      'version': c.version,
      'gameDate': Timestamp.fromDate(gameDate),
      'at': FieldValue.serverTimestamp(),
      'byUid': by.uid,
      'reason': reason,
    };

@Riverpod(keepAlive: true)
GamesRepository gamesRepository(Ref ref) => GamesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Game>> games(Ref ref) => ref.watch(gamesRepositoryProvider).watchAll();

@riverpod
Stream<List<FrozenSheet>> gameSnapshots(Ref ref, String gameId, DateTime gameDate) =>
    ref.watch(gamesRepositoryProvider).watchSnapshots(gameId, gameDate);
```

**`test/fakes.dart` :**
- ajouter les imports `package:portail_met/games/game.dart` et `package:portail_met/games/games_repository.dart`, dans l’ordre alphabétique (après `events/story_event.dart`) ;
- ajouter à la fin :

```dart
class FakeGamesRepository implements GamesRepository {
  final calls = <String>[];
  Object? error;
  DateTime? lastDate;
  DateTime? lastUntil;
  List<String> lastSheetIds = const [];
  String? lastReason;

  @override
  Future<void> freeze(DateTime date, DateTime until, List<Character> sheets, Actor by) async {
    calls.add('freeze');
    if (error != null) throw error!;
    lastDate = date;
    lastUntil = until;
    lastSheetIds = [for (final c in sheets) c.id];
  }

  @override
  Future<void> lift(Game g, Actor by) async {
    calls.add('lift:${g.id}');
    if (error != null) throw error!;
  }

  @override
  Future<void> correct(Game g, Character c, String reason, Actor by) async {
    calls.add('correct:${g.id}:${c.id}');
    if (error != null) throw error!;
    lastReason = reason;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucune partie : pas de gel.
final noGames = gamesProvider.overrideWith((ref) => Stream.value(const <Game>[]));
```

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter analyze`, puis `flutter test`, puis les tests des règles.

Expected : propre, tous les tests passent, et les tests des règles donnent `fail 0`.

- [ ] **Step 4 : commit**

```
git add firestore.rules firestore.indexes.json rules_test/games.test.js lib/games test/games test/fakes.dart
git commit -m "feat: gel des fiches — dépôt, règles (parties, pointeur, versions figées, verrou d’XP), index" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : bandeaux du gel (fiche du joueur, « Dépenser de l’XP », C3) et XP verrouillée en C3

**Files :**
- Create : `lib/games/freeze_banner.dart`.
- Modify :
  - `lib/core/theme.dart` ;
  - `lib/characters/character_screen.dart` ;
  - `lib/xp/spend_screen.dart` ;
  - `lib/characters/character_edit_screen.dart`.
- Test (modifiés) :
  - `test/characters/character_screen_test.dart` ;
  - `test/xp/spend_screen_test.dart` ;
  - `test/characters/character_edit_test.dart` ;
  - `test/characters/edit_fixes_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2 (`frozenBy`, `playerFreezeText`, `staffFreezeText`, `frozenUntilText`, `gamesProvider`, `noGames`, `frozenGame`).
- Produces :
  - `FreezeBanner(String text)` ;
  - `AppColors.frozen`, `AppColors.frozenText`, `AppColors.frozenBg`, `AppColors.frozenBorder`.

- [ ] **Step 1 : tests (échec attendu)**

**`test/characters/character_screen_test.dart` :**
- imports : `package:portail_met/games/game.dart`, `package:portail_met/games/games_repository.dart` et `'../games/game_rules_test.dart' show frozenGame` ;
- `pump` reçoit un paramètre nommé `List<Game> games = const []`, et sa liste `overrides` la ligne `gamesProvider.overrideWith((ref) => Stream.value(games)),` ;
- ajouter les tests :

```dart
  testWidgets('J2 : fiche figée, bandeau du gel (sous-projet 8a)', (tester) async {
    await pump(tester, Stream.value(sample()), games: [frozenGame(year: 2099)]);
    expect(find.text('Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct.'), findsOneWidget);
  });

  testWidgets('J2 : gel d’une autre fiche ou gel levé, pas de bandeau', (tester) async {
    await pump(tester, Stream.value(sample()), games: [
      frozenGame(year: 2099, sheetIds: const ['y']),
      frozenGame(id: 'g1', year: 2099, liftedAt: DateTime(2026, 10, 1)),
    ]);
    expect(find.textContaining('Fiche figée'), findsNothing);
  });
```

**`test/xp/spend_screen_test.dart` :**
- mêmes imports ;
- `pump` reçoit `List<Game> games = const []` et la surcharge `gamesProvider.overrideWith((ref) => Stream.value(games)),` ;
- ajouter le test :

```dart
  testWidgets('fiche figée : rappel du gel, la demande reste possible (sous-projet 8a)', (tester) async {
    await pump(tester, games: [frozenGame(year: 2099)]);
    expect(find.text('Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct.'), findsOneWidget);
    expect(find.text('Ajouter un achat'.toUpperCase()), findsOneWidget);
  });
```

**`test/characters/character_edit_test.dart` :**
- mêmes imports ;
- `pump` reçoit `List<Game> games = const []` et la surcharge `gamesProvider.overrideWith((ref) => Stream.value(games)),` ;
- ajouter les tests :

```dart
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
```

**`test/characters/edit_fixes_test.dart` :** ajouter `noGames,` à la liste `overrides` de `pump`.

Run : `flutter test test/characters/character_screen_test.dart test/xp/spend_screen_test.dart test/characters/character_edit_test.dart test/characters/edit_fixes_test.dart`.

Expected : les nouveaux tests échouent (aucun bandeau) ; les anciens passent.

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 3 impl`.

<!-- file: lib/games/freeze_banner.dart -->
```dart
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Bandeau bleu du gel (J-Fiche, C-Figer) : cadenas et texte.
class FreezeBanner extends StatelessWidget {
  const FreezeBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.frozenBg,
          border: Border.all(color: AppColors.frozenBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.frozen),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.frozenText, fontSize: 14))),
        ]),
      );
}
```

**`lib/core/theme.dart`**, dans `AppColors`, après `deadBg` :

```dart
  // Gel des fiches (C-Figer, J-Fiche).
  static const frozen = Color(0xFFA9C8EE);
  static const frozenText = Color(0xFFC9D6E6);
  static const frozenBg = Color(0xFF1E2A3A);
  static const frozenBorder = Color(0xFF36506E);
```

**`lib/characters/character_screen.dart` :**
- imports : `'../games/freeze_banner.dart'`, `'../games/game.dart'`, `'../games/game_rules.dart'`, `'../games/games_repository.dart'` ;
- dans `CharacterScreen.build`, dans le constructeur de `asyncView`, juste avant `return PageBody(children: [` :

```dart
      // Fiche du joueur pendant un gel (J-Fiche) ; l'historique n'en a pas besoin.
      final frozen = basePath.startsWith('/joueur') && !history
          ? frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], c.id, DateTime.now())
          : null;
```

- dans la liste, juste après `CharacterHeader(...)` et son `const SizedBox(height: 22),` :

```dart
        if (frozen != null) ...[
          FreezeBanner(playerFreezeText(frozen)),
          const SizedBox(height: 22),
        ],
```

**`lib/xp/spend_screen.dart` :**
- mêmes imports (chemins `'../games/...'`) ;
- dans `_body`, après `final problems = ...` :

```dart
    final frozen = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], c.id, DateTime.now());
```

- dans `final main = Column(...)`, juste après le `Text('Le coût est calculé selon …', …),` :

```dart
      if (frozen != null) ...[
        const SizedBox(height: 12),
        FreezeBanner(playerFreezeText(frozen)),
      ],
```

**`lib/characters/character_edit_screen.dart` :**
- mêmes imports (chemins `'../games/...'`) ;
- dans `_save`, juste après `if (by == null || changes.isEmpty || _saving) return;` :

```dart
    // Fiche figée : les règles refuseraient tout changement d'XP (staffEdit) ; on le dit avant le motif.
    final frozen = frozenBy(ref.read(gamesProvider).value ?? const <Game>[], _base!.id, DateTime.now());
    if (frozen != null && (_draft!.xpEarned != _base!.xpEarned || _draft!.xpSpent != _base!.xpSpent)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${frozenUntilText(frozen)} : l’XP ne peut pas changer.')));
      return;
    }
```

- dans `build`, juste après `final me = ref.watch(currentUserProvider).value;` :

```dart
    final games = ref.watch(gamesProvider).value ?? const <Game>[];
```

- dans le constructeur d’`asyncView`, juste après le bloc `if (latest == null) { ... }` :

```dart
      final frozen = frozenBy(games, latest.id, DateTime.now());
```

- dans la branche en lecture seule, juste après `_Banner(readOnlyReason),` ; et dans la branche d’édition, juste après `const _Banner('Mode conteur — …'),` :

```dart
          if (frozen != null) ...[
            const SizedBox(height: 12),
            FreezeBanner(staffFreezeText(frozen)),
          ],
```

Run : les quatre fichiers de test de l’étape 1, puis `flutter analyze`, puis `flutter test`.

Expected : tous les tests passent ; analyseur propre. Si d’autres tests échouent faute de surcharge de `gamesProvider`, leur ajouter `noGames,`.

- [ ] **Step 3 : commit**

```
git add lib/games/freeze_banner.dart lib/core/theme.dart lib/characters/character_screen.dart lib/xp/spend_screen.dart lib/characters/character_edit_screen.dart test/characters test/xp/spend_screen_test.dart
git commit -m "feat: gel des fiches — bandeaux (fiche, dépense d’XP, C3) et XP verrouillée en C3" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : XP verrouillée dans la validation, le gain, l’attribution et les corrections

**Files :**
- Modify :
  - `lib/xp/request_review.dart` ;
  - `lib/xp/xp_admin_screen.dart` ;
  - `lib/xp/corrections_screen.dart`.
- Test (modifiés) :
  - `test/creation/validation_screen_test.dart` ;
  - `test/xp/xp_admin_test.dart` ;
  - `test/xp/corrections_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2 (`frozenBy`, `frozenUntilText`, `frozenGainText`, `gamesProvider`, `frozenGame`).
- Produces : rien de nouveau.

- [ ] **Step 1 : tests (échec attendu)**

Dans chacun des trois fichiers :
- imports : `package:portail_met/games/game.dart`, `package:portail_met/games/games_repository.dart` et `'../games/game_rules_test.dart' show frozenGame` ;
- `pump` reçoit un paramètre nommé `List<Game> games = const []`, et sa liste `overrides` la ligne `gamesProvider.overrideWith((ref) => Stream.value(games)),`.

**`test/creation/validation_screen_test.dart`**, ajouter :

```dart
  testWidgets('dépense sur une fiche figée : validation bloquée, refus possible (sous-projet 8a, Review Focus 2)', (tester) async {
    await pump(tester, const [], requests: [auspex()], games: [frozenGame(year: 2099)]);
    expect(find.text('Fiche figée jusqu’au 4 oct.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider la dépense')).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Refuser')).onPressed, isNotNull);
  });

  testWidgets('dépense : gel d’une autre fiche, validation possible (sous-projet 8a)', (tester) async {
    await pump(tester, const [], requests: [auspex()], games: [frozenGame(year: 2099, sheetIds: const ['y'])]);
    expect(find.textContaining('Fiche figée'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider la dépense')).onPressed, isNotNull);
  });
```

**`test/xp/xp_admin_test.dart`**, ajouter :

```dart
  testWidgets('fiche figée : hors du gain mensuel, bonus impossible (sous-projet 8a, Review Focus 2)', (tester) async {
    await pump(tester, games: [frozenGame(year: 2099)]);
    expect(find.text('1 fiche figée : son gain sera versé après le gel.'), findsOneWidget);
    expect(find.text('Verser 6 XP'), findsNothing);
    expect(tester.widget<Checkbox>(find.byKey(const Key('award-x'))).onChanged, isNull);
    expect(find.text('Fiche figée jusqu’au 4 oct.'), findsOneWidget);
  });
```

**`test/xp/corrections_test.dart`**, ajouter :

```dart
  testWidgets('fiche figée : proposée mais non sélectionnable (sous-projet 8a, Review Focus 2)', (tester) async {
    await pump(tester, sample(), games: [frozenGame(year: 2099)]);
    await tester.tap(find.byKey(const Key('corr-sheet')));
    await tester.pumpAndSettle();
    const label = 'Isaure de Valcourt · Camille R. · Fiche figée jusqu’au 4 oct.';
    expect(find.text(label), findsWidgets);
    await tester.tap(find.text(label).last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer la correction'), findsNothing);
  });
```

Run : `flutter test test/creation/validation_screen_test.dart test/xp/xp_admin_test.dart test/xp/corrections_test.dart`.

Expected : les nouveaux tests échouent ; les anciens passent.

- [ ] **Step 2 : implémentation**

**`lib/xp/request_review.dart` :**
- imports : `'../games/game.dart'`, `'../games/game_rules.dart'`, `'../games/games_repository.dart'` ;
- dans `build`, juste après `final after = c.xpAvailable - reservedOthers - total;` :

```dart
        // Pendant le gel, une dépense ne se valide pas (règle staffEdit) ; une demande à 0 XP, si.
        final frozen = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], c.id, DateTime.now());
        final xpLocked = frozen != null && total > 0;
```

- dans le `Panel` de décision, juste avant le `Wrap` des boutons (après le bloc `if (_error != null) ...[...]` et son `const SizedBox(height: 12),`) :

```dart
                if (xpLocked) ...[
                  Text(frozenUntilText(frozen!), style: t.bodyMedium?.copyWith(color: AppColors.frozen)),
                  const SizedBox(height: 8),
                ],
```

- le bouton « Valider la dépense » devient `onPressed: blocked || xpLocked || _busy ? null : () => _decide(c, RequestStatus.accepted, rb),`.

**`lib/xp/xp_admin_screen.dart` :**
- mêmes imports ;
- dans `_body`, remplacer la ligne `final payable = [for (final d in dues) if (d.c.playerUid != me.uid) d];` par :

```dart
    final games = ref.watch(gamesProvider).value ?? const <Game>[];
    Game? frozen(Character c) => frozenBy(games, c.id, widget.now());
    // Fiche figée : son XP ne bouge pas pendant le gel (règle staffEdit) ; ses mois seront versés après la levée.
    final payable = [for (final d in dues) if (d.c.playerUid != me.uid && frozen(d.c) == null) d];
    final held = dues.where((d) => d.c.playerUid != me.uid && frozen(d.c) != null).length;
```

- dans `gainCard`, juste après le bloc `if (mine.isNotEmpty) ...[...]` :

```dart
        if (held > 0) ...[
          const SizedBox(height: 8),
          Text(frozenGainText(held), style: t.bodySmall?.copyWith(color: AppColors.frozen)),
        ],
```

- remplacer `final selectable = [for (final c in actives) if (c.playerUid != me.uid) c];` par :

```dart
    final selectable = [for (final c in actives) if (c.playerUid != me.uid && frozen(c) == null) c];
```

- dans la rangée de chaque fiche, le `Tooltip` et la `Checkbox` deviennent :

```dart
              Tooltip(
                message: c.playerUid == me.uid ? 'Votre propre fiche' : (frozen(c) == null ? '' : frozenUntilText(frozen(c)!)),
                child: Checkbox(
                  key: Key('award-${c.id}'),
                  value: _selected.containsKey(c.id),
                  onChanged: c.playerUid == me.uid || frozen(c) != null
                      ? null
                      : (on) => setState(() => on == true ? _selected[c.id] = _amount : _selected.remove(c.id)),
                ),
              ),
```

- dans la même rangée, juste après `SizedBox(width: 90, child: Text('${c.xpAvailable} XP', style: t.bodySmall)),` :

```dart
              if (frozen(c) case final g?) Text(frozenUntilText(g), style: t.bodySmall?.copyWith(color: AppColors.frozen)),
```

**`lib/xp/corrections_screen.dart` :**
- mêmes imports ;
- dans `build`, dans le constructeur d’`asyncView(ref.watch(allCharactersProvider), (chars) {`, juste après `final names = ...` :

```dart
      final games = ref.watch(gamesProvider).value ?? const <Game>[];
      final now = DateTime.now();
```

- la ligne `final sheet = options.where((c) => c.id == _sheetId).firstOrNull;` devient :

```dart
      // Une fiche figée ne se corrige pas pendant le gel (règle staffEdit).
      final sheet = options.where((c) => c.id == _sheetId && frozenBy(games, c.id, now) == null).firstOrNull;
```

- les `items` du menu `corr-sheet` deviennent :

```dart
            items: [
              for (final c in options)
                if (frozenBy(games, c.id, now) case final g?)
                  DropdownMenuItem(value: c.id, enabled: false, child: Text('${c.name} · ${c.playerName ?? 'PNJ'} · ${frozenUntilText(g)}'))
                else
                  DropdownMenuItem(value: c.id, child: Text('${c.name} · ${c.playerName ?? 'PNJ'}')),
            ],
```

Run : les trois fichiers de test de l’étape 1, puis `flutter analyze`, puis `flutter test`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 3 : commit**

```
git add lib/xp test/creation/validation_screen_test.dart test/xp
git commit -m "feat: gel des fiches — XP verrouillée en validation, gain mensuel, bonus et corrections" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : écran « Gel des fiches » (C-Figer)

**Files :**
- Create : `lib/games/freeze_screen.dart`.
- Modify : `lib/router.dart`, `lib/characters/characters_list_screen.dart`.
- Test : `test/games/freeze_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 à 3 (`Game`, `FrozenSheet`, calculs et textes, `gamesProvider`, `gameSnapshotsProvider`, `gamesRepositoryProvider`, `FakeGamesRepository`, `AppColors.frozen*`), plus `allCharactersProvider`, `allNpcLoansProvider`, `openRequestsProvider`.
- Produces : `FreezeScreen({now})` sur `/conteur/gel`, avec les clés `freeze-date`, `freeze-until-day`, `freeze-until-time`, `freeze-reason`, `freeze-row-<id>`, `kpi-sheets`, `kpi-requests`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 5 test`, puis `flutter test test/games/freeze_screen_test.dart`.

Expected : échec de compilation (`freeze_screen.dart` absent).

<!-- file: test/games/freeze_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/freeze_screen.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

import '../characters/character_test.dart' show sample;
import '../fakes.dart';
import 'game_rules_test.dart' show frozenGame, npc;

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);
  const zoe = AppUser(uid: 'zoe', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur);
  final now = DateTime(2026, 10, 1, 12);

  // Gel précédent, levé depuis longtemps : partie du samedi 29 août, figée le vendredi 28 à 20h.
  final g1 = Game(id: 'g1', date: DateTime(2026, 8, 29), frozenAt: DateTime(2026, 8, 28, 20), until: DateTime(2026, 8, 30, 6), byUid: 'lea', sheetIds: const ['x', 'y']);
  final g2 = frozenGame(sheetIds: const ['x', 'y', 'n1']);
  Character bastien() => Character.fromMap('y', {...sample().toMap(), 'name': 'Bastien Roche', 'playerUid': 'u2', 'playerName': 'Karim L.'});
  FrozenSheet snap(Game g, Character c) => FrozenSheet(characterId: c.id, gameId: g.id, sheet: c.toMap(), version: c.version, gameDate: g.date);
  final loan = NpcLoan(characterId: 'n1', characterName: 'Octave Marchetti', playerUid: 'u1', playerName: 'Camille R.', from: DateTime(2026, 9, 1), until: DateTime(2026, 10, 10));
  XpRequest auspex() => XpRequest(
        id: 'r1',
        characterId: 'x',
        characterName: 'Isaure de Valcourt',
        playerUid: 'u1',
        playerName: 'Camille R.',
        status: RequestStatus.pending,
        items: [const XpItem(XpKind.discipline, 'Auspex', 3, 4, 12)],
      );

  // Gel en cours : Isaure a changé depuis le gel précédent, Bastien non, Octave est figé pour la première fois.
  // La fiche actuelle d'Isaure (version 5) a changé depuis sa version figée (version 4).
  final current = [snap(g2, sample()..humanity = 5), snap(g2, bastien()), snap(g2, npc('n1'))];
  final before = [snap(g1, sample()), snap(g1, bastien())];

  Future<FakeGamesRepository> pump(
    WidgetTester tester, {
    AppUser me = lea,
    List<Game> games = const [],
    List<Character>? chars,
    List<NpcLoan> loans = const [],
    List<XpRequest> requests = const [],
    Size size = const Size(1440, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeGamesRepository();
    await tester.pumpWidget(ProviderScope(
      // Clé neuve : un second pump dans le même test repart d'une portée vierge.
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(me)),
        gamesRepositoryProvider.overrideWith((ref) => repo),
        gamesProvider.overrideWith((ref) => Stream.value(games)),
        allCharactersProvider.overrideWith((ref) => Stream.value(chars ?? [sample()..version = 5, bastien(), npc('n1')])),
        allNpcLoansProvider.overrideWith((ref) => Stream.value(loans)),
        openRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        gameSnapshotsProvider('g2', g2.date).overrideWith((ref) => Stream.value(current)),
        gameSnapshotsProvider('g1', g1.date).overrideWith((ref) => Stream.value(before)),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: FreezeScreen(now: () => now))),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('sans gel : compte des fiches, levée prévue, figer', (tester) async {
    final repo = await pump(tester, games: [g1], loans: [loan]);
    expect(find.text('3 fiches seront figées : 2 PJ actifs et 1 PNJ confié.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('freeze-date')), '03/10/2026');
    await tester.pump();
    expect(find.text('Levée prévue : dimanche 4 oct. à 6h'), findsOneWidget);
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Figer'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['freeze']);
    expect(repo.lastSheetIds, ['x', 'y', 'n1']);
    expect(repo.lastDate, DateTime(2026, 10, 3));
    expect(repo.lastUntil, DateTime(2026, 10, 4, 6));
  });

  testWidgets('sans gel : date invalide, levée passée, refus', (tester) async {
    final repo = await pump(tester, games: [g1]);
    expect(find.text('2 fiches seront figées : 2 PJ actifs et 0 PNJ confié.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('freeze-date')), 'xx');
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    expect(find.text('Date de partie invalide'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('freeze-date')), '03/10/2026');
    await tester.enterText(find.byKey(const Key('freeze-until-day')), '30/09/2026');
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    expect(find.text('La levée doit être dans le futur.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byKey(const Key('freeze-until-day')), '');
    repo.error = Exception('refusé');
    await tester.tap(find.text('Figer maintenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Figer'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('freeze-date'))).controller!.text, '03/10/2026');
  });

  testWidgets('gel dépassé : le formulaire revient (Review Focus 3)', (tester) async {
    final past = Game(id: 'g3', date: DateTime(2026, 9, 26), frozenAt: DateTime(2026, 9, 22), until: DateTime(2026, 9, 27, 6), sheetIds: const ['x']);
    await pump(tester, games: [past]);
    expect(find.text('Figer maintenant'), findsOneWidget);
    expect(find.text('Lever le gel'), findsNothing);
  });

  testWidgets('gel en cours : bandeau, tableau, comparaison, filtre', (tester) async {
    await pump(tester, games: [g1, g2], requests: [auspex()]);
    expect(find.text('Gel en cours · partie du samedi 3 octobre'), findsOneWidget);
    expect(find.text('Depuis le mardi 29 sept. à 20h, jusqu’au dimanche 4 oct. à 6h'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('kpi-sheets'))).data, '3');
    expect(tester.widget<Text>(find.byKey(const Key('kpi-requests'))).data, '1');
    expect(find.text('Depuis le gel du 28 août'), findsOneWidget);
    expect(find.text('1 changement'), findsOneWidget);
    expect(find.text('Aucun'), findsOneWidget);
    expect(find.text('Première version figée'), findsOneWidget);
    expect(find.text('Auspex ●●●● · 12 XP'), findsOneWidget);
    expect(find.text('Humanité 0 → 5'), findsOneWidget);
    await tester.tap(find.text('Modifiées'));
    await tester.pump();
    expect(find.text('Bastien Roche · PJ'), findsNothing);
    expect(find.text('Isaure de Valcourt · PJ'), findsOneWidget);
    expect(find.text('Octave Marchetti · PNJ'), findsOneWidget);
  });

  testWidgets('correction urgente : motif obligatoire, puis version figée mise à jour', (tester) async {
    final repo = await pump(tester, games: [g1, g2]);
    await tester.tap(find.text('Correction urgente…'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mettre à jour la version figée')).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('freeze-reason')), 'Erreur de saisie');
    await tester.pump();
    await tester.tap(find.text('Mettre à jour la version figée'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['correct:g2:x']);
    expect(repo.lastReason, 'Erreur de saisie');
    await tester.tap(find.byKey(const Key('freeze-row-y')));
    await tester.pump();
    expect(find.text('Aucun changement à reporter'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Correction urgente…')).onPressed, isNull);
  });

  testWidgets('sa propre fiche : pas de correction (Review Focus 5)', (tester) async {
    await pump(tester, games: [g1, g2], chars: [sample()
      ..version = 5
      ..playerUid = 'lea', bastien(), npc('n1')]);
    expect(find.text('Votre propre fiche : un autre conteur doit la corriger.'), findsOneWidget);
    expect(find.text('Correction urgente…'), findsNothing);
  });

  testWidgets('lever le gel', (tester) async {
    final repo = await pump(tester, games: [g1, g2]);
    await tester.tap(find.text('Lever le gel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lever'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['lift:g2']);
  });

  testWidgets('narrateur : lecture seule', (tester) async {
    await pump(tester, me: julien, games: [g1, g2]);
    expect(find.text('Gel en cours · partie du samedi 3 octobre'), findsOneWidget);
    expect(find.text('Lever le gel'), findsNothing);
    expect(find.text('Correction urgente…'), findsNothing);
  });

  testWidgets('narrateur sans gel : rien à figer', (tester) async {
    await pump(tester, me: julien, games: [g1]);
    expect(find.text('Aucun gel en cours.'), findsOneWidget);
    expect(find.text('Figer maintenant'), findsNothing);
  });

  testWidgets('joueur : réservé à l’équipe', (tester) async {
    await pump(tester, me: zoe, games: [g2]);
    expect(find.text('Réservé à l’équipe'), findsOneWidget);
  });

  testWidgets('390 px : formulaire et gel en cours sans débordement', (tester) async {
    await pump(tester, games: [g1], size: const Size(390, 3000));
    expect(tester.takeException(), isNull);
    await pump(tester, games: [g1, g2], requests: [auspex()], size: const Size(390, 3000));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-17-parties-gel.md 5 impl`.

<!-- file: lib/games/freeze_screen.dart -->
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/describe_changes.dart';
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show parseDay;
import '../npcs/npc_loans_repository.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'game.dart';
import 'game_rules.dart';
import 'games_repository.dart';

const _during = [
  'Dépenses et gains d’XP bloqués ; les demandes restent en file.',
  'Une nouvelle fiche peut être validée, pour la partie suivante.',
  'Saisies de jeu permises : péchés, événements, liens de sang, titres.',
  'Correction urgente : avec motif, elle met à jour la version figée.',
];

int? _count(FrozenSheet? snap, FrozenSheet? old) => snap == null || old == null ? null : changeCount(old.character, snap.character);

/// Ligne du tableau : la fiche actuelle, sa version figée, celle du gel précédent et ses demandes ouvertes.
class _Row {
  _Row(this.live, this.snap, this.old, this.requests) : changes = _count(snap, old);
  final Character live;
  final FrozenSheet? snap;
  final FrozenSheet? old;
  final List<XpRequest> requests;
  final int? changes;

  String get diffLabel => snap == null ? '—' : changeLabel(changes);

  /// « Modifiées » : changée depuis le gel précédent, ou figée pour la première fois.
  bool get modified => snap != null && (old == null || changes! > 0);
}

/// « Gel des fiches » (C-Figer) : figer les fiches avant une partie, suivre le gel, corriger une version figée.
class FreezeScreen extends ConsumerStatefulWidget {
  const FreezeScreen({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  ConsumerState<FreezeScreen> createState() => _FreezeScreenState();
}

class _FreezeScreenState extends ConsumerState<FreezeScreen> {
  final _date = TextEditingController();
  final _untilDay = TextEditingController();
  final _untilTime = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _selectedId;
  bool _onlyChanged = false;

  // La levée prévue est vérifiée chaque minute : passé l'heure, l'écran revient au formulaire.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _date.dispose();
    _untilDay.dispose();
    _untilTime.dispose();
    super.dispose();
  }

  Future<void> _freeze(List<Character> sheets) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final plan = freezePlan(_date.text, _untilDay.text, _untilTime.text, widget.now());
    if (plan.error != null) {
      setState(() => _error = plan.error);
      return;
    }
    final ok = await confirm(
      context,
      title: 'Figer les fiches',
      body: '${freezeCountText(sheets)} Leur XP ne pourra plus changer jusqu’à la levée, ${dayAndHour(plan.until!)}.',
      action: 'Figer',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).freeze(plan.date!, plan.until!, sheets, by);
      _date.clear();
      _untilDay.clear();
      _untilTime.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Fiches figées.')));
    } catch (_) {
      // Un autre membre du conte a pu figer entre-temps : les règles refusent un second gel.
      final other = runningGame(ref.read(gamesProvider).value ?? const <Game>[], widget.now());
      if (mounted) setState(() => _error = other != null ? 'Un gel est déjà en cours.' : 'Enregistrement refusé : réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lift(Game g) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final ok = await confirm(
      context,
      title: 'Lever le gel',
      body: 'L’XP des fiches figées redevient modifiable. Les versions figées sont conservées.',
      action: 'Lever',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(gamesRepositoryProvider).lift(g, by);
      messenger.showSnackBar(const SnackBar(content: Text('Gel levé.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _correct(Game g, Character live, FrozenSheet snap) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null || _busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CorrectionDialog(name: live.name, changes: describeChanges(snap.character, live)),
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(gamesRepositoryProvider).correct(g, live, reason, by);
      messenger.showSnackBar(SnackBar(content: Text('Version figée mise à jour : ${live.name}.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (!me.role.isStaff) {
      return const EmptyState(kind: EmptyKind.forbidden, title: 'Réservé à l’équipe', message: 'Le gel des fiches est l’affaire du conte.');
    }
    return asyncView(
      ref.watch(gamesProvider),
      (games) => asyncView(
        ref.watch(allCharactersProvider),
        (chars) => _page(context, me, games, chars),
        onRetry: () => ref.invalidate(allCharactersProvider),
      ),
      onRetry: () => ref.invalidate(gamesProvider),
    );
  }

  Widget _page(BuildContext context, AppUser me, List<Game> games, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final running = runningGame(games, widget.now());
    return PageBody(children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(onPressed: () => context.go('/conteur/fiches'), child: const Text('Fiches')),
        Text('/ Gel des fiches', style: t.bodySmall),
      ]),
      PageTitle(
        'Gel des fiches',
        subtitle: 'Une version figée par fiche fait foi pendant la partie. C’est elle qu’on imprimera.',
        action: running != null && me.role.managesAccounts
            ? OutlinedButton(onPressed: _busy ? null : () => _lift(running), child: const Text('Lever le gel'))
            : null,
      ),
      const SizedBox(height: 22),
      if (running == null) _newFreeze(context, me, chars) else _running(context, me, running, games, chars),
    ]);
  }

  Widget _newFreeze(BuildContext context, AppUser me, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    if (!me.role.managesAccounts) return Panel(child: Text('Aucun gel en cours.', style: t.titleMedium));
    return asyncView(ref.watch(allNpcLoansProvider), (loans) {
      final sheets = sheetsToFreeze(chars, loans, widget.now());
      final date = parseDay(_date.text);
      final until = date == null ? null : untilOf(date, _untilDay.text, _untilTime.text);
      void edited(String _) => setState(() => _error = null);
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Nouveau gel'),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 200,
              child: TextField(
                key: const Key('freeze-date'),
                controller: _date,
                decoration: const InputDecoration(labelText: 'Partie du', hintText: 'JJ/MM/AAAA'),
                onChanged: edited,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                key: const Key('freeze-until-day'),
                controller: _untilDay,
                decoration: InputDecoration(labelText: 'Lever le', hintText: date == null ? 'JJ/MM/AAAA' : slashDay(defaultUntil(date))),
                onChanged: edited,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                key: const Key('freeze-until-time'),
                controller: _untilTime,
                decoration: const InputDecoration(labelText: 'à', hintText: '06:00'),
                onChanged: edited,
              ),
            ),
          ]),
          if (until != null) ...[
            const SizedBox(height: 10),
            Text('Levée prévue : ${dayAndHour(until)}', style: t.bodyMedium),
          ],
          const SizedBox(height: 12),
          Text(freezeCountText(sheets), style: t.titleSmall),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.linkHover)),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: sheets.isEmpty || _busy ? null : () => _freeze(sheets), child: const Text('Figer maintenant')),
          ),
        ]),
      );
    }, onRetry: () => ref.invalidate(allNpcLoansProvider));
  }

  Widget _running(BuildContext context, AppUser me, Game g, List<Game> games, List<Character> chars) {
    final t = Theme.of(context).textTheme;
    final prev = previousGame(games, g);
    final current = ref.watch(gameSnapshotsProvider(g.id, g.date)).value ?? const <FrozenSheet>[];
    final before = prev == null ? const <FrozenSheet>[] : ref.watch(gameSnapshotsProvider(prev.id, prev.date)).value ?? const <FrozenSheet>[];
    final requests = ref.watch(openRequestsProvider).value ?? const <XpRequest>[];
    final live = {for (final c in chars) c.id: c};
    final snaps = {for (final s in current) s.characterId: s};
    final olds = {for (final s in before) s.characterId: s};
    final rows = [
      for (final id in g.sheetIds)
        if (live[id] case final c?) _Row(c, snaps[id], olds[id], [for (final r in requests) if (r.characterId == id) r]),
    ];
    final shown = _onlyChanged ? [for (final r in rows) if (r.modified) r] : rows;
    final selected = rows.where((r) => r.live.id == _selectedId).firstOrNull ?? shown.firstOrNull;
    final pending = rows.fold<int>(0, (s, r) => s + r.requests.length);

    Widget kpi(String value, String label, String key) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, key: Key(key), style: t.headlineSmall),
          Text(label, style: t.bodySmall?.copyWith(color: AppColors.frozenText)),
        ]);

    final banner = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.frozenBg,
        border: Border.all(color: AppColors.frozenBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(spacing: 24, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Icon(Icons.lock_outline, color: AppColors.frozen),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gameTitle(g), style: t.titleMedium),
          Text(gameSpanText(g), style: t.bodyMedium?.copyWith(color: AppColors.frozenText)),
        ]),
        kpi('${g.sheetIds.length}', 'fiches figées', 'kpi-sheets'),
        kpi('$pending', 'demandes en file', 'kpi-requests'),
      ]),
    );

    Widget cells(List<Widget> children) => Wrap(spacing: 16, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: children);
    final table = Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const SectionTitle('Fiches figées pour cette partie'),
            ChoiceChip(label: const Text('Toutes'), selected: !_onlyChanged, onSelected: (_) => setState(() => _onlyChanged = false)),
            ChoiceChip(label: const Text('Modifiées'), selected: _onlyChanged, onSelected: (_) => setState(() => _onlyChanged = true)),
          ]),
        ),
        if (isWide(context))
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: cells([
              SizedBox(width: 230, child: Text('Fiche', style: t.bodySmall)),
              SizedBox(width: 140, child: Text('Joueur', style: t.bodySmall)),
              SizedBox(width: 170, child: Text(prev == null ? 'Depuis le gel précédent' : 'Depuis le gel du ${formatDay(prev.frozenAt)}', style: t.bodySmall)),
              Text('En attente', style: t.bodySmall),
            ]),
          ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text('Aucune fiche modifiée depuis le gel précédent.', style: t.bodySmall),
          ),
        for (final r in shown)
          InkWell(
            key: Key('freeze-row-${r.live.id}'),
            onTap: () => setState(() => _selectedId = r.live.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: r == selected ? AppColors.navActive : null,
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: cells([
                SizedBox(width: 230, child: Text('${r.live.name} · ${r.live.kind.label}', style: t.bodyMedium)),
                SizedBox(width: 140, child: Text(r.live.playerName ?? '—', style: t.bodySmall)),
                SizedBox(width: 170, child: Text(r.diffLabel, style: t.bodyMedium)),
                Text(
                  r.requests.isEmpty ? '—' : [for (final x in r.requests) x.summary].join(', '),
                  style: t.bodySmall?.copyWith(color: r.requests.isEmpty ? null : AppColors.goldLight),
                ),
              ]),
            ),
          ),
      ]),
    );

    final aside = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (selected != null) ...[_detail(context, me, g, prev, selected), const SizedBox(height: 20)],
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Pendant le gel'),
          const SizedBox(height: 10),
          for (final s in _during) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(s, style: t.bodyMedium)),
        ]),
      ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      banner,
      const SizedBox(height: 20),
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: table),
          const SizedBox(width: 24),
          SizedBox(width: 440, child: aside),
        ])
      else ...[table, const SizedBox(height: 20), aside],
    ]);
  }

  /// Panneau de la fiche choisie : changements depuis le gel précédent, correction urgente.
  Widget _detail(BuildContext context, AppUser me, Game g, Game? prev, _Row r) {
    final t = Theme.of(context).textTheme;
    final snap = r.snap;
    final old = r.old;
    final lines = snap == null || old == null ? const <String>[] : describeChanges(old.character, snap.character);
    final toReport = snap != null && snap.version != r.live.version;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(r.live.name),
        const SizedBox(height: 6),
        Text(
          prev == null ? 'Gel du ${formatDay(g.frozenAt)}' : 'Gel du ${formatDay(prev.frozenAt)} → gel du ${formatDay(g.frozenAt)}',
          style: t.bodySmall,
        ),
        const SizedBox(height: 10),
        if (snap == null)
          Text('Version figée en cours de chargement.', style: t.bodySmall)
        else if (old == null)
          Text('Première version figée.', style: t.bodyMedium)
        else if (lines.isEmpty)
          Text('Aucun changement depuis le gel précédent.', style: t.bodyMedium)
        else
          for (final l in lines) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(l, style: t.bodyMedium)),
        if (snap?.reason case final reason?) ...[
          const SizedBox(height: 10),
          Text('Corrigée le ${formatDay(snap!.at)} : $reason', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
        ],
        if (me.role.managesAccounts) ...[
          const SizedBox(height: 16),
          if (r.live.playerUid == me.uid)
            Text('Votre propre fiche : un autre conteur doit la corriger.', style: t.bodyMedium?.copyWith(color: AppColors.goldLight))
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: toReport && !_busy ? () => _correct(g, r.live, snap!) : null,
                child: const Text('Correction urgente…'),
              ),
            ),
            if (snap != null && !toReport) ...[
              const SizedBox(height: 6),
              Text('Aucun changement à reporter', style: t.bodySmall),
            ],
          ],
        ],
      ]),
    );
  }
}

/// Motif obligatoire de la correction urgente ; renvoie null si annulée.
class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.name, required this.changes});
  final String name;
  final List<String> changes;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Correction urgente'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('La version figée de ${widget.name} sera remplacée par la fiche actuelle :'),
              const SizedBox(height: 8),
              for (final c in widget.changes) Text('· $c', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                key: const Key('freeze-reason'),
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _reason.text.trim()),
            child: const Text('Mettre à jour la version figée'),
          ),
        ],
      );
}
```

**`lib/router.dart` :**
- import `'games/freeze_screen.dart'` (ordre alphabétique, après `events/story_screen.dart`) ;
- juste après `page('/conteur/fiches', const CharactersListScreen()),` :

```dart
          page('/conteur/gel', const FreezeScreen()),
```

**`lib/characters/characters_list_screen.dart`**, dans le `Wrap` de l’action de `PageTitle`, en premier :

```dart
            OutlinedButton(onPressed: () => context.go('/conteur/gel'), child: const Text('Gel des fiches')),
```

Run : `flutter test test/games/freeze_screen_test.dart`, puis `flutter analyze`, puis `flutter test`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 3 : vérification à l’écran (émulateurs)**

Run : `flutter run -d chrome --dart-define=EMULATORS=true`, se connecter en conteur, ouvrir Fiches → « Gel des fiches », figer, vérifier le bandeau d’une fiche de joueur, puis lever le gel.

Expected : le gel s’écrit sans refus des règles ; la liste des versions figées se charge (sur l’émulateur, aucun index n’est requis).

- [ ] **Step 4 : commit**

```
git add lib/games/freeze_screen.dart lib/router.dart lib/characters/characters_list_screen.dart test/games/freeze_screen_test.dart
git commit -m "feat: gel des fiches — écran « Gel des fiches » (C-Figer)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : revue, puis déploiement (avec accord)

- [ ] **Step 1 :** revue finale de la branche contre la spec (sous-agent le plus capable).
- [ ] **Step 2 :** suite complète : `flutter analyze`, `flutter test`, tests des règles.
- [ ] **Step 3 :** avec l’accord de l’utilisateur seulement :
  - `firebase deploy --only firestore:rules,firestore:indexes` (l’index `frozen.gameDate` met quelques minutes à se construire) ;
  - `flutter build web` puis `firebase deploy --only hosting` ;
  - fusion de `parties-gel` dans `main`, puis `git push`.
