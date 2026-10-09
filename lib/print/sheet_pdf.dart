import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'print_sheet.dart';

/// Polices embarquées : Source Sans 3 (texte), Cormorant Garamond (noms, concept).
class PdfFonts {
  const PdfFonts({required this.regular, required this.bold, required this.serif, required this.serifItalic});
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font serif;
  final pw.Font serifItalic;
}

Future<PdfFonts>? _fonts;

/// Polices lues dans les assets, une fois ; un échec n'est pas gardé en cache.
Future<PdfFonts> loadPdfFonts() => _fonts ??= _loadFonts().catchError((Object e) {
      _fonts = null;
      throw e;
    });

Future<PdfFonts> _loadFonts() async {
  Future<pw.Font> font(String name) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
  return PdfFonts(
    regular: await font('SourceSans3-Regular'),
    bold: await font('SourceSans3-Bold'),
    serif: await font('CormorantGaramond-Bold'),
    serifItalic: await font('CormorantGaramond-Italic'),
  );
}

// Noir et blanc : encre, gris des précisions, gris clair des filets.
const _ink = PdfColor.fromInt(0xFF1A1414);
const _muted = PdfColor.fromInt(0xFF5A504A);
const _rule = PdfColor.fromInt(0xFFD6CEC4);

/// La fiche en A4 portrait : page 1, saut de page, page 2 (et suivantes si la fiche est longue).
pw.Document sheetDocument(PrintSheet s, PdfFonts f) {
  final doc = pw.Document(title: s.name, theme: pw.ThemeData.withFont(base: f.regular, bold: f.bold));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 26),
    header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _reminder(s, f),
    footer: (ctx) => _footer(s, ctx),
    build: (ctx) => [..._page1(s, f), pw.NewPage(), ..._page2(s, f)],
  ));
  return doc;
}

Future<Uint8List> sheetPdf(PrintSheet s, PdfFonts f) => sheetDocument(s, f).save();

pw.Widget _title(String t) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 3),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2))),
      child: pw.Text(t.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
    );

/// [n] ronds pleins, complétés jusqu'à [max] par des ronds vides.
pw.Widget _dots(int n, {int max = 0}) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      for (var i = 0; i < (max > n ? max : n); i++)
        pw.Container(
          width: 6,
          height: 6,
          margin: const pw.EdgeInsets.only(left: 1.5),
          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: i < n ? _ink : null, border: pw.Border.all(color: _ink, width: 0.8)),
        ),
    ]);

pw.Widget _row(PrintRow r) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(style: const pw.TextStyle(fontSize: 9.5, color: _ink), children: [
              pw.TextSpan(text: r.label),
              if (r.detail.isNotEmpty) pw.TextSpan(text: '  ${r.detail}', style: const pw.TextStyle(color: _muted)),
            ]),
          ),
        ),
        if (r.dots > 0 || r.dotsMax > 0) pw.Padding(padding: const pw.EdgeInsets.only(left: 6, top: 2.5), child: _dots(r.dots, max: r.dotsMax)),
        if (r.value.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 6),
            child: pw.Text(r.value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ),
      ]),
    );

pw.Widget _section(String title, List<PrintRow> rows) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [_title(title), for (final r in rows) _row(r)]);

pw.Widget _boxes(int n, {int filled = 0, bool round = false}) => pw.Wrap(spacing: 2.5, runSpacing: 2.5, children: [
      for (var i = 0; i < n; i++)
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            shape: round ? pw.BoxShape.circle : pw.BoxShape.rectangle,
            color: i < filled ? _ink : null,
            border: pw.Border.all(color: _ink, width: 1),
          ),
        ),
    ]);

pw.Widget _gauge(PrintGauge g) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.RichText(
          text: pw.TextSpan(style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink), children: [
            pw.TextSpan(text: g.label),
            if (g.note.isNotEmpty) pw.TextSpan(text: ' · ${g.note}', style: const pw.TextStyle(fontWeight: pw.FontWeight.normal, color: _muted)),
          ]),
        ),
        pw.SizedBox(height: 3),
        if (g.groups.isEmpty)
          _boxes(g.boxes, filled: g.filled, round: g.round)
        else
          pw.Row(children: [
            for (final (label, n) in g.groups)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 12),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _boxes(n),
                  pw.SizedBox(height: 2),
                  pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
          ]),
      ]),
    );

pw.Widget _frame(pw.Widget child, {pw.EdgeInsets margin = pw.EdgeInsets.zero}) => pw.Container(
      margin: margin,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
      child: child,
    );

// ponytail: les rangées à deux colonnes ne se coupent pas entre deux pages ; une liste de compétences
// plus haute qu'une page lèverait une erreur. Passer ces colonnes en sections pleine largeur si cela arrive.
List<pw.Widget> _page1(PrintSheet s, PdfFonts f) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(s.name, style: pw.TextStyle(font: f.serif, fontSize: 26)),
            if (s.identity.isNotEmpty) pw.Text(s.identity, style: const pw.TextStyle(fontSize: 10.5)),
            pw.Text(s.people, style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
          ]),
        ),
        _frame(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          for (final (i, line) in s.stamp.indexed)
            pw.Text(
              i == 0 ? line.toUpperCase() : line,
              style: i == 0 ? pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1) : const pw.TextStyle(fontSize: 9),
            ),
        ])),
      ]),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        for (final (i, a) in s.attributes.indexed)
          pw.Expanded(
            child: _frame(
              margin: pw.EdgeInsets.only(left: i == 0 ? 0 : 6),
              pw.Row(children: [
                pw.Text('${a.value}', style: pw.TextStyle(font: f.serif, fontSize: 24)),
                pw.SizedBox(width: 8),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(a.name.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
                  pw.Text('Focus : ${a.focus}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                ]),
              ]),
            ),
          ),
      ]),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section('Compétences', s.skills)),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 200,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [_title('À cocher en jeu'), for (final g in s.gauges) _gauge(g)]),
        ),
      ]),
      _title('Disciplines'),
      for (final r in s.disciplines) _row(r),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section(s.meritsTitle, s.merits)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _section(s.flawsTitle, s.flaws)),
      ]),
    ];

List<pw.Widget> _page2(PrintSheet s, PdfFonts f) => [
      _title('Historiques'),
      for (final r in s.backgrounds) _row(r),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section('Moralité', s.morality)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _section('Liens de sang connus', s.bonds)),
      ]),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _section('Équipement', s.items)),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _section('Lieux', s.places)),
      ]),
      _title('Expérience'),
      pw.Row(children: [
        for (final (label, value) in s.xp)
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
      ]),
      _title('Concept'),
      if (s.concept.isNotEmpty) pw.Text(s.concept, style: pw.TextStyle(font: f.serifItalic, fontSize: 13)),
      if (s.story.isNotEmpty) ...[pw.SizedBox(height: 4), pw.Paragraph(text: s.story, style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2))],
      if (s.concept.isEmpty && s.story.isEmpty) pw.Text('Aucun', style: const pw.TextStyle(fontSize: 9.5)),
      _title('Notes de partie'),
      for (var i = 0; i < 9; i++)
        pw.Container(height: 20, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.8)))),
    ];

pw.Widget _reminder(PrintSheet s, PdfFonts f) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _muted, width: 0.8))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(s.name, style: pw.TextStyle(font: f.serif, fontSize: 15)),
        pw.Text(s.reminder, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ]),
    );

pw.Widget _footer(PrintSheet s, pw.Context ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _muted, width: 0.8))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(s.footer, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
      ]),
    );
