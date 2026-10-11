import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/wiki/word_diff.dart';

String show(List<DiffPart> parts) => [
      for (final p in parts)
        switch (p.kind) {
          DiffKind.same => p.text,
          DiffKind.added => '[+${p.text}]',
          DiffKind.removed => '[-${p.text}]',
        },
    ].join();

void main() {
  test('mots ajoutés et retirés, le reste inchangé, espaces et sauts de ligne compris', () {
    expect(show(wordDiff('Le chat dort.', 'Le chien dort.')), 'Le [-chat][+chien] dort.');
    expect(show(wordDiff('Un.\n\nDeux.', 'Un.\n\nDeux. Trois.')), 'Un.\n\nDeux.[+ Trois.]');
    expect(show(wordDiff('', 'Tout neuf')), '[+Tout neuf]');
    expect(show(wordDiff('Rien', '')), '[-Rien]');
    expect(wordDiff('', ''), isEmpty);
  });

  test('morceaux voisins de même nature fusionnés', () {
    final parts = wordDiff('a b c', 'x y z');
    expect([for (final p in parts) p.kind], [DiffKind.removed, DiffKind.added, DiffKind.same, DiffKind.removed, DiffKind.added, DiffKind.same, DiffKind.removed, DiffKind.added]);
    expect(show(wordDiff('a b', 'a b')), 'a b');
  });

  test('texte trop long : tout l’ancien retiré, tout le nouveau ajouté', () {
    final big = List.filled(2100, 'mot').join(' ');
    final parts = wordDiff(big, '$big fin');
    expect([for (final p in parts) p.kind], [DiffKind.removed, DiffKind.added]);
  });
}
