// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'games_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(gamesRepository)
final gamesRepositoryProvider = GamesRepositoryProvider._();

final class GamesRepositoryProvider
    extends
        $FunctionalProvider<GamesRepository, GamesRepository, GamesRepository>
    with $Provider<GamesRepository> {
  GamesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gamesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gamesRepositoryHash();

  @$internal
  @override
  $ProviderElement<GamesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GamesRepository create(Ref ref) {
    return gamesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GamesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GamesRepository>(value),
    );
  }
}

String _$gamesRepositoryHash() => r'baf36b7c6154ff128ed18a85a14101239d33ba1b';

@ProviderFor(games)
final gamesProvider = GamesProvider._();

final class GamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Game>>,
          List<Game>,
          Stream<List<Game>>
        >
    with $FutureModifier<List<Game>>, $StreamProvider<List<Game>> {
  GamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gamesHash();

  @$internal
  @override
  $StreamProviderElement<List<Game>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Game>> create(Ref ref) {
    return games(ref);
  }
}

String _$gamesHash() => r'2272c3051049a283059f87c3e0f19657b625599b';

@ProviderFor(gameSnapshots)
final gameSnapshotsProvider = GameSnapshotsFamily._();

final class GameSnapshotsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FrozenSheet>>,
          List<FrozenSheet>,
          Stream<List<FrozenSheet>>
        >
    with
        $FutureModifier<List<FrozenSheet>>,
        $StreamProvider<List<FrozenSheet>> {
  GameSnapshotsProvider._({
    required GameSnapshotsFamily super.from,
    required (String, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'gameSnapshotsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gameSnapshotsHash();

  @override
  String toString() {
    return r'gameSnapshotsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<FrozenSheet>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<FrozenSheet>> create(Ref ref) {
    final argument = this.argument as (String, DateTime);
    return gameSnapshots(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is GameSnapshotsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gameSnapshotsHash() => r'f2b6c362aaebe7f6cc33545f06eb1ac8a75b62d0';

final class GameSnapshotsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<FrozenSheet>>,
          (String, DateTime)
        > {
  GameSnapshotsFamily._()
    : super(
        retry: null,
        name: r'gameSnapshotsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GameSnapshotsProvider call(String gameId, DateTime gameDate) =>
      GameSnapshotsProvider._(argument: (gameId, gameDate), from: this);

  @override
  String toString() => r'gameSnapshotsProvider';
}

@ProviderFor(frozenSheet)
final frozenSheetProvider = FrozenSheetFamily._();

final class FrozenSheetProvider
    extends
        $FunctionalProvider<
          AsyncValue<FrozenSheet?>,
          FrozenSheet?,
          Stream<FrozenSheet?>
        >
    with $FutureModifier<FrozenSheet?>, $StreamProvider<FrozenSheet?> {
  FrozenSheetProvider._({
    required FrozenSheetFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'frozenSheetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$frozenSheetHash();

  @override
  String toString() {
    return r'frozenSheetProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<FrozenSheet?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<FrozenSheet?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return frozenSheet(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is FrozenSheetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$frozenSheetHash() => r'8b33cc5b244d5fc823064cc62cd4918bb44dc4f1';

final class FrozenSheetFamily extends $Family
    with $FunctionalFamilyOverride<Stream<FrozenSheet?>, (String, String)> {
  FrozenSheetFamily._()
    : super(
        retry: null,
        name: r'frozenSheetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FrozenSheetProvider call(String characterId, String gameId) =>
      FrozenSheetProvider._(argument: (characterId, gameId), from: this);

  @override
  String toString() => r'frozenSheetProvider';
}
