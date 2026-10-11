import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/wiki/wiki_view.dart';

import 'wiki_rules_test.dart' show rbWiki;

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(withFonts: false), home: Scaffold(body: SingleChildScrollView(child: child))));
  }

  testWidgets('texte : titre, encadré, liste, tableau ; lien visible cliquable, lien caché en texte simple (Review Focus 1)', (tester) async {
    final opened = <String>[];
    await pump(
        tester,
        WikiBody(
          '## Envoûtement\n\n§ Coûte un point de Sang.\n\n- Fascination\n\n| Niveau | Pouvoir |\n|---|---|\n| 1 | **Fascination** |\n\n'
          'Voir [[Présence]] et [[Page cachée]].',
          target: (t) => t == 'Présence' ? 'pre' : null,
          onOpen: opened.add,
        ));
    expect(find.text('Envoûtement'), findsOneWidget);
    expect(find.text('Coûte un point de Sang.'), findsOneWidget);
    expect(find.text('Fascination'), findsNWidgets(2));
    expect(find.text('Niveau'), findsOneWidget);
    expect(find.textContaining('Page cachée'), findsOneWidget);
    expect(find.text('Page cachée'), findsNothing);
    await tester.tap(find.text('Présence'));
    expect(opened, ['pre']);
  });

  testWidgets('données du référentiel et pouvoirs d’une discipline', (tester) async {
    await pump(tester, RuleDataView(cat: 'disciplines', entry: rbWiki.find('disciplines', 'Présence')!));
    expect(find.text('Commune (achetable hors clan) : Oui'), findsOneWidget);
    expect(find.byKey(const Key('wk-power-3-Envoûtement')), findsOneWidget);
    expect(find.text('Rend la cible dévouée.'), findsOneWidget);
    expect(find.text('●●'), findsOneWidget);
    expect(find.text('Dread Gaze'), findsOneWidget);
  });

  testWidgets('pastille de visibilité', (tester) async {
    await pump(tester, const AudiencePill('clan:toreador', 'Clan Toreador'));
    expect(find.text('Clan Toreador'), findsOneWidget);
  });

  test('adresses de lecture', () {
    expect(const WikiNav(staff: false).home, '/joueur/wiki');
    expect(const WikiNav(staff: false).page('cour'), '/joueur/wiki/page/cour');
    expect(const WikiNav(staff: true).home, '/conteur/wiki/accueil');
    expect(const WikiNav(staff: true, preview: true).search('la cour'), '/conteur/wiki/recherche?q=la+cour&apercu=1');
    expect(const WikiNav(staff: true, preview: true).rubric('disciplines'), '/conteur/wiki/rubrique/disciplines?apercu=1');
  });
}
