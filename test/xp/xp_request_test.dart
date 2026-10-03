import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/xp/xp_request.dart';

void main() {
  test('nowMs : sans microsecondes (le Web relit à la milliseconde)', () {
    expect(nowMs().microsecond, 0);
  });

  test('aller-retour toMap / fromMap', () {
    final r = XpRequest(
      id: 'r1',
      characterId: 'x',
      characterName: 'Isaure de Valcourt',
      playerUid: 'u1',
      playerName: 'Camille R.',
      status: RequestStatus.changes,
      items: [const XpItem(XpKind.skill, 'Linguistique', 0, 1, 2, note: 'italien')],
      justification: 'Leçons.',
      thread: [XpMessage('lea', 'Léa G.', DateTime.fromMillisecondsSinceEpoch(1000), 'Précise.')],
    );
    final back = XpRequest.fromMap('r1', r.toMap());
    expect(back.toMap(), r.toMap());
    expect(back.thread.single.at.millisecondsSinceEpoch, 1000);
    expect(back.items.single.note, 'italien');
  });

  test('statuts : ouverts et modifiables', () {
    expect([for (final s in RequestStatus.values) if (s.open) s], [RequestStatus.pending, RequestStatus.changes]);
    expect(RequestStatus.draft.editable, isTrue);
    expect(RequestStatus.accepted.editable, isFalse);
  });

  test('résumé : niveau final de chaque trait', () {
    final r = XpRequest(characterId: 'x', characterName: 'I', playerUid: 'u1', playerName: 'C', items: [
      const XpItem(XpKind.skill, 'Linguistique', 0, 1, 2),
      const XpItem(XpKind.skill, 'Linguistique', 1, 2, 4),
      const XpItem(XpKind.attribute, 'mental', 0, 1, 3),
    ]);
    expect(r.summary, 'Linguistique ●●, Mental 1 · 9 XP');
  });
}
