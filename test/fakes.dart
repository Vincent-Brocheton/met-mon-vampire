import 'package:portail_met/auth/auth_repository.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart';

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

  @override
  Future<void> saveEdit(Character before, Character after, String reason, Actor by) async {
    calls.add('saveEdit:$reason');
    if (error != null) throw error!;
  }

  @override
  Future<String> create({required String name, required CharacterKind kind, String? playerUid, String? playerName, required Actor by}) async {
    calls.add('create:${kind.name}:$name');
    return 'new-id';
  }

  @override
  Future<void> saveNotes(String id, String text, Actor by) async => calls.add('notes:$text');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
