import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_providers.dart';

part 'offline.g.dart';

const offlineEditText = 'Pas de réseau : les modifications de la fiche attendent le réseau.';

/// Écriture de fiche tentée hors ligne par l'équipe (sous-projet 8d) : refusée tout de suite, rien ne part en file.
/// Sinon, elle pourrait être rejetée au retour du réseau si la fiche a changé entre-temps (version).
class OfflineError implements Exception {
  const OfflineError();

  @override
  String toString() => offlineEditText;
}

/// Texte d'un enregistrement refusé : celui du hors ligne, ou celui de l'écran.
String refusalText(Object e, String fallback) => e is OfflineError ? offlineEditText : fallback;

/// Vrai quand les parties viennent du cache de l'appareil : pas de réseau. Faux tant que rien n'est arrivé, et sans compte.
@Riverpod(keepAlive: true)
Stream<bool> offline(Ref ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  if (uid == null) return Stream.value(false);
  return ref.watch(firestoreProvider).collection('games').snapshots(includeMetadataChanges: true).map((q) => q.metadata.isFromCache);
}
