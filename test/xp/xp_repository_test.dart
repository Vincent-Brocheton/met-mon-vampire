import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/xp/xp_repository.dart';
import 'package:portail_met/xp/xp_request.dart';

/// Les clés que la règle staffRequestDecision autorise (firestore.rules).
const allowed = {'status', 'thread', 'decidedAt', 'decidedByUid', 'updatedAt', 'version'};

void main() {
  final r = XpRequest(
    id: 'r1',
    characterId: 'x',
    characterName: 'Isaure',
    playerUid: 'u1',
    playerName: 'Camille R.',
    status: RequestStatus.pending,
    thread: [XpMessage('u1', 'Camille R.', DateTime.fromMillisecondsSinceEpoch(1), 'Voilà.')],
    version: 3,
  );
  final msg = XpMessage('lea', 'Léa G.', DateTime.fromMillisecondsSinceEpoch(2), 'Précise.');

  test('décision : seules les clés permises par les règles, fil allongé d’un message', () {
    for (final to in [RequestStatus.changes, RequestStatus.rejected, RequestStatus.accepted]) {
      final m = decisionUpdate(r, to, msg, 'lea', 'NOW');
      expect(allowed.containsAll(m.keys), isTrue, reason: to.name);
      expect((m['thread'] as List).length, 2);
      expect(m['version'], 4);
      expect(m['status'], to.name);
    }
    expect(decisionUpdate(r, RequestStatus.changes, msg, 'lea', 'NOW').containsKey('decidedAt'), isFalse);
    expect(decisionUpdate(r, RequestStatus.accepted, null, 'lea', 'NOW')['thread'], hasLength(1));
  });
}
