import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';
import '../characters/character_repository.dart' show Actor;
import '../morality/sin.dart' show dayOf;

/// Identifiant du document d'un lien : `<régnant>_<lié>`.
String bondId(String regnantId, String thrallId) => '${regnantId}_$thrallId';

/// Lien de sang entre deux fiches (`bonds/{regnantId}_{thrallId}`, sous-projet 7c).
/// Le régnant donne son sang ; le lié boit. Noms et joueurs recopiés : un joueur ne lit pas la fiche de l'autre.
class Bond {
  Bond({
    required this.regnantId,
    this.regnantName = '',
    this.regnantPlayerUid,
    required this.thrallId,
    this.thrallName = '',
    this.thrallPlayerUid,
    this.ghoul = false,
    this.level = 0,
    required this.lastDrink,
    required this.lastContact,
    this.known = true,
    this.regnantKnows = true,
    this.byName = '',
    this.stored = false,
  });

  factory Bond.fromMap(Map<String, dynamic> m) => Bond(
        regnantId: m['regnantId'] as String? ?? '',
        regnantName: m['regnantName'] as String? ?? '',
        regnantPlayerUid: m['regnantPlayerUid'] as String?,
        thrallId: m['thrallId'] as String? ?? '',
        thrallName: m['thrallName'] as String? ?? '',
        thrallPlayerUid: m['thrallPlayerUid'] as String?,
        ghoul: m['ghoul'] == true,
        level: (m['level'] as num?)?.toInt() ?? 0,
        lastDrink: (m['lastDrink'] as Timestamp?)?.toDate() ?? DateTime(1900),
        lastContact: (m['lastContact'] as Timestamp?)?.toDate() ?? DateTime(1900),
        known: m['known'] != false,
        regnantKnows: m['regnantKnows'] != false,
        byName: m['byName'] as String? ?? '',
        stored: true,
      );

  final String regnantId;
  String regnantName;
  String? regnantPlayerUid;
  final String thrallId;
  String thrallName;
  String? thrallPlayerUid;

  /// Le lié est la goule du régnant (« votre goule » pour le joueur).
  bool ghoul;

  /// Niveau enregistré, de 0 à 3 ; le niveau du jour se calcule (`effectiveLevel`).
  int level;
  DateTime lastDrink;
  DateTime lastContact;

  /// Le lié sait de qui vient le sang.
  bool known;

  /// Le régnant connaît le lien envers lui.
  bool regnantKnows;
  String byName;

  /// Vrai si le document existe déjà (lu de Firestore).
  bool stored;

  String get id => bondId(regnantId, thrallId);

  Map<String, dynamic> toMap() => {
        'regnantId': regnantId,
        'regnantName': regnantName,
        'regnantPlayerUid': regnantPlayerUid,
        'thrallId': thrallId,
        'thrallName': thrallName,
        'thrallPlayerUid': thrallPlayerUid,
        'ghoul': ghoul,
        'level': level,
        'lastDrink': Timestamp.fromDate(dayOf(lastDrink)),
        'lastContact': Timestamp.fromDate(dayOf(lastContact)),
        'known': known,
        'regnantKnows': regnantKnows,
      };

  Bond copy() => Bond(
        regnantId: regnantId,
        regnantName: regnantName,
        regnantPlayerUid: regnantPlayerUid,
        thrallId: thrallId,
        thrallName: thrallName,
        thrallPlayerUid: thrallPlayerUid,
        ghoul: ghoul,
        level: level,
        lastDrink: lastDrink,
        lastContact: lastContact,
        known: known,
        regnantKnows: regnantKnows,
        byName: byName,
        stored: stored,
      );
}

/// Nouveau lien entre deux fiches, daté de [day] ; niveau 0 tant qu'aucune gorgée n'est appliquée.
Bond bondBetween(Character regnant, Character thrall, DateTime day) => Bond(
      regnantId: regnant.id,
      regnantName: regnant.name,
      regnantPlayerUid: regnant.playerUid,
      thrallId: thrall.id,
      thrallName: thrall.name,
      thrallPlayerUid: thrall.playerUid,
      ghoul: thrall.ghoul?.domitorId == regnant.id,
      lastDrink: dayOf(day),
      lastContact: dayOf(day),
    );

/// Le lien avec les noms et joueurs actuels des deux fiches (rafraîchis à chaque écriture).
Bond refreshed(Bond b, Character regnant, Character thrall) => b.copy()
  ..regnantName = regnant.name
  ..regnantPlayerUid = regnant.playerUid
  ..thrallName = thrall.name
  ..thrallPlayerUid = thrall.playerUid
  ..ghoul = thrall.ghoul?.domitorId == regnant.id;

/// Document écrit (fusionné) : exactement les clés permises par les règles ; `createdAt` à la création seulement.
Map<String, dynamic> bondData(Bond b, Actor by) {
  final now = FieldValue.serverTimestamp();
  return {...b.toMap(), 'byUid': by.uid, 'byName': by.name, 'updatedAt': now, if (!b.stored) 'createdAt': now};
}
