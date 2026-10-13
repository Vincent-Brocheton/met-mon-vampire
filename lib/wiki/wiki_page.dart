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
    this.updatedByUid,
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
        updatedByUid: m['updatedByUid'] as String?,
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
  final String? updatedByUid;

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

/// Copie d'une publication (`wiki/{id}/versions/{n}`).
class WikiVersion {
  WikiVersion({required this.n, required this.page, this.note = '', this.byName = '', this.at});

  factory WikiVersion.fromMap(String pageId, String id, Map<String, dynamic> m) => WikiVersion(
        n: int.tryParse(id) ?? 0,
        page: WikiPage.fromMap(pageId, m),
        note: m['note'] as String? ?? '',
        byName: m['byName'] as String? ?? '',
        at: (m['at'] as Timestamp?)?.toDate(),
      );

  final int n;

  /// Contenu publié (sa `version` n'a pas de sens ici : voir [n]).
  final WikiPage page;
  final String note;
  final String byName;
  final DateTime? at;
}

/// Contenu de la version [v], à republier par-dessus la version publiée [current].
WikiPage restoredPage(WikiVersion v, int current) => WikiPage(
      id: v.page.id,
      title: v.page.title,
      rubric: v.page.rubric,
      audience: v.page.audience,
      body: v.page.body,
      source: v.page.source,
      cat: v.page.cat,
      entryId: v.page.entryId,
      version: current,
    );
