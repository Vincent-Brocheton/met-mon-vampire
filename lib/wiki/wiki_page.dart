import 'package:cloud_firestore/cloud_firestore.dart';

/// Page du wiki : version publiée (`wiki/{id}`) ou brouillon (`wikiDrafts/{id}`).
/// Pour un brouillon, [version] est la version publiée sur laquelle il part (`baseVersion`).
class WikiPage {
  WikiPage({
    required this.id,
    this.title = '',
    this.rubric = '',
    this.audience = 'all',
    this.body = '',
    this.source = '',
    this.cat,
    this.entryId,
    this.version = 0,
    this.updatedAt,
    this.updatedByName,
  });

  factory WikiPage.fromMap(String id, Map<String, dynamic> m) => WikiPage(
        id: id,
        title: m['title'] as String? ?? '',
        rubric: m['rubric'] as String? ?? '',
        audience: m['audience'] as String? ?? 'all',
        body: m['body'] as String? ?? '',
        source: m['source'] as String? ?? '',
        cat: m['cat'] as String?,
        entryId: m['entryId'] as String?,
        version: ((m['version'] ?? m['baseVersion']) as num?)?.toInt() ?? 0,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        updatedByName: m['updatedByName'] as String?,
      );

  final String id;
  final String title;
  final String rubric;
  final String audience;
  final String body;
  final String source;

  /// Page de règle : catégorie et clé de l'entrée du référentiel.
  final String? cat;
  final String? entryId;
  final int version;
  final DateTime? updatedAt;
  final String? updatedByName;

  /// Contenu commun à la page publiée, au brouillon et aux versions.
  Map<String, dynamic> contentMap() => {
        'title': title.trim(),
        'rubric': rubric,
        'audience': audience,
        'body': body,
        'source': source.trim(),
        if (cat != null) 'cat': cat,
        if (entryId != null) 'entryId': entryId,
      };
}
