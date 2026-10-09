import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import '../games/game.dart';
import '../router.dart';
import 'device.dart';
import 'devices_repository.dart';
import 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';
import 'wipe.dart';

part 'device_session.g.dart';

Future<void> _keepPrepared(String uid, String deviceId) async {}

Future<WipePolicy> _weekPolicy() async => WipePolicy.week;

/// Déconnexion de cet appareil (« Se déconnecter », ou demandée depuis un autre appareil) :
/// document retiré, cache Firestore vidé, identifiant oublié, compte déconnecté, app relancée.
/// Effacement des données de l'appareil (sous-projet 8d) : partie préparée oubliée, cache vidé, app relancée, compte gardé.
class DeviceSession {
  DeviceSession({
    required this.removeDevice,
    required this.pendingWrites,
    required this.wipeCache,
    required this.forgetDevice,
    required this.signOutAccount,
    required this.restart,
    this.clearPrepared = _keepPrepared,
    this.policy = _weekPolicy,
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

  /// `gameId` et `preparedAt` à nul : la copie hors ligne n'est plus annoncée dans « Mon compte ».
  final Future<void> Function(String uid, String deviceId) clearPrepared;

  /// Politique d'effacement choisie sur cet appareil.
  final Future<WipePolicy> Function() policy;
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
        } catch (e) {
          debugPrint('Déconnexion : suppression du document de l’appareil échouée ($e)');
          // Le document reste : la ligne s'affiche « Déconnexion en attente » et reste listée.
        }
      }
      try {
        await wipeCache();
      } catch (e) {
        debugPrint('Déconnexion : effacement du cache Firestore échoué ($e)');
        // La déconnexion et le redémarrage doivent toujours avoir lieu.
      }
      await forgetDevice();
      await signOutAccount();
      await restart(revoked ? '/connexion?retire=1' : '/connexion');
    } finally {
      _busy = false;
    }
  }

  /// « Effacer maintenant », effacement programmé : le compte reste connecté.
  Future<void> wipe(String? uid, String? deviceId, String location) async {
    if (_busy) return;
    _busy = true;
    try {
      if (uid != null && deviceId != null) {
        try {
          await clearPrepared(uid, deviceId).timeout(removeTimeout);
        } catch (e) {
          // Le prochain démarrage en ligne refera l'effacement, puis oubliera la partie.
          debugPrint('Effacement : partie préparée non oubliée ($e)');
        }
      }
      try {
        await wipeCache();
      } catch (e) {
        debugPrint('Effacement : cache Firestore non vidé ($e)');
      }
      // L'instance arrêtée par `terminate` ne resservirait pas : on repart dans tous les cas.
      await restart(location);
    } finally {
      _busy = false;
    }
  }

  /// Effacement programmé : la partie préparée est finie depuis le délai choisi, et rien n'attend le réseau.
  Future<void> wipeIfDue(String? uid, Device? d, List<Game> games, DateTime now, String location) async {
    final gameId = d?.gameId;
    if (_busy || d == null || gameId == null) return;
    final g = games.where((g) => g.id == gameId).firstOrNull;
    if (!shouldWipe(await policy(), g, now)) return;
    if (await pendingWrites()) return;
    await wipe(uid, d.id, location);
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
    clearPrepared: devices.clearPrepared,
    policy: () async => (await OfflinePrefs.load()).policy,
  );
}
