import 'dart:math';

enum DiffKind { same, added, removed }

typedef DiffPart = ({DiffKind kind, String text});

final _token = RegExp(r'\s+|\S+');

/// Différences mot à mot entre deux textes (plus longue sous-suite commune), espaces et sauts de ligne compris.
/// Les morceaux voisins de même nature sont fusionnés.
// ponytail: tableau n × m ; au-delà de 4 millions de cases, tout l'ancien texte est retiré et le nouveau ajouté.
List<DiffPart> wordDiff(String before, String after) {
  final a = [for (final m in _token.allMatches(before)) m[0]!];
  final b = [for (final m in _token.allMatches(after)) m[0]!];
  final out = <DiffPart>[];
  void add(DiffKind kind, String text) {
    if (out.isNotEmpty && out.last.kind == kind) {
      out[out.length - 1] = (kind: kind, text: out.last.text + text);
    } else {
      out.add((kind: kind, text: text));
    }
  }

  if (a.length * b.length > 4000000) {
    if (before.isNotEmpty) add(DiffKind.removed, before);
    if (after.isNotEmpty) add(DiffKind.added, after);
    return out;
  }
  // lcs[i][j] : longueur de la plus longue sous-suite commune de a[i..] et b[j..].
  final lcs = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      add(DiffKind.same, a[i]);
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      add(DiffKind.removed, a[i++]);
    } else {
      add(DiffKind.added, b[j++]);
    }
  }
  while (i < a.length) {
    add(DiffKind.removed, a[i++]);
  }
  while (j < b.length) {
    add(DiffKind.added, b[j++]);
  }
  return out;
}
