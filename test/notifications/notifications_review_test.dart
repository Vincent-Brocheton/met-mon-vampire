import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/notifications/notifications_repository.dart';
import 'package:portail_met/offline/offline.dart';

class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Firestore touché');
}

void main() {
  test('revue : « Tout marquer comme lu » hors ligne refusé sans rien mettre en file', () {
    expect(() => NotificationsRepository(_NoDb(), offline: () => true).markAllRead('zoe'), throwsA(isA<OfflineError>()));
    expect(() => NotificationsRepository(_NoDb(), offline: () => false).markAllRead('zoe'), throwsStateError);
  });

  test('revue : heure du serveur en attente : estimée, pas absente (sinon tout redevient non lu)', () {
    final m = {'displayName': 'Zoé', 'role': 'joueur', 'notifSeenAt': null};
    final before = DateTime.now();
    expect(AppUser.fromMap('zoe', m, pending: true).notifSeenAt!.isBefore(before), isFalse);
    expect(AppUser.fromMap('zoe', m).notifSeenAt, isNull);
  });
}
