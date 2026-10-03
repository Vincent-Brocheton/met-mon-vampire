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

  test('nom trop long : erreur dans l’aperçu (revue)', () {
    final p = previewImport(merits, const [], 'name;state\n${'x' * 81};available\n${'y' * 80};available');
    expect(p.errors, ['Ligne 2 : nom trop long (80 caractères au plus)']);
    expect(p.news.single.name, 'y' * 80);
  });

  test('guillemet non fermé : erreur précise (revue)', () {
    expect(previewImport(merits, const [], 'name;state\n"Chanceux;available\nAutre;available').errors, ['Guillemet non fermé à la ligne 2']);
  });

  test('numéros de ligne du texte collé, lignes vides comprises (revue)', () {
    final p = previewImport(merits, const [], 'name;state\n\nChanceux;available\n"Deux\nlignes";available\n;available');
    expect(p.errors, ['Ligne 6 : nom manquant']);
  });

  test('séparé par des virgules : message clair (revue)', () {
    expect(previewImport(merits, const [], 'name,state\nChanceux,available').errors,
        ['Séparateur attendu : « ; » ou tabulation (le texte semble séparé par des virgules)']);
  });

  test('ligne identique : inchangée, pas modifiée (revue)', () {
    final p = previewImport(merits, [RuleEntry(id: 'x1', name: 'Chanceux', data: {'cost': 2})], 'name;state;cost\nChanceux;available;2');
    expect(p.updates, isEmpty);
    expect(p.unchanged, 1);
  });

  test('« | » dans une valeur de liste : aller-retour (revue)', () {
    final skills = categoryById('skills')!;
    final e = RuleEntry(name: 'Artisanat', data: {'domains': ['Peinture | huile', 'Chant']});
    expect(previewImport(skills, const [], exportCsv(skills, [e])).news.single.data['domains'], ['Peinture | huile', 'Chant']);
  });

  test('nouvel atout importé : proposé à la création et à l’XP sauf colonne contraire (revue)', () {
    expect(previewImport(merits, const [], 'name;state;cost\nMécène;available;3').news.single.data, {'cost': 3, 'atCreation': true, 'withXp': true});
    expect(previewImport(merits, const [], 'name;state;cost;withXp\nMécène;available;3;non').news.single.data['withXp'], isFalse);
  });
}
