import 'package:cloud_firestore/cloud_firestore.dart';

import '../characters/character.dart';
import '../core/dates.dart';
import '../games/game.dart';
import '../games/game_rules.dart' show hourText;
import '../print/print_sheet.dart' show healthGroups;

/// Longueur maximale d'une note de partie, et nombre de notes gardées (règles Firestore : 100 au plus).
const noteMaxLength = 500;
const notesMax = 100;

const offlineText = 'Pas de réseau. Tout ce que vous cochez reste sur cet appareil et part au conte dès que le réseau revient.';
const webTabText = 'Gardez cet onglet ouvert pendant la partie : sans réseau, il ne se rechargera pas.';
const notPreparedText = 'Cette fiche n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau avant la partie.';
const refusedText = 'Une saisie a été refusée : vérifiez votre suivi.';
const notFrozenText = 'Cette fiche n’est pas figée pour une partie en cours';
const beastNote = 'Les traits de Bête sont saisis par le conte. Vous les voyez quand son appareil et le vôtre se sont synchronisés.';

/// Note de partie ; l'heure est celle de l'appareil, la note pouvant être prise sans réseau.
class NightNote {
  const NightNote(this.text, this.at);

  factory NightNote.fromMap(Map<dynamic, dynamic> m) =>
      NightNote(m['text'] as String? ?? '', (m['at'] as Timestamp?)?.toDate() ?? DateTime(2000));

  final String text;
  final DateTime at;

  Map<String, dynamic> toMap() => {'text': text, 'at': Timestamp.fromDate(at)};
}

/// Suivi de la soirée (`characters/{id}/night/{gameId}`) : ce que le joueur a dépensé et noté pendant la partie.
/// Il ne modifie jamais la fiche.
class Night {
  const Night({this.blood = 0, this.willpower = 0, this.health = const [0, 0, 0], this.notes = const [], this.at});

  factory Night.fromMap(Map<String, dynamic> m) {
    final h = [for (final v in (m['health'] as List?) ?? const []) (v as num).toInt()];
    return Night(
      blood: (m['blood'] as num?)?.toInt() ?? 0,
      willpower: (m['willpower'] as num?)?.toInt() ?? 0,
      health: [for (var i = 0; i < 3; i++) i < h.length ? h[i] : 0],
      notes: [for (final n in (m['notes'] as List?) ?? const []) NightNote.fromMap(n as Map)],
      at: (m['at'] as Timestamp?)?.toDate(),
    );
  }

  /// Points dépensés.
  final int blood;
  final int willpower;

  /// Cases cochées : Sain, Blessé, Incapacité.
  final List<int> health;

  /// De la plus ancienne à la plus récente.
  final List<NightNote> notes;

  /// Heure du serveur à la dernière écriture.
  final DateTime? at;

  Night copy({int? blood, int? willpower, List<int>? health, List<NightNote>? notes}) => Night(
        blood: blood ?? this.blood,
        willpower: willpower ?? this.willpower,
        health: health ?? this.health,
        notes: notes ?? this.notes,
        at: at,
      );

  /// Sans `byUid` ni `at`, ajoutés par le dépôt.
  Map<String, dynamic> toMap() => {
        'blood': blood,
        'willpower': willpower,
        'health': [...health],
        'notes': [for (final n in notes) n.toMap()],
      };
}

/// Ligne de cases du suivi ; les trois dernières sont les groupes de santé.
enum NightTrack { blood, willpower, healthy, hurt, incapacitated }

/// Nombre de cases de chaque ligne, d'après la version figée.
class NightLimits {
  const NightLimits({required this.blood, required this.willpower, required this.health, this.vitae = false});

  /// Une goule a 5 de Vitae ; la santé « 3 · 3 · 3 » se lit comme à l'impression.
  factory NightLimits.of(Character c) => NightLimits(
        blood: c.ghoul != null ? 5 : c.blood,
        willpower: c.willpower,
        health: [for (final (_, n) in healthGroups(c.health)) n],
        vitae: c.ghoul != null,
      );

  final int blood;
  final int willpower;
  final List<int> health;
  final bool vitae;

  int of(NightTrack t) => switch (t) {
        NightTrack.blood => blood,
        NightTrack.willpower => willpower,
        _ => health[t.index - 2],
      };
}

int nightValue(Night n, NightTrack t) => switch (t) {
      NightTrack.blood => n.blood,
      NightTrack.willpower => n.willpower,
      _ => n.health[t.index - 2],
    };

Night _set(Night n, NightTrack t, int v) => switch (t) {
      NightTrack.blood => n.copy(blood: v),
      NightTrack.willpower => n.copy(willpower: v),
      _ => n.copy(health: [for (var i = 0; i < 3; i++) i == t.index - 2 ? v : n.health[i]]),
    };

/// Chaque ligne ramenée entre 0 et son maximum (version figée corrigée pendant la partie).
Night clampTo(Night n, NightLimits l) => NightTrack.values.fold<Night>(n, (acc, t) => _set(acc, t, nightValue(acc, t).clamp(0, l.of(t))));

/// Cliquer la case [index] (à partir de 1) coche jusqu'à elle ; cliquer la dernière case cochée la décoche.
Night toggle(Night n, NightTrack t, int index, NightLimits l) {
  final base = clampTo(n, l);
  final current = nightValue(base, t);
  return _set(base, t, (index == current ? index - 1 : index).clamp(0, l.of(t)));
}

/// « Annuler le dernier coup » : les cases reviennent à [previous], les notes de [current] restent.
Night undoTo(Night current, Night previous) =>
    current.copy(blood: previous.blood, willpower: previous.willpower, health: previous.health);

/// Ajoute une note ; null si elle est vide. Coupée à 500 caractères ; au-delà de 100 notes, la plus ancienne part.
Night? addNote(Night n, String text, DateTime at) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final notes = [...n.notes, NightNote(t.length > noteMaxLength ? t.substring(0, noteMaxLength) : t, at)];
  return n.copy(notes: notes.length > notesMax ? notes.sublist(notes.length - notesMax) : notes);
}

/// « 3 / 12 · reste 9 ».
String spentText(int spent, int max) => '$spent / $max · reste ${max - spent}';

/// « Sang 3 / 12 · Volonté 1 / 6 · Santé 2 · 0 · 0 » (écran du gel).
String nightSummary(Night n, NightLimits l) =>
    '${l.vitae ? 'Vitae' : 'Sang'} ${n.blood} / ${l.blood} · Volonté ${n.willpower} / ${l.willpower} · Santé ${n.health.join(' · ')}';

/// « Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h ».
String versionLine(Game g, DateTime? preparedAt) => 'Version figée du ${formatDay(g.frozenAt)}'
    '${preparedAt == null ? '' : ' · préparée sur cet appareil le ${formatDay(preparedAt)} à ${hourText(preparedAt)}'}';

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String sentText(bool pending) => pending ? 'Des saisies attendent le réseau.' : 'Tout est envoyé.';

/// « 22h15 · Inès Morel, galeriste ».
String noteLine(NightNote n) => '${hourText(n.at)} · ${n.text}';
