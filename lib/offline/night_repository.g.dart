// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'night_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nightRepository)
final nightRepositoryProvider = NightRepositoryProvider._();

final class NightRepositoryProvider
    extends
        $FunctionalProvider<NightRepository, NightRepository, NightRepository>
    with $Provider<NightRepository> {
  NightRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nightRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nightRepositoryHash();

  @$internal
  @override
  $ProviderElement<NightRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NightRepository create(Ref ref) {
    return nightRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NightRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NightRepository>(value),
    );
  }
}

String _$nightRepositoryHash() => r'8c541895ec22a495e340364e9770c371c85e452c';

@ProviderFor(night)
final nightProvider = NightFamily._();

final class NightProvider
    extends
        $FunctionalProvider<AsyncValue<NightView>, NightView, Stream<NightView>>
    with $FutureModifier<NightView>, $StreamProvider<NightView> {
  NightProvider._({
    required NightFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'nightProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nightHash();

  @override
  String toString() {
    return r'nightProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<NightView> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<NightView> create(Ref ref) {
    final argument = this.argument as (String, String);
    return night(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is NightProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nightHash() => r'6093f2e67d2cdc4be637402867f94828243cf99d';

final class NightFamily extends $Family
    with $FunctionalFamilyOverride<Stream<NightView>, (String, String)> {
  NightFamily._()
    : super(
        retry: null,
        name: r'nightProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NightProvider call(String characterId, String gameId) =>
      NightProvider._(argument: (characterId, gameId), from: this);

  @override
  String toString() => r'nightProvider';
}
