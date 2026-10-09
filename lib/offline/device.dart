import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import '../core/dates.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show isRunning;

const revokedNotice = 'Cet appareil a été déconnecté depuis un autre appareil.';
const pendingLossText = 'Des saisies n’ont pas encore été envoyées : elles seront perdues.';

DateTime? _date(Object? v) => (v as Timestamp?)?.toDate();

/// Un appareil où le compte est connecté (`users/{uid}/devices/{id}`).
class Device {
  const Device({required this.id, required this.name, this.web = false, this.lastSeen, this.gameId, this.preparedAt, this.revokedAt});

  factory Device.fromMap(String id, Map<String, dynamic> m) => Device(
        id: id,
        name: m['name'] as String? ?? '',
        web: m['web'] == true,
        lastSeen: _date(m['lastSeen']),
        gameId: m['gameId'] as String?,
        preparedAt: _date(m['preparedAt']),
        revokedAt: _date(m['revokedAt']),
      );

  final String id;
  final String name;
  final bool web;

  /// Dernier démarrage de l'app connectée.
  final DateTime? lastSeen;

  /// Partie préparée sur l'appareil (écran « En partie » ouvert avec du réseau).
  final String? gameId;
  final DateTime? preparedAt;

  /// Déconnexion demandée depuis un autre appareil.
  final DateTime? revokedAt;
}

/// « Navigateur · Windows », « Android »…
String deviceName({required bool web, required TargetPlatform platform}) {
  final os = switch (platform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  return web ? 'Navigateur · $os' : os;
}

/// Copie hors ligne d'une partie dont le gel court encore, sinon le type de connexion.
String deviceKindText(Device d, List<Game> games, DateTime now) {
  final g = games.where((g) => g.id == d.gameId).firstOrNull;
  if (g != null && isRunning(g, now)) return 'Copie hors ligne · partie du ${formatDay(g.date)}';
  return d.web ? 'Connexion web' : 'Application Android';
}

/// « aujourd’hui », « hier », « 29 sept. ».
String lastSeenText(DateTime? d, DateTime now) {
  if (d == null) return '—';
  final day = DateTime(d.year, d.month, d.day);
  if (day == DateTime(now.year, now.month, now.day)) return 'aujourd’hui';
  if (day == DateTime(now.year, now.month, now.day - 1)) return 'hier';
  return formatDay(d);
}

/// Seconde ligne d'un appareil dans « Mon compte ».
String deviceLine(Device d, List<Game> games, DateTime now) =>
    d.revokedAt != null ? 'Déconnexion en attente' : '${deviceKindText(d, games, now)} · ${lastSeenText(d.lastSeen, now)}';
