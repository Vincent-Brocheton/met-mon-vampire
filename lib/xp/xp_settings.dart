import 'package:cloud_firestore/cloud_firestore.dart';

/// Palier du gain mensuel : pendant [months] mois (null : sans limite), [xp] XP tous les [every] mois.
class XpTier {
  const XpTier(this.months, this.xp, this.every);

  factory XpTier.fromMap(Map<String, dynamic> m) =>
      XpTier((m['months'] as num?)?.toInt(), (m['xp'] as num?)?.toInt() ?? 0, (m['every'] as num?)?.toInt() ?? 1);

  final int? months;
  final int xp;
  final int every;

  Map<String, dynamic> toMap() => {'months': months, 'xp': xp, 'every': every};
}

/// Paliers de la maquette C-Parametres.
const defaultTiers = [XpTier(36, 3, 1), XpTier(36, 2, 1), XpTier(24, 1, 1), XpTier(null, 1, 2)];

/// `chronicle/xp`.
class XpSettings {
  const XpSettings({
    this.monthlyEnabled = false,
    this.gainSince,
    this.tiers = defaultTiers,
    this.updatedAt,
    this.updatedByName,
  });

  factory XpSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const XpSettings();
    final tiers = [for (final t in (m['tiers'] as List?) ?? const []) XpTier.fromMap(Map<String, dynamic>.from(t as Map))];
    return XpSettings(
      monthlyEnabled: m['monthlyEnabled'] == true,
      gainSince: m['gainSince'] as String?,
      tiers: tiers.isEmpty ? defaultTiers : tiers,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      updatedByName: m['updatedByName'] as String?,
    );
  }

  final bool monthlyEnabled;

  /// Premier mois versé ('aaaa-mm').
  final String? gainSince;
  final List<XpTier> tiers;
  final DateTime? updatedAt;
  final String? updatedByName;

  Map<String, dynamic> toMap() => {
        'monthlyEnabled': monthlyEnabled,
        'gainSince': gainSince,
        'tiers': [for (final t in tiers) t.toMap()],
      };
}
