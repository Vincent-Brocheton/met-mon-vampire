# Liens de sang (sous-projet 7c) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** les liens de sang entre fiches sont tenus par le conte (gorgées, contacts), avec des échéances calculées seules, visibles du joueur selon ce qu'il sait.

**Architecture :**
- **Collection `bonds/{regnantId}_{thrallId}`**, un document par couple de fiches ; modèle `Bond` dans `lib/bonds/bond.dart`.
- **Calculs purs** dans `lib/bonds/bond_rules.dart` : niveau effectif à une date (aucune tâche planifiée), échéance, gorgée, contact, filtres.
- **Dépôt** `lib/bonds/bonds_repository.dart` : la gorgée s'écrit en un lot (lien, liens moindres effacés, événement « Lien de sang » du lié).
- **Écrans :**
  - formulaire commun `DrinkForm` (`lib/bonds/drink_form.dart`) ;
  - bloc du conte `StaffBonds` et bloc du joueur `PlayerBonds`, dans l'onglet « Moralité & liens » ;
  - page `BondsScreen` (`/conteur/liens`) ;
  - le panneau de la goule lit son lien dans `bonds`.

**Tech Stack :** inchangée.

**Spec :** `docs/superpowers/specs/2026-10-15-liens-de-sang-design.md`.

**Maquettes :** canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp, planches `C-Moralite.dc.html`, `J-Moralite.dc.html` (bloc Liens de sang), `C-Liens.dc.html` et `C-Liens-mobile.dc.html`. Pour les lire : outil Artifact, `action: read`, `path: project/<planche>`.

## Global Constraints

- **Contraintes habituelles :**
  - extraction par `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md <N> [test|impl]` ;
  - textes en français, apostrophe typographique ’ dans les textes affichés ;
  - analyseur propre, pas de `dart format` ;
  - fins de ligne LF ;
  - commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - ne jamais commiter `bash.exe.stackdump` ni `rules_test/firestore-debug.log`.
- **Branche :** `liens`, déjà créée.
- **Code généré :** `dart run build_runner build --delete-conflicting-outputs` après un nouveau `@riverpod`.
- **Tests des règles :** depuis `rules_test`, `JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test`.
- **Dart :** un record contenant des listes se compare par identité. Ne pas écrire `expect((a, [..]), (x, [..]))`.
- **Valeurs fixes :**
  - délais : 3 mois (●●● → ●●), 6 mois sans contact (●● effacé), un an sans contact (● effacé), en mois du calendrier ; le jour même de l'échéance, le changement a eu lieu ;
  - échéance proche : 30 jours ou moins ;
  - gorgées : 1 à 3, niveau plafonné à 3 ;
  - refus : « <lié> est déjà lié complètement à <régnant>. » ;
  - contrôles : « Choisissez qui donne son sang », « Choisissez qui boit », « Une fiche ne peut pas se lier elle-même », « Date invalide » ;
  - écriture refusée : « Enregistrement refusé : réessayez. ».
- **Lecture seule du conte :** narrateur ; conte sur sa propre fiche (vue du joueur) ; fiche en brouillon ou en validation qui n'est pas un PNJ.
- **Leçons des lots précédents :**
  - un widget qui lit `currentUserProvider` à l'enregistrement le surveille aussi dans `build` ;
  - vérifier 390 px (rangées de boutons en `Wrap`) ;
  - un enregistrement refusé ne vide pas le formulaire.

## Review Focus

1. **Gorgée datée dans le passé, contact sur un lien effacé :** les dates ne reculent jamais et un lien effacé n'est pas ravivé. Tests : tâche 1.
2. **Lien complet existant ailleurs :** refus visible, bouton inactif, aucune écriture. Tests : tâches 1 et 3.
3. **Joueur :** il ne voit jamais un lien qu'il ne connaît pas ; sa requête filtrée passe et la requête sans filtre est refusée. Tests : tâches 2 et 4.
4. **Bornes des délais :** la veille, le niveau n'a pas changé ; le jour même, il a changé ; fin de mois du calendrier. Tests : tâche 1.
5. **390 px :** bloc du conte avec le formulaire ouvert, page de la chronique sur mobile. Tests : tâches 3 et 5.

**Décision prise ici :** l'équipe lit tous les liens, y compris ceux qui touchent sa propre fiche. Une requête sur toute la collection ne peut pas les exclure. Sur sa propre fiche, l'écran montre la vue du joueur.

---

### Task 1 : modèle, calculs purs, type d'événement

**Files :**
- Create : `lib/bonds/bond.dart`, `lib/bonds/bond_rules.dart`.
- Modify : `lib/events/story_event.dart` (type `bond`).
- Test : `test/bonds/bond_rules_test.dart`.

**Interfaces :**
- Produces :
  - `Bond({regnantId, regnantName, regnantPlayerUid, thrallId, thrallName, thrallPlayerUid, ghoul, level, lastDrink, lastContact, known, regnantKnows, byName, stored})`, `Bond.fromMap`, `toMap`, `copy`, `id` ;
  - `bondId(regnantId, thrallId)`, `bondBetween(regnant, thrall, day)`, `refreshed(b, regnant, thrall)`, `bondData(b, by)` ;
  - dans `bond_rules.dart` : `addMonths`, `bondDots`, `effectiveLevel`, `nextChange`, `dueText`, `daysUntil`, `dueSoon`, `DrinkOutcome`, `drinkOutcome`, `drunk`, `contacted`, `DrinkWrite`, `drinkWrite`, `bondEvent`, `drinkPreview`, `bondChecks`, `partyTag`, `activeBonds`, `BondFilter`, `bondMatches`, `bondStats`, `ghoulBondToDate`, `datedGhoulBond`, `staffLine`, `sufferedLine`, `sufferedDelay`, `exertedLine` ;
  - `EventType.bond` (« Lien de sang », pastille sang) ;
  - dans le test, des fiches et liens d'exemple réutilisés par les tâches 3 à 5 : `today`, `lucie()`, `octave()`, `agathe()`, `lemaire()`, `bastien()`, `jonas()`, `cast()`, `link(...)`, `octLuc()`, `lucLem()`, `agaBas()`, `octJon()`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 1 test`, puis `flutter test test/bonds/bond_rules_test.dart`.

Expected : échec au chargement.

<!-- file: test/bonds/bond_rules_test.dart -->
```dart
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
```

- [ ] **Step 2 : type d'événement**

Dans `lib/events/story_event.dart`, ajouter `bond` après `morality` :

```dart
  morality('Moralité', EventTone.moral),
  bond('Lien de sang', EventTone.blood),
```

- [ ] **Step 3 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 1 impl`.

<!-- file: lib/bonds/bond.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';
import '../characters/character_repository.dart' show Actor;
import '../morality/sin.dart' show dayOf;

/// Identifiant du document d'un lien : `<régnant>_<lié>`.
String bondId(String regnantId, String thrallId) => '${regnantId}_$thrallId';

/// Lien de sang entre deux fiches (`bonds/{regnantId}_{thrallId}`, sous-projet 7c).
/// Le régnant donne son sang ; le lié boit. Noms et joueurs recopiés : un joueur ne lit pas la fiche de l'autre.
class Bond {
  Bond({
    required this.regnantId,
    this.regnantName = '',
    this.regnantPlayerUid,
    required this.thrallId,
    this.thrallName = '',
    this.thrallPlayerUid,
    this.ghoul = false,
    this.level = 0,
    required this.lastDrink,
    required this.lastContact,
    this.known = true,
    this.regnantKnows = true,
    this.byName = '',
    this.stored = false,
  });

  factory Bond.fromMap(Map<String, dynamic> m) => Bond(
        regnantId: m['regnantId'] as String? ?? '',
        regnantName: m['regnantName'] as String? ?? '',
        regnantPlayerUid: m['regnantPlayerUid'] as String?,
        thrallId: m['thrallId'] as String? ?? '',
        thrallName: m['thrallName'] as String? ?? '',
        thrallPlayerUid: m['thrallPlayerUid'] as String?,
        ghoul: m['ghoul'] == true,
        level: (m['level'] as num?)?.toInt() ?? 0,
        lastDrink: (m['lastDrink'] as Timestamp?)?.toDate() ?? DateTime(1900),
        lastContact: (m['lastContact'] as Timestamp?)?.toDate() ?? DateTime(1900),
        known: m['known'] != false,
        regnantKnows: m['regnantKnows'] != false,
        byName: m['byName'] as String? ?? '',
        stored: true,
      );

  final String regnantId;
  String regnantName;
  String? regnantPlayerUid;
  final String thrallId;
  String thrallName;
  String? thrallPlayerUid;

  /// Le lié est la goule du régnant (« votre goule » pour le joueur).
  bool ghoul;

  /// Niveau enregistré, de 0 à 3 ; le niveau du jour se calcule (`effectiveLevel`).
  int level;
  DateTime lastDrink;
  DateTime lastContact;

  /// Le lié sait de qui vient le sang.
  bool known;

  /// Le régnant connaît le lien envers lui.
  bool regnantKnows;
  String byName;

  /// Vrai si le document existe déjà (lu de Firestore).
  bool stored;

  String get id => bondId(regnantId, thrallId);

  Map<String, dynamic> toMap() => {
        'regnantId': regnantId,
        'regnantName': regnantName,
        'regnantPlayerUid': regnantPlayerUid,
        'thrallId': thrallId,
        'thrallName': thrallName,
        'thrallPlayerUid': thrallPlayerUid,
        'ghoul': ghoul,
        'level': level,
        'lastDrink': Timestamp.fromDate(dayOf(lastDrink)),
        'lastContact': Timestamp.fromDate(dayOf(lastContact)),
        'known': known,
        'regnantKnows': regnantKnows,
      };

  Bond copy() => Bond(
        regnantId: regnantId,
        regnantName: regnantName,
        regnantPlayerUid: regnantPlayerUid,
        thrallId: thrallId,
        thrallName: thrallName,
        thrallPlayerUid: thrallPlayerUid,
        ghoul: ghoul,
        level: level,
        lastDrink: lastDrink,
        lastContact: lastContact,
        known: known,
        regnantKnows: regnantKnows,
        byName: byName,
        stored: stored,
      );
}

/// Nouveau lien entre deux fiches, daté de [day] ; niveau 0 tant qu'aucune gorgée n'est appliquée.
Bond bondBetween(Character regnant, Character thrall, DateTime day) => Bond(
      regnantId: regnant.id,
      regnantName: regnant.name,
      regnantPlayerUid: regnant.playerUid,
      thrallId: thrall.id,
      thrallName: thrall.name,
      thrallPlayerUid: thrall.playerUid,
      ghoul: thrall.ghoul?.domitorId == regnant.id,
      lastDrink: dayOf(day),
      lastContact: dayOf(day),
    );

/// Le lien avec les noms et joueurs actuels des deux fiches (rafraîchis à chaque écriture).
Bond refreshed(Bond b, Character regnant, Character thrall) => b.copy()
  ..regnantName = regnant.name
  ..regnantPlayerUid = regnant.playerUid
  ..thrallName = thrall.name
  ..thrallPlayerUid = thrall.playerUid
  ..ghoul = thrall.ghoul?.domitorId == regnant.id;

/// Document écrit (fusionné) : exactement les clés permises par les règles ; `createdAt` à la création seulement.
Map<String, dynamic> bondData(Bond b, Actor by) {
  final now = FieldValue.serverTimestamp();
  return {...b.toMap(), 'byUid': by.uid, 'byName': by.name, 'updatedAt': now, if (!b.stored) 'createdAt': now};
}
```

<!-- file: lib/bonds/bond_rules.dart -->
```dart
import 'dart:math' show min;

import '../characters/character.dart';
import '../core/dates.dart' show monthAbbr;
import '../events/story_event.dart';
import '../morality/sin.dart' show dayOf;
import '../npcs/loan_rules.dart' show formatLoanDay;
import 'bond.dart';

/// Délais des règles, en mois du calendrier (fixes pour l'instant ; réglage dans les paramètres plus tard).
const fullDropMonths = 3;
const twoFadeMonths = 6;
const oneFadeMonths = 12;

/// [d] + [n] mois du calendrier ; un jour qui n'existe pas devient le dernier du mois (31 janv. + 1 → 28 ou 29 févr.).
DateTime addMonths(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, min(d.day, last));
}

/// « ●●○ ».
String bondDots(int n) {
  final k = n.clamp(0, 3);
  return '●' * k + '○' * (3 - k);
}

/// Changement à venir d'un lien : sa date et le niveau après.
typedef BondChange = ({DateTime at, int to});

List<BondChange> _steps(Bond b) => switch (b.level) {
      >= 3 => [
          (at: addMonths(dayOf(b.lastDrink), fullDropMonths), to: 2),
          (at: addMonths(dayOf(b.lastContact), twoFadeMonths), to: 0),
        ],
      2 => [(at: addMonths(dayOf(b.lastContact), twoFadeMonths), to: 0)],
      1 => [(at: addMonths(dayOf(b.lastContact), oneFadeMonths), to: 0)],
      _ => const [],
    };

/// Niveau du lien à [day] : le jour même d'une échéance, le changement a eu lieu.
int effectiveLevel(Bond b, DateTime day) {
  var level = b.level.clamp(0, 3);
  for (final s in _steps(b)) {
    if (!dayOf(day).isBefore(s.at)) level = s.to;
  }
  return level;
}

/// Prochaine échéance après [day], ou null pour un lien effacé.
BondChange? nextChange(Bond b, DateTime day) => _steps(b).where((s) => dayOf(day).isBefore(s.at)).firstOrNull;

/// « 1er déc. », « 20 mars 2027 » (année si elle diffère de celle de [now]).
String _on(DateTime d, DateTime now) {
  final s = formatLoanDay(d, now: now);
  return d.day == 1 ? s.replaceFirst('1 ', '1er ') : s;
}

/// « 27 déc. 2026 ».
String _long(DateTime d) => '${d.day == 1 ? '1er' : d.day} ${monthAbbr(d.month)} ${d.year}';

/// « Redescend à ●● le 1er déc. », « S’efface le 20 mars 2027 sans contact » ; vide pour un lien effacé.
String dueText(Bond b, DateTime day) {
  final c = nextChange(b, day);
  if (c == null) return '';
  return c.to == 2 ? 'Redescend à ●● le ${_on(c.at, day)}' : 'S’efface le ${_on(c.at, day)} sans contact';
}

/// Jours de calendrier de [from] à [to].
int daysUntil(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Échéance dans 30 jours ou moins.
bool dueSoon(Bond b, DateTime day) {
  final c = nextChange(b, day);
  return c != null && daysUntil(day, c.at) <= 30;
}

/// Effet d'une gorgée : le refus, ou le nouveau niveau et les liens moindres effacés.
class DrinkOutcome {
  const DrinkOutcome(this.level, this.erased) : refusal = null;
  const DrinkOutcome.refused(this.refusal)
      : level = 0,
        erased = const <Bond>[];

  final String? refusal;
  final int level;

  /// Liens moindres du lié envers d'autres régnants, ramenés à 0 par un lien complet.
  final List<Bond> erased;
}

/// Gorgée de [count] (1 à 3) sur [b], à [day], parmi tous les liens connus [all].
DrinkOutcome drinkOutcome(Bond b, List<Bond> all, DateTime day, int count) {
  final others = [
    for (final o in all)
      if (o.thrallId == b.thrallId && o.regnantId != b.regnantId && effectiveLevel(o, day) > 0) o,
  ];
  final full = others.where((o) => effectiveLevel(o, day) >= 3).firstOrNull;
  if (full != null) return DrinkOutcome.refused('${b.thrallName} est déjà lié complètement à ${full.regnantName}.');
  final level = min(3, effectiveLevel(b, day) + count);
  return DrinkOutcome(level, level == 3 ? [for (final o in others) o.copy()..level = 0] : const <Bond>[]);
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Le lien après une gorgée : les dates ne reculent jamais.
Bond drunk(Bond b, DateTime day, int level, bool known) => b.copy()
  ..level = level
  ..lastDrink = b.stored ? _later(dayOf(b.lastDrink), dayOf(day)) : dayOf(day)
  ..lastContact = b.stored ? _later(dayOf(b.lastContact), dayOf(day)) : dayOf(day)
  ..known = known;

/// Le lien après un contact : niveau du jour enregistré ; un lien effacé n'est pas ravivé.
Bond contacted(Bond b, DateTime day) => b.copy()
  ..level = effectiveLevel(b, day)
  ..lastContact = _later(dayOf(b.lastContact), dayOf(day));

/// Ce qu'écrit une gorgée, en un lot.
class DrinkWrite {
  const DrinkWrite(this.after, this.erased, this.event);
  final Bond after;
  final List<Bond> erased;
  final StoryEvent event;
}

/// Écriture d'une gorgée, ou null si elle est refusée.
DrinkWrite? drinkWrite(Bond base, List<Bond> all, DateTime day, int count, bool known) {
  final out = drinkOutcome(base, all, day, count);
  if (out.refusal != null) return null;
  final after = drunk(base, day, out.level, known);
  return DrinkWrite(after, out.erased, bondEvent(after, day));
}

/// Événement automatique du lié : visible du joueur si le lien lui est connu.
StoryEvent bondEvent(Bond after, DateTime day) {
  final title = 'Boit le sang de ${after.regnantName} · ${bondDots(after.level)}';
  return StoryEvent(
    id: '',
    type: EventType.bond,
    title: title.length > 80 ? '${title.substring(0, 79)}…' : title,
    year: day.year,
    month: day.month,
    day: day.day,
    visibility: after.known ? EventVisibility.player : EventVisibility.staff,
    auto: true,
  );
}

/// Aperçu d'une gorgée : les lignes du panneau, ou le seul refus.
List<String> drinkPreview(Bond base, List<Bond> all, DateTime day, int count) {
  final out = drinkOutcome(base, all, day, count);
  if (out.refusal != null) return [out.refusal!];
  final from = effectiveLevel(base, day);
  final next = nextChange(drunk(base, day, out.level, base.known), day)!;
  final names = [for (final e in out.erased) e.regnantName];
  return [
    'Lien envers ${base.regnantName} : ${bondDots(from)} → ${bondDots(out.level)}',
    if (out.level == 3 && from < 3)
      'Lien complet. Les liens moindres de ${base.thrallName} envers d’autres vampires sont effacés : '
          '${names.isEmpty ? 'aucun' : names.join(', ')}.',
    next.to == 2
        ? 'Sans nouvelle gorgée, il redescendra à ●● le ${_long(next.at)}.'
        : 'Sans contact, il s’effacera le ${_long(next.at)}.',
  ];
}

/// Contrôles du choix des fiches et de la date.
List<String> bondChecks({required String? regnantId, required String? thrallId, required DateTime? day}) => [
      if (regnantId == null) 'Choisissez qui donne son sang',
      if (thrallId == null) 'Choisissez qui boit',
      if (regnantId != null && regnantId == thrallId) 'Une fiche ne peut pas se lier elle-même',
      if (day == null) 'Date invalide',
    ];

/// « PNJ · Ventrue », « Goule · PNJ », « PJ · Malkavien ».
String partyTag(Character c) => c.ghoul != null
    ? 'Goule · ${c.kind.label}'
    : [c.kind.label, if ((c.clan ?? '').isNotEmpty) c.clan!].join(' · ');

/// Liens actifs (niveau du jour ≥ 1), échéance la plus proche d'abord.
List<Bond> activeBonds(Iterable<Bond> all, DateTime day) =>
    [for (final b in all) if (effectiveLevel(b, day) > 0) b]..sort((a, b) => nextChange(a, day)!.at.compareTo(nextChange(b, day)!.at));

/// Filtres de la page de la chronique.
enum BondFilter {
  all('Tous'),
  full('Complets'),
  soon('Échéance proche'),
  unknown('Ignorés du lié'),
  pjThrall('PJ liés');

  const BondFilter(this.label);
  final String label;
}

/// Filtre et recherche par nom (régnant ou lié, sans tenir compte de la casse).
bool bondMatches(Bond b, BondFilter f, String query, DateTime day) {
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty && !b.regnantName.toLowerCase().contains(q) && !b.thrallName.toLowerCase().contains(q)) return false;
  return switch (f) {
    BondFilter.all => true,
    BondFilter.full => effectiveLevel(b, day) == 3,
    BondFilter.soon => dueSoon(b, day),
    BondFilter.unknown => !b.known,
    BondFilter.pjThrall => b.thrallPlayerUid != null,
  };
}

/// Compteurs de la page : liens actifs, complets, échéance sous 30 jours, ignorés du lié.
({int active, int full, int soon, int unknown}) bondStats(List<Bond> active, DateTime day) => (
      active: active.length,
      full: active.where((b) => effectiveLevel(b, day) == 3).length,
      soon: active.where((b) => dueSoon(b, day)).length,
      unknown: active.where((b) => !b.known).length,
    );

/// Ancien niveau de la fiche de goule, sans document de lien envers son domitor : à dater ; 0 sinon.
int ghoulBondToDate(Character c, Iterable<Bond> all) {
  final g = c.ghoul;
  if (g == null || g.bond <= 0 || g.domitorId.isEmpty) return 0;
  return all.any((b) => b.regnantId == g.domitorId && b.thrallId == c.id) ? 0 : g.bond.clamp(1, 3);
}

/// Lien de la goule envers son domitor, au niveau de sa fiche, daté de [day], connu des deux.
Bond datedGhoulBond(Character ghoul, Character domitor, DateTime day) =>
    bondBetween(domitor, ghoul, day)..level = ghoul.ghoul!.bond.clamp(1, 3);

/// Ligne du conte : « Dernière gorgée le 20 sept. · Redescend à ●● le 1er déc. ».
String staffLine(Bond b, DateTime day) => 'Dernière gorgée le ${_on(b.lastDrink, day)} · ${dueText(b, day)}';

/// Joueur, lien subi : « 2 gorgées · dernière le 20 sept. ».
String sufferedLine(Bond b, DateTime day) {
  final what = switch (effectiveLevel(b, day)) {
    1 => 'Une gorgée',
    2 => '2 gorgées',
    _ => 'Lien complet',
  };
  return '$what · dernière le ${_on(b.lastDrink, day)}';
}

/// Joueur, lien subi : le délai qui le menace.
String sufferedDelay(Bond b, DateTime day) => switch (effectiveLevel(b, day)) {
      1 => 'Disparaît après un an sans le voir ni lui parler.',
      2 => 'Disparaît après six mois sans le voir ni lui parler.',
      _ => 'Redescend après trois mois sans boire son sang.',
    };

/// Joueur, lien exercé : « Dernière gorgée le 26 sept. · à renforcer avant le 26 déc. ».
String exertedLine(Bond b, DateTime day) {
  final c = nextChange(b, day)!;
  final due = effectiveLevel(b, day) == 3 ? 'à renforcer avant le ${_on(c.at, day)}' : 's’efface le ${_on(c.at, day)} sans contact';
  return 'Dernière gorgée le ${_on(b.lastDrink, day)} · $due';
}
```

- [ ] **Step 4 : tests (succès attendu)**

Run : `flutter test test/bonds/bond_rules_test.dart`, puis `flutter analyze` et `flutter test`.

Expected : succès ; analyseur propre.

- [ ] **Step 5 : commit**

```bash
git add lib/bonds/bond.dart lib/bonds/bond_rules.dart lib/events/story_event.dart test/bonds/bond_rules_test.dart
git commit -m "feat: liens de sang — modèle, niveau effectif, gorgée, contact, échéances

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : dépôt, règles Firestore, faux dépôt

**Files :**
- Create : `lib/bonds/bonds_repository.dart` (et son `.g.dart` généré).
- Modify : `firestore.rules`, `test/fakes.dart`.
- Test : `rules_test/bonds.test.js`.

**Interfaces :**
- Consumes : la tâche 1 (`Bond`, `bondData`, `DrinkWrite`).
- Produces :
  - `BondsRepository` : `watchAll()`, `watchSuffered(characterId, uid)`, `watchExerted(characterId, uid)`, `drink(DrinkWrite w, Actor by)`, `save(Bond b, Actor by)` ;
  - `bondsRepositoryProvider`, `allBondsProvider` (`Stream<List<Bond>>`), `characterBondsProvider(characterId)` (`Future<List<Bond>>` : tous les liens de la fiche pour l'équipe hors sa propre fiche, ceux connus du joueur sinon) ;
  - `FakeBondsRepository` dans `test/fakes.dart` : `calls` (`'drink:<id>:<niveau>'`, `'save:<id>:<niveau>'`), `lastDrink` (`DrinkWrite?`), `lastSaved` (`Bond?`), `error`.

- [ ] **Step 1 : test des règles (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 2 test`, puis les tests des règles.

Expected : échec des tests de `bonds.test.js` (la collection n'est pas encore permise).

<!-- file: rules_test/bonds.test.js -->
```js
import { test, before, after, beforeEach } from 'node:test';
import { strictEqual } from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, deleteDoc, collection, query, where, writeBatch } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-portail-met',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());

const bond = (over) => ({
  regnantId: 'oct', regnantName: 'Octave', regnantPlayerUid: null,
  thrallId: 'luc', thrallName: 'Lucie', thrallPlayerUid: 'zoe', ghoul: false, level: 2,
  lastDrink: new Date('2026-09-20T00:00:00'), lastContact: new Date('2026-09-20T00:00:00'),
  known: true, regnantKnows: true, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});
const ev = (over) => ({
  type: 'bond', title: 'Boit le sang de Octave · ●●●', description: '', year: 2026, month: 9, day: 27,
  visibility: 'player', auto: true, byUid: 'lea', byName: 'lea', createdAt: new Date(), updatedAt: new Date(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const users = { lea: 'conteur', julien: 'narrateur', zoe: 'joueur', max: 'joueur' };
    for (const [uid, role] of Object.entries(users)) await setDoc(doc(db, `users/${uid}`), { displayName: uid, email: `${uid}@ex.fr`, role });
    await setDoc(doc(db, 'characters/luc'), { name: 'Lucie', kind: 'pj', playerUid: 'zoe', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/oct'), { name: 'Octave', kind: 'pnj', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/aga'), { name: 'Agathe', kind: 'pnj', status: 'active', version: 1 });
    await setDoc(doc(db, 'characters/lea1'), { name: 'Léa joue', kind: 'pj', playerUid: 'lea', status: 'active', version: 1 });
    await setDoc(doc(db, 'bonds/oct_luc'), bond({}));
    await setDoc(doc(db, 'bonds/aga_luc'), bond({ regnantId: 'aga', regnantName: 'Agathe', known: false }));
    await setDoc(doc(db, 'bonds/luc_aga'), bond({
      regnantId: 'luc', regnantName: 'Lucie', regnantPlayerUid: 'zoe', thrallId: 'aga', thrallName: 'Agathe', thrallPlayerUid: null,
      regnantKnows: false,
    }));
    await setDoc(doc(db, 'bonds/luc_oct'), bond({
      regnantId: 'luc', regnantName: 'Lucie', regnantPlayerUid: 'zoe', thrallId: 'oct', thrallName: 'Octave', thrallPlayerUid: null,
    }));
  });
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@ex.fr`, email_verified: true }).firestore();
const suffered = (db, uid) => query(collection(db, 'bonds'),
  where('thrallId', '==', 'luc'), where('thrallPlayerUid', '==', uid), where('known', '==', true));
const exerted = (db, uid) => query(collection(db, 'bonds'),
  where('regnantId', '==', 'luc'), where('regnantPlayerUid', '==', uid), where('regnantKnows', '==', true));

test('lecture : l’équipe voit tout', async () => {
  await assertSucceeds(getDocs(collection(as('julien'), 'bonds')));
  await assertSucceeds(getDocs(collection(as('lea'), 'bonds')));
});

test('lecture du joueur : liens connus seulement, requête filtrée (Review Focus 3)', async () => {
  const zoe = as('zoe');
  strictEqual((await assertSucceeds(getDocs(suffered(zoe, 'zoe')))).size, 1);
  strictEqual((await assertSucceeds(getDocs(exerted(zoe, 'zoe')))).size, 1);
  await assertSucceeds(getDoc(doc(zoe, 'bonds/oct_luc')));
  await assertFails(getDoc(doc(zoe, 'bonds/aga_luc')));
  await assertFails(getDoc(doc(zoe, 'bonds/luc_aga')));
  await assertFails(getDocs(collection(zoe, 'bonds')));
  await assertFails(getDoc(doc(as('max'), 'bonds/oct_luc')));
});

test('écriture : le conte, champs contrôlés, identifiant imposé', async () => {
  const lea = as('lea');
  await assertSucceeds(setDoc(doc(lea, 'bonds/oct_luc'), bond({ level: 3 })));
  await assertSucceeds(setDoc(doc(lea, 'bonds/aga_oct'), bond({ regnantId: 'aga', thrallId: 'oct', thrallPlayerUid: null })));
  await assertFails(setDoc(doc(lea, 'bonds/autre'), bond({})));
  await assertFails(setDoc(doc(lea, 'bonds/oct_oct'), bond({ thrallId: 'oct', thrallPlayerUid: null })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ level: 4 })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ level: '2' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ lastDrink: '20/09/2026' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ secret: 1 })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ byUid: 'julien' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ thrallPlayerUid: 'max' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ known: 'oui' })));
  await assertFails(setDoc(doc(lea, 'bonds/oct_luc'), bond({ ghoul: 1 })));
});

test('écriture refusée : narrateur, joueur, fiche du conte, suppression', async () => {
  await assertFails(setDoc(doc(as('julien'), 'bonds/oct_luc'), bond({ byUid: 'julien' })));
  await assertFails(setDoc(doc(as('zoe'), 'bonds/oct_luc'), bond({ byUid: 'zoe' })));
  await assertFails(setDoc(doc(as('lea'), 'bonds/oct_lea1'), bond({ thrallId: 'lea1', thrallPlayerUid: 'lea' })));
  await assertFails(setDoc(doc(as('lea'), 'bonds/lea1_oct'), bond({
    regnantId: 'lea1', regnantPlayerUid: 'lea', thrallId: 'oct', thrallPlayerUid: null,
  })));
  await assertFails(deleteDoc(doc(as('lea'), 'bonds/oct_luc')));
});

test('gorgée en un lot : lien, lien moindre effacé, événement « Lien de sang »', async () => {
  const lea = as('lea');
  const batch = writeBatch(lea);
  batch.set(doc(lea, 'bonds/oct_luc'), bond({ level: 3 }), { merge: true });
  batch.set(doc(lea, 'bonds/aga_luc'), bond({ regnantId: 'aga', regnantName: 'Agathe', level: 0, known: false }), { merge: true });
  batch.set(doc(lea, 'characters/luc/events/e1'), ev({}));
  await assertSucceeds(batch.commit());
});
```

- [ ] **Step 2 : règles**

Dans `firestore.rules` :

1. Dans `eventValid()` (événements de la fiche), ajouter `'bond'` à la liste des types, après `'morality'` :

```
            && d.type in ['diablerie', 'titleGained', 'titleLost', 'sectChange', 'pathAdopted', 'morality', 'bond', 'bloodHunt', 'torpor',
```

2. Juste avant la ligne `    // Demandes d'XP (sous-projet 4). Le joueur écrit tant que la demande est ouverte ; le conte tranche.`, ajouter :

```
    // Liens de sang entre fiches (sous-projet 7c). Lus par l'équipe, par le joueur du lié s'il le connaît
    // et par le joueur du régnant s'il le connaît ; écrits par le conte, jamais sur un lien qui touche sa propre fiche.
    match /bonds/{b} {
      function bondValid() {
        let d = request.resource.data;
        let r = getAfter(charPath(d.regnantId)).data;
        let t = getAfter(charPath(d.thrallId)).data;
        return d.keys().hasOnly(['regnantId', 'regnantName', 'regnantPlayerUid', 'thrallId', 'thrallName', 'thrallPlayerUid',
              'ghoul', 'level', 'lastDrink', 'lastContact', 'known', 'regnantKnows', 'byUid', 'byName', 'createdAt', 'updatedAt'])
          && d.regnantId is string && d.thrallId is string && d.regnantId != d.thrallId
          && b == d.regnantId + '_' + d.thrallId
          && d.regnantName is string && d.thrallName is string
          && d.get('regnantPlayerUid', null) == r.get('playerUid', null)
          && d.get('thrallPlayerUid', null) == t.get('playerUid', null)
          && r.get('playerUid', null) != request.auth.uid
          && t.get('playerUid', null) != request.auth.uid
          && d.ghoul is bool
          && d.level is int && d.level >= 0 && d.level <= 3
          && d.lastDrink is timestamp && d.lastContact is timestamp
          && d.known is bool && d.regnantKnows is bool
          && d.byUid == request.auth.uid;
      }
      allow read: if isStaff()
        || (signedIn() && resource.data.get('thrallPlayerUid', null) == request.auth.uid && resource.data.known == true)
        || (signedIn() && resource.data.get('regnantPlayerUid', null) == request.auth.uid && resource.data.regnantKnows == true);
      allow create, update: if managesAccounts() && bondValid();
      allow delete: if false;
    }

```

- [ ] **Step 3 : dépôt et faux dépôt**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 2 impl`, puis `dart run build_runner build --delete-conflicting-outputs`.

<!-- file: lib/bonds/bonds_repository.dart -->
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';
import '../characters/character_repository.dart';
import '../events/story_event.dart';
import 'bond.dart';
import 'bond_rules.dart' show DrinkWrite;

part 'bonds_repository.g.dart';

/// `bonds/{regnantId}_{thrallId}` : liens de sang, écrits par le conte (sous-projet 7c).
class BondsRepository {
  BondsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('bonds');

  List<Bond> _list(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) Bond.fromMap(d.data())];

  /// Équipe : tous les liens.
  Stream<List<Bond>> watchAll() => _col.snapshots().map(_list);

  /// Joueur : liens subis par sa fiche et connus d'elle. Les règles exigent ces filtres.
  Stream<List<Bond>> watchSuffered(String characterId, String uid) => _col
      .where('thrallId', isEqualTo: characterId)
      .where('thrallPlayerUid', isEqualTo: uid)
      .where('known', isEqualTo: true)
      .snapshots()
      .map(_list);

  /// Joueur : liens exercés par sa fiche et connus d'elle. Les règles exigent ces filtres.
  Stream<List<Bond>> watchExerted(String characterId, String uid) => _col
      .where('regnantId', isEqualTo: characterId)
      .where('regnantPlayerUid', isEqualTo: uid)
      .where('regnantKnows', isEqualTo: true)
      .snapshots()
      .map(_list);

  /// Gorgée en un lot : le lien, les liens moindres effacés, l'événement du lié.
  Future<void> drink(DrinkWrite w, Actor by) {
    final batch = _db.batch()..set(_col.doc(w.after.id), bondData(w.after, by), SetOptions(merge: true));
    for (final e in w.erased) {
      batch.set(_col.doc(e.id), bondData(e, by), SetOptions(merge: true));
    }
    batch.set(_db.collection('characters').doc(w.after.thrallId).collection('events').doc(), newEventData(w.event, by.uid, by.name));
    return batch.commit();
  }

  /// Contact, ou lien de goule daté : une seule écriture.
  Future<void> save(Bond b, Actor by) => _col.doc(b.id).set(bondData(b, by), SetOptions(merge: true));
}

@Riverpod(keepAlive: true)
BondsRepository bondsRepository(Ref ref) => BondsRepository(ref.watch(firestoreProvider));

@riverpod
Stream<List<Bond>> allBonds(Ref ref) => ref.watch(bondsRepositoryProvider).watchAll();

@riverpod
Stream<List<Bond>> sufferedBonds(Ref ref, String characterId, String uid) =>
    ref.watch(bondsRepositoryProvider).watchSuffered(characterId, uid);

@riverpod
Stream<List<Bond>> exertedBonds(Ref ref, String characterId, String uid) =>
    ref.watch(bondsRepositoryProvider).watchExerted(characterId, uid);

/// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.
@riverpod
Future<List<Bond>> characterBonds(Ref ref, String characterId) async {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final c = ref.watch(characterProvider(characterId)).value;
  if (me.role.isStaff && c != null && c.playerUid != me.uid) {
    final all = await ref.watch(allBondsProvider.future);
    return [for (final b in all) if (b.thrallId == characterId || b.regnantId == characterId) b];
  }
  final suffered = await ref.watch(sufferedBondsProvider(characterId, me.uid).future);
  final exerted = await ref.watch(exertedBondsProvider(characterId, me.uid).future);
  return [...suffered, ...exerted];
}
```

Dans `test/fakes.dart`, ajouter les imports :

```dart
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bond_rules.dart' show DrinkWrite;
import 'package:portail_met/bonds/bonds_repository.dart';
```

puis, à la fin du fichier :

```dart
class FakeBondsRepository implements BondsRepository {
  final calls = <String>[];
  DrinkWrite? lastDrink;
  Bond? lastSaved;
  Object? error;

  @override
  Future<void> drink(DrinkWrite w, Actor by) async {
    calls.add('drink:${w.after.id}:${w.after.level}');
    if (error != null) throw error!;
    lastDrink = w;
  }

  @override
  Future<void> save(Bond b, Actor by) async {
    calls.add('save:${b.id}:${b.level}');
    if (error != null) throw error!;
    lastSaved = b;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 4 : tests (succès attendu)**

Run : les tests des règles (tous), puis `flutter analyze` et `flutter test`.

Expected : succès ; analyseur propre.

- [ ] **Step 5 : commit**

```bash
git add lib/bonds/bonds_repository.dart lib/bonds/bonds_repository.g.dart firestore.rules test/fakes.dart rules_test/bonds.test.js
git commit -m "feat: liens de sang — dépôt, règles d'accès, gorgée en un lot

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : formulaire de gorgée et bloc du conte

Maquette : `C-Moralite.dc.html` et `C-Moralite-mobile.dc.html`, bloc Liens de sang.

**Files :**
- Create : `lib/bonds/drink_form.dart`, `lib/bonds/bonds_staff.dart`.
- Modify : `lib/morality/morality_screen.dart`, `test/morality/morality_staff_test.dart`.
- Test : `test/bonds/bonds_staff_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2 ; `allCharactersProvider`, `actorOf`, `currentUserProvider`.
- Produces :
  - `DrinkForm({base, all, today, onDrink, onContact, errors, busy})`, avec les clés `dr-date`, `dr-count`, `dr-known`, `dr-preview`, `dr-save`, `dr-contact` ;
  - `StaffBonds({character, canEdit, today})`, avec les clés `bo-all`, `bo-<idLien>`, `bo-dots-<idLien>`, `bo-drink-<idLien>`, `bo-contact-<idLien>`, `bo-new`, `bo-dir-suffered`, `bo-dir-exerted`, `bo-partner`, `bo-date`, `bo-date-create`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 3 test`, puis `flutter test test/bonds/bonds_staff_test.dart`.

Expected : échec au chargement.

<!-- file: test/bonds/bonds_staff_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/bonds/bonds_staff.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/events/story_event.dart';

import '../fakes.dart';
import 'bond_rules_test.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);

  Future<FakeBondsRepository> pump(WidgetTester tester, Character c,
      {List<Bond> bonds = const [], bool canEdit = true, Size size = const Size(1000, 1800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeBondsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(lea)),
        allBondsProvider.overrideWith((ref) => Stream.value(bonds)),
        allCharactersProvider.overrideWith((ref) => Stream.value(cast())),
        bondsRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: StaffBonds(character: c, canEdit: canEdit, today: today))),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('subis et exercés : pastilles, échéances, connu du lié', (tester) async {
    await pump(tester, lucie(), bonds: [octLuc(), lucLem()]);
    expect(find.text('Subis'), findsOneWidget);
    expect(find.text('Exercés'), findsOneWidget);
    expect(find.text('Octave Marchetti'), findsOneWidget);
    expect(find.text('PNJ · Ventrue'), findsOneWidget);
    expect(find.text('Goule · PNJ'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('bo-dots-oct_luc'))).data, '●●○');
    expect(find.text('Dernière gorgée le 20 sept. · S’efface le 20 mars 2027 sans contact'), findsOneWidget);
    expect(find.text('Dernière gorgée le 1er sept. · Redescend à ●● le 1er déc.'), findsOneWidget);
    expect(find.text('Connu de Lucie Arnaud'), findsOneWidget);
    expect(find.text('Connu de Dr Lemaire'), findsOneWidget);
  });

  testWidgets('gorgée depuis la fiche : aperçu, lien complet, événement', (tester) async {
    final repo = await pump(tester, lucie(), bonds: [octLuc()]);
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.text('Lien envers Octave Marchetti : ●●○ → ●●●'), findsOneWidget);
    expect(find.text('Lien complet. Les liens moindres de Lucie Arnaud envers d’autres vampires sont effacés : aucun.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['drink:oct_luc:3']);
    expect(repo.lastDrink!.event.title, 'Boit le sang de Octave Marchetti · ●●●');
    expect(repo.lastDrink!.event.visibility, EventVisibility.player);
    expect(find.byKey(const Key('dr-save')), findsNothing);
  });

  testWidgets('lien complet ailleurs : refus, bouton inactif (Review Focus 2)', (tester) async {
    final agaFull = link(agathe(), lucie(), 3, DateTime(2026, 9, 25));
    final repo = await pump(tester, lucie(), bonds: [octLuc(), agaFull]);
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.text('Lucie Arnaud est déjà lié complètement à Sœur Agathe.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('dr-save'))).onPressed, isNull);
    expect(repo.calls, isEmpty);
  });

  testWidgets('lien complet : liens moindres effacés dans le même lot', (tester) async {
    final agaLuc = link(agathe(), lucie(), 1, DateTime(2026, 9, 1));
    final repo = await pump(tester, lucie(), bonds: [octLuc(), agaLuc]);
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(find.text('Lien complet. Les liens moindres de Lucie Arnaud envers d’autres vampires sont effacés : Sœur Agathe.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect([for (final e in repo.lastDrink!.erased) '${e.id}:${e.level}'], ['aga_luc:0']);
  });

  testWidgets('contact : date du jour, niveau du jour', (tester) async {
    final repo = await pump(tester, lucie(), bonds: [octLuc()]);
    await tester.tap(find.byKey(const Key('bo-contact-oct_luc')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:oct_luc:2']);
    expect(repo.lastSaved!.lastContact, today);
  });

  testWidgets('nouveau lien exercé', (tester) async {
    final repo = await pump(tester, lucie());
    expect(find.text('Aucun lien.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bo-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bo-dir-exerted')));
    await tester.pumpAndSettle();
    await choose(tester, 'bo-partner', 'Sœur Agathe · PNJ · Malkavien');
    expect(find.text('Lien envers Lucie Arnaud : ○○○ → ●○○'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['drink:luc_aga:1']);
    expect(repo.lastDrink!.after.stored, isFalse);
  });

  testWidgets('goule à dater : créer le lien au niveau de la fiche', (tester) async {
    final repo = await pump(tester, lemaire());
    expect(find.text('Lien de Lucie Arnaud ●●● à dater'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bo-date-create')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:luc_lem:3']);
    await pump(tester, lemaire(), bonds: [lucLem()]);
    expect(find.byKey(const Key('bo-date')), findsNothing);
  });

  testWidgets('lecture seule : narrateur, fiche en brouillon', (tester) async {
    await pump(tester, lucie(), bonds: [octLuc()], canEdit: false);
    expect(find.byKey(const Key('bo-drink-oct_luc')), findsNothing);
    expect(find.byKey(const Key('bo-contact-oct_luc')), findsNothing);
    expect(find.byKey(const Key('bo-new')), findsNothing);
    await pump(tester, lucie()..status = CharacterStatus.draft, bonds: [octLuc()]);
    expect(find.byKey(const Key('bo-drink-oct_luc')), findsNothing);
    expect(find.byKey(const Key('bo-new')), findsNothing);
  });

  testWidgets('écriture refusée : message, formulaire gardé', (tester) async {
    final repo = await pump(tester, lucie(), bonds: [octLuc()]);
    repo.error = Exception('refusé');
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement refusé : réessayez.'), findsOneWidget);
    expect(find.byKey(const Key('dr-save')), findsOneWidget);
  });

  testWidgets('390 px : formulaire ouvert sans débordement (Review Focus 5)', (tester) async {
    await pump(tester, lucie(), bonds: [octLuc(), lucLem()], size: const Size(390, 1600));
    await tester.tap(find.byKey(const Key('bo-drink-oct_luc')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('bo-new')));
    await tester.pumpAndSettle();
    await choose(tester, 'bo-partner', 'Sœur Agathe · PNJ · Malkavien');
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 3 impl`.

<!-- file: lib/bonds/drink_form.dart -->
```dart
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../npcs/loan_rules.dart' show parseDay;
import 'bond.dart';
import 'bond_rules.dart';

/// Formulaire d'une gorgée (fiche et page de la chronique) : date, nombre, « sait de qui vient ce sang », aperçu.
class DrinkForm extends StatefulWidget {
  const DrinkForm({
    super.key,
    required this.base,
    required this.all,
    required this.today,
    required this.onDrink,
    this.onContact,
    this.errors = const [],
    this.busy = false,
  });

  /// Le lien tel qu'il est (ou nouveau, au niveau 0), noms à jour.
  final Bond base;

  /// Tous les liens connus : liens moindres effacés et refus.
  final List<Bond> all;
  final DateTime today;
  final Future<void> Function(DrinkWrite w) onDrink;

  /// « Noter un simple contact » ; absent pour un lien qui n'existe pas encore.
  final Future<void> Function(Bond contacted)? onContact;

  /// Contrôles du choix des fiches.
  final List<String> errors;
  final bool busy;

  @override
  State<DrinkForm> createState() => _DrinkFormState();
}

class _DrinkFormState extends State<DrinkForm> {
  late final _date = TextEditingController(text: _input(widget.today));
  int _count = 1;
  late bool _known = widget.base.known;

  static String _input(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final day = parseDay(_date.text);
    final errors = [...widget.errors, if (day == null) 'Date invalide'];
    final base = widget.base.copy()..known = _known;
    final preview = day == null || widget.errors.isNotEmpty ? const <String>[] : drinkPreview(base, widget.all, day, _count);
    final write = day == null || widget.errors.isNotEmpty ? null : drinkWrite(base, widget.all, day, _count, _known);
    final canContact = widget.onContact != null && day != null && effectiveLevel(widget.base, day) > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 160,
            child: TextField(
              key: const Key('dr-date'),
              controller: _date,
              decoration: const InputDecoration(labelText: 'Date (JJ/MM/AAAA)'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int>(
              key: const Key('dr-count'),
              initialValue: _count,
              decoration: const InputDecoration(labelText: 'Gorgées'),
              items: [for (var n = 1; n <= 3; n++) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: (v) => setState(() => _count = v ?? 1),
            ),
          ),
        ]),
        CheckboxListTile(
          key: const Key('dr-known'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _known,
          onChanged: (v) => setState(() => _known = v ?? true),
          title: Text('${widget.base.thrallName} sait de qui vient ce sang'),
        ),
        for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
        if (preview.isNotEmpty)
          Container(
            key: const Key('dr-preview'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.deadBg,
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, p) in preview.indexed)
                Text(p, style: i == 0 ? t.titleSmall : t.bodySmall?.copyWith(color: AppColors.linkHover)),
            ]),
          ),
        const SizedBox(height: 8),
        Text(
          'La gorgée s’ajoute aussi aux événements de ${widget.base.thrallName}, visible par le joueur si le lien lui est connu.',
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(
            key: const Key('dr-save'),
            onPressed: write == null || widget.busy ? null : () => widget.onDrink(write),
            child: const Text('Enregistrer la gorgée'),
          ),
          if (canContact)
            OutlinedButton(
              key: const Key('dr-contact'),
              onPressed: widget.busy ? null : () => widget.onContact!(contacted(widget.base, day)),
              child: const Text('Noter un simple contact'),
            ),
        ]),
      ]),
    );
  }
}
```

<!-- file: lib/bonds/bonds_staff.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'bond.dart';
import 'bond_rules.dart';
import 'bonds_repository.dart';
import 'drink_form.dart';

/// Bloc « Liens de sang » du conte (C-Moralite) : liens subis et exercés de la fiche, gorgées, contacts.
class StaffBonds extends ConsumerStatefulWidget {
  const StaffBonds({super.key, required this.character, required this.canEdit, this.today});

  final Character character;
  final bool canEdit;

  /// Date du jour (tests) ; aujourd'hui par défaut.
  final DateTime? today;

  @override
  ConsumerState<StaffBonds> createState() => _StaffBondsState();
}

class _StaffBondsState extends ConsumerState<StaffBonds> {
  /// Lien dont le formulaire est ouvert ; `new` pour un nouveau lien.
  String? _open;
  String? _partnerId;
  bool _suffered = true;
  bool _busy = false;

  Character get c => widget.character;

  Future<void> _run(Future<void> Function(Actor by) write) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await write(by);
      if (mounted) {
        setState(() {
          _open = null;
          _partnerId = null;
        });
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider).value; // l'auteur est relu à l'enregistrement
    final today = widget.today ?? DateTime.now();
    final all = ref.watch(allBondsProvider).value ?? const <Bond>[];
    final chars = ref.watch(allCharactersProvider).value ?? const <Character>[];
    final repo = ref.read(bondsRepositoryProvider);
    Character? byId(String id) => chars.where((x) => x.id == id).firstOrNull;
    final ro = !widget.canEdit || !(c.kind == CharacterKind.pnj || c.status.settled);
    final suffered = activeBonds(all.where((b) => b.thrallId == c.id), today);
    final exerted = activeBonds(all.where((b) => b.regnantId == c.id), today);
    final toDate = ghoulBondToDate(c, all);
    final domitor = c.ghoul == null ? null : byId(c.ghoul!.domitorId);
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);

    Bond current(Bond b) {
      final r = byId(b.regnantId);
      final th = byId(b.thrallId);
      return r == null || th == null ? b : refreshed(b, r, th);
    }

    Widget form(Bond base) => DrinkForm(
          key: ValueKey('dr-${base.id}'),
          base: base,
          all: all,
          today: today,
          busy: _busy,
          onDrink: (w) => _run((by) => repo.drink(w, by)),
          onContact: base.stored ? (b) => _run((by) => repo.save(b, by)) : null,
        );

    Widget tile(Bond b, {required bool isSuffered}) {
      final other = byId(isSuffered ? b.regnantId : b.thrallId);
      final open = _open == b.id;
      return Container(
        key: Key('bo-${b.id}'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(isSuffered ? b.regnantName : b.thrallName, style: t.titleSmall),
            if (other != null) Text(partyTag(other), style: muted),
            Text(
              bondDots(effectiveLevel(b, today)),
              key: Key('bo-dots-${b.id}'),
              style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3),
            ),
          ]),
          Text(staffLine(b, today), style: t.bodySmall?.copyWith(color: dueSoon(b, today) ? AppColors.goldLight : AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (!ro) ...[
              OutlinedButton(
                key: Key('bo-drink-${b.id}'),
                onPressed: _busy ? null : () => setState(() => _open = open ? null : b.id),
                child: const Text('+ Gorgée'),
              ),
              OutlinedButton(
                key: Key('bo-contact-${b.id}'),
                onPressed: _busy ? null : () => _run((by) => repo.save(contacted(current(b), today), by)),
                child: const Text('Contact'),
              ),
            ],
            Text(
              b.known ? 'Connu de ${b.thrallName}' : 'Ignoré de ${b.thrallName}',
              style: t.bodySmall?.copyWith(color: b.known ? AppColors.success : AppColors.linkHover),
            ),
          ]),
          if (open && !ro) form(current(b)),
        ]),
      );
    }

    Widget newLink() {
      final partners = [
        for (final x in chars)
          if (x.id != c.id && (me == null || x.playerUid != me.uid)) x,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final p = _partnerId == null ? null : byId(_partnerId!);
      Bond? base;
      if (p != null) {
        final (r, th) = _suffered ? (p, c) : (c, p);
        final existing = all.where((b) => b.id == bondId(r.id, th.id)).firstOrNull;
        base = existing == null ? bondBetween(r, th, today) : refreshed(existing, r, th);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            key: const Key('bo-dir-suffered'),
            label: const Text('Subi'),
            selected: _suffered,
            onSelected: (_) => setState(() => _suffered = true),
          ),
          ChoiceChip(
            key: const Key('bo-dir-exerted'),
            label: const Text('Exercé'),
            selected: !_suffered,
            onSelected: (_) => setState(() => _suffered = false),
          ),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('bo-partner'),
          initialValue: _partnerId,
          isExpanded: true,
          decoration: InputDecoration(labelText: _suffered ? 'Qui donne son sang' : 'Qui boit'),
          items: [
            for (final x in partners)
              DropdownMenuItem(value: x.id, child: Text('${x.name} · ${partyTag(x)}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _partnerId = v),
        ),
        if (base != null) form(base),
      ]);
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SectionTitle('Liens de sang'),
            TextButton(
              key: const Key('bo-all'),
              onPressed: () => context.go('/conteur/liens'),
              child: const Text('Tous les liens de la chronique'),
            ),
          ],
        ),
        if (toDate > 0)
          Padding(
            key: const Key('bo-date'),
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Lien de ${domitor?.name ?? c.ghoul!.domitorName} ${bondDots(toDate)} à dater', style: t.bodyMedium),
              if (!ro && domitor != null)
                OutlinedButton(
                  key: const Key('bo-date-create'),
                  onPressed: _busy ? null : () => _run((by) => repo.save(datedGhoulBond(c, domitor, today), by)),
                  child: const Text('Créer le lien'),
                ),
            ]),
          ),
        if (suffered.isEmpty && exerted.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucun lien.', style: t.bodyMedium)),
        if (suffered.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Subis', style: t.labelMedium),
          for (final b in suffered) tile(b, isSuffered: true),
        ],
        if (exerted.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Exercés', style: t.labelMedium),
          for (final b in exerted) tile(b, isSuffered: false),
        ],
        if (!ro) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('bo-new'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _open = _open == 'new' ? null : 'new';
                        _partnerId = null;
                      }),
              child: const Text('+ Nouveau lien'),
            ),
          ),
          if (_open == 'new') newLink(),
        ],
      ]),
    );
  }
}
```

- [ ] **Step 3 : onglet Moralité**

Dans `lib/morality/morality_screen.dart` :

1. Ajouter l'import `import '../bonds/bonds_staff.dart';` (ordre alphabétique, avant `'../characters/character.dart'`).
2. Dans la vue du conte, après `StaffDerangements(character: c, rb: rb, canEdit: canEdit),` :

```dart
            const SizedBox(height: 20),
            StaffBonds(character: c, canEdit: canEdit),
```

Dans `test/morality/morality_staff_test.dart`, ajouter les imports :

```dart
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
```

puis, dans la liste `overrides` de `pump`, après `characterRepositoryProvider.overrideWith((ref) => chars),` :

```dart
        allBondsProvider.overrideWith((ref) => Stream.value(const <Bond>[])),
        allCharactersProvider.overrideWith((ref) => Stream.value(const <Character>[])),
```

- [ ] **Step 4 : tests (succès attendu)**

Run : `flutter test test/bonds test/morality`, puis `flutter analyze` et `flutter test`.

Expected : succès ; analyseur propre.

- [ ] **Step 5 : commit**

```bash
git add lib/bonds/drink_form.dart lib/bonds/bonds_staff.dart lib/morality/morality_screen.dart test/bonds/bonds_staff_test.dart test/morality/morality_staff_test.dart
git commit -m "feat: liens de sang — bloc du conte (gorgée, contact, nouveau lien, goule à dater)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : bloc du joueur, panneau de la goule

Maquette : `J-Moralite.dc.html`, blocs « Liens de sang que vous subissez » et « Liens que vous exercez ».

**Files :**
- Create : `lib/bonds/bonds_player.dart`.
- Modify :
  - `lib/morality/morality_screen.dart` ;
  - `lib/characters/ghoul_panel.dart` ;
  - `lib/characters/sheet_widgets.dart` ;
  - `lib/characters/character_edit_screen.dart` ;
  - `test/morality/morality_player_test.dart` ;
  - `test/characters/ghoul_panel_test.dart`.
- Test : `test/bonds/bonds_player_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 et 2 (`characterBondsProvider`, `effectiveLevel`, `bondDots`, `sufferedLine`, `sufferedDelay`, `exertedLine`, `activeBonds`).
- Produces :
  - `PlayerBonds({character, today})` ;
  - `GhoulPanel(g, {characterId, now})` : `characterId` devient obligatoire.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 4 test`, puis `flutter test test/bonds/bonds_player_test.dart test/characters/ghoul_panel_test.dart`.

Expected : échec au chargement.

<!-- file: test/bonds/bonds_player_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_player.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/core/theme.dart';

import 'bond_rules_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Bond> bonds, {Size size = const Size(1000, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [characterBondsProvider('luc').overrideWith((ref) async => bonds)],
      child: MaterialApp(
        theme: buildTheme(withFonts: false),
        home: Scaffold(body: SingleChildScrollView(child: PlayerBonds(character: lucie(), today: today))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('liens subis et exercés, en lecture ; lien effacé absent (Review Focus 3)', (tester) async {
    final gone = link(agathe(), lucie(), 1, DateTime(2025, 1, 1));
    await pump(tester, [octLuc(), lucLem(), gone]);
    expect(find.text('Octave Marchetti'), findsOneWidget);
    expect(find.text('2 gorgées · dernière le 20 sept.'), findsOneWidget);
    expect(find.text('Disparaît après six mois sans le voir ni lui parler.'), findsOneWidget);
    expect(find.text('Dr Lemaire'), findsOneWidget);
    expect(find.text('votre goule'), findsOneWidget);
    expect(find.text('Dernière gorgée le 1er sept. · à renforcer avant le 1er déc.'), findsOneWidget);
    expect(find.text('●●○'), findsOneWidget);
    expect(find.text('●●●'), findsOneWidget);
    expect(find.text('Sœur Agathe'), findsNothing);
    expect(find.text('2 gorgées : 1 Volonté par heure pour lui nuire. 3 gorgées : lien complet, qui efface les liens moindres.'), findsOneWidget);
    expect(find.text('Le conte choisit ce que vous savez des liens envers vous.'), findsOneWidget);
    expect(find.text('+ Gorgée'), findsNothing);
  });

  testWidgets('aucun lien ; 390 px sans débordement', (tester) async {
    await pump(tester, const []);
    expect(find.text('Aucun lien.'), findsNWidgets(2));
    await pump(tester, [octLuc(), lucLem()], size: const Size(390, 1400));
    expect(tester.takeException(), isNull);
  });
}
```

Le fichier `test/characters/ghoul_panel_test.dart` est remplacé par :

<!-- file: test/characters/ghoul_panel_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/ghoul_panel.dart';
import 'package:portail_met/characters/sheet_widgets.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart' show formatDay;

import 'ghoul_test.dart' show ghoulState, mila;

void main() {
  Widget scope(List<Bond> bonds, Widget child) => ProviderScope(
        overrides: [characterBondsProvider('g').overrideWith((ref) async => bonds)],
        child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  testWidgets('état de goule : domitor, sang, échéance proche', (tester) async {
    await tester.pumpWidget(scope(const [], GhoulPanel(ghoulState(), characterId: 'g', now: DateTime(2026, 10, 20))));
    await tester.pumpAndSettle();
    expect(find.text('Goule de Isaure de Valcourt · clan du domitor : Toreador'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('Buvez avant le ${formatDay(DateTime(2026, 10, 26))}, sinon son âge le rattrape : 10 ans par jour.'), findsOneWidget);
    expect(find.text('ne peut pas baisser'), findsOneWidget);
    expect(find.text('●○○'), findsOneWidget, reason: 'sans lien de sang enregistré : ancien niveau de la fiche');
    expect(identityLine(mila()), 'Goule de Isaure de Valcourt · clan du domitor : Toreador', reason: 'revue : en-tête de la spec');
  });

  testWidgets('lien de sang lu dans les liens, au niveau du jour', (tester) async {
    final b = Bond(
      regnantId: 'x',
      thrallId: 'g',
      level: 2,
      lastDrink: DateTime(2026, 10, 1),
      lastContact: DateTime(2026, 10, 1),
      stored: true,
    );
    await tester.pumpWidget(scope([b], GhoulPanel(ghoulState(), characterId: 'g', now: DateTime(2026, 10, 20))));
    await tester.pumpAndSettle();
    expect(find.text('●●○'), findsOneWidget);
  });

  testWidgets('fiche en lecture d’une goule : panneau affiché', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scope(const [], CharacterSheetView(mila())));
    await tester.pumpAndSettle();
    expect(find.text('ÉTAT DE GOULE'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : bloc du joueur**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 4 impl`.

<!-- file: lib/bonds/bonds_player.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../characters/character.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'bond.dart';
import 'bond_rules.dart';
import 'bonds_repository.dart';

/// Blocs du joueur (J-Moralite) : liens subis et exercés que le conte lui laisse connaître, en lecture.
class PlayerBonds extends ConsumerWidget {
  const PlayerBonds({super.key, required this.character, this.today});

  final Character character;

  /// Date du jour (tests) ; aujourd'hui par défaut.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final day = today ?? DateTime.now();
    final c = character;
    final bonds = ref.watch(characterBondsProvider(c.id)).value ?? const <Bond>[];
    final suffered = activeBonds(bonds.where((b) => b.thrallId == c.id), day);
    final exerted = activeBonds(bonds.where((b) => b.regnantId == c.id), day);
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);

    Widget card(Bond b, String name, String? tag, List<String> lines) => Container(
          key: Key('bo-${b.id}'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(name, style: t.titleSmall),
                  if (tag != null) Text(tag, style: t.bodySmall?.copyWith(color: AppColors.narrator)),
                ]),
              ),
              Text(bondDots(effectiveLevel(b, day)), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
            ]),
            const SizedBox(height: 4),
            for (final (i, l) in lines.indexed)
              Text(l, style: i == 0 ? t.bodyMedium?.copyWith(color: AppColors.textSecondary) : muted),
          ]),
        );

    Widget empty() => Padding(padding: const EdgeInsets.only(top: 10), child: Text('Aucun lien.', style: t.bodyMedium));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Liens de sang que vous subissez'),
          if (suffered.isEmpty) empty(),
          for (final b in suffered) card(b, b.regnantName, null, [sufferedLine(b, day), sufferedDelay(b, day)]),
          const SizedBox(height: 12),
          Text(
            '2 gorgées : 1 Volonté par heure pour lui nuire. 3 gorgées : lien complet, qui efface les liens moindres.',
            style: muted,
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Liens que vous exercez'),
          if (exerted.isEmpty) empty(),
          for (final b in exerted) card(b, b.thrallName, b.ghoul ? 'votre goule' : null, [exertedLine(b, day)]),
          const SizedBox(height: 12),
          Text('Le conte choisit ce que vous savez des liens envers vous.', style: muted),
        ]),
      ),
    ]);
  }
}
```

Dans `lib/morality/morality_screen.dart` :
1. Ajouter l'import `import '../bonds/bonds_player.dart';` (avant `'../bonds/bonds_staff.dart'`).
2. Dans la vue du joueur, après `PlayerDerangements(character: c, rb: rb, basePath: basePath),` :

```dart
            const SizedBox(height: 20),
            PlayerBonds(character: c),
```

Dans `test/morality/morality_player_test.dart`, ajouter les imports :

```dart
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
```

puis, dans la liste `overrides` de `pump`, après `characterSinsProvider('x').overrideWith((ref) => Stream.value(list)),` :

```dart
        characterBondsProvider('x').overrideWith((ref) async => const <Bond>[]),
```

- [ ] **Step 3 : goule**

Dans `lib/characters/ghoul_panel.dart` :

1. Remplacer les imports par :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bonds/bond.dart';
import '../bonds/bond_rules.dart' show bondDots, effectiveLevel;
import '../bonds/bonds_repository.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../servants/servant_rules.dart' show DueState, dueDate, dueState;
import 'character.dart';
import 'sheet_widgets.dart' show InfoRow;
```

2. Remplacer la classe, de son commentaire jusqu'à la ligne `return Panel(` exclue, par :

```dart
/// « État de goule » (J-Goule) : domitor, lien, vitae, échéance, rappels des règles.
/// Le lien envers le domitor est lu dans les liens de sang (sous-projet 7c) ; à défaut, l'ancien niveau de la fiche.
class GhoulPanel extends ConsumerWidget {
  const GhoulPanel(this.g, {super.key, required this.characterId, this.now});
  final GhoulState g;

  /// Fiche de la goule.
  final String characterId;

  /// Date du jour (tests) ; maintenant par défaut.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = now ?? DateTime.now();
    final last = g.lastDrink;
    final state = dueState(last, today);
    final alert = switch (state) {
      DueState.late => 'Échéance dépassée le ${formatDay(dueDate(last!))} : son âge le rattrape, 10 ans par jour.',
      DueState.soon => 'Buvez avant le ${formatDay(dueDate(last!))}, sinon son âge le rattrape : 10 ans par jour.',
      _ => null,
    };
    final bond = (ref.watch(characterBondsProvider(characterId)).value ?? const <Bond>[])
        .where((b) => b.regnantId == g.domitorId && b.thrallId == characterId)
        .firstOrNull;
    final level = bond == null ? g.bond.clamp(0, 3) : effectiveLevel(bond, today);
```

3. Remplacer la ligne `InfoRow('Lien de sang', g.bond == 0 ? 'aucun' : dots(g.bond)),` par :

```dart
        InfoRow('Lien de sang', level == 0 ? 'aucun' : bondDots(level)),
```

Dans `lib/characters/sheet_widgets.dart`, remplacer `GhoulPanel(c.ghoul!)` par `GhoulPanel(c.ghoul!, characterId: c.id)`.

Dans `lib/characters/character_edit_screen.dart`, section « État de goule », remplacer le `DropdownButtonFormField<int>` de clé `ghoul-bond` (tout le widget, de `DropdownButtonFormField<int>(` à son `),` fermant) par :

```dart
            Text(
              'Lien de sang : il se règle dans l’onglet Moralité & liens.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
```

Si `dots` ou un autre import n'est plus utilisé dans ces fichiers, retirer l'import (l'analyseur le signale).

- [ ] **Step 4 : tests (succès attendu)**

Run : `flutter test test/bonds test/morality test/characters`, puis `flutter analyze` et `flutter test`.

Expected : succès ; analyseur propre. Si un autre test qui affiche la fiche d'une goule échoue faute de `ProviderScope`, l'envelopper comme `scope` ci-dessus, avec `characterBondsProvider('<id>').overrideWith((ref) async => const <Bond>[])`.

- [ ] **Step 5 : commit**

```bash
git add lib/bonds/bonds_player.dart lib/morality/morality_screen.dart lib/characters/ghoul_panel.dart lib/characters/sheet_widgets.dart lib/characters/character_edit_screen.dart test/bonds/bonds_player_test.dart test/morality/morality_player_test.dart test/characters/ghoul_panel_test.dart
git commit -m "feat: liens de sang — vue du joueur, lien de la goule lu dans les liens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : page « Liens de sang de la chronique »

Maquette : `C-Liens.dc.html` et `C-Liens-mobile.dc.html`.

**Files :**
- Create : `lib/bonds/bonds_screen.dart`.
- Modify : `lib/router.dart`, `lib/characters/characters_list_screen.dart`.
- Test : `test/bonds/bonds_screen_test.dart`.

**Interfaces :**
- Consumes : les tâches 1 à 3 (`DrinkForm`, calculs, `allBondsProvider`, `bondsRepositoryProvider`).
- Produces : `BondsScreen({today})` sur `/conteur/liens`, avec les clés `bo-stat-active`, `bo-stat-full`, `bo-stat-soon`, `bo-stat-unknown`, `bo-filter-<nom du filtre>`, `bo-search`, `bo-row-<idLien>`, `bo-panel`, `bo-regnant`, `bo-thrall`, `bo-alert`, `bo-m-drink`, `bo-m-contact`, `bo-back`.

- [ ] **Step 1 : test (échec attendu)**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 5 test`, puis `flutter test test/bonds/bonds_screen_test.dart`.

Expected : échec au chargement.

<!-- file: test/bonds/bonds_screen_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/bonds/bonds_screen.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/theme.dart';

import '../fakes.dart';
import 'bond_rules_test.dart';

void main() {
  const lea = AppUser(uid: 'lea', displayName: 'Léa G.', email: 'l@ex.fr', role: Role.conteur);
  const julien = AppUser(uid: 'julien', displayName: 'Julien', email: 'j@ex.fr', role: Role.narrateur);

  Future<FakeBondsRepository> pump(WidgetTester tester, {AppUser user = lea, Size size = const Size(1440, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeBondsRepository();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        allBondsProvider.overrideWith((ref) => Stream.value([octJon(), octLuc(), agaBas(), lucLem()])),
        allCharactersProvider.overrideWith((ref) => Stream.value(cast())),
        bondsRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: BondsScreen(today: today))),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Finder inKey(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  testWidgets('compteurs, liens triés par échéance', (tester) async {
    await pump(tester);
    expect(find.text('Liens de sang de la chronique'), findsOneWidget);
    expect(inKey('bo-stat-active', '4'), findsOneWidget);
    expect(inKey('bo-stat-full', '1'), findsOneWidget);
    expect(inKey('bo-stat-soon', '1'), findsOneWidget);
    expect(inKey('bo-stat-unknown', '1'), findsOneWidget);
    final y = [for (final id in ['aga_bas', 'luc_lem', 'oct_luc', 'oct_jon']) tester.getTopLeft(find.byKey(Key('bo-row-$id'))).dy];
    expect([...y]..sort(), y);
    expect(inKey('bo-row-aga_bas', 'S’efface le 3 oct. sans contact'), findsOneWidget);
    expect(inKey('bo-row-oct_jon', 'Connu du lié : non'), findsOneWidget);
  });

  testWidgets('filtres et recherche', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('bo-filter-full')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-row-luc_lem')), findsOneWidget);
    expect(find.byKey(const Key('bo-row-oct_luc')), findsNothing);
    await tester.tap(find.byKey(const Key('bo-filter-all')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bo-search')), 'jonas');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-row-oct_jon')), findsOneWidget);
    expect(find.byKey(const Key('bo-row-oct_luc')), findsNothing);
  });

  testWidgets('panneau : gorgée entre deux fiches choisies', (tester) async {
    final repo = await pump(tester);
    expect(find.text('Choisissez qui donne son sang'), findsOneWidget);
    await choose(tester, 'bo-regnant', 'Octave Marchetti · PNJ · Ventrue');
    await choose(tester, 'bo-thrall', 'Lucie Arnaud · PJ · Malkavien');
    expect(find.text('Lien envers Octave Marchetti : ●●○ → ●●●'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dr-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['drink:oct_luc:3']);
  });

  testWidgets('une ligne charge le panneau ; simple contact', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('bo-row-luc_lem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dr-contact')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['save:luc_lem:3']);
  });

  testWidgets('même fiche des deux côtés : refus', (tester) async {
    final repo = await pump(tester);
    await choose(tester, 'bo-regnant', 'Octave Marchetti · PNJ · Ventrue');
    await choose(tester, 'bo-thrall', 'Octave Marchetti · PNJ · Ventrue');
    expect(find.text('Une fiche ne peut pas se lier elle-même'), findsOneWidget);
    expect(find.byKey(const Key('dr-save')), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('narrateur : la page sans le panneau', (tester) async {
    await pump(tester, user: julien);
    expect(find.byKey(const Key('bo-row-oct_luc')), findsOneWidget);
    expect(find.byKey(const Key('bo-panel')), findsNothing);
  });

  testWidgets('mobile : alerte d’échéance, panneau en pleine page, 390 px (Review Focus 5)', (tester) async {
    await pump(tester, size: const Size(390, 1600));
    expect(find.text('Échéance dans 6 jours'), findsOneWidget);
    expect(find.text('Le lien de Bastien Roche envers Sœur Agathe : s’efface le 3 oct. sans contact.'), findsOneWidget);
    expect(find.byKey(const Key('bo-panel')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('bo-m-drink')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-panel')), findsOneWidget);
    expect(find.byKey(const Key('bo-back')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('bo-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bo-panel')), findsNothing);
  });
}
```

- [ ] **Step 2 : implémentation**

Run : `python tool/extract_plan.py docs/superpowers/plans/2026-10-15-liens-de-sang.md 5 impl`.

<!-- file: lib/bonds/bonds_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../npcs/loan_rules.dart' show formatLoanDay;
import 'bond.dart';
import 'bond_rules.dart';
import 'bonds_repository.dart';
import 'drink_form.dart';

String _lowerFirst(String s) => s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

/// Page « Liens de sang de la chronique » (C-Liens) : liens actifs, filtres, panneau « Enregistrer une gorgée ».
class BondsScreen extends ConsumerStatefulWidget {
  const BondsScreen({super.key, this.today});

  /// Date du jour (tests) ; aujourd'hui par défaut.
  final DateTime? today;

  @override
  ConsumerState<BondsScreen> createState() => _BondsScreenState();
}

class _BondsScreenState extends ConsumerState<BondsScreen> {
  BondFilter _filter = BondFilter.all;
  String _query = '';
  String? _regnantId;
  String? _thrallId;

  /// Mobile : panneau ouvert en pleine page.
  bool _panel = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function(Actor by) write) async {
    final by = actorOf(ref.read(currentUserProvider).value);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await write(by);
      if (mounted) setState(() => _panel = false);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Enregistrement refusé : réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value; // l'auteur est relu à l'enregistrement
    final canEdit = me != null && me.role.managesAccounts;
    final today = widget.today ?? DateTime.now();
    return asyncView(ref.watch(allBondsProvider), (all) {
      final t = Theme.of(context).textTheme;
      final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
      final chars = ref.watch(allCharactersProvider).value ?? const <Character>[];
      Character? byId(String? id) => id == null ? null : chars.where((x) => x.id == id).firstOrNull;
      final wide = isWide(context);
      final active = activeBonds(all, today);
      final shown = [for (final b in active) if (bondMatches(b, _filter, _query, today)) b];
      final s = bondStats(active, today);
      final repo = ref.read(bondsRepositoryProvider);

      Widget panel() {
        final pickable = [
          for (final x in chars)
            if (x.playerUid == null || x.playerUid != me?.uid) x,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        Widget pick(String key, String label, String? value, ValueChanged<String?> onChanged) => KeyedSubtree(
              key: ValueKey('$key-$value'),
              child: DropdownButtonFormField<String>(
                key: Key(key),
                initialValue: pickable.any((x) => x.id == value) ? value : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final x in pickable)
                    DropdownMenuItem(value: x.id, child: Text('${x.name} · ${partyTag(x)}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: onChanged,
              ),
            );
        final r = byId(_regnantId);
        final th = byId(_thrallId);
        final errors = bondChecks(regnantId: r?.id, thrallId: th?.id, day: today);
        Bond? base;
        if (r != null && th != null && errors.isEmpty) {
          final existing = all.where((b) => b.id == bondId(r.id, th.id)).firstOrNull;
          base = existing == null ? bondBetween(r, th, today) : refreshed(existing, r, th);
        }
        return Container(
          key: const Key('bo-panel'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Enregistrer une gorgée'),
            const SizedBox(height: 12),
            pick('bo-regnant', 'Qui donne son sang', _regnantId, (v) => setState(() => _regnantId = v)),
            const SizedBox(height: 10),
            pick('bo-thrall', 'Qui boit', _thrallId, (v) => setState(() => _thrallId = v)),
            if (base == null) ...[
              const SizedBox(height: 10),
              for (final e in errors) Text(e, style: t.bodySmall?.copyWith(color: AppColors.linkHover)),
            ] else
              DrinkForm(
                key: ValueKey('dr-${base.id}'),
                base: base,
                all: all,
                today: today,
                busy: _busy,
                onDrink: (w) => _run((by) => repo.drink(w, by)),
                onContact: base.stored ? (b) => _run((by) => repo.save(b, by)) : null,
              ),
            const SizedBox(height: 16),
            Text('Règles appliquées', style: t.labelMedium),
            const SizedBox(height: 4),
            Text('●○○ s’efface après un an sans contact.', style: muted),
            Text('●●○ s’efface après six mois sans contact ; résister coûte 1 Volonté par heure.', style: muted),
            Text('●●● redescend à ●●○ après trois mois sans boire et efface les liens moindres.', style: muted),
          ]),
        );
      }

      Widget stat(String key, int v, String label, Color color) => Container(
            key: Key(key),
            width: 170,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$v', style: t.headlineMedium?.copyWith(color: color)),
              Text(label, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
          );

      Widget party(String name, Character? c) => SizedBox(
            width: 200,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: t.titleSmall),
              if (c != null) Text(partyTag(c), style: muted),
            ]),
          );

      Widget row(Bond b) {
        final selected = _regnantId == b.regnantId && _thrallId == b.thrallId;
        return InkWell(
          key: Key('bo-row-${b.id}'),
          onTap: () => setState(() {
            _regnantId = b.regnantId;
            _thrallId = b.thrallId;
            _panel = true;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.deadBg : null,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(spacing: 18, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              party(b.regnantName, byId(b.regnantId)),
              party(b.thrallName, byId(b.thrallId)),
              Text(bondDots(effectiveLevel(b, today)), style: t.titleMedium?.copyWith(color: AppColors.accentIcon, letterSpacing: 3)),
              Text(
                'Gorgée ${formatLoanDay(b.lastDrink, now: today)} · contact ${formatLoanDay(b.lastContact, now: today)}',
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Text(dueText(b, today), style: t.bodySmall?.copyWith(color: dueSoon(b, today) ? AppColors.goldLight : AppColors.textSecondary)),
              Text(
                b.known ? 'Connu du lié : oui' : 'Connu du lié : non',
                style: t.bodySmall?.copyWith(color: b.known ? AppColors.success : AppColors.linkHover),
              ),
            ]),
          ),
        );
      }

      final soonest = active.where((b) => dueSoon(b, today)).firstOrNull;
      final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton(onPressed: () => context.go('/conteur/fiches'), child: const Text('Fiches')),
          Text('/ Liens de sang', style: muted),
        ]),
        const PageTitle(
          'Liens de sang de la chronique',
          subtitle: 'Chaque gorgée et chaque contact mettent à jour les deux fiches. Les échéances se calculent seules.',
        ),
        const SizedBox(height: 18),
        if (!wide && soonest != null) ...[
          Container(
            key: const Key('bo-alert'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.reviewBg,
              border: Border.all(color: AppColors.gold),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                'Échéance dans ${daysUntil(today, nextChange(soonest, today)!.at)} jours',
                style: t.titleSmall?.copyWith(color: AppColors.goldLight),
              ),
              Text(
                'Le lien de ${soonest.thrallName} envers ${soonest.regnantName} : ${_lowerFirst(dueText(soonest, today))}.',
                style: t.bodyMedium,
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        Wrap(spacing: 14, runSpacing: 14, children: [
          stat('bo-stat-active', s.active, 'liens actifs', AppColors.text),
          stat('bo-stat-full', s.full, 'liens complets', AppColors.accentIcon),
          stat('bo-stat-soon', s.soon, 'échéance sous 30 jours', AppColors.goldLight),
          stat('bo-stat-unknown', s.unknown, 'ignorés du lié', AppColors.linkHover),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final f in BondFilter.values)
            ChoiceChip(
              key: Key('bo-filter-${f.name}'),
              label: Text(f.label),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            ),
          SizedBox(
            width: 240,
            child: TextField(
              key: const Key('bo-search'),
              decoration: const InputDecoration(hintText: 'Rechercher un personnage…'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (shown.isEmpty) Padding(padding: const EdgeInsets.all(18), child: Text('Aucun lien.', style: t.bodyMedium)),
            for (final b in shown) row(b),
          ]),
        ),
      ]);

      if (!wide && _panel && canEdit) {
        return PageBody(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('bo-back'),
              onPressed: () => setState(() => _panel = false),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Retour'),
            ),
          ),
          const SizedBox(height: 8),
          panel(),
        ]);
      }
      if (wide) {
        return PageBody(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: list),
            if (canEdit) ...[const SizedBox(width: 24), SizedBox(width: 420, child: panel())],
          ]),
        ]);
      }
      return PageBody(children: [
        list,
        if (canEdit) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('bo-m-contact'),
                onPressed: () => setState(() => _panel = true),
                child: const Text('Contact'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const Key('bo-m-drink'),
                onPressed: () => setState(() => _panel = true),
                child: const Text('+ Gorgée'),
              ),
            ),
          ]),
        ],
      ]);
    }, onRetry: () => ref.invalidate(allBondsProvider));
  }
}
```

- [ ] **Step 3 : route et entrée**

Dans `lib/router.dart` :
1. Ajouter l'import `import 'bonds/bonds_screen.dart';` (ordre alphabétique des imports du fichier).
2. Après `page('/conteur/allies', const AlliesAdminScreen()),` :

```dart
          page('/conteur/liens', const BondsScreen()),
```

Dans `lib/characters/characters_list_screen.dart`, dans le `Wrap` de l'action de `PageTitle`, après le bouton « Alliés en jeu » :

```dart
            OutlinedButton(onPressed: () => context.go('/conteur/liens'), child: const Text('Liens de sang')),
```

- [ ] **Step 4 : tests (succès attendu)**

Run : `flutter test test/bonds`, puis `flutter analyze` et `flutter test`.

Expected : succès ; analyseur propre.

- [ ] **Step 5 : commit**

```bash
git add lib/bonds/bonds_screen.dart lib/router.dart lib/characters/characters_list_screen.dart test/bonds/bonds_screen_test.dart
git commit -m "feat: liens de sang — page de la chronique (compteurs, filtres, panneau de gorgée)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : revue, puis déploiement (avec accord)

- [ ] **Step 1 :** revue finale de la branche contre la spec (sous-agent le plus capable).
- [ ] **Step 2 :** suite complète : `flutter analyze`, `flutter test`, tests des règles.
- [ ] **Step 3 :** avec l'accord de l'utilisateur seulement :
  - `firebase deploy --only firestore:rules` ;
  - `flutter build web` puis `firebase deploy --only hosting` ;
  - fusion de `liens` dans `main`, puis `git push`.
