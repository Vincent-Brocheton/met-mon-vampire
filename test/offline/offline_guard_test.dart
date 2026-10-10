import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character_repository.dart';
import 'package:portail_met/games/games_repository.dart';
import 'package:portail_met/offline/offline.dart';

import '../characters/character_test.dart' show sample;
import '../games/game_rules_test.dart' show frozenGame;

/// Firestore absent : toute écriture qui passe la garde le touche et lève StateError.
class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Firestore touché');
}

void main() {
  const lea = Actor('lea', 'Léa G.');

  test('hors ligne : une modification de fiche par l’équipe est refusée sans rien écrire', () {
    final repo = CharacterRepository(_NoDb(), offline: () => true);
    expect(() => repo.setBonus(sample(), 2, lea), throwsA(isA<OfflineError>()));
    expect(() => repo.saveEdit(sample(), sample()..humanity = 4, 'Motif', lea), throwsA(isA<OfflineError>()));
  });

  test('hors ligne : le joueur sur sa propre fiche passe la garde (Review Focus 2)', () {
    final repo = CharacterRepository(_NoDb(), offline: () => true);
    // sample() appartient à u1 : la garde laisse passer, Firestore (absent ici) est touché.
    expect(() => repo.submit(sample(), const Actor('u1', 'Camille R.')), throwsStateError);
  });

  test('en ligne : la garde laisse passer', () {
    final repo = CharacterRepository(_NoDb(), offline: () => false);
    expect(() => repo.setBonus(sample(), 2, lea), throwsStateError);
    expect(() => CharacterRepository(_NoDb()).setBonus(sample(), 2, lea), throwsStateError);
  });

  test('gel : figer, lever, corriger refusés hors ligne', () {
    final repo = GamesRepository(_NoDb(), offline: () => true);
    final g = frozenGame();
    expect(() => repo.freeze(g.date, g.until, [sample()], lea), throwsA(isA<OfflineError>()));
    expect(() => repo.lift(g, lea), throwsA(isA<OfflineError>()));
    expect(() => repo.correct(g, sample(), 'Erreur', lea), throwsA(isA<OfflineError>()));
    expect(() => GamesRepository(_NoDb(), offline: () => false).lift(g, lea), throwsStateError);
  });

  test('texte du refus : celui du hors ligne, sinon celui de l’écran', () {
    expect(refusalText(const OfflineError(), 'Enregistrement refusé : réessayez.'), offlineEditText);
    expect(refusalText(Exception('refus'), 'Enregistrement refusé : réessayez.'), 'Enregistrement refusé : réessayez.');
    expect(const OfflineError().toString(), 'Pas de réseau : les modifications de la fiche attendent le réseau.');
  });
}
