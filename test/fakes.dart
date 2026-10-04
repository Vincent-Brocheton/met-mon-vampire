import 'dart:async';

import 'package:portail_met/auth/auth_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/places/place.dart';
import 'package:portail_met/places/places_repository.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/rulebook.dart';
import 'package:portail_met/rulebook/rulebook_provider.dart';
import 'package:portail_met/rulebook/rules_repository.dart';
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

  @override
  Future<void> saveEdit(Character before, Character after, String reason, Actor by) async {
    calls.add('saveEdit:$reason');
    onSaveEdit?.call();
    if (error != null) throw error!;
  }

  @override
  Future<String> create({required String name, required CharacterKind kind, String? playerUid, String? playerName, required Actor by}) async {
    calls.add('create:${kind.name}:$name');
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
  Stream<List<PlaceEntry>> watchHistory(String id) => Stream.value(const []);

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
