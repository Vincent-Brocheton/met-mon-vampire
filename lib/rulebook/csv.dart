import 'dart:convert';

import 'rule_entry.dart';
import 'schema.dart';

const _common = ['name', 'vo', 'state', 'source', 'description'];

List<String> columnsOf(RuleCategory c) => [..._common, for (final f in c.fields) f.key];

/// Cellules d'un CSV (« ; ») ou d'un collage de tableur (tabulations, détectées sur la première ligne).
/// Guillemets doublés, séparateurs et retours à la ligne entre guillemets ; lignes vides ignorées.
List<List<String>> parseTable(String text) {
  final sep = text.split('\n').first.contains('\t') ? '\t' : ';';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch != '"') {
        cell.write(ch);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (ch == '"' && cell.isEmpty) {
      quoted = true;
    } else if (ch == sep) {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String _quote(String s) => s.contains(RegExp('[;"\n\t]')) ? '"${s.replaceAll('"', '""')}"' : s;

String _encode(RuleField f, Object? v) {
  if (v == null) return '';
  return switch (f.type) {
    FieldType.flag => v == true ? 'oui' : 'non',
    FieldType.multi || FieldType.list => (v as List).join(' | '),
    FieldType.keyed || FieldType.rows => jsonEncode(v),
    _ => '$v',
  };
}

String exportCsv(RuleCategory c, List<RuleEntry> entries) => [
      columnsOf(c).join(';'),
      for (final e in entries)
        [
          e.name,
          e.vo ?? '',
          e.state.name,
          e.source ?? '',
          e.description,
          for (final f in c.fields) _encode(f, e.data[f.key]),
        ].map(_quote).join(';'),
    ].join('\n');

String _choice(RuleField f, String s) {
  final t = s.trim().toLowerCase();
  final o = f.options.where((o) => o.$1.toLowerCase() == t || o.$2.toLowerCase() == t).firstOrNull;
  if (o == null) throw FormatException('valeur inconnue « ${s.trim()} »');
  return o.$1;
}

/// Valeur d'une cellule (null : vide) ; FormatException avec le motif lisible.
Object? _decode(RuleField f, String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  List<String> parts() => [for (final p in t.split('|')) if (p.trim().isNotEmpty) p.trim()];
  switch (f.type) {
    case FieldType.flag:
      if (['oui', 'yes', 'true', '1', 'x'].contains(t.toLowerCase())) return true;
      if (['non', 'no', 'false', '0'].contains(t.toLowerCase())) return false;
      throw FormatException('oui ou non attendu, « $t »');
    case FieldType.number:
      return int.tryParse(t) ?? (throw FormatException('nombre attendu, « $t »'));
    case FieldType.choice:
      return _choice(f, t);
    case FieldType.multi:
      return [for (final p in parts()) _choice(f, p)];
    case FieldType.list:
      return parts();
    case FieldType.keyed || FieldType.rows:
      Object? v;
      try {
        v = jsonDecode(t);
      } on FormatException {
        v = null;
      }
      if ((f.type == FieldType.keyed && v is Map) || (f.type == FieldType.rows && v is List)) return v;
      throw const FormatException('JSON attendu');
    case FieldType.text || FieldType.longText:
      return t;
  }
}

class ImportPreview {
  ImportPreview({this.news = const [], this.updates = const [], this.errors = const [], this.warnings = const []});
  final List<RuleEntry> news;

  /// Éléments existants (même nom), avec leur id.
  final List<RuleEntry> updates;
  final List<String> errors;
  final List<String> warnings;
}

ImportPreview previewImport(RuleCategory c, List<RuleEntry> existing, String text) {
  final rows = parseTable(text);
  if (rows.isEmpty) return ImportPreview(errors: ['Rien à importer']);
  final header = [for (final h in rows.first) h.trim()];
  final missing = [for (final k in ['name', 'state']) if (!header.contains(k)) 'Colonne « $k » absente'];
  if (missing.isNotEmpty) return ImportPreview(errors: missing);
  final known = columnsOf(c);
  final warnings = [for (final h in header) if (h.isNotEmpty && !known.contains(h)) 'Colonne ignorée : $h'];
  final byName = {for (final e in existing) nameKey(e.name): e};
  final news = <RuleEntry>[], updates = <RuleEntry>[], errors = <String>[];
  final seen = <String>{};
  for (final (i, row) in rows.skip(1).indexed) {
    final line = i + 2;
    String cell(String key) {
      final idx = header.indexOf(key);
      return idx < 0 || idx >= row.length ? '' : row[idx];
    }

    String? opt(String key) => cell(key).trim().isEmpty ? null : cell(key).trim();
    final name = cell('name').trim();
    if (name.isEmpty) {
      errors.add('Ligne $line : nom manquant');
      continue;
    }
    final stateText = cell('state').trim().toLowerCase();
    final state = RuleState.values.where((s) => s.name.toLowerCase() == stateText || s.label.toLowerCase() == stateText).firstOrNull;
    if (state == null) {
      errors.add(stateText.isEmpty ? 'Ligne $line : état manquant' : 'Ligne $line : état inconnu « ${cell('state').trim()} »');
      continue;
    }
    if (!seen.add(nameKey(name))) {
      errors.add('Ligne $line : « $name » apparaît deux fois');
      continue;
    }
    final old = byName[nameKey(name)];
    final data = <String, dynamic>{...?old?.data};
    String? error;
    for (final f in c.fields) {
      if (!header.contains(f.key)) continue;
      try {
        final v = _decode(f, cell(f.key));
        if (v == null) {
          data.remove(f.key);
        } else {
          data[f.key] = v;
        }
      } on FormatException catch (e) {
        error = 'Ligne $line, ${f.key} : ${e.message}';
        break;
      }
    }
    if (error != null) {
      errors.add(error);
      continue;
    }
    // Colonne absente : la valeur existante est gardée.
    (old == null ? news : updates).add(RuleEntry(
      id: old?.id ?? '',
      name: old?.name ?? name,
      vo: header.contains('vo') ? opt('vo') : old?.vo,
      state: state,
      source: header.contains('source') ? opt('source') : old?.source,
      description: header.contains('description') ? cell('description').trim() : (old?.description ?? ''),
      data: data,
    ));
  }
  return ImportPreview(news: news, updates: updates, errors: errors, warnings: warnings);
}
