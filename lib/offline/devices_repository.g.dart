// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(devicesRepository)
final devicesRepositoryProvider = DevicesRepositoryProvider._();

final class DevicesRepositoryProvider
    extends
        $FunctionalProvider<
          DevicesRepository,
          DevicesRepository,
          DevicesRepository
        >
    with $Provider<DevicesRepository> {
  DevicesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicesRepositoryHash();

  @$internal
  @override
  $ProviderElement<DevicesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DevicesRepository create(Ref ref) {
    return devicesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevicesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevicesRepository>(value),
    );
  }
}

String _$devicesRepositoryHash() => r'2d0953a85aeee5f8c06566c461e55861669c8bb6';

@ProviderFor(myDevices)
final myDevicesProvider = MyDevicesProvider._();

final class MyDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Device>>,
          List<Device>,
          Stream<List<Device>>
        >
    with $FutureModifier<List<Device>>, $StreamProvider<List<Device>> {
  MyDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<Device>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Device>> create(Ref ref) {
    return myDevices(ref);
  }
}

String _$myDevicesHash() => r'd9d3a0ad58dca70c47c7c2c2bb6b2c3b06e836f7';

/// Identifiant de cet appareil, créé au premier lancement (identifiant aléatoire de Firestore, 20 caractères).

@ProviderFor(deviceId)
final deviceIdProvider = DeviceIdProvider._();

/// Identifiant de cet appareil, créé au premier lancement (identifiant aléatoire de Firestore, 20 caractères).

final class DeviceIdProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Identifiant de cet appareil, créé au premier lancement (identifiant aléatoire de Firestore, 20 caractères).
  DeviceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceIdHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return deviceId(ref);
  }
}

String _$deviceIdHash() => r'a7f6fcbdbf3e525dbf20cd4dbfa7f54b1287898a';

/// Le document de cet appareil. Mis à jour une fois par session (dernière visite), sauf s'il est marqué :
/// l'appareil va alors se déconnecter (écoute dans `router.dart`).

@ProviderFor(thisDevice)
final thisDeviceProvider = ThisDeviceProvider._();

/// Le document de cet appareil. Mis à jour une fois par session (dernière visite), sauf s'il est marqué :
/// l'appareil va alors se déconnecter (écoute dans `router.dart`).

final class ThisDeviceProvider
    extends $FunctionalProvider<AsyncValue<Device?>, Device?, Stream<Device?>>
    with $FutureModifier<Device?>, $StreamProvider<Device?> {
  /// Le document de cet appareil. Mis à jour une fois par session (dernière visite), sauf s'il est marqué :
  /// l'appareil va alors se déconnecter (écoute dans `router.dart`).
  ThisDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thisDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thisDeviceHash();

  @$internal
  @override
  $StreamProviderElement<Device?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Device?> create(Ref ref) {
    return thisDevice(ref);
  }
}

String _$thisDeviceHash() => r'50aa6aad0a6c48aa71d2a83b10dee37a76bcb6d2';
