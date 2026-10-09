import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      Device.fromMap(d.id, d.data()!);

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
    if (!touched) {
      // Décidé une seule fois, sur le premier instantané : un document marqué puis retiré ne doit pas être recréé.
      touched = true;
      if (d?.revokedAt == null) repo.touch(uid, deviceId, name: deviceName(web: kIsWeb, platform: defaultTargetPlatform), web: kIsWeb).catchError((Object _) {});
    }
    yield d;
  }
}
