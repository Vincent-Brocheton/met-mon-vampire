import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/allies/ally_file.dart';

void main() {
  test('aller-retour et résumé d’historique', () {
    final f = AllyFile(id: 'x-a1', name: 'Me Castan', characterId: 'x', characterName: 'Isaure', holderPlayers: ['u1'], version: 1);
    expect(AllyFile.fromMap('x-a1', f.toMap()).toMap(), f.toMap());
    final used = f.copy()
      ..usedAt = DateTime(2026, 9, 20)
      ..returnAt = DateTime(2027, 1, 20)
      ..lastUse = 'Classer une plainte.';
    expect(allyFileChanges(f, used), ['Utilisé le 20 sept. : Classer une plainte.', 'Retour le 20 janv. 2027']);
    final free = used.copy()
      ..usedAt = null
      ..returnAt = null;
    expect(allyFileChanges(used, free), ['Rendu disponible']);
  });
}
