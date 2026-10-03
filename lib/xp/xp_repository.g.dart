// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xp_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(xpRepository)
final xpRepositoryProvider = XpRepositoryProvider._();

final class XpRepositoryProvider
    extends $FunctionalProvider<XpRepository, XpRepository, XpRepository>
    with $Provider<XpRepository> {
  XpRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xpRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xpRepositoryHash();

  @$internal
  @override
  $ProviderElement<XpRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  XpRepository create(Ref ref) {
    return xpRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(XpRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<XpRepository>(value),
    );
  }
}

String _$xpRepositoryHash() => r'4709d585fc27ae761c7fa2e769e0c9696bce6b93';

@ProviderFor(myRequests)
final myRequestsProvider = MyRequestsProvider._();

final class MyRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<XpRequest>>,
          List<XpRequest>,
          Stream<List<XpRequest>>
        >
    with $FutureModifier<List<XpRequest>>, $StreamProvider<List<XpRequest>> {
  MyRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myRequestsHash();

  @$internal
  @override
  $StreamProviderElement<List<XpRequest>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<XpRequest>> create(Ref ref) {
    return myRequests(ref);
  }
}

String _$myRequestsHash() => r'2f1c0c6e123368eb6cb9445100971fd02c8ad478';

@ProviderFor(pendingRequests)
final pendingRequestsProvider = PendingRequestsProvider._();

final class PendingRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<XpRequest>>,
          List<XpRequest>,
          Stream<List<XpRequest>>
        >
    with $FutureModifier<List<XpRequest>>, $StreamProvider<List<XpRequest>> {
  PendingRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingRequestsHash();

  @$internal
  @override
  $StreamProviderElement<List<XpRequest>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<XpRequest>> create(Ref ref) {
    return pendingRequests(ref);
  }
}

String _$pendingRequestsHash() => r'859e3bebb87502c38d7361d0a2892eb00ee0703f';

@ProviderFor(characterRequests)
final characterRequestsProvider = CharacterRequestsFamily._();

final class CharacterRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<XpRequest>>,
          List<XpRequest>,
          Stream<List<XpRequest>>
        >
    with $FutureModifier<List<XpRequest>>, $StreamProvider<List<XpRequest>> {
  CharacterRequestsProvider._({
    required CharacterRequestsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterRequestsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterRequestsHash();

  @override
  String toString() {
    return r'characterRequestsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<XpRequest>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<XpRequest>> create(Ref ref) {
    final argument = this.argument as String;
    return characterRequests(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterRequestsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterRequestsHash() => r'0b30746a5f0ff2cb09c4bb8224b2a9e08b488bc4';

final class CharacterRequestsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<XpRequest>>, String> {
  CharacterRequestsFamily._()
    : super(
        retry: null,
        name: r'characterRequestsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CharacterRequestsProvider call(String characterId) =>
      CharacterRequestsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterRequestsProvider';
}

@ProviderFor(xpSettings)
final xpSettingsProvider = XpSettingsProvider._();

final class XpSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<XpSettings>,
          XpSettings,
          Stream<XpSettings>
        >
    with $FutureModifier<XpSettings>, $StreamProvider<XpSettings> {
  XpSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xpSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xpSettingsHash();

  @$internal
  @override
  $StreamProviderElement<XpSettings> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<XpSettings> create(Ref ref) {
    return xpSettings(ref);
  }
}

String _$xpSettingsHash() => r'2c3f7dc64ec973a2a056b01bac643de41bd2f090';

@ProviderFor(corrections)
final correctionsProvider = CorrectionsProvider._();

final class CorrectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CorrectionEntry>>,
          List<CorrectionEntry>,
          Stream<List<CorrectionEntry>>
        >
    with
        $FutureModifier<List<CorrectionEntry>>,
        $StreamProvider<List<CorrectionEntry>> {
  CorrectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'correctionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$correctionsHash();

  @$internal
  @override
  $StreamProviderElement<List<CorrectionEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CorrectionEntry>> create(Ref ref) {
    return corrections(ref);
  }
}

String _$correctionsHash() => r'44cb04546d4b0f8a133ae2f930ac6714584c60d9';
