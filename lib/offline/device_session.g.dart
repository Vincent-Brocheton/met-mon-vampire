// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceSession)
final deviceSessionProvider = DeviceSessionProvider._();

final class DeviceSessionProvider
    extends $FunctionalProvider<DeviceSession, DeviceSession, DeviceSession>
    with $Provider<DeviceSession> {
  DeviceSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceSessionHash();

  @$internal
  @override
  $ProviderElement<DeviceSession> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceSession create(Ref ref) {
    return deviceSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceSession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceSession>(value),
    );
  }
}

String _$deviceSessionHash() => r'9f27d19b682165cfde19a09417704a55cc0a775d';
