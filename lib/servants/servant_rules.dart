import 'dart:math';

import '../characters/character.dart';
import '../core/dates.dart';
import '../rulebook/rulebook.dart';
import 'servant_file.dart';

/// Réserve de test d'un serviteur.
int pool(int rank) => 2 * rank;

/// Un mois après la dernière gorgée.
DateTime dueDate(DateTime lastDrink) => DateTime(lastDrink.year, lastDrink.month + 1, lastDrink.day);

enum DueState { ok, soon, late }

/// État de l'échéance : « proche » dans les 7 jours qui la précèdent ; null sans gorgée notée.
DueState? dueState(DateTime? lastDrink, DateTime now) {
  if (lastDrink == null) return null;
  final due = dueDate(lastDrink);
  if (now.isAfter(due)) return DueState.late;
  if (now.isAfter(DateTime(due.year, due.month, due.day - 7))) return DueState.soon;
  return DueState.ok;
}

/// Points indisponibles pour le domitor : deux semaines par point du serviteur libéré (Base p. 104 : une partie ou
/// deux semaines par point, le plus long ; seules les dates sont suivies). Jours de calendrier : pas de décalage d'heure.
DateTime unavailableUntil(DateTime releasedAt, int rank) =>
    DateTime(releasedAt.year, releasedAt.month, releasedAt.day + 14 * max(rank, 1), releasedAt.hour, releasedAt.minute);

int animalPoints(List<String> qualities, Rulebook rb) => qualities.fold(0, (s, q) => s + (rb.cost('animalQualities', q) ?? 0));

/// Compétences proposées, plus les disciplines du clan du domitor.
List<String> specialtyOptions(Character? domitor, Rulebook rb) => {...rb.offeredNames('skills'), ...rb.clanDisciplines(domitor?.clan)}.toList();

/// Avertissements (le conte peut quand même enregistrer). [entry] : le serviteur sur la fiche du domitor.
List<String> servantWarnings(ServantFile f, Rulebook rb, {Servant? entry, Character? domitor, required DateTime now}) {
  final out = <String>[];
  final rank = entry?.rank ?? 0;
  if (!f.isMortal && f.specialties.length > rank) out.add('${f.specialties.length} spécialités sur $rank');
  final clan = rb.clanDisciplines(domitor?.clan);
  for (final s in f.specialties) {
    if (domitor != null && rb.find('disciplines', s) != null && !clan.contains(s)) out.add('$s : discipline hors du clan du domitor');
  }
  // Base p. 105 : une seule des spécialités d'un serviteur peut être une discipline.
  if (f.kind == 'human' && f.specialties.where((s) => rb.find('disciplines', s) != null).length > 1) {
    out.add('Une seule spécialité de discipline pour un serviteur');
  }
  if (f.kind == 'animal') {
    final points = animalPoints(f.qualities, rb);
    if (points > rank) out.add('Qualités animales : $points points sur $rank');
    for (final q in f.qualities) {
      final e = rb.find('animalQualities', q);
      if (e == null) {
        out.add('$q : hors du référentiel');
        continue;
      }
      final requires = (e.data['requires'] as String? ?? '').trim();
      if (requires.isNotEmpty && !f.qualities.contains(requires)) out.add('$q demande $requires');
      if (!e.state.offered) out.add('$q est interdite dans la chronique');
    }
  }
  if (dueState(f.lastDrink, now) == DueState.late) out.add('Plus de vitae depuis le ${formatDay(f.lastDrink)} : son âge le rattrape');
  if (domitor != null) {
    if (domitor.status == CharacterStatus.retired || domitor.status == CharacterStatus.dead) out.add('Le domitor est une fiche retirée ou morte');
    if (f.version > 0 && domitor.playerUid != null && !f.holderPlayers.contains(domitor.playerUid)) {
      out.add('Le joueur du domitor a changé : enregistrez pour mettre à jour l’accès');
    }
  }
  return out;
}

/// Une ligne par changement, pour l'historique du serviteur.
List<String> servantChanges(ServantFile a, ServantFile b) {
  final out = <String>[];
  if (a.name != b.name) out.add('Nom : ${a.name} → ${b.name}');
  if (a.attachment != b.attachment) out.add('Rattachement : ${a.attachment} → ${b.attachment}');
  for (final s in b.specialties) {
    if (!a.specialties.contains(s)) out.add('+ Spécialité $s');
  }
  for (final s in a.specialties) {
    if (!b.specialties.contains(s)) out.add('− Spécialité $s');
  }
  for (final q in b.qualities) {
    if (!a.qualities.contains(q)) out.add('+ Qualité $q');
  }
  for (final q in a.qualities) {
    if (!b.qualities.contains(q)) out.add('− Qualité $q');
  }
  if (a.vitae != b.vitae) out.add('Vitae ${a.vitae} → ${b.vitae}');
  if (a.bond != b.bond) out.add('Lien ${a.bond} → ${b.bond}');
  if (a.lastDrink != b.lastDrink && b.lastDrink != null) out.add('Gorgée du ${formatDay(b.lastDrink)}');
  if (a.description != b.description) out.add('Description modifiée');
  if (a.releasedAt == null && b.releasedAt != null) out.add('Libéré de la fiche du domitor');
  return out;
}

/// Ligne de « Goules et mortels » : serviteur d'une fiche (avec ou sans fiche détaillée), fiche libérée ou mortel.
class ServantRow {
  const ServantRow({this.entry, this.domitor, this.file});
  final Servant? entry;
  final Character? domitor;
  final ServantFile? file;

  String get id => entry?.id ?? file?.id ?? '';
  String get name => entry?.name ?? file?.name ?? '';
  String get kind => entry?.kind.name ?? file?.kind ?? 'mortal';
  String get typeLabel => servantKindLabel(kind);
  int get rank => entry?.rank ?? 0;

  /// Nouveau mortel, pas encore enregistré.
  bool get isNew => entry == null && file == null;

  /// Acheté, pas encore détaillé par le conte.
  bool get toComplete => entry != null && file == null;

  /// Fiche détaillée d'un serviteur qui n'est plus sur la fiche de son domitor.
  bool get released => entry == null && file != null && !file!.isMortal;

  /// Domitor, ou rattachement d'un mortel.
  String get owner => domitor?.name ?? file?.domitorName ?? file?.attachment ?? '';
}

List<ServantRow> servantRows(List<Character> characters, List<ServantFile> files) {
  final byId = {for (final f in files) f.id: f};
  final listed = <String>{};
  final rows = <ServantRow>[];
  for (final c in characters) {
    for (final s in c.servants) {
      listed.add(s.id);
      rows.add(ServantRow(entry: s, domitor: c, file: byId[s.id]));
    }
  }
  final rest = [for (final f in files) if (!listed.contains(f.id)) f]..sort((a, b) => (a.isMortal ? 0 : 1).compareTo(b.isMortal ? 0 : 1));
  for (final f in rest) {
    rows.add(ServantRow(domitor: characters.where((c) => c.id == f.domitorId).firstOrNull, file: f));
  }
  return rows;
}
