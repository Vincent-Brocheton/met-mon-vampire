import 'package:portail_met/auth/auth_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
