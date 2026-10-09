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

String _$deviceSessionHash() => r'b0e96964c389222f24ad1f39005b601d59d354c2';
