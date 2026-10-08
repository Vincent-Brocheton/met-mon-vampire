// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sins_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sinsRepository)
final sinsRepositoryProvider = SinsRepositoryProvider._();

final class SinsRepositoryProvider
    extends $FunctionalProvider<SinsRepository, SinsRepository, SinsRepository>
    with $Provider<SinsRepository> {
  SinsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sinsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sinsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SinsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SinsRepository create(Ref ref) {
    return sinsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SinsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SinsRepository>(value),
    );
  }
}

String _$sinsRepositoryHash() => r'17f25bdbde54e48012cf8d0a174ed86678929a1a';

@ProviderFor(characterSins)
final characterSinsProvider = CharacterSinsFamily._();

final class CharacterSinsProvider
    extends
        $FunctionalProvider<AsyncValue<List<Sin>>, List<Sin>, Stream<List<Sin>>>
    with $FutureModifier<List<Sin>>, $StreamProvider<List<Sin>> {
  CharacterSinsProvider._({
    required CharacterSinsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterSinsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterSinsHash();

  @override
  String toString() {
    return r'characterSinsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Sin>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Sin>> create(Ref ref) {
    final argument = this.argument as String;
    return characterSins(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterSinsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterSinsHash() => r'38a2817c28ccfed37451a255db0cc6925df50bac';

final class CharacterSinsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Sin>>, String> {
  CharacterSinsFamily._()
    : super(
        retry: null,
        name: r'characterSinsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CharacterSinsProvider call(String characterId) =>
      CharacterSinsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterSinsProvider';
}
