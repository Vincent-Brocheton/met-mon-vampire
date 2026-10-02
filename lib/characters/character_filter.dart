import 'character.dart';

/// Filtres de la liste C2.
class CharacterFilter {
  const CharacterFilter({
    this.kinds = const {CharacterKind.pj, CharacterKind.pnj},
    this.statuses = defaultStatuses,
    this.sect,
    this.clan,
    this.query = '',
  });

  static const defaultStatuses = {CharacterStatus.draft, CharacterStatus.review, CharacterStatus.active};
  static const _keep = Object();

  final Set<CharacterKind> kinds;
  final Set<CharacterStatus> statuses;
  final String? sect;
  final String? clan;
  final String query;

  CharacterFilter copyWith({
    Set<CharacterKind>? kinds,
    Set<CharacterStatus>? statuses,
    Object? sect = _keep,
    Object? clan = _keep,
    String? query,
  }) =>
      CharacterFilter(
        kinds: kinds ?? this.kinds,
        statuses: statuses ?? this.statuses,
        sect: identical(sect, _keep) ? this.sect : sect as String?,
        clan: identical(clan, _keep) ? this.clan : clan as String?,
        query: query ?? this.query,
      );
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i',
  'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'ñ': 'n', 'œ': 'oe',
  'æ': 'ae',
};

/// Minuscules sans accents, pour la recherche.
String fold(String s) => s.toLowerCase().split('').map((ch) => _accents[ch] ?? ch).join();

List<Character> filterCharacters(List<Character> list, CharacterFilter f) {
  final q = fold(f.query.trim());
  return [
    for (final c in list)
      if (f.kinds.contains(c.kind) &&
          f.statuses.contains(c.status) &&
          (f.sect == null || c.sect == f.sect) &&
          (f.clan == null || c.clan == f.clan) &&
          (q.isEmpty || fold('${c.name} ${c.playerName ?? ''}').contains(q)))
        c,
  ];
}
