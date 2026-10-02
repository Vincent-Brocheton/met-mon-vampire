import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session.dart';
import 'package:portail_met/chronicle/accounts_screen.dart';

void main() {
  AppUser u(Role r) => AppUser(uid: r.name, displayName: r.name, email: '${r.name}@ex.fr', role: r);
  final everyone = Role.values.map(u).toList();

  List<Role> roles(AccountFilter f) => everyone.where((x) => matchesFilter(x, f)).map((x) => x.role).toList();

  test('Tous : tout sauf les demandes en attente', () {
    expect(roles(AccountFilter.all), isNot(contains(Role.pending)));
    expect(roles(AccountFilter.all).length, Role.values.length - 1);
  });

  test('Conteurs : narrateur, conteur, principal', () {
    expect(roles(AccountFilter.staff), [Role.narrateur, Role.conteur, Role.principal]);
  });

  test('Joueurs et désactivés', () {
    expect(roles(AccountFilter.players), [Role.joueur]);
    expect(roles(AccountFilter.disabled), [Role.disabled]);
  });
}
