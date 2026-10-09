// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_game_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineGameRepository)
final offlineGameRepositoryProvider = OfflineGameRepositoryProvider._();

final class OfflineGameRepositoryProvider
    extends
        $FunctionalProvider<
          OfflineGameRepository,
          OfflineGameRepository,
          OfflineGameRepository
        >
    with $Provider<OfflineGameRepository> {
  OfflineGameRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineGameRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineGameRepositoryHash();

  @$internal
  @override
  $ProviderElement<OfflineGameRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineGameRepository create(Ref ref) {
    return offlineGameRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineGameRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineGameRepository>(value),
    );
  }
}

String _$offlineGameRepositoryHash() =>
    r'3e5e521065d31b99a28feab3470d6bc6401efc5d';

@ProviderFor(trackedSins)
final trackedSinsProvider = TrackedSinsFamily._();

final class TrackedSinsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Tracked<Sin>>>,
          List<Tracked<Sin>>,
          Stream<List<Tracked<Sin>>>
        >
    with
        $FutureModifier<List<Tracked<Sin>>>,
        $StreamProvider<List<Tracked<Sin>>> {
  TrackedSinsProvider._({
    required TrackedSinsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trackedSinsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trackedSinsHash();

  @override
  String toString() {
    return r'trackedSinsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Tracked<Sin>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Tracked<Sin>>> create(Ref ref) {
    final argument = this.argument as String;
    return trackedSins(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackedSinsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trackedSinsHash() => r'b0cf367c4585faf3f477fdfd3166cda00b645eab';

final class TrackedSinsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Tracked<Sin>>>, String> {
  TrackedSinsFamily._()
    : super(
        retry: null,
        name: r'trackedSinsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TrackedSinsProvider call(String characterId) =>
      TrackedSinsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'trackedSinsProvider';
}

@ProviderFor(trackedEvents)
final trackedEventsProvider = TrackedEventsFamily._();

final class TrackedEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Tracked<StoryEvent>>>,
          List<Tracked<StoryEvent>>,
          Stream<List<Tracked<StoryEvent>>>
        >
    with
        $FutureModifier<List<Tracked<StoryEvent>>>,
        $StreamProvider<List<Tracked<StoryEvent>>> {
  TrackedEventsProvider._({
    required TrackedEventsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trackedEventsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trackedEventsHash();

  @override
  String toString() {
    return r'trackedEventsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Tracked<StoryEvent>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Tracked<StoryEvent>>> create(Ref ref) {
    final argument = this.argument as String;
    return trackedEvents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackedEventsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trackedEventsHash() => r'3bd6585aa5632093d10d174f3b33270acea20d2f';

final class TrackedEventsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Tracked<StoryEvent>>>, String> {
  TrackedEventsFamily._()
    : super(
        retry: null,
        name: r'trackedEventsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TrackedEventsProvider call(String characterId) =>
      TrackedEventsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'trackedEventsProvider';
}
