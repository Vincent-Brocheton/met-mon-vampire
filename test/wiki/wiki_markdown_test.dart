import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/wiki/wiki_markdown.dart';

void main() {
  test('blocs : titre, paragraphe sur deux lignes, liste, encadré, tableau', () {
    final b = parseWiki('## Envoûtement\n\nUn paragraphe\nsur deux lignes.\n\n- un\n- deux\n§ Coûte un point de Sang.\n'
        '| Niveau | Effet |\n|---|---|\n| 1 | Fascination |\r\n\nFin.');
    expect(b.map((x) => x.runtimeType).toList(), [WikiHeading, WikiPara, WikiList, WikiRuleBox, WikiTable, WikiPara]);
    expect((b[0] as WikiHeading).text, 'Envoûtement');
    expect((b[1] as WikiPara).text, 'Un paragraphe sur deux lignes.');
    expect((b[2] as WikiList).items, ['un', 'deux']);
    expect((b[3] as WikiRuleBox).text, 'Coûte un point de Sang.');
    expect((b[4] as WikiTable).rows, [
      ['Niveau', 'Effet'],
      ['1', 'Fascination'],
    ]);
    expect((b[5] as WikiPara).text, 'Fin.');
  });

  test('un paragraphe s’arrête avant une liste ; texte vide', () {
    final b = parseWiki('Avant\n- point\nAprès');
    expect(b.map((x) => x.runtimeType).toList(), [WikiPara, WikiList, WikiPara]);
    expect(parseWiki('  \n\n'), isEmpty);
  });

  test('en ligne : gras, italique, lien ; syntaxe non fermée laissée telle quelle', () {
    final s = parseInline('Un **gras**, un *italique* et [[ Présence ]].');
    expect([for (final x in s) x.text], ['Un ', 'gras', ', un ', 'italique', ' et ', 'Présence', '.']);
    expect([s[1].bold, s[3].italic, s[5].link], [true, true, true]);
    expect(s[0].bold || s[0].italic || s[0].link, isFalse);
    final open = parseInline('**non fermé et [[lien');
    expect(open.length, 1);
    expect(open.single.text, '**non fermé et [[lien');
  });

  test('texte sans balises et titres du sommaire', () {
    const src = '## Pouvoirs\n\nUn **effet** de [[Présence]].\n\n- *vite*\n| A | B |';
    expect(plainText(src), 'Pouvoirs\nUn effet de Présence.\nvite\nA B');
    expect(headingsOf(src), ['Pouvoirs']);
  });

  test('barre d’outils : entourer la sélection, préfixer la ligne, insérer un bloc', () {
    const sel = TextEditingValue(text: 'un mot', selection: TextSelection(baseOffset: 3, extentOffset: 6));
    final bold = wrapSelection(sel, '**', '**', 'texte');
    expect(bold.text, 'un **mot**');
    expect(bold.selection, const TextSelection(baseOffset: 5, extentOffset: 8));
    final link = wrapSelection(const TextEditingValue(text: 'Voir ', selection: TextSelection.collapsed(offset: 5)), '[[', ']]', 'Titre');
    expect(link.text, 'Voir [[Titre]]');
    expect(link.selection, const TextSelection(baseOffset: 7, extentOffset: 12));
    expect(wrapSelection(TextEditingValue.empty, '**', '**', 'texte').text, '**texte**');
    final title = prefixLine(const TextEditingValue(text: 'a\nbc', selection: TextSelection.collapsed(offset: 3)), '## ');
    expect(title.text, 'a\n## bc');
    expect(title.selection.baseOffset, 6);
    final table = insertBlock(const TextEditingValue(text: 'Intro', selection: TextSelection.collapsed(offset: 5)), '| A |');
    expect(table.text, 'Intro\n\n| A |\n');
    expect(insertBlock(TextEditingValue.empty, '| A |').text, '| A |\n');
  });
}
