import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/rulebook/csv.dart';
import 'package:portail_met/rulebook/rule_entry.dart';
import 'package:portail_met/rulebook/schema.dart';

void main() {
  final merits = categoryById('merits')!;
  final clans = categoryById('clans')!;

  test('lecture : guillemets, point-virgule et retour à la ligne dans une cellule (Review Focus 4)', () {
    final rows = parseTable('name;description\n"Chanceux";"Une chance ; insolente\nsur scène"\n\n"Dit ""non""";x\n');
    expect(rows, [
      ['name', 'description'],
      ['Chanceux', 'Une chance ; insolente\nsur scène'],
      ['Dit "non"', 'x'],
    ]);
  });

  test('collé depuis un tableur : tabulations', () {
    expect(parseTable('name\tstate\tcost\r\nChanceux\tavailable\t2'), [
      ['name', 'state', 'cost'],
      ['Chanceux', 'available', '2'],
    ]);
  });

  test('aller-retour : listes, cases, choix, valeurs par secte, lignes', () {
    final e = RuleEntry(name: 'Tremere', state: RuleState.approval, source: 'Livre de base, p. 52', data: {
      'disciplines': ['Auspex', 'Domination', 'Thaumaturgie'],
      'rarity': {'Camarilla': 'common', 'Sabbat': 'rare'},
      'weakness': 'Lien ; sang',
      'bloodlines': [
        {'name': 'Telyav', 'merit': 'Lignée Telyav'},
      ],
    });
    final p = previewImport(clans, const [], exportCsv(clans, [e]));
    expect(p.errors, isEmpty);
    expect(p.news.single.toMap(), e.toMap());
    final m = RuleEntry(name: 'Chanceux', data: {'cost': 2, 'type': 'general', 'atCreation': true, 'withXp': false});
    expect(previewImport(merits, const [], exportCsv(merits, [m])).news.single.toMap(), m.toMap());
  });

  test('aperçu : nouveaux, modifiés, erreurs, colonnes ignorées (Review Focus 1)', () {
    final existing = [RuleEntry(id: 'x1', name: 'Chanceux', data: {'cost': 2})];
    final p = previewImport(merits, existing, [
      'name;state;cost;type;couleur',
      '  chanceux ;available;3;clan;rouge',
      'Nouveau;Accord du conte;1;Général;',
      ';available;1;general;',
      'Faux;inconnu;1;general;',
      'Cher;available;beaucoup;general;',
      'Bizarre;available;1;cosmique;',
      'Nouveau;available;1;general;',
    ].join('\n'));
    expect(p.updates.single.id, 'x1');
    expect(p.updates.single.name, 'Chanceux');
    expect(p.updates.single.data['cost'], 3);
    expect(p.updates.single.data['type'], 'clan');
    expect(p.news.single.name, 'Nouveau');
    expect(p.news.single.state, RuleState.approval);
    expect(p.news.single.data['type'], 'general');
    expect(p.warnings, ['Colonne ignorée : couleur']);
    expect(p.errors, [
      'Ligne 4 : nom manquant',
      'Ligne 5 : état inconnu « inconnu »',
      'Ligne 6, cost : nombre attendu, « beaucoup »',
      'Ligne 7, type : valeur inconnue « cosmique »',
      'Ligne 8 : « Nouveau » apparaît deux fois',
    ]);
  });

  test('colonnes obligatoires', () {
    expect(previewImport(merits, const [], 'cost\n2').errors, ['Colonne « name » absente', 'Colonne « state » absente']);
    expect(previewImport(merits, const [], '').errors, ['Rien à importer']);
  });
}
