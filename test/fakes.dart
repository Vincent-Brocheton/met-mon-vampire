import 'package:portail_met/auth/auth_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
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
  Future<void> decide(XpRequest r, Character c, RequestStatus to, String comment, Actor by) async {
    calls.add('decide:${to.name}:$comment');
    if (error != null) throw error!;
  }

  /// Noms refusés renvoyés par payGain et award.
  List<String> refused = const [];

  @override
  Future<void> saveSettings(XpSettings s, Actor by) async => calls.add(
      'settings:${s.monthlyEnabled}:${s.gainSince}:${[for (final t in s.tiers) '${t.months}/${t.xp}/${t.every}'].join(',')}');

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

  @override
  Stream<String> watchNote(String cat, String id) => Stream.value('');

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
  Future<void> saveSettings(String cat, Map<String, dynamic> values, Actor by) async => calls.add('settings:$cat');

  @override
  Future<void> importEntries(String cat, List<RuleEntry> entries, Actor by) async => calls.add('import:$cat:${entries.length}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
