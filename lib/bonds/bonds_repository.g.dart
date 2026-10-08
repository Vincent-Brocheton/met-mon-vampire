// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bonds_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bondsRepository)
final bondsRepositoryProvider = BondsRepositoryProvider._();

final class BondsRepositoryProvider
    extends
        $FunctionalProvider<BondsRepository, BondsRepository, BondsRepository>
    with $Provider<BondsRepository> {
  BondsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bondsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bondsRepositoryHash();

  @$internal
  @override
  $ProviderElement<BondsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BondsRepository create(Ref ref) {
    return bondsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BondsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BondsRepository>(value),
    );
  }
}

String _$bondsRepositoryHash() => r'f84ab8c81d8f0cc5e51329e49c3b96f5fb7a2904';

@ProviderFor(allBonds)
final allBondsProvider = AllBondsProvider._();

final class AllBondsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Bond>>,
          List<Bond>,
          Stream<List<Bond>>
        >
    with $FutureModifier<List<Bond>>, $StreamProvider<List<Bond>> {
  AllBondsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allBondsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allBondsHash();

  @$internal
  @override
  $StreamProviderElement<List<Bond>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Bond>> create(Ref ref) {
    return allBonds(ref);
  }
}

String _$allBondsHash() => r'e912071b6e9337ad062216254561d5e1e4bd1db9';

@ProviderFor(sufferedBonds)
final sufferedBondsProvider = SufferedBondsFamily._();

final class SufferedBondsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Bond>>,
          List<Bond>,
          Stream<List<Bond>>
        >
    with $FutureModifier<List<Bond>>, $StreamProvider<List<Bond>> {
  SufferedBondsProvider._({
    required SufferedBondsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'sufferedBondsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sufferedBondsHash();

  @override
  String toString() {
    return r'sufferedBondsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<Bond>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Bond>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return sufferedBonds(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SufferedBondsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sufferedBondsHash() => r'8c45c14b10d7cf4611d0661fafd21897f619c47b';

final class SufferedBondsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Bond>>, (String, String)> {
  SufferedBondsFamily._()
    : super(
        retry: null,
        name: r'sufferedBondsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SufferedBondsProvider call(String characterId, String uid) =>
      SufferedBondsProvider._(argument: (characterId, uid), from: this);

  @override
  String toString() => r'sufferedBondsProvider';
}

@ProviderFor(exertedBonds)
final exertedBondsProvider = ExertedBondsFamily._();

final class ExertedBondsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Bond>>,
          List<Bond>,
          Stream<List<Bond>>
        >
    with $FutureModifier<List<Bond>>, $StreamProvider<List<Bond>> {
  ExertedBondsProvider._({
    required ExertedBondsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'exertedBondsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exertedBondsHash();

  @override
  String toString() {
    return r'exertedBondsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<Bond>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Bond>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return exertedBonds(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ExertedBondsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exertedBondsHash() => r'c64cdb0ab9f8dde786a18e87983db17d8a0310cb';

final class ExertedBondsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Bond>>, (String, String)> {
  ExertedBondsFamily._()
    : super(
        retry: null,
        name: r'exertedBondsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExertedBondsProvider call(String characterId, String uid) =>
      ExertedBondsProvider._(argument: (characterId, uid), from: this);

  @override
  String toString() => r'exertedBondsProvider';
}

/// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.

@ProviderFor(characterBonds)
final characterBondsProvider = CharacterBondsFamily._();

/// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.

final class CharacterBondsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Bond>>,
          List<Bond>,
          FutureOr<List<Bond>>
        >
    with $FutureModifier<List<Bond>>, $FutureProvider<List<Bond>> {
  /// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.
  CharacterBondsProvider._({
    required CharacterBondsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterBondsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterBondsHash();

  @override
  String toString() {
    return r'characterBondsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Bond>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Bond>> create(Ref ref) {
    final argument = this.argument as String;
    return characterBonds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterBondsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterBondsHash() => r'd8ccbd7ffe0311f8e54ed48b50af00ef1bb549f5';

/// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.

final class CharacterBondsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Bond>>, String> {
  CharacterBondsFamily._()
    : super(
        retry: null,
        name: r'characterBondsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Liens d'une fiche : tous pour l'équipe (hors sa propre fiche), ceux connus du joueur sinon.

  CharacterBondsProvider call(String characterId) =>
      CharacterBondsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterBondsProvider';
}
