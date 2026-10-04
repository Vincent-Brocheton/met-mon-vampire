// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(placesRepository)
final placesRepositoryProvider = PlacesRepositoryProvider._();

final class PlacesRepositoryProvider
    extends
        $FunctionalProvider<
          PlacesRepository,
          PlacesRepository,
          PlacesRepository
        >
    with $Provider<PlacesRepository> {
  PlacesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlacesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlacesRepository create(Ref ref) {
    return placesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlacesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlacesRepository>(value),
    );
  }
}

String _$placesRepositoryHash() => r'f6af902922bb42e012d63abff4b5c61922d072b2';

@ProviderFor(allPlaces)
final allPlacesProvider = AllPlacesProvider._();

final class AllPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Place>>,
          List<Place>,
          Stream<List<Place>>
        >
    with $FutureModifier<List<Place>>, $StreamProvider<List<Place>> {
  AllPlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allPlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allPlacesHash();

  @$internal
  @override
  $StreamProviderElement<List<Place>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Place>> create(Ref ref) {
    return allPlaces(ref);
  }
}

String _$allPlacesHash() => r'9a377d28793cdcee349f5664aaa05075acae2e48';

@ProviderFor(publicPlaces)
final publicPlacesProvider = PublicPlacesProvider._();

final class PublicPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Place>>,
          List<Place>,
          Stream<List<Place>>
        >
    with $FutureModifier<List<Place>>, $StreamProvider<List<Place>> {
  PublicPlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicPlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicPlacesHash();

  @$internal
  @override
  $StreamProviderElement<List<Place>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Place>> create(Ref ref) {
    return publicPlaces(ref);
  }
}

String _$publicPlacesHash() => r'531e9cfe5bb4eaecc3b312ace729923d9139b42a';

/// Lieux d'un personnage : requête de l'équipe, ou lieux du joueur filtrés par personnage.

@ProviderFor(characterPlaces)
final characterPlacesProvider = CharacterPlacesFamily._();

/// Lieux d'un personnage : requête de l'équipe, ou lieux du joueur filtrés par personnage.

final class CharacterPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Place>>,
          List<Place>,
          Stream<List<Place>>
        >
    with $FutureModifier<List<Place>>, $StreamProvider<List<Place>> {
  /// Lieux d'un personnage : requête de l'équipe, ou lieux du joueur filtrés par personnage.
  CharacterPlacesProvider._({
    required CharacterPlacesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterPlacesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterPlacesHash();

  @override
  String toString() {
    return r'characterPlacesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Place>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Place>> create(Ref ref) {
    final argument = this.argument as String;
    return characterPlaces(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterPlacesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterPlacesHash() => r'7cddb48578196e4f26c68c6469f806f5dd4c112b';

/// Lieux d'un personnage : requête de l'équipe, ou lieux du joueur filtrés par personnage.

final class CharacterPlacesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Place>>, String> {
  CharacterPlacesFamily._()
    : super(
        retry: null,
        name: r'characterPlacesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lieux d'un personnage : requête de l'équipe, ou lieux du joueur filtrés par personnage.

  CharacterPlacesProvider call(String characterId) =>
      CharacterPlacesProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterPlacesProvider';
}

@ProviderFor(placeNote)
final placeNoteProvider = PlaceNoteFamily._();

final class PlaceNoteProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  PlaceNoteProvider._({
    required PlaceNoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'placeNoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$placeNoteHash();

  @override
  String toString() {
    return r'placeNoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<String> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String> create(Ref ref) {
    final argument = this.argument as String;
    return placeNote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlaceNoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$placeNoteHash() => r'bf102f274b311761869975615cb1b56f572a5a8d';

final class PlaceNoteFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String>, String> {
  PlaceNoteFamily._()
    : super(
        retry: null,
        name: r'placeNoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PlaceNoteProvider call(String id) =>
      PlaceNoteProvider._(argument: id, from: this);

  @override
  String toString() => r'placeNoteProvider';
}

@ProviderFor(placeHistory)
final placeHistoryProvider = PlaceHistoryFamily._();

final class PlaceHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TraceEntry>>,
          List<TraceEntry>,
          Stream<List<TraceEntry>>
        >
    with $FutureModifier<List<TraceEntry>>, $StreamProvider<List<TraceEntry>> {
  PlaceHistoryProvider._({
    required PlaceHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'placeHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$placeHistoryHash();

  @override
  String toString() {
    return r'placeHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TraceEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TraceEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return placeHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlaceHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$placeHistoryHash() => r'3506ff6c58e63d25a07f9f14a96a0e2cd43d6692';

final class PlaceHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TraceEntry>>, String> {
  PlaceHistoryFamily._()
    : super(
        retry: null,
        name: r'placeHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PlaceHistoryProvider call(String id) =>
      PlaceHistoryProvider._(argument: id, from: this);

  @override
  String toString() => r'placeHistoryProvider';
}
