import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/core/empty_state.dart';
import 'package:portail_met/core/theme.dart';
import 'package:portail_met/core/widgets.dart';

void main() {
  test('initialsOf', () {
    expect(initialsOf('Camille R.'), 'CR');
    expect(initialsOf('  marc  '), 'M');
    expect(initialsOf(''), '');
  });

  test('formatDay', () {
    expect(formatDay(DateTime(2026, 9, 27)), '27 sept.');
    expect(formatDay(null), '—');
  });

  testWidgets('EmptyState.error : bouton Réessayer', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(withFonts: false),
      home: Scaffold(body: EmptyState.error(onRetry: () => retried++)),
    ));
    expect(find.text('Quelque chose s’est mal passé'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, 1);
  });
}
