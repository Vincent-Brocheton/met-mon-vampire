import 'dart:async';

import 'package:portail_met/allies/ally_file.dart';
import 'package:portail_met/allies/allies_repository.dart';
import 'package:portail_met/auth/auth_repository.dart';
import 'package:portail_met/bonds/bond.dart';
import 'package:portail_met/bonds/bond_rules.dart' show DrinkWrite;
import 'package:portail_met/bonds/bonds_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/core/trace.dart';
import 'package:portail_met/events/events_repository.dart';
import 'package:portail_met/events/story_event.dart';
import 'package:portail_met/items/item.dart';
import 'package:portail_met/items/items_repository.dart';
import 'package:portail_met/morality/sin.dart';
import 'package:portail_met/morality/sins_repository.dart';
import 'package:portail_met/npcs/npc_loan.dart';
import 'package:portail_met/npcs/npc_loans_repository.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/places/places_repository.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/rulebook/rules_repository.dart';
import 'package:portail_met/servants/servant_file.dart';
import 'package:portail_met/servants/servants_repository.dart';
import 'package:portail_met/xp/xp_corrections.dart';
import 'package:portail_met/xp/xp_gain.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';
import 'package:portail_met/xp/xp_settings.dart';

/// Enregistre les appels ; lève [error] s’il est défini.
class FakeAuthRepository implements AuthRepository {
  Object? error;
  final calls = <String>[];

  Future<void> _record(String call) async {
    calls.add(call);
    if (error != null) throw error!;
  }

  @override
  Future<void> signIn(String email, String password, {bool remember = true}) => _record('signIn:$email');

  @override
  Future<void> sendPasswordReset(String email) => _record('reset:$email');

  @override
  Future<void> ensureProfile({String? message}) => _record('ensureProfile');

  @override
  Future<bool> applyInvitation() async {
    await _record('applyInvitation');
    return false;
  }

  @override
  bool isSignInLink(String link) => link.contains('mode=signIn');

  @override
  Future<void> signInWithLink(String email, String link) => _record('signInWithLink:$email');

  @override
  Future<void> signOut() => _record('signOut');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCharacterRepository implements CharacterRepository {
  final calls = <String>[];
  Object? error;

  /// Appelé pendant saveEdit (simule l'instantané local de Firestore avant la fin du commit).
  void Function()? onSaveEdit;

  Character? lastAfter;
  String? lastKind;
  Map<String, Object?>? lastExtra;
  Character? lastCreated;
  String? lastCreatedId;
  List<StoryEvent> lastEvents = const [];
  List<StoryEvent> lastCreatedEvents = const [];

  @override
  Future<void> saveEdit(Character before, Character after, String reason, Actor by, {String? kind, Map<String, Object?> extra = const {}, List<StoryEvent> events = const []}) async {
    calls.add('saveEdit:$reason');
    lastAfter = after;
    lastKind = kind;
    lastExtra = extra;
    lastEvents = events;
    onSaveEdit?.call();
    if (error != null) throw error!;
  }

  @override
  Future<String> createSheet(Character c, Actor by, String summary, {String? id, List<StoryEvent> events = const []}) async {
    calls.add('createSheet:${c.name}');
    lastCreatedId = id;
    lastCreatedEvents = events;
    if (error != null) throw error!;
    lastCreated = c;
    return 'new-sheet';
  }

  GhoulState? lastGhoul;

  @override
  Future<String> create({required String name, required CharacterKind kind, String? playerUid, String? playerName, GhoulState? ghoul, required Actor by}) async {
    calls.add('create:${kind.name}:$name');
    lastGhoul = ghoul;
    return 'new-id';
  }

  @override
  Future<void> saveNotes(String id, String text, Actor by) async => calls.add('notes:$text');

  /// Dernier brouillon reçu par saveDraft.
  Character? lastDraft;

  /// Si défini, saveDraft attend ce futur (enregistrement en cours).
  Future<void>? saveGate;

  @override
  Future<void> saveDraft(Character c) async {
    calls.add('saveDraft');
    lastDraft = c;
    if (saveGate != null) await saveGate;
    if (error != null) throw error!;
  }

  @override
  Future<void> submit(Character c, Actor by) async => calls.add('submit:${c.name}');

  @override
  Future<void> withdraw(Character c, Actor by) async => calls.add('withdraw');

  @override
  Future<void> setBonus(Character c, int bonus, Actor by) async => calls.add('bonus:$bonus');

  @override
  Future<void> decide(Character c, CharacterStatus to, String comment, Actor by) async =>
      calls.add('decide:${to.name}:$comment');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeXpRepository implements XpRepository {
  final calls = <String>[];
  Object? error;

  /// Dernière demande reçue par save.
  XpRequest? lastSaved;

  @override
  Future<String> save(XpRequest r, {required bool submit}) async {
    calls.add('save:${submit ? 'submit' : 'draft'}:${r.total}');
    lastSaved = r;
    if (error != null) throw error!;
    return r.id.isEmpty ? 'new-req' : r.id;
  }

  @override
  Future<void> reply(XpRequest r, String text, Actor by) async => calls.add('reply:$text');

  @override
  Future<void> cancel(XpRequest r) async => calls.add('cancel:${r.id}');

  @override
  Future<void> decide(XpRequest r, Character c, RequestStatus to, String comment, Actor by, {Rulebook rb = const Rulebook()}) async {
    calls.add('decide:${to.name}:$comment');
    if (error != null) throw error!;
  }

  /// Noms refusés renvoyés par payGain et award.
  List<String> refused = const [];

  XpSettings? lastSettings;

  @override
  Future<void> saveSettings(XpSettings s, Actor by) async {
    lastSettings = s;
    calls.add('settings:${s.monthlyEnabled}:${s.gainSince}:${[for (final t in s.tiers) '${t.months}/${t.xp}/${t.every}'].join(',')}');
  }

  @override
  Future<List<String>> payGain(List<GainDue> dues, Actor by) async {
    calls.add('gain:${[for (final d in dues) '${d.c.id}=${d.xp}@${d.through}'].join(',')}');
    return refused;
  }

  @override
  Future<List<String>> award(List<(Character, int)> items, String reason, Actor by) async {
    calls.add('award:$reason:${[for (final (c, n) in items) '${c.id}=$n'].join(',')}');
    return refused;
  }

  @override
  Future<void> correct(Character before, Character after, CorrectionKind k, String reason, Actor by) async =>
      calls.add('correction:${k.name}:${before.xpSpent}→${after.xpSpent}:$reason');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRulesRepository implements RulesRepository {
  final calls = <String>[];
  RuleEntry? lastSaved;
  String? lastNote;
  Map<String, dynamic>? lastSettings;
  Object? importError;
  int noteWatches = 0;

  /// Retient l'import jusqu'à ce que le test le libère.
  Completer<void>? importGate;

  @override
  Stream<String> watchNote(String cat, String id) {
    noteWatches++;
    return Stream.value('');
  }

  @override
  Future<String> save(String cat, RuleEntry e, Actor by, {String? note}) async {
    calls.add('save:$cat:${e.name}:${e.state.name}');
    lastSaved = e;
    lastNote = note;
    return e.id.isEmpty ? 'new-rule' : e.id;
  }

  @override
  Future<void> delete(String cat, String id) async => calls.add('delete:$cat:$id');

  @override
  Future<void> saveSettings(String cat, Map<String, dynamic> values, Actor by) async {
    calls.add('settings:$cat');
    lastSettings = values;
  }

  @override
  Future<void> importEntries(String cat, List<RuleEntry> entries, Actor by) async {
    await importGate?.future;
    if (importError != null) throw importError!;
    calls.add('import:$cat:${entries.length}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Référentiel de base, sans Firestore.
final baseRulebook = rulebookProvider.overrideWith((ref) => const Rulebook());

class FakePlacesRepository implements PlacesRepository {
  final calls = <String>[];
  Place? lastSaved;
  Place? lastBefore;
  String? lastNote;
  String? lastReason;
  Object? error;

  @override
  Stream<String> watchNote(String id) => Stream.value('');

  @override
  Stream<List<TraceEntry>> watchHistory(String id) => Stream.value(const []);

  @override
  Future<String> save(Place before, Place p, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    calls.add('save:${p.name}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = p;
    lastNote = note;
    lastReason = reason;
    return p.id.isEmpty ? 'new-place' : p.id;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucun lieu pour la fiche 'x' (écrans qui affichent la section « Lieux »).
final noPlaces = characterPlacesProvider('x').overrideWith((ref) => Stream.value(const <Place>[]));

class FakeServantsRepository implements ServantsRepository {
  final calls = <String>[];
  ServantFile? lastSaved;
  ServantFile? lastBefore;
  String? lastNote;
  String? lastReason;
  Object? error;

  @override
  Stream<String> watchNote(String id) => Stream.value('');

  @override
  Stream<List<TraceEntry>> watchHistory(String id) => Stream.value(const []);

  @override
  Future<String> save(ServantFile before, ServantFile f, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    calls.add('save:${f.name}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = f;
    lastNote = note;
    lastReason = reason;
    return f.id.isEmpty ? 'new-servant' : f.id;
  }

  Object? releaseError;

  @override
  Future<void> setPlayers(String id, List<String> players, Actor by) async => calls.add('players:$id:${players.join(',')}');

  @override
  Future<void> release(String id, Actor by, {int rank = 1}) async {
    calls.add('release:$id');
    if (releaseError != null) throw releaseError!;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucune fiche détaillée de serviteur pour la fiche 'x'.
final noServantFiles = characterServantFilesProvider('x').overrideWith((ref) => Stream.value(const <ServantFile>[]));

class FakeNpcLoansRepository implements NpcLoansRepository {
  final calls = <String>[];
  NpcLoan? lastSaved;
  NpcLoan? lastBefore;
  Map<String, dynamic>? lastSheet;
  String? lastNotes;
  Object? error;

  @override
  Future<String> save(NpcLoan before, NpcLoan l, Actor by, {Map<String, dynamic>? sheet}) async {
    calls.add('save:${l.characterName}:${l.playerName}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = l;
    lastSheet = sheet;
    return l.id.isEmpty ? 'new-loan' : l.id;
  }

  @override
  Future<void> saveNotes(String id, String text) async {
    calls.add('notes:$id');
    if (error != null) throw error!;
    lastNotes = text;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucun prêt pour la fiche 'x'.
final noNpcLoans = characterNpcLoansProvider('x').overrideWith((ref) => Stream.value(const <NpcLoan>[]));

class FakeItemsRepository implements ItemsRepository {
  final calls = <String>[];
  Item? lastSaved;
  Item? lastBefore;
  Item? lastRequest;
  String? lastNote;
  String? lastReason;
  Object? error;

  @override
  Stream<String> watchNote(String id) => Stream.value('');

  @override
  Stream<List<TraceEntry>> watchHistory(String id) => Stream.value(const []);

  @override
  Future<String> save(Item before, Item i, Actor by, {String? note, String noteBefore = '', String reason = ''}) async {
    calls.add('save:${i.name}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = i;
    lastNote = note;
    lastReason = reason;
    return i.id.isEmpty ? 'new-item' : i.id;
  }

  @override
  Future<String> request(Item i, Actor by) async {
    calls.add('request:${i.name}');
    if (error != null) throw error!;
    lastRequest = i;
    return 'new-request';
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (error != null) throw error!;
  }

  @override
  Future<void> deleteRequest(String id) async {
    calls.add('deleteRequest:$id');
    if (error != null) throw error!;
  }

  @override
  Future<void> setPlayer(String characterId, String playerUid, Actor by) async {
    calls.add('player:$characterId:$playerUid');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucun objet pour la fiche 'x'.
final noItems = characterItemsProvider('x').overrideWith((ref) => Stream.value(const <Item>[]));

class FakeAlliesRepository implements AlliesRepository {
  final calls = <String>[];
  AllyFile? lastSaved;
  AllyFile? lastBefore;
  String? lastReason;
  Object? error;

  @override
  Stream<List<TraceEntry>> watchHistory(String id) => Stream.value(const []);

  @override
  Future<void> save(AllyFile before, AllyFile f, Actor by, {String reason = ''}) async {
    calls.add('save:${f.id}');
    lastBefore = before;
    if (error != null) throw error!;
    lastSaved = f;
    lastReason = reason;
  }

  @override
  Future<void> setPlayers(String characterId, List<String> players, Actor by) async {
    calls.add('players:$characterId:${players.join(',')}');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Aucun suivi d'allié pour la fiche 'x'.
final noAllyFiles = characterAllyFilesProvider('x').overrideWith((ref) => Stream.value(const <AllyFile>[]));

class FakeEventsRepository implements EventsRepository {
  final calls = <String>[];
  StoryEvent? lastSaved;
  Object? error;

  @override
  Future<void> save(String characterId, StoryEvent e, Actor by) async {
    calls.add('save:$characterId:${e.id.isEmpty ? 'new' : e.id}');
    if (error != null) throw error!;
    lastSaved = e;
  }

  @override
  Future<void> delete(String characterId, String id) async {
    calls.add('delete:$characterId:$id');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSinsRepository implements SinsRepository {
  final calls = <String>[];
  Sin? lastSaved;
  Object? error;

  @override
  Future<void> save(String characterId, Sin s, Actor by) async {
    calls.add('save:$characterId:${s.id.isEmpty ? 'new' : s.id}');
    if (error != null) throw error!;
    lastSaved = s;
  }

  @override
  Future<void> delete(String characterId, String id) async {
    calls.add('delete:$characterId:$id');
    if (error != null) throw error!;
  }

  @override
  Future<void> applyEveningLoss(Character before, List<Sin> evening, Actor by) async {
    calls.add('loss:${before.id}:${[for (final s in evening) s.id].join(',')}');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  Future<void> setPlayer(String characterId, String playerUid, Actor by) async {
    calls.add('player:$characterId:$playerUid');
    if (error != null) throw error!;
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
