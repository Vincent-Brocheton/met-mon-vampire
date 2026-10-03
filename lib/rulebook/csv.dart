import 'dart:convert';

import 'rule_entry.dart';
import 'schema.dart';

const _common = ['name', 'vo', 'state', 'source', 'description'];

List<String> columnsOf(RuleCategory c) => [..._common, for (final f in c.fields) f.key];

/// Cellules d'un CSV (« ; ») ou d'un collage de tableur (tabulations, détectées sur la première ligne),
/// avec le numéro de la ligne du texte où chacune commence.
/// Guillemets doublés, séparateurs et retours à la ligne entre guillemets ; lignes vides ignorées.
/// FormatException si un guillemet n'est pas fermé.
List<(int, List<String>)> parseRows(String text) {
  final sep = text.split('\n').first.contains('\t') ? '\t' : ';';
  final rows = <(int, List<String>)>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var line = 1, start = 1, quoteLine = 1;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add((start, row));
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '\n') line++;
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
      quoteLine = line;
    } else if (ch == sep) {
      endCell();
    } else if (ch == '\n') {
      endRow();
      start = ++line;
    } else if (ch != '\r') {
      cell.write(ch);
    }
  }
  if (quoted) throw FormatException('Guillemet non fermé à la ligne $quoteLine');
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

List<List<String>> parseTable(String text) => [for (final (_, r) in parseRows(text)) r];

String _quote(String s) => s.contains(RegExp('[;"\n\t]')) ? '"${s.replaceAll('"', '""')}"' : s;

String _encode(RuleField f, Object? v) {
  if (v == null) return '';
  return switch (f.type) {
    FieldType.flag => v == true ? 'oui' : 'non',
    // Une valeur qui contient « | » passe en JSON, sinon elle serait coupée à la relecture.
    FieldType.list when (v as List).any((x) => '$x'.contains('|')) => jsonEncode(v),
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
      if (t.startsWith('[')) {
        try {
          return [for (final x in jsonDecode(t) as List) '$x'];
        } on Object {
          // pas du JSON : liste « | » ordinaire
        }
      }
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
  ImportPreview({this.news = const [], this.updates = const [], this.errors = const [], this.warnings = const [], this.unchanged = 0});

  /// Lignes identiques à l'élément existant : rien à écrire.
  final int unchanged;
  final List<RuleEntry> news;

  /// Éléments existants (même nom), avec leur id.
  final List<RuleEntry> updates;
  final List<String> errors;
  final List<String> warnings;
}

/// Clés de map triées : deux valeurs JSON égales donnent le même texte.
Object? _sorted(Object? v) => switch (v) {
      Map() => {for (final k in [for (final k in v.keys) '$k']..sort()) k: _sorted(v[k])},
      List() => [for (final x in v) _sorted(x)],
      _ => v,
    };

bool _same(RuleEntry a, RuleEntry b) => jsonEncode(_sorted(a.toMap())) == jsonEncode(_sorted(b.toMap()));

ImportPreview previewImport(RuleCategory c, List<RuleEntry> existing, String text) {
  final List<(int, List<String>)> rows;
  try {
    rows = parseRows(text);
  } on FormatException catch (e) {
    return ImportPreview(errors: [e.message]);
  }
  if (rows.isEmpty) return ImportPreview(errors: ['Rien à importer']);
  final header = [for (final h in rows.first.$2) h.trim()];
  final missing = [for (final k in ['name', 'state']) if (!header.contains(k)) 'Colonne « $k » absente'];
  if (missing.isNotEmpty) {
    final commas = header.length == 1 && header.first.contains(',');
    return ImportPreview(
        errors: commas ? ['Séparateur attendu : « ; » ou tabulation (le texte semble séparé par des virgules)'] : missing);
  }
  final known = columnsOf(c);
  final warnings = [for (final h in header) if (h.isNotEmpty && !known.contains(h)) 'Colonne ignorée : $h'];
  final byName = {for (final e in existing) nameKey(e.name): e};
  final news = <RuleEntry>[], updates = <RuleEntry>[], errors = <String>[];
  final seen = <String>{};
  var unchanged = 0;
  for (final (line, row) in rows.skip(1)) {
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
    if (name.length > 80) {
      errors.add('Ligne $line : nom trop long (80 caractères au plus)');
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
    final data = <String, dynamic>{...(old?.data ?? newEntryData(c.id))};
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
    final entry = RuleEntry(
      id: old?.id ?? '',
      name: old?.name ?? name,
      vo: header.contains('vo') ? opt('vo') : old?.vo,
      state: state,
      source: header.contains('source') ? opt('source') : old?.source,
      description: header.contains('description') ? cell('description').trim() : (old?.description ?? ''),
      data: data,
    );
    if (old == null) {
      news.add(entry);
    } else if (_same(entry, old)) {
      unchanged++;
    } else {
      updates.add(entry);
    }
  }
  return ImportPreview(news: news, updates: updates, errors: errors, warnings: warnings, unchanged: unchanged);
}
