import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/print/print_sheet.dart';
import 'package:portail_met/print/sheet_pdf.dart';

import 'print_sheet_test.dart' show full, printed;

/// Polices lues sur disque : les tests n'ont pas besoin du bundle d'assets.
PdfFonts testFonts() {
  pw.Font font(String name) => pw.Font.ttf(ByteData.sublistView(File('assets/fonts/$name.ttf').readAsBytesSync()));
  return PdfFonts(
    regular: font('SourceSans3-Regular'),
    bold: font('SourceSans3-Bold'),
    serif: font('CormorantGaramond-Bold'),
    serifItalic: font('CormorantGaramond-Italic'),
  );
}

Future<int> pages(PrintSheet s) async {
  final doc = sheetDocument(s, testFonts());
  final bytes = await doc.save();
  expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  return doc.document.pdfPageList.pages.length;
}

void main() {
  test('fiche complète : un PDF de deux pages, version figée', () async {
    expect(await pages(printed(version: PrintVersion.frozen, frozen: true)), 2);
  });

  test('fiche vide : deux pages (Review Focus 4)', () async {
    expect(await pages(printed(c: Character(id: 'e', name: 'Vide', kind: CharacterKind.pj, status: CharacterStatus.active))), 2);
  });

  test('fiche longue : une page de plus, sans erreur (Review Focus 4)', () async {
    final long = full()
      ..backgrounds = [for (var i = 0; i < 30; i++) Trait('Historique $i', 2, note: 'précision du point $i')]
      ..story = List.filled(300, 'Une longue nuit à l’opéra, sous les lustres.').join(' ');
    expect(await pages(printed(c: long)), greaterThan(2));
  });

  test('sheetPdf renvoie les octets du document', () async {
    final bytes = await sheetPdf(printed(), testFonts());
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
