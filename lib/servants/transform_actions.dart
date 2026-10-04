import '../auth/session.dart';
import '../characters/character.dart';
import '../characters/character_repository.dart';
import '../characters/transformations.dart';
import '../rulebook/rulebook.dart';
import 'servant_file.dart';
import 'servant_rules.dart';
import 'servants_repository.dart';

/// Mortel devenu serviteur : le domitor paie le rang (écriture tracée « xp »), puis la fiche du mortel devient
/// la fiche détaillée du serviteur (même identifiant). Renvoie un message si la seconde écriture échoue.
Future<String?> mortalToServant(
  CharacterRepository chars,
  ServantsRepository servants, {
  required ServantFile mortal,
  required Character domitor,
  required ServantKind kind,
  required int rank,
  required String reason,
  required Actor by,
  Rulebook rb = const Rulebook(),
}) async {
  // Reprise après un échec : le domitor a déjà ce serviteur, seule la fiche reste à convertir.
  if (!domitor.servants.any((s) => s.id == mortal.id)) {
    await chars.saveEdit(domitor, withServant(domitor, mortal.id, mortal.name, kind, rank, rb: rb), reason, by, kind: 'xp');
  }
  try {
    await servants.save(
      mortal,
      mortal.copy()
        ..kind = kind.name
        ..domitorId = domitor.id
        ..domitorName = domitor.name
        ..holderPlayers = [?domitor.playerUid],
      by,
      reason: reason,
    );
  } catch (_) {
    return '${mortal.name} est ajouté aux serviteurs de ${domitor.name}, mais sa fiche n’a pas été convertie : relancez « Devenir serviteur de… ».';
  }
  return null;
}

/// Mortel ou serviteur étreint : nouvelle fiche, puis fiche d'origine (mortel supprimé ; serviteur retiré de son
/// domitor et fiche détaillée libérée). Renvoie un message si la suite échoue.
Future<String?> embraceFollower(
  CharacterRepository chars,
  ServantsRepository servants, {
  required ServantRow row,
  required Character sheet,
  required String reason,
  required Actor by,
}) async {
  final owner = row.domitor;
  // Le conte ne peut modifier qu'une fiche jouée ou close : refus avant toute écriture.
  if (row.entry != null && owner != null && owner.kind == CharacterKind.pj && !owner.status.settled) {
    return 'Le domitor ${owner.name} a une fiche en création : étreignez ${row.name} après sa validation.';
  }
  // Même identifiant que la fiche d'origine : une relance ne crée pas de seconde fiche.
  await chars.createSheet(sheet, by, 'Fiche créée par l’étreinte de ${row.name}', id: row.id);
  try {
    final d = row.domitor;
    if (row.entry != null && d != null) {
      await chars.saveEdit(d, d.clone()..servants.removeWhere((s) => s.id == row.id), reason, by);
      if (row.file != null) await servants.release(row.id, by);
    } else if (row.file != null) {
      await servants.delete(row.file!.id);
    }
  } catch (_) {
    return 'Fiche de ${row.name} créée, mais l’ancienne fiche n’a pas été mise à jour : retirez-la à la main.';
  }
  return null;
}

/// Mortel devenu goule jouée : amorce de goule pour le joueur, puis suppression de la fiche du mortel.
Future<String?> mortalToGhoul(
  CharacterRepository chars,
  ServantsRepository servants, {
  required ServantFile mortal,
  required AppUser player,
  required Character domitor,
  required Actor by,
}) async {
  await chars.create(
    name: mortal.name,
    kind: CharacterKind.pj,
    playerUid: player.uid,
    playerName: player.displayName,
    ghoul: GhoulState.of(domitor),
    by: by,
  );
  try {
    await servants.delete(mortal.id);
  } catch (_) {
    return 'Fiche de goule créée, mais celle du mortel reste : supprimez-la.';
  }
  return null;
}
