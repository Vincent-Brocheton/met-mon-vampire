import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/auth_repository.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/auth/session_providers.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMeta implements SnapshotMetadata {
  _FakeMeta(this.isFromCache);
  @override
  final bool isFromCache;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ignore: subtype_of_sealed_class
class _FakeSnap implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeSnap({required this.exists, required bool fromCache}) : metadata = _FakeMeta(fromCache);
  @override
  final bool exists;
  @override
  final SnapshotMetadata metadata;
  @override
  String get id => 'u';
  @override
  Map<String, dynamic>? data() => exists ? {'displayName': 'Zoé', 'email': 'z@ex.fr', 'role': 'joueur'} : null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('C1 : profil pas encore reçu après la connexion → session en chargement', () async {
    final auth = StreamController<User?>();
    final profile = StreamController<AppUser?>();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => auth.stream),
      chronicleProvider.overrideWith((ref) => Stream.value(null)),
      currentUserProvider.overrideWith((ref) {
        final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
        return uid == null ? Stream.value(null) : profile.stream;
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionProvider, (_, _) {});

    auth.add(null);
    await pumpEventQueue();
    expect(container.read(sessionProvider).uid, isNull);

    auth.add(_FakeUser());
    await pumpEventQueue();
    expect(container.read(sessionProvider).loading, isTrue);

    profile.add(const AppUser(uid: 'u', displayName: 'Zoé', email: 'z@ex.fr', role: Role.joueur));
    await pumpEventQueue();
    expect(container.read(sessionProvider).role, Role.joueur);
  });

  test('I1 : document absent lu depuis le cache (hors ligne) → ignoré', () async {
    final out = await profileStream(Stream.fromIterable([
      _FakeSnap(exists: false, fromCache: true),
      _FakeSnap(exists: true, fromCache: false),
    ])).toList();
    expect(out.single?.role, Role.joueur);
  });

  test('I1 : document absent confirmé par le serveur → null', () async {
    final out = await profileStream(Stream.value(_FakeSnap(exists: false, fromCache: false))).toList();
    expect(out, [null]);
  });

  test('M6 : nom par défaut tronqué à 60 caractères', () {
    expect(defaultDisplayName(null, '${'a' * 64}@ex.fr').length, 60);
    expect(defaultDisplayName(' Zoé ', 'z@ex.fr'), 'Zoé');
  });
}
