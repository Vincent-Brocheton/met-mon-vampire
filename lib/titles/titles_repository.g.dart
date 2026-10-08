// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'titles_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(titlesRepository)
final titlesRepositoryProvider = TitlesRepositoryProvider._();

final class TitlesRepositoryProvider
    extends
        $FunctionalProvider<
          TitlesRepository,
          TitlesRepository,
          TitlesRepository
        >
    with $Provider<TitlesRepository> {
  TitlesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'titlesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$titlesRepositoryHash();

  @$internal
  @override
  $ProviderElement<TitlesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TitlesRepository create(Ref ref) {
    return titlesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TitlesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TitlesRepository>(value),
    );
  }
}

String _$titlesRepositoryHash() => r'66fa4b7859fc3387e9e94b8efc064871924a89e7';

@ProviderFor(court)
final courtProvider = CourtProvider._();

final class CourtProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CourtEntry>>,
          List<CourtEntry>,
          Stream<List<CourtEntry>>
        >
    with $FutureModifier<List<CourtEntry>>, $StreamProvider<List<CourtEntry>> {
  CourtProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courtProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courtHash();

  @$internal
  @override
  $StreamProviderElement<List<CourtEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CourtEntry>> create(Ref ref) {
    return court(ref);
  }
}

String _$courtHash() => r'82b4d3ff448ab6dc390cdf3879c4f35881b2f665';
