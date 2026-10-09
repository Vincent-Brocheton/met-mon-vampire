import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portail_met/auth/session_providers.dart';
import 'package:portail_met/offline/device.dart';
import 'package:portail_met/offline/devices_repository.dart';

import '../fakes.dart';

class _User implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo extends FakeDevicesRepository {
  _Repo(this.snapshots);

  final List<Device?> snapshots;

  @override
  Stream<Device?> watch(String uid, String id) => Stream.fromIterable(snapshots);
}

Future<List<String>> run(List<Device?> snapshots) async {
  final repo = _Repo(snapshots);
  final c = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(_User())),
    deviceIdProvider.overrideWith((ref) async => 'd1'),
    devicesRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  final sub = c.listen(thisDeviceProvider, (_, _) {});
  addTearDown(sub.close);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return repo.calls;
}

void main() {
  test('premier instantané marqué, puis retiré : aucun document fantôme', () async {
    final calls = await run([Device(id: 'd1', name: 'x', revokedAt: DateTime(2026)), null]);
    expect(calls, isEmpty);
  });

  test('premier instantané normal : une seule visite enregistrée', () async {
    final calls = await run([const Device(id: 'd1', name: 'x'), const Device(id: 'd1', name: 'x'), null]);
    expect(calls, ['touch:u1/d1']);
  });
}
