import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/characters/character.dart';
import 'package:portail_met/characters/character_repository.dart' show draftData;
import 'package:portail_met/characters/describe_changes.dart';
import 'package:portail_met/characters/sheet_widgets.dart';
import 'package:portail_met/core/theme.dart';

import 'character_test.dart' show sample;

void main() {
  test('clés tardives : absentes tant que vides, gardées une fois écrites (Review Focus 1)', () {
    final c = sample();
    expect(c.toMap().keys, isNot(anyOf(contains('rituals'), contains('techniques'), contains('elderPowers'), contains('attributeBonus'))));
    c.rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1));
    c.techniques.add('Regard ardent');
    c.elderPowers.add(ElderPower('Clairvoyance', 'Auspex'));
    c.attributeBonus[AttrCategory.mental] = 1;
    final back = Character.fromMap('x', c.toMap());
    expect(back.toMap(), c.toMap());
    expect(back.rituals.single.level, 1);
    expect(back.attributeBonus[AttrCategory.mental], 1);
    back.rituals.clear();
    expect(back.toMap()['rituals'], isEmpty, reason: 'déjà écrite : la liste vide est écrite pour retirer le rituel');
    expect(back.clone().toMap()['rituals'], isEmpty);
  });

  test('brouillon du joueur : draftData n’écrit jamais allies (clé protégée par les règles)', () {
    final c = sample();
    expect(draftData(c).keys, containsAll(['rituals', 'servants']));
    expect(draftData(c).keys, isNot(contains('allies')));
    expect(c.laterKeys().keys, contains('allies'), reason: 'le conte, lui, l’écrit');
  });

  test('résumé des changements et rebase des listes tardives', () {
    final a = sample();
    final b = a.clone()
      ..rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1))
      ..techniques.add('Regard ardent');
    b.attributeBonus[AttrCategory.mental] = 1;
    expect(describeChanges(a, b), containsAll(['+ Rituel Goût du sang', '+ Technique Regard ardent', 'Points bonus Mental 0 → 1']));
    final merged = rebase(a, b, a.clone()..version = 5);
    expect(merged.rituals.single.name, 'Goût du sang');
    expect(merged.techniques, ['Regard ardent']);
    expect(merged.version, 5);
  });

  testWidgets('fiche : rituels, techniques, pouvoirs d’anciens, points bonus', (tester) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = sample()
      ..rituals = [Ritual('Goût du sang', 'thaumaturgy', 1)]
      ..techniques = ['Regard ardent']
      ..elderPowers = [ElderPower('Clairvoyance', 'Auspex')];
    c.attributeBonus[AttrCategory.social] = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: CharacterSheetView(c))),
    ));
    expect(find.text('Rituel · Goût du sang'), findsOneWidget);
    expect(find.text('Regard ardent'), findsOneWidget);
    expect(find.text('Pouvoir d’ancien · Clairvoyance'), findsOneWidget);
    expect(find.textContaining('1 point bonus'), findsOneWidget);
  });

  test('brouillon et C3 : une liste vidée sur la même copie est bien effacée (revue)', () {
    final c = sample()..rituals.add(Ritual('Goût du sang', 'thaumaturgy', 1));
    c.rituals.clear();
    expect(c.toMap().containsKey('rituals'), isFalse, reason: 'la copie de travail ignore que la clé a été écrite');
    expect(draftData(c)['rituals'], isEmpty);
    expect(draftData(c)['attributeBonus'], {'physical': 0, 'social': 0, 'mental': 0});
    expect(c.laterKeys().keys, containsAll(['rituals', 'techniques', 'elderPowers', 'attributeBonus']));
  });
}
