# Hors ligne et appareils connectés (sous-projet 8c) : plan d’implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** pendant une partie, le joueur suit sa fiche figée sans réseau (sang, volonté, santé cochés, notes) et ses saisies partent au conte au retour du réseau ; « Mon compte » liste les appareils connectés et permet d’en déconnecter un.

**Architecture :**
- **Cache Firestore persistant** (`main.dart`) : le hors ligne repose sur le cache et la file d’écritures de Firestore, sans base locale.
- **Calculs purs :** `lib/offline/night.dart` (suivi, bornes, coches, annulation, notes, textes) et `lib/offline/device.dart` (appareil, textes).
- **Dépôts :** `night_repository.dart` (`characters/{id}/night/{gameId}`, avec l’état cache / en attente) et `devices_repository.dart` (`users/{uid}/devices/{id}`, identifiant local, document de cet appareil).
- **Déconnexion de l’appareil :** `device_session.dart` retire le document, vide le cache (`terminate` puis `clearPersistence`), oublie l’identifiant, déconnecte le compte et relance l’app (rechargement de la page sur le Web).
- **Écrans :** « En partie » (`night_screen.dart`), bloc « Suivi de la soirée » de l’écran du gel, section « Appareils connectés » de « Mon compte » (`devices_section.dart`), message de la page de connexion.

**Tech Stack :** ajout de `shared_preferences` (identifiant de l’appareil) et de `web` (rechargement de la page, déjà présent en dépendance transitive).

**Spec :** `docs/superpowers/specs/2026-10-19-hors-ligne-design.md`.

**Maquettes :** canvas https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planches `J-HorsLigne.dc.html`, `J-HorsLigne-mobile.dc.html`, `Compte.dc.html` (outil Artifact, `action: read`, `path: project/<planche>`).

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md <N> [test|impl]` (fichiers complets seulement ; les modifications de fichiers existants sont décrites et se font à la main) ;
  - textes en français, apostrophe typographique ’ dans les textes affichés ;
  - analyseur propre, pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` exactement ;
  - ne jamais commiter `bash.exe.stackdump`, `rules_test/bash.exe.stackdump`, `CLAUDE.md` ni `firestore-debug.log`.
- **Branche :** `hors-ligne`, déjà créée (la spec y est commitée).
- **Code généré :** `dart run build_runner build --delete-conflicting-outputs` après un nouveau `@riverpod`. Si des `.g.dart` sans rapport changent (empreintes seulement), les commiter avec la tâche.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Règles Firestore :** tests depuis `rules_test/` avec `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Textes fixes :**
  - « Pas de réseau. Tout ce que vous cochez reste sur cet appareil et part au conte dès que le réseau revient. » ;
  - « Gardez cet onglet ouvert pendant la partie : sans réseau, il ne se rechargera pas. » ;
  - « Cette fiche n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau avant la partie. » ;
  - « Une saisie a été refusée : vérifiez votre suivi. » ;
  - « Cette fiche n’est pas figée pour une partie en cours » ;
  - « Tout est envoyé. » / « Des saisies attendent le réseau. » ;
  - « Les traits de Bête sont saisis par le conte. Vous les voyez quand son appareil et le vôtre se sont synchronisés. » ;
  - « Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h » ; « 3 / 12 · reste 9 » ; « Sang 3 / 12 · Volonté 1 / 6 · Santé 2 · 0 · 0 » ;
  - « Copie hors ligne · partie du 3 oct. », « Connexion web », « Application Android », « aujourd’hui », « hier », « Déconnexion en attente », « Cet appareil » ;
  - « Déconnecter un appareil efface aussi sa copie hors ligne. », « Un appareil hors ligne est déconnecté à son prochain passage en ligne. » ;
  - « Cet appareil a été déconnecté depuis un autre appareil. » ;
  - « Des saisies n’ont pas encore été envoyées : elles seront perdues. ».
- **Leçons des lots précédents :**
  - un `ref.read` d’un provider pas encore écouté renvoie null : le surveiller dans `build` ;
  - rangées de boutons en `Wrap` (390 px) ;
  - tout écran qui lit un nouveau provider oblige ses tests à le surcharger ;
  - `SectionTitle` affiche son texte en capitales : les tests cherchent « SUIVI DE LA SOIRÉE ».

## Review Focus

1. **Saisie hors ligne envoyée après la levée du gel :** elle est acceptée par les règles, sinon le joueur perdrait sa soirée. Test : tâche 3.
2. **Version figée corrigée avec des maxima plus petits :** la prochaine coche ramène les valeurs au maximum, sans écriture refusée. Test : tâche 1.
3. **« Annuler le dernier coup » après une note :** les cases reviennent, la note reste. Tests : tâches 1 et 5.
4. **Écriture refusée au retour du réseau :** le joueur voit « Une saisie a été refusée : vérifiez votre suivi. ». Test : tâche 5.
5. **Déconnexion d’un appareil sans réseau, ou déclenchée deux fois :** elle ne bloque pas et n’agit qu’une fois. Test : tâche 4.

---

### Task 1 : suivi de la soirée, calculs purs

**Files :**
- Create : `lib/offline/night.dart`.
- Test : `test/offline/night_test.dart`.

**Interfaces :**
- Consumes : `healthGroups` (`lib/print/print_sheet.dart`), `hourText` (`lib/games/game_rules.dart`), `formatDay` (`lib/core/dates.dart`), `Game`, `Character`.
- Produces :
  - `NightNote(text, at)`, `Night({blood, willpower, health, notes, at})` avec `fromMap`, `toMap`, `copy` ;
  - `enum NightTrack { blood, willpower, healthy, hurt, incapacitated }` ;
  - `NightLimits.of(Character)` avec `blood`, `willpower`, `health`, `vitae`, `of(NightTrack)` ;
  - `nightValue(Night, NightTrack)`, `clampTo(Night, NightLimits)`, `toggle(Night, NightTrack, int index, NightLimits)`, `undoTo(Night current, Night previous)`, `addNote(Night, String, DateTime)` → `Night?` ;
  - textes : `spentText`, `nightSummary`, `versionLine`, `firstName`, `sentText`, `noteLine`, constantes `offlineText`, `webTabText`, `notPreparedText`, `refusedText`, `notFrozenText`, `beastNote`, `noteMaxLength`, `notesMax`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 1 test`, puis `flutter test test/offline/night_test.dart`.

Expected : échec de compilation (`night.dart` absent).

<!-- file: test/offline/night_test.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/offline/night.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show ghoulState;
import '../games/game_rules_test.dart' show frozenGame;

/// Isaure en partie : 12 de sang, 6 de volonté, santé 3 · 3 · 3.
Character player() => sample()
  ..blood = 12
  ..willpower = 6;

void main() {
  final l = NightLimits.of(player());

  test('maxima : sang, volonté, santé ; goule à 5 de Vitae ; santé illisible à 3', () {
    expect(l.blood, 12);
    expect(l.willpower, 6);
    expect(l.health, [3, 3, 3]);
    expect(l.vitae, isFalse);
    final g = NightLimits.of(player()..ghoul = ghoulState());
    expect(g.blood, 5);
    expect(g.vitae, isTrue);
    expect(NightLimits.of(player()..health = '4 · x').health, [4, 3, 3]);
  });

  test('coche jusqu’à la case, décoche la dernière, reste dans les bornes', () {
    var n = toggle(const Night(), NightTrack.blood, 3, l);
    expect(n.blood, 3);
    n = toggle(n, NightTrack.blood, 3, l);
    expect(n.blood, 2);
    n = toggle(n, NightTrack.blood, 1, l);
    expect(n.blood, 1);
    n = toggle(n, NightTrack.hurt, 2, l);
    expect(n.health, [0, 2, 0]);
    expect(toggle(n, NightTrack.willpower, 9, l).willpower, 6);
  });

  test('version figée corrigée : une valeur au-delà est ramenée au maximum à la prochaine coche (Review Focus 2)', () {
    final small = NightLimits.of(player()..blood = 4);
    final n = toggle(const Night(blood: 10, health: [5, 0, 0]), NightTrack.willpower, 1, small);
    expect(n.blood, 4);
    expect(n.health, [3, 0, 0]);
    expect(n.willpower, 1);
  });

  test('annuler : les cases reviennent, les notes restent (Review Focus 3)', () {
    const before = Night(blood: 2);
    final now = Night(blood: 5, health: const [1, 0, 0], notes: [NightNote('Inès', DateTime(2026, 10, 3, 22))]);
    final back = undoTo(now, before);
    expect(back.blood, 2);
    expect(back.health, [0, 0, 0]);
    expect(back.notes.single.text, 'Inès');
  });

  test('notes : vide refusée, coupée à 500 caractères, 100 au plus', () {
    final at = DateTime(2026, 10, 3, 22, 15);
    expect(addNote(const Night(), '   ', at), isNull);
    expect(addNote(const Night(), ' Inès Morel ', at)!.notes.single.text, 'Inès Morel');
    expect(addNote(const Night(), 'x' * 600, at)!.notes.single.text.length, 500);
    var n = const Night();
    for (var i = 0; i < 101; i++) {
      n = addNote(n, 'note $i', at)!;
    }
    expect(n.notes.length, 100);
    expect(n.notes.first.text, 'note 1');
  });

  test('aller-retour Firestore', () {
    final n = Night(blood: 3, willpower: 1, health: const [2, 0, 0], notes: [NightNote('Inès', DateTime(2026, 10, 3, 22, 15))]);
    final back = Night.fromMap({...n.toMap(), 'at': Timestamp.fromDate(DateTime(2026, 10, 3, 23))});
    expect(back.blood, 3);
    expect(back.willpower, 1);
    expect(back.health, [2, 0, 0]);
    expect(back.notes.single.text, 'Inès');
    expect(back.notes.single.at, DateTime(2026, 10, 3, 22, 15));
    expect(back.at, DateTime(2026, 10, 3, 23));
    expect(Night.fromMap(const {}).health, [0, 0, 0]);
  });

  test('textes', () {
    expect(spentText(3, 12), '3 / 12 · reste 9');
    final g = frozenGame();
    expect(versionLine(g, null), 'Version figée du 29 sept.');
    expect(versionLine(g, DateTime(2026, 10, 3, 18)), 'Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h');
    expect(nightSummary(const Night(blood: 3, willpower: 1, health: [2, 0, 0]), l), 'Sang 3 / 12 · Volonté 1 / 6 · Santé 2 · 0 · 0');
    expect(nightSummary(const Night(), NightLimits.of(player()..ghoul = ghoulState())), 'Vitae 0 / 5 · Volonté 0 / 6 · Santé 0 · 0 · 0');
    expect(firstName('Isaure de Valcourt'), 'Isaure');
    expect(sentText(true), 'Des saisies attendent le réseau.');
    expect(sentText(false), 'Tout est envoyé.');
    expect(noteLine(NightNote('Inès', DateTime(2026, 10, 3, 22, 15))), '22h15 · Inès');
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 1 impl`.

<!-- file: lib/offline/night.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';
import '../core/dates.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show hourText;
import '../print/print_sheet.dart' show healthGroups;

/// Longueur maximale d'une note de partie, et nombre de notes gardées (règles Firestore : 100 au plus).
const noteMaxLength = 500;
const notesMax = 100;

const offlineText = 'Pas de réseau. Tout ce que vous cochez reste sur cet appareil et part au conte dès que le réseau revient.';
const webTabText = 'Gardez cet onglet ouvert pendant la partie : sans réseau, il ne se rechargera pas.';
const notPreparedText = 'Cette fiche n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau avant la partie.';
const refusedText = 'Une saisie a été refusée : vérifiez votre suivi.';
const notFrozenText = 'Cette fiche n’est pas figée pour une partie en cours';
const beastNote = 'Les traits de Bête sont saisis par le conte. Vous les voyez quand son appareil et le vôtre se sont synchronisés.';

/// Note de partie ; l'heure est celle de l'appareil, la note pouvant être prise sans réseau.
class NightNote {
  const NightNote(this.text, this.at);

  factory NightNote.fromMap(Map<dynamic, dynamic> m) =>
      NightNote(m['text'] as String? ?? '', (m['at'] as Timestamp?)?.toDate() ?? DateTime(2000));

  final String text;
  final DateTime at;

  Map<String, dynamic> toMap() => {'text': text, 'at': Timestamp.fromDate(at)};
}

/// Suivi de la soirée (`characters/{id}/night/{gameId}`) : ce que le joueur a dépensé et noté pendant la partie.
/// Il ne modifie jamais la fiche.
class Night {
  const Night({this.blood = 0, this.willpower = 0, this.health = const [0, 0, 0], this.notes = const [], this.at});

  factory Night.fromMap(Map<String, dynamic> m) {
    final h = [for (final v in (m['health'] as List?) ?? const []) (v as num).toInt()];
    return Night(
      blood: (m['blood'] as num?)?.toInt() ?? 0,
      willpower: (m['willpower'] as num?)?.toInt() ?? 0,
      health: [for (var i = 0; i < 3; i++) i < h.length ? h[i] : 0],
      notes: [for (final n in (m['notes'] as List?) ?? const []) NightNote.fromMap(n as Map)],
      at: (m['at'] as Timestamp?)?.toDate(),
    );
  }

  /// Points dépensés.
  final int blood;
  final int willpower;

  /// Cases cochées : Sain, Blessé, Incapacité.
  final List<int> health;

  /// De la plus ancienne à la plus récente.
  final List<NightNote> notes;

  /// Heure du serveur à la dernière écriture.
  final DateTime? at;

  Night copy({int? blood, int? willpower, List<int>? health, List<NightNote>? notes}) => Night(
        blood: blood ?? this.blood,
        willpower: willpower ?? this.willpower,
        health: health ?? this.health,
        notes: notes ?? this.notes,
        at: at,
      );

  /// Sans `byUid` ni `at`, ajoutés par le dépôt.
  Map<String, dynamic> toMap() => {
        'blood': blood,
        'willpower': willpower,
        'health': [...health],
        'notes': [for (final n in notes) n.toMap()],
      };
}

/// Ligne de cases du suivi ; les trois dernières sont les groupes de santé.
enum NightTrack { blood, willpower, healthy, hurt, incapacitated }

/// Nombre de cases de chaque ligne, d'après la version figée.
class NightLimits {
  const NightLimits({required this.blood, required this.willpower, required this.health, this.vitae = false});

  /// Une goule a 5 de Vitae ; la santé « 3 · 3 · 3 » se lit comme à l'impression.
  factory NightLimits.of(Character c) => NightLimits(
        blood: c.ghoul != null ? 5 : c.blood,
        willpower: c.willpower,
        health: [for (final (_, n) in healthGroups(c.health)) n],
        vitae: c.ghoul != null,
      );

  final int blood;
  final int willpower;
  final List<int> health;
  final bool vitae;

  int of(NightTrack t) => switch (t) {
        NightTrack.blood => blood,
        NightTrack.willpower => willpower,
        _ => health[t.index - 2],
      };
}

int nightValue(Night n, NightTrack t) => switch (t) {
      NightTrack.blood => n.blood,
      NightTrack.willpower => n.willpower,
      _ => n.health[t.index - 2],
    };

Night _set(Night n, NightTrack t, int v) => switch (t) {
      NightTrack.blood => n.copy(blood: v),
      NightTrack.willpower => n.copy(willpower: v),
      _ => n.copy(health: [for (var i = 0; i < 3; i++) i == t.index - 2 ? v : n.health[i]]),
    };

/// Chaque ligne ramenée entre 0 et son maximum (version figée corrigée pendant la partie).
Night clampTo(Night n, NightLimits l) => NightTrack.values.fold<Night>(n, (acc, t) => _set(acc, t, nightValue(acc, t).clamp(0, l.of(t))));

/// Cliquer la case [index] (à partir de 1) coche jusqu'à elle ; cliquer la dernière case cochée la décoche.
Night toggle(Night n, NightTrack t, int index, NightLimits l) {
  final base = clampTo(n, l);
  final current = nightValue(base, t);
  return _set(base, t, (index == current ? index - 1 : index).clamp(0, l.of(t)));
}

/// « Annuler le dernier coup » : les cases reviennent à [previous], les notes de [current] restent.
Night undoTo(Night current, Night previous) =>
    current.copy(blood: previous.blood, willpower: previous.willpower, health: previous.health);

/// Ajoute une note ; null si elle est vide. Coupée à 500 caractères ; au-delà de 100 notes, la plus ancienne part.
Night? addNote(Night n, String text, DateTime at) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final notes = [...n.notes, NightNote(t.length > noteMaxLength ? t.substring(0, noteMaxLength) : t, at)];
  return n.copy(notes: notes.length > notesMax ? notes.sublist(notes.length - notesMax) : notes);
}

/// « 3 / 12 · reste 9 ».
String spentText(int spent, int max) => '$spent / $max · reste ${max - spent}';

/// « Sang 3 / 12 · Volonté 1 / 6 · Santé 2 · 0 · 0 » (écran du gel).
String nightSummary(Night n, NightLimits l) =>
    '${l.vitae ? 'Vitae' : 'Sang'} ${n.blood} / ${l.blood} · Volonté ${n.willpower} / ${l.willpower} · Santé ${n.health.join(' · ')}';

/// « Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h ».
String versionLine(Game g, DateTime? preparedAt) => 'Version figée du ${formatDay(g.frozenAt)}'
    '${preparedAt == null ? '' : ' · préparée sur cet appareil le ${formatDay(preparedAt)} à ${hourText(preparedAt)}'}';

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String sentText(bool pending) => pending ? 'Des saisies attendent le réseau.' : 'Tout est envoyé.';

/// « 22h15 · Inès Morel, galeriste ».
String noteLine(NightNote n) => '${hourText(n.at)} · ${n.text}';
```

- [ ] **Step 3 : vérifier**

Run : `flutter test test/offline/night_test.dart` puis `flutter analyze`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 4 : commit**

```bash
git add lib/offline/night.dart test/offline/night_test.dart
git commit -m "feat: hors ligne — suivi de la soirée, calculs purs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : appareils, modèle et textes

**Files :**
- Create : `lib/offline/device.dart`.
- Test : `test/offline/device_test.dart`.

**Interfaces :**
- Consumes : `isRunning` (`lib/games/game_rules.dart`), `formatDay`, `Game`.
- Produces :
  - `Device({id, name, web, lastSeen, gameId, preparedAt, revokedAt})`, `Device.fromMap(id, map)` ;
  - `deviceName({required bool web, required TargetPlatform platform})` ;
  - `deviceKindText(Device, List<Game>, DateTime now)`, `lastSeenText(DateTime?, DateTime now)`, `deviceLine(Device, List<Game>, DateTime now)` ;
  - constantes `revokedNotice`, `pendingLossText`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 2 test`, puis `flutter test test/offline/device_test.dart`.

Expected : échec de compilation (`device.dart` absent).

<!-- file: test/offline/device_test.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/offline/device.dart';

import '../games/game_rules_test.dart' show frozenGame;

void main() {
  final now = DateTime(2099, 10, 3, 21);
  final game = frozenGame(year: 2099);

  test('nom d’après la plateforme', () {
    expect(deviceName(web: true, platform: TargetPlatform.windows), 'Navigateur · Windows');
    expect(deviceName(web: true, platform: TargetPlatform.android), 'Navigateur · Android');
    expect(deviceName(web: false, platform: TargetPlatform.android), 'Android');
  });

  test('dernière visite', () {
    expect(lastSeenText(DateTime(2099, 10, 3, 8), now), 'aujourd’hui');
    expect(lastSeenText(DateTime(2099, 10, 2, 23), now), 'hier');
    expect(lastSeenText(DateTime(2099, 9, 30, 23), DateTime(2099, 10, 1, 1)), 'hier');
    expect(lastSeenText(DateTime(2099, 9, 29), now), '29 sept.');
    expect(lastSeenText(null, now), '—');
  });

  test('copie hors ligne tant que le gel de la partie court', () {
    const web = Device(id: 'd1', name: 'Navigateur · Windows', web: true);
    const android = Device(id: 'd2', name: 'Android', gameId: 'g2');
    expect(deviceKindText(web, [game], now), 'Connexion web');
    expect(deviceKindText(android, [game], now), 'Copie hors ligne · partie du 3 oct.');
    expect(deviceKindText(android, [game], DateTime(2099, 10, 4, 7)), 'Application Android');
    expect(deviceKindText(android, const [], now), 'Application Android');
  });

  test('ligne de l’appareil', () {
    expect(deviceLine(Device(id: 'd1', name: 'x', web: true, lastSeen: DateTime(2099, 10, 3, 8)), [game], now), 'Connexion web · aujourd’hui');
    expect(deviceLine(Device(id: 'd1', name: 'x', revokedAt: DateTime(2099, 10, 3, 20)), [game], now), 'Déconnexion en attente');
  });

  test('lu depuis Firestore', () {
    final d = Device.fromMap('d1', {
      'name': 'Android',
      'web': false,
      'lastSeen': Timestamp.fromDate(DateTime(2099, 10, 3, 8)),
      'gameId': 'g2',
      'preparedAt': null,
      'revokedAt': null,
    });
    expect(d.id, 'd1');
    expect(d.name, 'Android');
    expect(d.web, isFalse);
    expect(d.lastSeen, DateTime(2099, 10, 3, 8));
    expect(d.gameId, 'g2');
    expect(d.preparedAt, isNull);
    expect(d.revokedAt, isNull);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 2 impl`.

<!-- file: lib/offline/device.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import '../core/dates.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show isRunning;

const revokedNotice = 'Cet appareil a été déconnecté depuis un autre appareil.';
const pendingLossText = 'Des saisies n’ont pas encore été envoyées : elles seront perdues.';

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();

/// Un appareil où le compte est connecté (`users/{uid}/devices/{id}`).
class Device {
  const Device({required this.id, required this.name, this.web = false, this.lastSeen, this.gameId, this.preparedAt, this.revokedAt});

  factory Device.fromMap(String id, Map<String, dynamic> m) => Device(
        id: id,
        name: m['name'] as String? ?? '',
        web: m['web'] == true,
        lastSeen: _date(m['lastSeen']),
        gameId: m['gameId'] as String?,
        preparedAt: _date(m['preparedAt']),
        revokedAt: _date(m['revokedAt']),
      );

  final String id;
  final String name;
  final bool web;

  /// Dernier démarrage de l'app connectée.
  final DateTime? lastSeen;

  /// Partie préparée sur l'appareil (écran « En partie » ouvert avec du réseau).
  final String? gameId;
  final DateTime? preparedAt;

  /// Déconnexion demandée depuis un autre appareil.
  final DateTime? revokedAt;
}

/// « Navigateur · Windows », « Android »…
String deviceName({required bool web, required TargetPlatform platform}) {
  final os = switch (platform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  return web ? 'Navigateur · $os' : os;
}

/// Copie hors ligne d'une partie dont le gel court encore, sinon le type de connexion.
String deviceKindText(Device d, List<Game> games, DateTime now) {
  final g = games.where((g) => g.id == d.gameId).firstOrNull;
  if (g != null && isRunning(g, now)) return 'Copie hors ligne · partie du ${formatDay(g.date)}';
  return d.web ? 'Connexion web' : 'Application Android';
}

/// « aujourd’hui », « hier », « 29 sept. ».
String lastSeenText(DateTime? d, DateTime now) {
  if (d == null) return '—';
  final day = DateTime(d.year, d.month, d.day);
  if (day == DateTime(now.year, now.month, now.day)) return 'aujourd’hui';
  if (day == DateTime(now.year, now.month, now.day - 1)) return 'hier';
  return formatDay(d);
}

/// Seconde ligne d'un appareil dans « Mon compte ».
String deviceLine(Device d, List<Game> games, DateTime now) =>
    d.revokedAt != null ? 'Déconnexion en attente' : '${deviceKindText(d, games, now)} · ${lastSeenText(d.lastSeen, now)}';
```

- [ ] **Step 3 : vérifier**

Run : `flutter test test/offline/device_test.dart` puis `flutter analyze`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 4 : commit**

```bash
git add lib/offline/device.dart test/offline/device_test.dart
git commit -m "feat: hors ligne — appareils, modèle et textes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : règles Firestore du suivi et des appareils

**Files :**
- Modify : `firestore.rules` (un bloc `match /night/{gid}` dans `match /characters/{id}`, un bloc `match /users/{uid}/devices/{d}`).
- Test : `rules_test/offline.test.js`.

**Interfaces :**
- Consumes : fonctions existantes `signedIn()`, `isStaff()`, `validName(n)`, `charPath(id)`, `gamePath(g)`.
- Produces : les collections `characters/{id}/night/{gid}` (clés `blood`, `willpower`, `health`, `notes`, `byUid`, `at`) et `users/{uid}/devices/{d}` (clés `name`, `web`, `lastSeen`, `gameId`, `preparedAt`, `revokedAt`), utilisées par la tâche 4.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 3 test`, puis depuis `rules_test/` : `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.

Expected : les tests de `offline.test.js` qui attendent un succès échouent (aucune règle ne couvre ces chemins) ; les autres fichiers passent.

<!-- file: rules_test/offline.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const future = () => Timestamp.fromDate(new Date(Date.now() + 2 * 86400000));
const longAgo = () => Timestamp.fromDate(new Date(2020, 0, 1));
const gameDate = Timestamp.fromDate(new Date(2030, 9, 3));

const night = (uid, over = {}) => ({
  blood: 3, willpower: 1, health: [1, 0, 0], notes: [{ text: 'Inès Morel', at: Timestamp.now() }], byUid: uid, at: serverTimestamp(), ...over,
});
const device = (over = {}) => ({ name: 'Navigateur · Windows', web: true, lastSeen: serverTimestamp(), ...over });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', tom: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    const chars = { 'zoe-pj': 'zoe', 'zoe-goule': 'zoe', 'tom-pj': 'tom' };
    for (const [id, uid] of Object.entries(chars)) {
      await setDoc(doc(db, `characters/${id}`), { name: id, kind: 'pj', playerUid: uid, status: 'active', version: 1 });
    }
    // Partie g0 : Isaure et la goule de Zoé sont figées ; la version figée de Bastien existe mais il n'est pas dans la partie.
    await setDoc(doc(db, 'games/g0'), {
      date: gameDate, frozenAt: Timestamp.now(), until: future(), liftedAt: null, liftedByUid: null, byUid: 'lea', sheetIds: ['zoe-pj', 'zoe-goule'],
    });
    const sheets = {
      'zoe-pj': { name: 'Isaure', blood: 12, willpower: 6 },
      'zoe-goule': { name: 'Mila', blood: 0, willpower: 3, ghoul: { domitorId: 'zoe-pj' } },
      'tom-pj': { name: 'Bastien', blood: 12, willpower: 6 },
    };
    for (const [id, sheet] of Object.entries(sheets)) {
      await setDoc(doc(db, `characters/${id}/frozen/g0`), { sheet, version: 1, gameDate, at: Timestamp.now(), byUid: 'lea', reason: null });
    }
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const nightOf = (uid, cid, gid = 'g0') => doc(as(uid), `characters/${cid}/night/${gid}`);
const dev = (uid, owner = uid, id = 'd1') => doc(as(uid), `users/${owner}/devices/${id}`);

test('suivi : le joueur écrit le sien ; un autre joueur non ; l’équipe lit sans écrire', async () => {
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe')));
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { blood: 4 })));
  await assertSucceeds(getDoc(nightOf('zoe', 'zoe-pj')));
  await assertFails(setDoc(nightOf('tom', 'zoe-pj'), night('tom')));
  await assertFails(getDoc(nightOf('tom', 'zoe-pj')));
  await assertSucceeds(getDoc(nightOf('lea', 'zoe-pj')));
  await assertSucceeds(getDoc(nightOf('julien', 'zoe-pj')));
  await assertFails(setDoc(nightOf('lea', 'zoe-pj'), night('lea')));
});

test('suivi : fiche hors de la partie, bornes de la version figée, heure, auteur, clés', async () => {
  await assertFails(setDoc(nightOf('tom', 'tom-pj'), night('tom')));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj', 'g9'), night('zoe')));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { blood: 13 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { blood: -1 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { willpower: 7 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { health: [21, 0, 0] })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { health: [1, 0] })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { notes: Array.from({ length: 101 }, () => ({ text: 'x' })) })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { at: longAgo() })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { byUid: 'tom' })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe', { extra: 1 })));
});

test('suivi : goule bornée à 5 de Vitae', async () => {
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-goule'), night('zoe', { blood: 5 })));
  await assertFails(setDoc(nightOf('zoe', 'zoe-goule'), night('zoe', { blood: 6 })));
});

test('suivi : accepté après la levée du gel (Review Focus 1) ; jamais supprimé', async () => {
  await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'games/g0'), { liftedAt: Timestamp.now(), liftedByUid: 'lea' }));
  await assertSucceeds(setDoc(nightOf('zoe', 'zoe-pj'), night('zoe')));
  await assertFails(deleteDoc(nightOf('zoe', 'zoe-pj')));
  await assertFails(deleteDoc(nightOf('lea', 'zoe-pj')));
});

test('appareils : chacun les siens, personne d’autre, conte compris', async () => {
  await assertSucceeds(setDoc(dev('zoe'), device(), { merge: true }));
  await assertSucceeds(getDoc(dev('zoe')));
  await assertFails(getDoc(dev('tom', 'zoe')));
  await assertFails(getDoc(dev('lea', 'zoe')));
  await assertFails(setDoc(dev('lea', 'zoe', 'd2'), device(), { merge: true }));
  await assertFails(updateDoc(dev('tom', 'zoe'), { revokedAt: serverTimestamp() }));
  await assertFails(deleteDoc(dev('lea', 'zoe')));
  await assertSucceeds(updateDoc(dev('zoe'), { gameId: 'g0', preparedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(dev('zoe'), { revokedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(dev('zoe'), device(), { merge: true }));
  await assertSucceeds(deleteDoc(dev('zoe')));
});

test('appareils : heures du serveur, nom, types, clés', async () => {
  await assertFails(setDoc(dev('zoe'), device({ lastSeen: longAgo() })));
  await assertFails(setDoc(dev('zoe'), device({ name: '' })));
  await assertFails(setDoc(dev('zoe'), device({ web: 'oui' })));
  await assertFails(setDoc(dev('zoe'), device({ extra: 1 })));
  await assertFails(setDoc(dev('zoe'), { name: 'Android', web: false }));
  await assertSucceeds(setDoc(dev('zoe'), device()));
  await assertFails(updateDoc(dev('zoe'), { revokedAt: longAgo() }));
  await assertFails(updateDoc(dev('zoe'), { preparedAt: longAgo() }));
  await assertFails(updateDoc(dev('zoe'), { gameId: 3 }));
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules`, à l’intérieur de `match /characters/{id} {`, juste après le bloc `match /frozen/{gid} { … }`, ajouter :

```
      // Suivi de la soirée (sous-projet 8c) : écrit par le joueur seul, sur une fiche de la partie, borné par la version figée ;
      // lu aussi par l'équipe. L'heure n'est pas vérifiée : une saisie hors ligne envoyée après la levée du gel reste acceptée.
      match /night/{gid} {
        function nightValid() {
          let d = request.resource.data;
          let s = get(/databases/$(database)/documents/characters/$(id)/frozen/$(gid)).data.sheet;
          let maxBlood = s.get('ghoul', null) != null ? 5 : s.get('blood', 0);
          return d.keys().hasOnly(['blood', 'willpower', 'health', 'notes', 'byUid', 'at'])
            && d.blood is int && d.blood >= 0 && d.blood <= maxBlood
            && d.willpower is int && d.willpower >= 0 && d.willpower <= s.get('willpower', 0)
            && d.health is list && d.health.size() == 3
            && d.health[0] is int && d.health[0] >= 0 && d.health[0] <= 20
            && d.health[1] is int && d.health[1] >= 0 && d.health[1] <= 20
            && d.health[2] is int && d.health[2] >= 0 && d.health[2] <= 20
            && d.notes is list && d.notes.size() <= 100
            && d.byUid == request.auth.uid
            && d.at == request.time
            && id in get(gamePath(gid)).data.sheetIds;
        }
        allow read: if signedIn()
          && (get(charPath(id)).data.get('playerUid', null) == request.auth.uid || isStaff());
        allow create, update: if signedIn()
          && get(charPath(id)).data.get('playerUid', null) == request.auth.uid
          && nightValid();
      }
```

Puis, juste après le bloc `match /users/{uid} { … }` (au même niveau), ajouter :

```
    // Appareils connectés (sous-projet 8c) : chacun les siens, personne d'autre.
    // Les heures sont celles du serveur quand elles changent.
    match /users/{uid}/devices/{d} {
      function sameOrNow(k) {
        return request.resource.data.get(k, null) == (resource == null ? null : resource.data.get(k, null))
          || request.resource.data.get(k, null) == request.time;
      }
      allow read, delete: if signedIn() && request.auth.uid == uid;
      allow create, update: if signedIn() && request.auth.uid == uid
        && request.resource.data.keys().hasOnly(['name', 'web', 'lastSeen', 'gameId', 'preparedAt', 'revokedAt'])
        && validName(request.resource.data.name)
        && request.resource.data.web is bool
        && request.resource.data.lastSeen is timestamp
        && sameOrNow('lastSeen') && sameOrNow('preparedAt') && sameOrNow('revokedAt')
        && (request.resource.data.get('gameId', null) == null || request.resource.data.gameId is string);
    }
```

- [ ] **Step 3 : vérifier**

Run : depuis `rules_test/`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.

Expected : tous les fichiers passent, `offline.test.js` compris. Ne pas commiter `rules_test/firestore-debug.log`.

- [ ] **Step 4 : commit**

```bash
git add firestore.rules rules_test/offline.test.js
git commit -m "feat: hors ligne — règles du suivi de soirée et des appareils

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : cache persistant, dépôts, déconnexion de l’appareil

**Files :**
- Modify : `pubspec.yaml`, `pubspec.lock` (par `flutter pub add`), `lib/main.dart`, `test/fakes.dart`.
- Create : `lib/offline/night_repository.dart`, `lib/offline/devices_repository.dart`, `lib/offline/device_session.dart`, `lib/offline/reload_stub.dart`, `lib/offline/reload_web.dart` (et les `.g.dart` générés).
- Test : `test/offline/device_session_test.dart`.

**Interfaces :**
- Consumes : `Night`, `Device`, `deviceName` (tâches 1 et 2) ; `firestoreProvider`, `authStateProvider`, `authRepositoryProvider` (`lib/auth/session_providers.dart`) ; `routerProvider` (`lib/router.dart`).
- Produces :
  - `NightView(night, {exists, fromCache, pending})` ; `NightRepository.watch(characterId, gameId)` → `Stream<NightView>`, `save(characterId, gameId, Night, uid)` ;
  - providers `nightRepositoryProvider`, `nightProvider(characterId, gameId)` ;
  - `DevicesRepository.watchAll(uid)`, `watch(uid, id)`, `touch(uid, id, {name, web})`, `prepared(uid, id, gameId)`, `revoke(uid, id)`, `remove(uid, id)` ;
  - providers `devicesRepositoryProvider`, `myDevicesProvider`, `deviceIdProvider` (`Future<String>`), `thisDeviceProvider` (`Stream<Device?>`), constante `deviceIdKey` ;
  - `DeviceSession` (`pendingWrites()`, `signOut(uid, deviceId, {revoked})`), provider `deviceSessionProvider` ;
  - dans `test/fakes.dart` : `FakeNightRepository([Map<String, NightView>])` (clé `'<characterId>/<gameId>'`, `saved`, `error`) et `FakeDevicesRepository` (`calls`, `error`).

- [ ] **Step 1 : dépendances**

Run : `flutter pub add shared_preferences web`.

Expected : `pubspec.yaml` gagne les deux lignes ; `web` passe de transitive à directe dans `pubspec.lock`.

- [ ] **Step 2 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 4 test`, puis `flutter test test/offline/device_session_test.dart`.

Expected : échec de compilation (`device_session.dart` absent).

<!-- file: test/offline/device_session_test.dart -->
```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/offline/device_session.dart';

DeviceSession session(List<String> calls, {Future<void> Function(String uid, String id)? remove}) => DeviceSession(
      removeDevice: remove ?? (uid, id) async => calls.add('remove:$uid/$id'),
      pendingWrites: () async => false,
      wipeCache: () async => calls.add('wipe'),
      forgetDevice: () async => calls.add('forget'),
      signOutAccount: () async => calls.add('signOut'),
      restart: (location) async => calls.add('restart:$location'),
      removeTimeout: const Duration(milliseconds: 20),
    );

void main() {
  test('déconnexion à distance : appareil retiré, cache vidé, identifiant oublié, compte déconnecté, message', () async {
    final calls = <String>[];
    await session(calls).signOut('u1', 'd1', revoked: true);
    expect(calls, ['remove:u1/d1', 'wipe', 'forget', 'signOut', 'restart:/connexion?retire=1']);
  });

  test('« Se déconnecter » : même chemin, sans message', () async {
    final calls = <String>[];
    await session(calls).signOut('u1', 'd1');
    expect(calls.last, 'restart:/connexion');
  });

  test('sans réseau : la suppression qui n’aboutit pas ne bloque pas (Review Focus 5)', () async {
    final calls = <String>[];
    await session(calls, remove: (_, _) => Completer<void>().future).signOut('u1', 'd1');
    expect(calls, ['wipe', 'forget', 'signOut', 'restart:/connexion']);
  });

  test('suppression refusée : ignorée', () async {
    final calls = <String>[];
    await session(calls, remove: (_, _) async => throw Exception('refus')).signOut('u1', 'd1');
    expect(calls, ['wipe', 'forget', 'signOut', 'restart:/connexion']);
  });

  test('sans identifiant : rien à retirer', () async {
    final calls = <String>[];
    await session(calls).signOut('u1', null);
    expect(calls, ['wipe', 'forget', 'signOut', 'restart:/connexion']);
  });

  test('deux déclenchements rapprochés : un seul effet (Review Focus 5)', () async {
    final calls = <String>[];
    final s = session(calls);
    await Future.wait([s.signOut('u1', 'd1', revoked: true), s.signOut('u1', 'd1', revoked: true)]);
    expect(calls.where((c) => c == 'wipe'), hasLength(1));
  });
}
```

- [ ] **Step 3 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 4 impl`.

<!-- file: lib/offline/night_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import 'night.dart';

part 'night_repository.g.dart';

/// Ce que l'écran sait du suivi : le document, s'il existe, et d'où il vient.
class NightView {
  const NightView(this.night, {this.exists = false, this.fromCache = false, this.pending = false});

  final Night night;
  final bool exists;

  /// Lu dans le cache de l'appareil : pas de réseau, ou pas encore de réponse du serveur.
  final bool fromCache;

  /// Des saisies attendent d'être envoyées.
  final bool pending;
}

/// `characters/{id}/night/{gameId}` : suivi de la soirée, écrit par le joueur seul.
class NightRepository {
  NightRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String characterId, String gameId) => _db.doc('characters/$characterId/night/$gameId');

  /// Avec les changements de métadonnées : passage hors ligne, envoi des saisies en attente.
  Stream<NightView> watch(String characterId, String gameId) => _doc(characterId, gameId).snapshots(includeMetadataChanges: true).map((d) => NightView(
        d.exists ? Night.fromMap(d.data(serverTimestampBehavior: ServerTimestampBehavior.estimate)!) : const Night(),
        exists: d.exists,
        fromCache: d.metadata.isFromCache,
        pending: d.metadata.hasPendingWrites,
      ));

  /// Réécrit tout le suivi. Hors ligne, le futur ne se termine qu'au retour du réseau ; il échoue si le serveur refuse.
  Future<void> save(String characterId, String gameId, Night n, String uid) =>
      _doc(characterId, gameId).set({...n.toMap(), 'byUid': uid, 'at': FieldValue.serverTimestamp()});
}

@Riverpod(keepAlive: true)
NightRepository nightRepository(Ref ref) => NightRepository(ref.watch(firestoreProvider));

@riverpod
Stream<NightView> night(Ref ref, String characterId, String gameId) => ref.watch(nightRepositoryProvider).watch(characterId, gameId);
```

<!-- file: lib/offline/devices_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import 'device.dart';

part 'devices_repository.g.dart';

/// Clé de l'identifiant de cet appareil dans `shared_preferences`.
const deviceIdKey = 'deviceId';

/// `users/{uid}/devices/{id}` : les appareils où le compte est connecté.
class DevicesRepository {
  DevicesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users').doc(uid).collection('devices');

  Device _device(DocumentSnapshot<Map<String, dynamic>> d) =>
      Device.fromMap(d.id, d.data(serverTimestampBehavior: ServerTimestampBehavior.estimate)!);

  /// Le plus récemment vu d'abord.
  Stream<List<Device>> watchAll(String uid) => _col(uid).snapshots().map((q) => [for (final d in q.docs) _device(d)]
    ..sort((a, b) => (b.lastSeen ?? DateTime(2000)).compareTo(a.lastSeen ?? DateTime(2000))));

  Stream<Device?> watch(String uid, String id) => _col(uid).doc(id).snapshots().map((d) => d.exists ? _device(d) : null);

  /// Dernière visite ; crée le document au premier lancement. `revokedAt` n'est jamais réécrit ici.
  Future<void> touch(String uid, String id, {required String name, required bool web}) =>
      _col(uid).doc(id).set({'name': name, 'web': web, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  /// Partie préparée sur cet appareil (« Copie hors ligne »).
  Future<void> prepared(String uid, String id, String gameId) =>
      _col(uid).doc(id).update({'gameId': gameId, 'preparedAt': FieldValue.serverTimestamp()});

  /// Demande de déconnexion : l'appareil visé l'applique à son prochain passage en ligne.
  Future<void> revoke(String uid, String id) => _col(uid).doc(id).update({'revokedAt': FieldValue.serverTimestamp()});

  Future<void> remove(String uid, String id) => _col(uid).doc(id).delete();
}

@Riverpod(keepAlive: true)
DevicesRepository devicesRepository(Ref ref) => DevicesRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Device>> myDevices(Ref ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(devicesRepositoryProvider).watchAll(uid);
}

/// Identifiant de cet appareil, créé au premier lancement (identifiant aléatoire de Firestore, 20 caractères).
@Riverpod(keepAlive: true)
Future<String> deviceId(Ref ref) async {
  final db = ref.watch(firestoreProvider);
  final prefs = await SharedPreferences.getInstance();
  final known = prefs.getString(deviceIdKey);
  if (known != null) return known;
  final fresh = db.collection('users').doc().id;
  await prefs.setString(deviceIdKey, fresh);
  return fresh;
}

/// Le document de cet appareil. Mis à jour une fois par session (dernière visite), sauf s'il est marqué :
/// l'appareil va alors se déconnecter (écoute dans `router.dart`).
@Riverpod(keepAlive: true)
Stream<Device?> thisDevice(Ref ref) async* {
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  final repo = ref.watch(devicesRepositoryProvider);
  final id = ref.watch(deviceIdProvider.future);
  if (uid == null) {
    yield null;
    return;
  }
  final deviceId = await id;
  var touched = false;
  await for (final d in repo.watch(uid, deviceId)) {
    if (!touched && d?.revokedAt == null) {
      touched = true;
      repo.touch(uid, deviceId, name: deviceName(web: kIsWeb, platform: defaultTargetPlatform), web: kIsWeb).catchError((Object _) {});
    }
    yield d;
  }
}
```

<!-- file: lib/offline/device_session.dart -->
```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import '../router.dart';
import 'devices_repository.dart';
import 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';

part 'device_session.g.dart';

/// Déconnexion de cet appareil (« Se déconnecter », ou demandée depuis un autre appareil) :
/// document retiré, cache Firestore vidé, identifiant oublié, compte déconnecté, app relancée.
class DeviceSession {
  DeviceSession({
    required this.removeDevice,
    required this.pendingWrites,
    required this.wipeCache,
    required this.forgetDevice,
    required this.signOutAccount,
    required this.restart,
    this.removeTimeout = const Duration(seconds: 3),
  });

  final Future<void> Function(String uid, String deviceId) removeDevice;

  /// Vrai si des écritures attendent encore le réseau : elles seraient perdues.
  final Future<bool> Function() pendingWrites;

  /// `terminate` puis `clearPersistence`.
  final Future<void> Function() wipeCache;

  /// La prochaine connexion sur cet appareil crée un nouveau document.
  final Future<void> Function() forgetDevice;
  final Future<void> Function() signOutAccount;

  /// Repart sur [location] avec une instance Firestore neuve.
  final Future<void> Function(String location) restart;
  final Duration removeTimeout;

  bool _busy = false;

  Future<void> signOut(String? uid, String? deviceId, {bool revoked = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      if (uid != null && deviceId != null) {
        try {
          // Hors ligne, la suppression resterait en file et partirait avec le cache : on n'attend pas le réseau.
          await removeDevice(uid, deviceId).timeout(removeTimeout);
        } catch (_) {
          // Le document reste : la ligne s'affiche « Déconnexion en attente » et peut être retirée de la liste.
        }
      }
      await wipeCache();
      await forgetDevice();
      await signOutAccount();
      await restart(revoked ? '/connexion?retire=1' : '/connexion');
    } finally {
      _busy = false;
    }
  }
}

@Riverpod(keepAlive: true)
DeviceSession deviceSession(Ref ref) {
  final db = ref.watch(firestoreProvider);
  final devices = ref.watch(devicesRepositoryProvider);
  final auth = ref.watch(authRepositoryProvider);
  return DeviceSession(
    removeDevice: devices.remove,
    pendingWrites: () => db.waitForPendingWrites().then((_) => false).timeout(const Duration(seconds: 2), onTimeout: () => true),
    wipeCache: () async {
      await db.terminate();
      await db.clearPersistence();
    },
    forgetDevice: () async {
      await (await SharedPreferences.getInstance()).remove(deviceIdKey);
    },
    signOutAccount: auth.signOut,
    restart: (location) async {
      // Web : l'instance Firestore arrêtée ne resservirait pas, on recharge la page.
      if (kIsWeb) return reloadAt(location);
      // Android : une instance neuve remplace l'ancienne ; on relance les providers qui la lisent.
      final router = ref.read(routerProvider);
      ref.invalidate(deviceIdProvider);
      ref.invalidate(firestoreProvider);
      router.go(location);
    },
  );
}
```

<!-- file: lib/offline/reload_stub.dart -->
```dart
/// Hors Web : rien à recharger (voir `device_session.dart`).
Future<void> reloadAt(String location) async {}
```

<!-- file: lib/offline/reload_web.dart -->
```dart
import 'package:web/web.dart' as web;

/// Recharge l'app sur [location] : l'instance Firestore arrêtée ne peut pas resservir.
Future<void> reloadAt(String location) async => web.window.location.assign(location);
```

- [ ] **Step 4 : cache persistant**

Dans `lib/main.dart`, juste après `await Firebase.initializeApp(...)` et avant le bloc `if (useEmulators)`, ajouter :

```dart
  // Hors ligne (8c) : cache persistant, partagé entre onglets sur le Web (IndexedDB), réglé avant toute lecture.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
```

- [ ] **Step 5 : faux dépôts**

Dans `test/fakes.dart`, ajouter les imports `package:portail_met/offline/devices_repository.dart`, `package:portail_met/offline/night.dart` et `package:portail_met/offline/night_repository.dart` (à leur place alphabétique), puis à la fin du fichier :

```dart
/// Suivi de la soirée : vues par `'<characterId>/<gameId>'` ; un enregistrement met la vue à jour.
class FakeNightRepository implements NightRepository {
  FakeNightRepository([Map<String, NightView>? views]) : views = views ?? {};

  final Map<String, NightView> views;
  final saved = <Night>[];
  Object? error;
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<NightView> watch(String characterId, String gameId) async* {
    final key = '$characterId/$gameId';
    yield views[key] ?? const NightView(Night());
    await for (final k in _changes.stream) {
      if (k == key) yield views[key]!;
    }
  }

  @override
  Future<void> save(String characterId, String gameId, Night n, String uid) async {
    saved.add(n);
    if (error != null) throw error!;
    views['$characterId/$gameId'] = NightView(n, exists: true);
    _changes.add('$characterId/$gameId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDevicesRepository implements DevicesRepository {
  final calls = <String>[];
  Object? error;

  Future<void> _record(String call) async {
    calls.add(call);
    if (error != null) throw error!;
  }

  @override
  Future<void> touch(String uid, String id, {required String name, required bool web}) => _record('touch:$uid/$id');

  @override
  Future<void> prepared(String uid, String id, String gameId) => _record('prepared:$uid/$id/$gameId');

  @override
  Future<void> revoke(String uid, String id) => _record('revoke:$uid/$id');

  @override
  Future<void> remove(String uid, String id) => _record('remove:$uid/$id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 6 : code généré et vérification**

Run : `dart run build_runner build --delete-conflicting-outputs`, puis `flutter test test/offline/` et `flutter analyze`.

Expected : `night_repository.g.dart`, `devices_repository.g.dart`, `device_session.g.dart` créés ; tests verts ; analyseur propre.

- [ ] **Step 7 : commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/offline/ test/fakes.dart test/offline/device_session_test.dart
git commit -m "feat: hors ligne — cache persistant, dépôts du suivi et des appareils, déconnexion de l’appareil

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : écran joueur « En partie »

**Files :**
- Create : `lib/offline/night_screen.dart`.
- Modify : `lib/router.dart` (route), `lib/characters/character_screen.dart` (bouton du bandeau).
- Test : `test/offline/night_screen_test.dart`, `test/characters/character_screen_test.dart`.

**Interfaces :**
- Consumes :
  - tâche 1 : `Night`, `NightLimits`, `NightTrack`, `nightValue`, `toggle`, `undoTo`, `addNote`, textes ;
  - tâche 4 : `nightProvider`, `nightRepositoryProvider`, `NightView`, `thisDeviceProvider`, `devicesRepositoryProvider`, `Device` ;
  - existants : `characterProvider`, `gamesProvider`, `frozenSheetProvider`, `frozenBy`, `rulebookProvider`, `characterItemsProvider`, `characterPlacesProvider`, `characterSinsProvider`, `dayOf`, `eveningTraits`, `lossThreshold`, `printSheet`, `PrintRow`, `PrintVersion`.
- Produces : `NightScreen({required String characterId, DateTime Function()? now})`, route `/joueur/personnages/:id/partie`.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 5 test`, puis `flutter test test/offline/night_screen_test.dart`.

Expected : échec de compilation (`night_screen.dart` absent).

<!-- file: test/offline/night_screen_test.dart -->
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/game.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/devices_repository.dart';
import 'package:portail_met/offline/night.dart';
import 'package:portail_met/offline/night_repository.dart';
import 'package:portail_met/offline/night_screen.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';

import '../characters/character_test.dart' show sample;
import '../characters/ghoul_test.dart' show ghoulState;
import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;
import '../titles/title_rules_test.dart' show rbTitles;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  // Gel en cours (partie du samedi 3 octobre 2099, levée le 4 à 6h) ; il est 21h le soir de la partie.
  final game = frozenGame(year: 2099);
  final now = DateTime(2099, 10, 3, 21);

  Character isaure() => sample()
    ..blood = 12
    ..willpower = 6
    ..allies = [Ally('a1', 'Maëlle Garnier', level: 1)];
  FrozenSheet snapshot([Character? c]) => FrozenSheet(characterId: 'x', gameId: game.id, sheet: (c ?? isaure()).toMap(), version: 4, gameDate: game.date);

  Future<(FakeNightRepository, FakeDevicesRepository)> pump(
    WidgetTester tester, {
    List<Game>? games,
    NightView? view,
    Stream<FrozenSheet?>? frozen,
    List<Sin> sins = const [],
    Device? device,
    Size size = const Size(1440, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nights = FakeNightRepository({if (view != null) 'x/${game.id}': view});
    final devices = FakeDevicesRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        characterProvider('x').overrideWith((ref) => Stream.value(isaure())),
        rulebookProvider.overrideWith((ref) => rbTitles),
        gamesProvider.overrideWith((ref) => Stream.value(games ?? [game])),
        frozenSheetProvider('x', game.id).overrideWith((ref) => frozen ?? Stream.value(snapshot())),
        nightRepositoryProvider.overrideWith((ref) => nights),
        devicesRepositoryProvider.overrideWith((ref) => devices),
        thisDeviceProvider.overrideWith((ref) => Stream.value(device)),
        characterSinsProvider('x').overrideWith((ref) => Stream.value(sins)),
        noItems,
        noPlaces,
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: NightScreen(characterId: 'x', now: () => now)),
      ),
    ));
    await tester.pumpAndSettle();
    return (nights, devices);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('en ligne : version, cases, pouvoirs, équipement ; la partie est préparée sur l’appareil', (tester) async {
    final (_, devices) = await pump(tester, device: const Device(id: 'd1', name: 'Android'));
    expect(find.text('Isaure en partie'), findsOneWidget);
    expect(find.text('Version figée du 29 sept.'), findsOneWidget);
    expect(find.text('Hors ligne'), findsNothing);
    expect(find.text('Sang dépensé'), findsOneWidget);
    expect(find.text('0 / 12 · reste 12'), findsOneWidget);
    expect(find.text('0 / 6 · reste 6'), findsOneWidget);
    expect(find.byKey(const Key('blood-12')), findsOneWidget);
    expect(find.byKey(const Key('blood-13')), findsNothing);
    expect(find.byKey(const Key('incapacitated-3')), findsOneWidget);
    expect(find.text('Auspex ●●●'), findsOneWidget);
    expect(find.text('Sens exacerbés'), findsOneWidget);
    expect(find.text('Maëlle Garnier ●'), findsOneWidget);
    expect(find.text('Tout est envoyé.'), findsOneWidget);
    expect(devices.calls, ['prepared:u1/d1/g2']);
  });

  testWidgets('préparée : la ligne de version le dit, pas de nouvelle écriture', (tester) async {
    final (_, devices) = await pump(tester, device: Device(id: 'd1', name: 'Android', gameId: 'g2', preparedAt: DateTime(2099, 10, 3, 18)));
    expect(find.text('Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h'), findsOneWidget);
    expect(devices.calls, isEmpty);
  });

  testWidgets('hors ligne : badge, bandeau, saisies en attente ; rien n’est noté sur l’appareil', (tester) async {
    final (_, devices) = await pump(tester, view: const NightView(Night(blood: 2), exists: true, fromCache: true, pending: true), device: const Device(id: 'd1', name: 'Android'));
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.text(offlineText), findsOneWidget);
    expect(find.text('Des saisies attendent le réseau.'), findsOneWidget);
    expect(find.text('2 / 12 · reste 10'), findsOneWidget);
    expect(devices.calls, isEmpty);
  });

  testWidgets('coches et annulation ; une note ajoutée ne s’annule pas (Review Focus 3)', (tester) async {
    final (nights, _) = await pump(tester);
    await tap(tester, find.byKey(const Key('blood-3')));
    expect(nights.saved.last.blood, 3);
    expect(find.text('3 / 12 · reste 9'), findsOneWidget);
    await tap(tester, find.byKey(const Key('hurt-2')));
    expect(nights.saved.last.health, [0, 2, 0]);
    await tester.ensureVisible(find.byKey(const Key('night-note')));
    await tester.enterText(find.byKey(const Key('night-note')), 'Inès Morel, galeriste');
    await tap(tester, find.text('Ajouter la note'));
    expect(nights.saved.last.notes.single.text, 'Inès Morel, galeriste');
    expect(find.text('21h · Inès Morel, galeriste'), findsOneWidget);
    await tap(tester, find.text('Annuler le dernier coup'));
    expect(nights.saved.last.health, [0, 0, 0]);
    expect(nights.saved.last.blood, 3);
    expect(nights.saved.last.notes.single.text, 'Inès Morel, galeriste');
    await tap(tester, find.text('Annuler le dernier coup'));
    expect(nights.saved.last.blood, 0);
    final undo = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Annuler le dernier coup'));
    expect(undo.onPressed, isNull);
  });

  testWidgets('refus du serveur : message (Review Focus 4)', (tester) async {
    final (nights, _) = await pump(tester);
    nights.error = Exception('permission-denied');
    await tap(tester, find.byKey(const Key('blood-1')));
    expect(find.text(refusedText), findsOneWidget);
  });

  testWidgets('traits de Bête de la soirée, en lecture', (tester) async {
    final (nights, _) = await pump(tester, sins: [
      Sin(id: 's1', date: DateTime(2099, 10, 3, 22), level: 2),
      Sin(id: 's2', date: DateTime(2099, 9, 20), level: 3),
    ]);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text(beastNote), findsOneWidget);
    await tap(tester, find.byKey(const Key('beast-4')));
    expect(nights.saved, isEmpty);
  });

  testWidgets('goule : Vitae dépensée, 5 cases', (tester) async {
    await pump(tester, frozen: Stream.value(snapshot(isaure()..ghoul = ghoulState())));
    expect(find.text('Vitae dépensée'), findsOneWidget);
    expect(find.byKey(const Key('blood-5')), findsOneWidget);
    expect(find.byKey(const Key('blood-6')), findsNothing);
  });

  testWidgets('fiche non figée : message', (tester) async {
    await pump(tester, games: const []);
    expect(find.text(notFrozenText), findsOneWidget);
  });

  testWidgets('version figée absente du cache : message de préparation', (tester) async {
    await pump(tester, frozen: StreamController<FrozenSheet?>().stream);
    expect(find.text(notPreparedText), findsOneWidget);
  });

  testWidgets('mobile, 390 px', (tester) async {
    await pump(tester, size: const Size(390, 2800));
    expect(tester.takeException(), isNull);
    expect(find.text('Isaure en partie'), findsOneWidget);
  });
}
```

Dans `test/characters/character_screen_test.dart`, ajouter à la fin de `main` :

```dart
  testWidgets('J2 : bouton « En partie » dans le bandeau du gel seulement (sous-projet 8c)', (tester) async {
    await pump(tester, Stream.value(sample()));
    expect(find.text('En partie'), findsNothing);
    await pump(tester, Stream.value(sample()), games: [frozenGame(year: 2099)]);
    expect(find.text('En partie'), findsOneWidget);
  });
```

- [ ] **Step 2 : implémentation de l’écran**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 5 impl`.

<!-- file: lib/offline/night_screen.dart -->
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../items/items_repository.dart';
import '../morality/morality_rules.dart' show eveningTraits, lossThreshold;
import '../morality/sin.dart' show Sin, dayOf;
import '../morality/sins_repository.dart';
import '../places/places_repository.dart';
import '../print/print_sheet.dart';
import '../rulebook/rulebook_provider.dart';
import 'device.dart';
import 'devices_repository.dart';
import 'night.dart';
import 'night_repository.dart';

/// « En partie » (J-HorsLigne) : suivi de la soirée sur la version figée, utilisable sans réseau.
class NightScreen extends ConsumerStatefulWidget {
  const NightScreen({super.key, required this.characterId, this.now});
  final String characterId;

  /// Heure de l'appareil ; remplacée dans les tests.
  final DateTime Function()? now;

  @override
  ConsumerState<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends ConsumerState<NightScreen> {
  /// États précédents des cases, pour « Annuler le dernier coup ».
  final _undo = <Night>[];
  final _note = TextEditingController();
  bool _preparing = false;

  String get _base => '/joueur/personnages/${widget.characterId}';
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Hors ligne, l'écriture attend le réseau : on ne l'attend pas ; un refus du serveur est signalé.
  void _save(String uid, String gameId, Night next) {
    ref.read(nightRepositoryProvider).save(widget.characterId, gameId, next, uid).catchError((Object _) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(refusedText)));
    });
  }

  void _play(String uid, String gameId, Night before, Night after) {
    setState(() => _undo.add(before));
    _save(uid, gameId, after);
  }

  void _cancel(String uid, String gameId, Night current) {
    final previous = _undo.removeLast();
    setState(() {});
    _save(uid, gameId, undoTo(current, previous));
  }

  void _addNote(String uid, String gameId, Night current) {
    final next = addNote(current, _note.text, _now);
    if (next == null) return;
    _note.clear();
    _save(uid, gameId, next);
  }

  /// Première ouverture avec réseau : l'appareil note la partie préparée (« Copie hors ligne » dans Mon compte).
  void _markPrepared(String uid, Device? device, String gameId, bool fromCache) {
    if (_preparing || fromCache || device == null || device.gameId == gameId) return;
    _preparing = true;
    ref.read(devicesRepositoryProvider).prepared(uid, device.id, gameId).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider).value?.uid;
    final value = ref.watch(characterProvider(widget.characterId));
    // Riverpod 3 relance un provider en erreur : on lit l'erreur même pendant la relance.
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    return asyncView(value, (live) {
      if (live == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      final now = _now;
      final game = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], live.id, now);
      if (game == null) {
        return EmptyState(
          kind: EmptyKind.empty,
          title: notFrozenText,
          message: 'Le bouton « En partie » apparaît sur la fiche pendant le gel.',
          actionLabel: 'Retour à la fiche',
          onAction: () => context.go(_base),
        );
      }
      final snap = ref.watch(frozenSheetProvider(live.id, game.id)).value;
      final view = ref.watch(nightProvider(live.id, game.id)).value;
      final rb = ref.watch(rulebookProvider);
      if (snap == null || view == null || rb == null) {
        return const EmptyState(kind: EmptyKind.offline, title: 'Chargement de la version figée…', message: notPreparedText);
      }
      final device = ref.watch(thisDeviceProvider).value;
      if (uid != null) _markPrepared(uid, device, game.id, view.fromCache);

      final c = snap.character;
      final limits = NightLimits.of(c);
      final night = view.night;
      final sheet = printSheet(
        c,
        version: PrintVersion.frozen,
        game: game,
        now: now,
        rb: rb,
        items: ref.watch(characterItemsProvider(live.id)).value ?? const [],
        places: ref.watch(characterPlacesProvider(live.id)).value ?? const [],
      );
      final evening = [
        for (final s in ref.watch(characterSinsProvider(live.id)).value ?? const <Sin>[])
          if (dayOf(s.date) == dayOf(game.date)) s,
      ];
      final traits = eveningTraits(evening).clamp(0, lossThreshold);
      final preparedAt = device?.gameId == game.id ? device?.preparedAt : null;
      final t = Theme.of(context).textTheme;
      final wide = isWide(context);

      Widget boxes(NightTrack track, String label) {
        final max = limits.of(track);
        final v = nightValue(night, track).clamp(0, max);
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 1; i <= max; i++)
            _Box(
              key: Key('${track.name}-$i'),
              label: '$label $i',
              filled: i <= v,
              onTap: uid == null ? null : () => _play(uid, game.id, night, toggle(night, track, i, limits)),
            ),
        ]);
      }

      Widget gauge(String title, String? count, Widget body) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: t.titleSmall)),
              if (count != null) Text(count, style: t.bodySmall),
            ]),
            const SizedBox(height: 8),
            body,
          ]);

      Widget rows(List<PrintRow> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.dots > 0 ? '${r.label} ${'●' * r.dots}' : r.label, style: t.titleSmall),
                  if (r.detail.isNotEmpty) Text(r.detail, style: t.bodySmall),
                ]),
              ),
          ]);

      final bloodLabel = limits.vitae ? 'Vitae dépensée' : 'Sang dépensé';
      final tracker = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
            const SectionTitle('Suivi de la soirée'),
            OutlinedButton(
              onPressed: _undo.isEmpty || uid == null ? null : () => _cancel(uid, game.id, night),
              child: const Text('Annuler le dernier coup'),
            ),
          ]),
          const SizedBox(height: 18),
          gauge(bloodLabel, spentText(nightValue(night, NightTrack.blood).clamp(0, limits.blood), limits.blood), boxes(NightTrack.blood, bloodLabel)),
          const SizedBox(height: 20),
          gauge('Volonté dépensée', spentText(nightValue(night, NightTrack.willpower).clamp(0, limits.willpower), limits.willpower),
              boxes(NightTrack.willpower, 'Volonté dépensée')),
          const SizedBox(height: 20),
          gauge(
            'Santé',
            null,
            Wrap(spacing: 16, runSpacing: 12, children: [
              for (final (track, name) in [(NightTrack.healthy, 'Sain'), (NightTrack.hurt, 'Blessé'), (NightTrack.incapacitated, 'Incapacité')])
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  boxes(track, name),
                  const SizedBox(height: 4),
                  Text(name, style: t.bodySmall),
                ]),
            ]),
          ),
          const SizedBox(height: 20),
          gauge(
            'Traits de Bête ce soir',
            '$traits / $lossThreshold',
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 1; i <= lossThreshold; i++) _Box(key: Key('beast-$i'), label: 'Traits de Bête ce soir $i', filled: i <= traits, round: true),
            ]),
          ),
          const SizedBox(height: 12),
          Text(beastNote, style: t.bodySmall),
        ]),
      );

      // `printSheet` met « Aucun » dans une liste vide : on le retire pour regrouper les trois listes.
      bool real(PrintRow r) => r.label != 'Aucun';
      final gear = [
        ...sheet.items.where(real),
        for (final a in c.allies) PrintRow(a.name, detail: 'allié', dots: a.level),
        ...sheet.places.where(real),
      ];

      final side = [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Pouvoirs'),
            const SizedBox(height: 8),
            rows(sheet.disciplines),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Note de partie'),
            const SizedBox(height: 10),
            TextField(
              key: const Key('night-note'),
              controller: _note,
              maxLines: 3,
              maxLength: noteMaxLength,
              decoration: const InputDecoration(hintText: 'Ce qui s’est passé, qui vous avez rencontré…'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton(onPressed: uid == null ? null : () => _addNote(uid, game.id, night), child: const Text('Ajouter la note')),
              OutlinedButton(onPressed: () => context.go('$_base/xp'), child: const Text('Brouillon de demande')),
            ]),
            for (final n in night.notes.reversed) Padding(padding: const EdgeInsets.only(top: 8), child: Text(noteLine(n), style: t.bodyMedium)),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Équipement, alliés et lieux'),
            const SizedBox(height: 8),
            if (gear.isEmpty) Text('Aucun', style: t.bodyMedium) else rows(gear),
          ]),
        ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Envoi'),
            const SizedBox(height: 8),
            Text(sentText(view.pending), style: t.bodyMedium?.copyWith(color: view.pending ? AppColors.goldLight : AppColors.success)),
          ]),
        ),
      ];

      return PageBody(children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton(onPressed: () => context.go(_base), child: Text(live.name)),
          Text('/ En partie', style: t.bodySmall),
        ]),
        Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${firstName(live.name)} en partie', style: wide ? t.displaySmall : t.headlineMedium),
          if (view.fromCache) const _OfflineBadge(),
        ]),
        const SizedBox(height: 6),
        Text(versionLine(game, preparedAt), style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: () => context.go(_base), child: const Text('Fiche complète (lecture)')),
        ),
        const SizedBox(height: 20),
        if (view.fromCache) ...[const _Notice(offlineText), const SizedBox(height: 12)],
        if (kIsWeb) ...[const _Notice(webTabText), const SizedBox(height: 12)],
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: tracker),
            const SizedBox(width: 24),
            SizedBox(
              width: 460,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final p in side) ...[p, const SizedBox(height: 20)],
              ]),
            ),
          ])
        else ...[
          tracker,
          const SizedBox(height: 20),
          for (final p in side) ...[p, const SizedBox(height: 20)],
        ],
      ]);
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }
}

/// Case du suivi ; ronde pour les traits de Bête, sans action quand elle est en lecture.
class _Box extends StatelessWidget {
  const _Box({super.key, required this.label, required this.filled, this.onTap, this.round = false});
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool round;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        toggled: filled,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: round ? const CircleBorder() : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: filled ? AppColors.accent : Colors.transparent,
              border: Border.all(color: filled ? AppColors.accentIcon : AppColors.fieldBorder, width: 1.5),
              borderRadius: round ? null : BorderRadius.circular(5),
              shape: round ? BoxShape.circle : BoxShape.rectangle,
            ),
          ),
        ),
      );
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.reviewBg, borderRadius: BorderRadius.circular(999)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off, size: 16, color: AppColors.goldLight),
          SizedBox(width: 6),
          Text('Hors ligne', style: TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Bandeau d'avertissement (hors ligne, onglet à garder ouvert).
class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.reviewBg,
          border: Border.all(color: AppColors.gold),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textSoft, fontSize: 15)),
      );
}
```

- [ ] **Step 3 : route et bouton du bandeau**

Dans `lib/router.dart` :
1. ajouter l’import `import 'offline/night_screen.dart';` à sa place alphabétique ;
2. juste après la route `/joueur/personnages/:id/imprimer`, ajouter :

```dart
          GoRoute(
            path: '/joueur/personnages/:id/partie',
            builder: (_, s) => NightScreen(characterId: s.pathParameters['id']!),
          ),
```

Dans `lib/characters/character_screen.dart`, remplacer l’`action:` du `FreezeBanner` :

```dart
            action: TextButton(onPressed: () => context.go('$basePath/imprimer'), child: const Text('Imprimer')),
```

par :

```dart
            action: Wrap(spacing: 4, children: [
              TextButton(onPressed: () => context.go('$basePath/partie'), child: const Text('En partie')),
              TextButton(onPressed: () => context.go('$basePath/imprimer'), child: const Text('Imprimer')),
            ]),
```

- [ ] **Step 4 : vérifier**

Run : `flutter test test/offline/ test/characters/character_screen_test.dart`, puis `flutter analyze`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 5 : commit**

```bash
git add lib/offline/night_screen.dart lib/router.dart lib/characters/character_screen.dart test/offline/night_screen_test.dart test/characters/character_screen_test.dart
git commit -m "feat: hors ligne — écran « En partie » du joueur, route et bouton du bandeau

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : suivi de la soirée sur l’écran du gel

**Files :**
- Modify : `lib/games/freeze_screen.dart`.
- Test : `test/games/freeze_screen_test.dart`.

**Interfaces :**
- Consumes : `nightProvider`, `nightRepositoryProvider`, `NightView` (tâche 4) ; `NightLimits`, `nightSummary`, `noteLine` (tâche 1) ; `FakeNightRepository` (`test/fakes.dart`).
- Produces : bloc « Suivi de la soirée » dans le panneau de la fiche choisie (`_NightBlock`).

- [ ] **Step 1 : tests (échec attendu)**

Dans `test/games/freeze_screen_test.dart` :
1. ajouter les imports `package:portail_met/offline/night.dart` et `package:portail_met/offline/night_repository.dart` ;
2. dans la signature de `pump`, ajouter le paramètre `FakeNightRepository? nights,` ;
3. dans la liste `overrides`, ajouter `nightRepositoryProvider.overrideWith((ref) => nights ?? FakeNightRepository()),` ;
4. à la fin de `main`, ajouter :

```dart
  testWidgets('gel en cours : suivi de la soirée de la fiche choisie, en lecture (sous-projet 8c)', (tester) async {
    final nights = FakeNightRepository({
      'x/g2': NightView(
        Night(blood: 3, willpower: 1, health: const [2, 0, 0], notes: [NightNote('Inès Morel, galeriste', DateTime(2026, 10, 3, 22, 15))]),
        exists: true,
      ),
    });
    await pump(tester, games: [g1, g2], nights: nights);
    await tester.tap(find.text('Isaure de Valcourt').first);
    await tester.pumpAndSettle();
    expect(find.text('SUIVI DE LA SOIRÉE'), findsOneWidget);
    // La version figée d'Isaure n'a ni sang ni volonté (fiche `sample()`).
    expect(find.text('Sang 3 / 0 · Volonté 1 / 0 · Santé 2 · 0 · 0'), findsOneWidget);
    expect(find.text('22h15 · Inès Morel, galeriste'), findsOneWidget);
    await tester.tap(find.text('Bastien Roche').first);
    await tester.pumpAndSettle();
    expect(find.text('Aucun suivi pour cette partie'), findsOneWidget);
    expect(nights.saved, isEmpty);
  });

  testWidgets('gel en cours : le narrateur voit aussi le suivi (sous-projet 8c)', (tester) async {
    await pump(tester, me: julien, games: [g1, g2]);
    expect(find.text('SUIVI DE LA SOIRÉE'), findsOneWidget);
  });
```

Run : `flutter test test/games/freeze_screen_test.dart`.

Expected : les deux nouveaux tests échouent (« SUIVI DE LA SOIRÉE » absent).

- [ ] **Step 2 : implémentation**

Dans `lib/games/freeze_screen.dart` :
1. ajouter les imports `import '../offline/night.dart';` et `import '../offline/night_repository.dart';` ;
2. dans `_detail`, juste avant `if (me.role.managesAccounts) ...[`, ajouter :

```dart
        const SizedBox(height: 16),
        _NightBlock(characterId: r.live.id, gameId: g.id, sheet: snap?.character ?? r.live),
```

3. à la fin du fichier, ajouter :

```dart
/// Suivi de la soirée saisi par le joueur (sous-projet 8c), en lecture pour tout le conte.
class _NightBlock extends ConsumerWidget {
  const _NightBlock({required this.characterId, required this.gameId, required this.sheet});
  final String characterId;
  final String gameId;

  /// Version figée : elle donne les maxima.
  final Character sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final view = ref.watch(nightProvider(characterId, gameId)).value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Suivi de la soirée'),
      const SizedBox(height: 8),
      if (view == null)
        Text('Chargement du suivi…', style: t.bodySmall)
      else if (!view.exists)
        Text('Aucun suivi pour cette partie', style: t.bodyMedium)
      else ...[
        Text(nightSummary(view.night, NightLimits.of(sheet)), style: t.bodyMedium),
        for (final n in view.night.notes.reversed) Padding(padding: const EdgeInsets.only(top: 6), child: Text(noteLine(n), style: t.bodySmall)),
      ],
    ]);
  }
}
```

- [ ] **Step 3 : vérifier**

Run : `flutter test test/games/` puis `flutter analyze`.

Expected : tous les tests passent ; analyseur propre.

- [ ] **Step 4 : commit**

```bash
git add lib/games/freeze_screen.dart test/games/freeze_screen_test.dart
git commit -m "feat: hors ligne — suivi de la soirée sur l’écran du gel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7 : appareils connectés, déconnexion à distance

**Files :**
- Create : `lib/offline/devices_section.dart`.
- Modify : `lib/account/account_screen.dart`, `lib/auth/login_screen.dart`, `lib/router.dart`.
- Test : `test/offline/devices_section_test.dart`, `test/login_screen_test.dart`.

**Interfaces :**
- Consumes : `Device`, `deviceLine`, `revokedNotice`, `pendingLossText` (tâche 2) ; `myDevicesProvider`, `deviceIdProvider`, `devicesRepositoryProvider`, `thisDeviceProvider`, `deviceSessionProvider` (tâche 4) ; `gamesProvider`, `currentUserProvider`, `authStateProvider`.
- Produces : `DevicesSection({required Future<void> Function() onSignOut, DateTime Function()? now})` ; `LoginScreen(revoked: bool)` ; écoute de `thisDeviceProvider` dans le routeur.

- [ ] **Step 1 : tests (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 7 test`.

<!-- file: test/offline/devices_section_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/devices_repository.dart';
import 'package:portail_met/offline/devices_section.dart';

import '../fakes.dart';
import '../games/game_rules_test.dart' show frozenGame;

void main() {
  const camille = AppUser(uid: 'u1', displayName: 'Camille R.', email: 'c@ex.fr', role: Role.joueur);
  final now = DateTime(2099, 10, 3, 21);
  final devices = [
    Device(id: 'd1', name: 'Navigateur · Windows', web: true, lastSeen: DateTime(2099, 10, 3, 18)),
    Device(id: 'd2', name: 'Android', lastSeen: DateTime(2099, 10, 2, 20), gameId: 'g2', preparedAt: DateTime(2099, 10, 2, 20)),
    Device(id: 'd3', name: 'Navigateur · Android', web: true, lastSeen: DateTime(2099, 9, 29), revokedAt: DateTime(2099, 10, 3, 20)),
  ];

  Future<(FakeDevicesRepository, List<String>)> pump(WidgetTester tester, {Size size = const Size(1440, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeDevicesRepository();
    final signedOut = <String>[];
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(camille)),
        myDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        deviceIdProvider.overrideWith((ref) async => 'd1'),
        gamesProvider.overrideWith((ref) => Stream.value([frozenGame(year: 2099)])),
        devicesRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(
          body: SingleChildScrollView(child: DevicesSection(now: () => now, onSignOut: () async => signedOut.add('moi'))),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (repo, signedOut);
  }

  testWidgets('liste : cet appareil, copie hors ligne, déconnexion en attente', (tester) async {
    await pump(tester);
    expect(find.text('APPAREILS CONNECTÉS'), findsOneWidget);
    expect(find.text('Navigateur · Windows · Cet appareil'), findsOneWidget);
    expect(find.text('Connexion web · aujourd’hui'), findsOneWidget);
    expect(find.text('Copie hors ligne · partie du 3 oct. · hier'), findsOneWidget);
    expect(find.text('Déconnexion en attente'), findsOneWidget);
    expect(find.text('Retirer'), findsOneWidget);
    expect(find.text('Déconnecter un appareil efface aussi sa copie hors ligne.'), findsOneWidget);
    expect(find.text('Un appareil hors ligne est déconnecté à son prochain passage en ligne.'), findsOneWidget);
  });

  testWidgets('déconnecter un autre appareil : confirmation, puis marque', (tester) async {
    final (repo, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('device-d2')));
    await tester.pumpAndSettle();
    expect(find.text('Déconnecter « Android » ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Déconnecter'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['revoke:u1/d2']);
  });

  testWidgets('déconnecter un autre appareil : annuler ne fait rien', (tester) async {
    final (repo, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('device-d2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('cet appareil : même effet que « Se déconnecter » ; appareil marqué : retiré de la liste', (tester) async {
    final (repo, signedOut) = await pump(tester);
    await tester.tap(find.byKey(const Key('device-d1')));
    await tester.pumpAndSettle();
    expect(signedOut, ['moi']);
    await tester.tap(find.byKey(const Key('device-d3')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['remove:u1/d3']);
  });

  testWidgets('mobile, 390 px', (tester) async {
    await pump(tester, size: const Size(390, 1200));
    expect(tester.takeException(), isNull);
  });
}
```

Dans `test/login_screen_test.dart` :
1. ajouter le paramètre `bool revoked = false` à `pumpLogin`, et passer `revoked: revoked` au `LoginScreen` ;
2. ajouter le test :

```dart
  testWidgets('appareil déconnecté à distance : message (sous-projet 8c)', (tester) async {
    await pumpLogin(tester, revoked: true);
    expect(find.text('Cet appareil a été déconnecté depuis un autre appareil.'), findsOneWidget);
  });
```

Run : `flutter test test/offline/devices_section_test.dart test/login_screen_test.dart`.

Expected : échec de compilation (`devices_section.dart` absent, paramètre `revoked` inconnu).

- [ ] **Step 2 : section « Appareils connectés »**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-19-hors-ligne.md 7 impl`.

<!-- file: lib/offline/devices_section.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/games_repository.dart';
import 'device.dart';
import 'devices_repository.dart';

/// « Appareils connectés » de Mon compte (Compte) : un appareil par ligne, « Déconnecter ».
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key, required this.onSignOut, this.now});

  /// Déconnexion de cet appareil, comme « Se déconnecter ».
  final Future<void> Function() onSignOut;

  /// Heure de l'appareil ; remplacée dans les tests.
  final DateTime Function()? now;

  Future<void> _revoke(BuildContext context, WidgetRef ref, String uid, Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnecter « ${d.name} » ?'),
        content: const Text('Sa copie hors ligne sera effacée à son prochain passage en ligne.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déconnecter')),
        ],
      ),
    );
    if (ok == true) await ref.read(devicesRepositoryProvider).revoke(uid, d.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final uid = ref.watch(currentUserProvider).value?.uid;
    final devices = ref.watch(myDevicesProvider).value ?? const <Device>[];
    final mine = ref.watch(deviceIdProvider).value;
    final games = ref.watch(gamesProvider).value ?? const <Game>[];
    final today = (now ?? DateTime.now)();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Appareils connectés'),
        const SizedBox(height: 8),
        if (devices.isEmpty) Text('Aucun appareil.', style: t.bodyMedium),
        for (final d in devices)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.id == mine ? '${d.name} · Cet appareil' : d.name, style: t.bodyLarge),
                  Text(deviceLine(d, games, today), style: t.bodySmall),
                ]),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: Key('device-${d.id}'),
                onPressed: uid == null
                    ? null
                    : () {
                        if (d.id == mine) {
                          onSignOut();
                        } else if (d.revokedAt != null) {
                          ref.read(devicesRepositoryProvider).remove(uid, d.id);
                        } else {
                          _revoke(context, ref, uid, d);
                        }
                      },
                child: Text(d.revokedAt != null && d.id != mine ? 'Retirer' : 'Déconnecter'),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Text('Déconnecter un appareil efface aussi sa copie hors ligne.', style: t.bodySmall),
        Text('Un appareil hors ligne est déconnecté à son prochain passage en ligne.', style: t.bodySmall),
      ]),
    );
  }
}
```

- [ ] **Step 3 : Mon compte**

Dans `lib/account/account_screen.dart` :
1. ajouter les imports :

```dart
import '../offline/device.dart' show pendingLossText;
import '../offline/device_session.dart';
import '../offline/devices_repository.dart' show deviceIdProvider;
import '../offline/devices_section.dart';
```

2. dans `_AccountScreenState`, après `_run(...)`, ajouter :

```dart
  /// « Se déconnecter » : le cache de l'appareil est vidé ; des saisies pas encore envoyées seraient perdues.
  Future<void> _signOut() async {
    final session = ref.read(deviceSessionProvider);
    if (await session.pendingWrites()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text(pendingLossText),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await session.signOut(ref.read(currentUserProvider).value?.uid, await ref.read(deviceIdProvider.future));
  }
```

3. dans `build`, remplacer `TextButton(onPressed: repo.signOut, child: const Text('Se déconnecter'))` par `TextButton(onPressed: _signOut, child: const Text('Se déconnecter'))` ;
4. juste avant `return PageBody(children: [`, ajouter `final devices = DevicesSection(onSignOut: _signOut);` ;
5. dans la mise en page large, remplacer `Expanded(child: password),` par `Expanded(child: Column(children: [password, const SizedBox(height: 20), devices])),` ; dans la mise en page étroite, après `password,` ajouter `const SizedBox(height: 20),` puis `devices,` ;
6. remplacer le texte `'Bientôt ici : notifications par e-mail, appareils connectés, export de vos données.'` par `'Bientôt ici : notifications par e-mail, export de vos données.'`.

- [ ] **Step 4 : page de connexion**

Dans `lib/auth/login_screen.dart` :
1. ajouter l’import `import '../offline/device.dart' show revokedNotice;` ;
2. dans le constructeur, ajouter `this.revoked = false` après `this.disabled = false`, et le champ :

```dart
  /// Arrivée après une déconnexion demandée depuis un autre appareil (`/connexion?retire=1`).
  final bool revoked;
```

3. juste après le bloc `if (widget.disabled) ...[ … ],`, ajouter :

```dart
          if (widget.revoked) ...[
            const FormError(revokedNotice),
            const SizedBox(height: 18),
          ],
```

- [ ] **Step 5 : routeur**

Dans `lib/router.dart` :
1. ajouter les imports `import 'offline/device_session.dart';` et `import 'offline/devices_repository.dart';` à leur place alphabétique ;
2. juste après le `ref.listen(currentUserProvider, …);` existant, ajouter :

```dart
  // Appareil déconnecté depuis un autre appareil (8c) : il vide son cache et se déconnecte lui-même.
  ref.listen(thisDeviceProvider, (_, next) {
    final d = next.value;
    if (d != null && d.revokedAt != null) {
      ref.read(deviceSessionProvider).signOut(ref.read(authStateProvider).value?.uid, d.id, revoked: true);
    }
  });
```

3. dans la route `/connexion`, ajouter au `LoginScreen` l’argument `revoked: state.uri.queryParameters['retire'] == '1',`.

- [ ] **Step 6 : vérifier**

Run : `dart run build_runner build --delete-conflicting-outputs` (le routeur peut changer d’empreinte), puis `flutter test` et `flutter analyze`.

Expected : toute la suite passe ; analyseur propre.

- [ ] **Step 7 : commit**

```bash
git add lib/offline/devices_section.dart lib/account/account_screen.dart lib/auth/login_screen.dart lib/router.dart lib/router.g.dart test/offline/devices_section_test.dart test/login_screen_test.dart
git commit -m "feat: hors ligne — appareils connectés dans Mon compte, déconnexion à distance

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8 : vérification finale

**Files :** aucun nouveau fichier, sauf correctifs éventuels.

**Interfaces :** aucune.

- [ ] **Step 1 : suites complètes**

Run :
- `flutter analyze` ;
- `flutter test` ;
- depuis `rules_test/` : `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.

Expected : analyseur propre ; tous les tests verts.

- [ ] **Step 2 : vérification à la main sur Chrome (émulateurs)**

Run : `firebase emulators:start --only auth,firestore` dans un terminal, puis `flutter run -d chrome --dart-define=EMULATORS=true`.

1. En conteur, figer une partie avec la fiche d’un joueur.
2. En joueur, ouvrir la fiche : le bandeau du gel montre « En partie ». L’ouvrir : version figée, cases, « Tout est envoyé. ».
3. Dans les outils de développement, onglet Réseau, passer « Hors ligne » : le badge « Hors ligne » et le bandeau apparaissent ; cocher deux cases de sang, ajouter une note : « Des saisies attendent le réseau. ».
4. Repasser en ligne : « Tout est envoyé. » ; en conteur (autre navigateur), l’écran du gel montre « Sang 2 / … » et la note.
5. « Mon compte » : la ligne de l’appareil montre « Cet appareil » et « Copie hors ligne · partie du … ».
6. Depuis un second navigateur connecté au même compte, « Déconnecter » le premier : il revient sur la connexion avec « Cet appareil a été déconnecté depuis un autre appareil. ».
7. Se reconnecter : l’app fonctionne (nouvelle instance Firestore après le rechargement).

- [ ] **Step 3 : vérification à la main sur l’APK**

Run : `flutter build apk --dart-define=EMULATORS=true`, installer sur l’émulateur Android.

1. Préparer la partie (ouvrir « En partie » avec du réseau), couper le réseau, fermer puis rouvrir l’app : la fiche figée et le suivi s’affichent depuis le cache.
2. « Se déconnecter » sans réseau après une coche : la confirmation « Des saisies n’ont pas encore été envoyées : elles seront perdues. » apparaît.
3. Se déconnecter, se reconnecter : les écrans se chargent (instance Firestore neuve après `terminate`). Si une erreur Firestore apparaît après la reconnexion, le signaler : le repli est de relancer l’app (`SystemNavigator.pop()`) au lieu de `router.go` dans `deviceSessionProvider`.

- [ ] **Step 4 : commit des correctifs éventuels**

```bash
git add -A -- lib test rules_test/offline.test.js firestore.rules
git commit -m "fix: hors ligne — revue finale

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Seulement s’il y a des correctifs ; vérifier `git status` avant, et ne jamais ajouter les `bash.exe.stackdump` ni `firestore-debug.log`.)
