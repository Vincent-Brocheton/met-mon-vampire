import 'package:flutter/services.dart';

/// Bloc du texte d'une page.
sealed class WikiBlock {
  const WikiBlock();
}

/// Titre `## …`.
class WikiHeading extends WikiBlock {
  const WikiHeading(this.text);
  final String text;
}

class WikiPara extends WikiBlock {
  const WikiPara(this.text);
  final String text;
}

/// Encadré « § Règle ».
class WikiRuleBox extends WikiBlock {
  const WikiRuleBox(this.text);
  final String text;
}

class WikiList extends WikiBlock {
  const WikiList(this.items);
  final List<String> items;
}

/// Tableau ; la première ligne sert d'en-tête.
class WikiTable extends WikiBlock {
  const WikiTable(this.rows);
  final List<List<String>> rows;
}

final _separator = RegExp(r'^:?-{3,}:?$');

/// Découpe le Markdown léger du wiki : `## titre`, `- liste`, `§ encadré`, `| a | b |`,
/// paragraphes séparés par une ligne vide.
List<WikiBlock> parseWiki(String source) {
  final blocks = <WikiBlock>[];
  final para = <String>[];
  List<String>? list;
  List<List<String>>? table;
  void flush() {
    if (para.isNotEmpty) blocks.add(WikiPara(para.join(' ')));
    para.clear();
    if (list case final l?) blocks.add(WikiList(l));
    if (table case final t?) blocks.add(WikiTable(t));
    list = null;
    table = null;
  }

  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(WikiHeading(line.substring(3).trim()));
    } else if (line.startsWith('§')) {
      flush();
      blocks.add(WikiRuleBox(line.substring(1).trim()));
    } else if (line.startsWith('- ')) {
      if (list == null) flush();
      (list ??= []).add(line.substring(2).trim());
    } else if (line.length > 1 && line.startsWith('|') && line.endsWith('|')) {
      if (table == null) flush();
      final rows = table ??= [];
      final cells = [for (final c in line.substring(1, line.length - 1).split('|')) c.trim()];
      if (!cells.every(_separator.hasMatch)) rows.add(cells);
    } else {
      if (list != null || table != null) flush();
      para.add(line);
    }
  }
  flush();
  return blocks;
}

/// Morceau de texte en ligne : `**gras**`, `*italique*`, `[[lien]]`.
class WikiSpan {
  const WikiSpan(this.text, {this.bold = false, this.italic = false, this.link = false});
  final String text;
  final bool bold;
  final bool italic;
  final bool link;
}

final _inline = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|\[\[(.+?)\]\]');

/// Une syntaxe non fermée reste du texte.
List<WikiSpan> parseInline(String s) {
  final out = <WikiSpan>[];
  var at = 0;
  for (final m in _inline.allMatches(s)) {
    if (m.start > at) out.add(WikiSpan(s.substring(at, m.start)));
    out.add(m[1] != null
        ? WikiSpan(m[1]!, bold: true)
        : m[2] != null
            ? WikiSpan(m[2]!, italic: true)
            : WikiSpan(m[3]!.trim(), link: true));
    at = m.end;
  }
  if (at < s.length) out.add(WikiSpan(s.substring(at)));
  return out;
}

String _plain(String s) => parseInline(s).map((x) => x.text).join();

/// Texte sans balises (recherche, extraits).
String plainText(String source) => [
      for (final b in parseWiki(source))
        switch (b) {
          WikiHeading(:final text) || WikiPara(:final text) || WikiRuleBox(:final text) => _plain(text),
          WikiList(:final items) => items.map(_plain).join(' '),
          WikiTable(:final rows) => [for (final r in rows) r.map(_plain).join(' ')].join(' '),
        },
    ].join('\n');

/// Titres `##` de la page, pour le sommaire.
List<String> headingsOf(String source) => [for (final b in parseWiki(source)) if (b is WikiHeading) b.text];

/// Entoure la sélection de [open] et [close] ; sans sélection, insère [placeholder] entouré, et le sélectionne.
TextEditingValue wrapSelection(TextEditingValue v, String open, String close, String placeholder) {
  final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
  final inner = sel.isCollapsed ? placeholder : sel.textInside(v.text);
  final start = sel.start + open.length;
  return TextEditingValue(
    text: sel.textBefore(v.text) + open + inner + close + sel.textAfter(v.text),
    selection: TextSelection(baseOffset: start, extentOffset: start + inner.length),
  );
}

/// Ajoute [prefix] au début de la ligne du curseur (titre, liste, encadré).
TextEditingValue prefixLine(TextEditingValue v, String prefix) {
  final at = v.selection.isValid ? v.selection.start : v.text.length;
  final lineStart = at == 0 ? 0 : v.text.lastIndexOf('\n', at - 1) + 1;
  return TextEditingValue(
    text: v.text.substring(0, lineStart) + prefix + v.text.substring(lineStart),
    selection: TextSelection.collapsed(offset: at + prefix.length),
  );
}

/// Insère [block] sur ses propres lignes, après la ligne du curseur.
TextEditingValue insertBlock(TextEditingValue v, String block) {
  final at = v.selection.isValid ? v.selection.end : v.text.length;
  final lineEnd = v.text.indexOf('\n', at);
  final cut = lineEnd < 0 ? v.text.length : lineEnd;
  final before = v.text.substring(0, cut);
  final lead = before.isEmpty ? '' : (before.endsWith('\n') ? '\n' : '\n\n');
  return TextEditingValue(
    text: '$before$lead$block\n${v.text.substring(cut)}',
    selection: TextSelection.collapsed(offset: before.length + lead.length + block.length),
  );
}
