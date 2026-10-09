import 'package:shared_preferences/shared_preferences.dart';

import '../games/game.dart';

/// Quand effacer les données de l'appareil après la partie préparée (sous-projet 8d).
enum WipePolicy {
  week('7 jours après la partie'),
  lift('Au dégel'),
  never('Jamais');

  const WipePolicy(this.label);
  final String label;

  static WipePolicy parse(String? s) => values.where((w) => w.name == s).firstOrNull ?? week;
}

/// Fin du gel : sa levée, ou la levée prévue une fois passée ; null tant qu'il court.
DateTime? gameEnd(Game g, DateTime now) => g.liftedAt ?? (now.isBefore(g.until) ? null : g.until);

/// L'effacement programmé est dû : partie connue, finie, délai de la politique passé.
bool shouldWipe(WipePolicy p, Game? g, DateTime now) {
  if (g == null || p == WipePolicy.never) return false;
  final end = gameEnd(g, now);
  if (end == null) return false;
  return p == WipePolicy.lift || !now.isBefore(end.add(const Duration(days: 7)));
}

const wipePolicyKey = 'wipePolicy';

/// Présent tant que le cache n'a pas pu être vidé : le prochain démarrage réessaie.
const wipePendingKey = 'wipePending';
const _rulebookKey = 'prepare.rulebook';
const _bondsKey = 'prepare.bonds';
const _notesKey = 'prepare.notes';

/// Réglages propres à cet appareil (`shared_preferences`) : ce que « Préparer la partie » lit, et la politique d'effacement.
class OfflinePrefs {
  const OfflinePrefs({this.rulebook = true, this.bonds = true, this.notes = false, this.policy = WipePolicy.week});

  final bool rulebook;

  /// Liens de sang et événements, y compris les secrets.
  final bool bonds;

  /// Notes du conte (`private/notes`).
  final bool notes;
  final WipePolicy policy;

  OfflinePrefs copyWith({bool? rulebook, bool? bonds, bool? notes, WipePolicy? policy}) => OfflinePrefs(
        rulebook: rulebook ?? this.rulebook,
        bonds: bonds ?? this.bonds,
        notes: notes ?? this.notes,
        policy: policy ?? this.policy,
      );

  static Future<OfflinePrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return OfflinePrefs(
      rulebook: p.getBool(_rulebookKey) ?? true,
      bonds: p.getBool(_bondsKey) ?? true,
      notes: p.getBool(_notesKey) ?? false,
      policy: WipePolicy.parse(p.getString(wipePolicyKey)),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_rulebookKey, rulebook);
    await p.setBool(_bondsKey, bonds);
    await p.setBool(_notesKey, notes);
    await p.setString(wipePolicyKey, policy.name);
  }
}
