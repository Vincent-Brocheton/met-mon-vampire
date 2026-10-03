import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum RuleState {
  available('Disponible'),
  approval('Accord du conte'),
  draft('Brouillon'),
  forbidden('Interdit');

  const RuleState(this.label);
  final String label;

  /// Proposé aux joueurs (le plan B lit cette propriété).
  bool get offered => this == available || this == approval;
}

/// Clé de comparaison des noms : sans casse ni espaces superflus (doublons, import).
String nameKey(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Élément du référentiel : `rules/{cat}/entries/{id}`.
class RuleEntry {
  RuleEntry({
    this.id = '',
    required this.name,
    this.vo,
    this.state = RuleState.available,
    this.source,
    this.description = '',
    Map<String, dynamic>? data,
    this.updatedAt,
    this.updatedByName,
  }) : data = data ?? {};

  factory RuleEntry.fromMap(String id, Map<String, dynamic> m) => RuleEntry(
        id: id,
        name: m['name'] as String? ?? '',
        vo: m['vo'] as String?,
        state: RuleState.values.asNameMap()[m['state']] ?? RuleState.available,
        source: m['source'] as String?,
        description: m['description'] as String? ?? '',
        data: m['data'] == null ? {} : Map<String, dynamic>.from(m['data'] as Map),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  String name;
  String? vo;
  RuleState state;
  String? source;
  String description;

  /// Champs propres à la catégorie (voir schema.dart) : valeurs JSON seulement.
  Map<String, dynamic> data;
  final DateTime? updatedAt;
  final String? updatedByName;

  Map<String, dynamic> toMap() => {
        'name': name,
        'vo': vo,
        'state': state.name,
        'source': source,
        'description': description,
        'data': data,
      };

  /// Copie profonde (le formulaire modifie la copie, pas l'élément affiché).
  RuleEntry copy() => RuleEntry(
        id: id,
        name: name,
        vo: vo,
        state: state,
        source: source,
        description: description,
        data: Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map),
        updatedAt: updatedAt,
        updatedByName: updatedByName,
      );
}
