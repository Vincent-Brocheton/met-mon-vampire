# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Portail MET is a Flutter app (web first, with an Android target) for running a Vampire Mind's Eye Theatre chronicle. Players create and follow their characters (« fiches »). The storytelling staff (« conte ») validates sheets, awards and spends XP, and maintains the rules referential, NPCs, places, items, allies, events, morality and so on. The UI text, code comments, specs and commit messages are all in **French**. Backend: Firebase Auth and Cloud Firestore (project `met-mon-vampire`), hosted at https://met-mon-vampire.web.app.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after adding or changing any @riverpod provider (*.g.dart files are committed)
flutter analyze                                            # must be clean
flutter test                                               # whole suite
flutter test test/morality/derangement_rules_test.dart     # one file
flutter test test/morality/derangement_rules_test.dart --plain-name "contrôles"   # one test by name
flutter run -d chrome --dart-define=EMULATORS=true         # app against local emulators (auth 9099, firestore 8080)
```

Firestore security-rules tests (Node, run in the Firestore emulator). Run them from `rules_test/`. On this machine they need the Android Studio JBR:

```bash
cd rules_test && JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test
```

Deploy commands:
- `firebase deploy --only firestore:rules`
- `flutter build web && firebase deploy --only hosting`

Deploying, merging into `main` and pushing happen only with the user's explicit approval.

## Conventions

- **Formatting and files:**
  - Do not run `dart format`; the code uses long lines on purpose. Keep LF line endings.
  - Never commit `bash.exe.stackdump`, `rules_test/firestore-debug.log` or `firestore-debug.log`.
- **Text and tests:**
  - User-facing text uses the typographic apostrophe ’ and French punctuation (« », a space before `:`).
  - Dart records that contain lists compare the lists by identity. Never write `expect((a, [..]), (x, [..]))`; split it into separate expectations.

## Architecture

### Code organization

- **Feature folders.** `lib/` is split by feature (`characters`, `xp`, `creation`, `rulebook`, `servants`, `npcs`, `places`, `items`, `allies`, `events`, `morality`, …). Shared UI lives in `lib/core` (theme `AppColors`, `Panel`, `PageBody`, `PageTitle`, `SectionTitle`, `asyncView`, `isWide`).
- **Typical feature layout:**
  - a model with `fromMap` / `toMap` / `copy` ;
  - `*_rules.dart`: pure functions (calculations, checks, French display strings) that hold most of the logic and most of the tests ;
  - `*_repository.dart`: Firestore access plus `@riverpod` providers ;
  - screens as `ConsumerWidget` / `ConsumerStatefulWidget`.
- **State and routing:**
  - Riverpod 3 with code generation.
  - `go_router` is set up in `lib/router.dart`. Staff pages live under `/conteur/...` and player pages under `/joueur/...`. A sheet's tabs are sub-routes of `/conteur/fiches/:id` and `/joueur/personnages/:id`.
  - `lib/redirect.dart` is a pure function that maps the session and role to a redirect.

### Roles

- **Roles** (`lib/auth/session.dart`): `pending`, `joueur`, `narrateur`, `conteur`, `principal`, `disabled`.
  - `role.isStaff` covers narrateur, conteur and principal.
  - `role.managesAccounts` covers conteur and principal. Only those can write staff data; the narrateur is read-only.
- **A staff member viewing their own sheet** is treated as a player, in both the screens and the Firestore rules. The usual test is `staffView = me.role.isStaff && c.playerUid != me.uid`.

### Character sheets (`lib/characters/character.dart`, `character_repository.dart`)

- **Versions and history:**
  - Every sheet document carries a `version`.
  - Each staff change goes through `CharacterRepository.stageEdit(batch, …)` or `saveEdit(...)`. These bump the version and write an entry in the `characters/{id}/history` subcollection, built from `describeChanges(before, after)`.
  - Optional story events can be staged in the same batch.
  - The Firestore rules enforce the version increment and the history entry (`historyOk`).
- **Late keys** (`_laterKeys`):
  - These are fields added by later sub-projects (`allies`, `ghoul`, `path`, `derangements`, …).
  - `toMap()` writes one only if it is non-empty or was already stored (`storedKeys`), so old documents stay unchanged.
  - Keys the player must never write are stripped from `draftData` and listed as protected in the rules (`playerDraftSave`). A late key that leaks into the player draft makes every draft save fail.
- **Subcollections** of a sheet: `history`, `events` (story timeline, with visibility `public`, `player` or `staff`), `sins`, `private`.

### XP requests as a generic request channel

`lib/xp` handles player requests that staff validate or refuse (`XpRequest` / `XpItem` / `XpKind`). `xp_rules.dart` defines cost, checks, `applyRequest` and the correction (`_revert`).

Some kinds cost 0 XP and act as « role requests » validated by staff, for example `XpKind.ally` and `XpKind.derangement`. They carry their detail in a map on `XpItem` and are excluded from the normal XP spend screen.

### Rules referential

`lib/rulebook` loads the editable rules referential: Firestore collection `rules/{cat}`, exposed as a `Rulebook` through `rulebookProvider`. It covers merits, flaws, disciplines, clans, paths, derangements and so on. Screens take an `rb` argument instead of hard-coding the game data.

### Firestore rules (`firestore.rules`)

- They are the security boundary. Every collection validates its exact key set (`keys().hasOnly`), its types and its author (`byUid == request.auth.uid`).
- Batched writes use `getAfter` to check related documents.
- Player queries must carry the same filters the read rules test, such as a visibility or ownership field. Otherwise Firestore refuses the query.
- Any rules change needs a matching test in `rules_test/*.test.js`.

### Tests

- **Shared helpers:**
  - `test/fakes.dart` holds fake repositories that record calls into `calls` lists and can throw through `error`.
  - `test/characters/character_test.dart` exports the `sample()` sheet fixture.
- **Widget tests:**
  - They wrap the widget in `ProviderScope(overrides: [...])`, overriding `currentUserProvider` and the providers the widget reads.
  - They set `tester.view.physicalSize`; layouts are also checked at 390 px wide (`expect(tester.takeException(), isNull)`).
  - Any screen that adds a provider forces every test pumping that screen to add an override.

## Design docs and workflow

- **Sub-projects.** Work is done in numbered sub-projects. Each one has:
  - a spec in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` ;
  - an implementation plan in `docs/superpowers/plans/` ;
  - a feature branch, merged into `main` once approved.
- **Plans** embed the complete code as blocks preceded by `<!-- file: path -->`. `python tool/extract_plan.py <plan> <task> [test|impl]` writes a task's files to disk.
- **Mockups.** The UI follows the Claude Design mockups at https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp.
  - Each board has its own file (`project/C-*.dc.html` for staff screens, `project/J-*.dc.html` for player screens, `*-mobile` variants).
  - Read them with the Artifact tool (`action: read`, `path: project/<board>`).
