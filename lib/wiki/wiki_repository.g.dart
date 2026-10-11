// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wiki_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(wikiRepository)
final wikiRepositoryProvider = WikiRepositoryProvider._();

final class WikiRepositoryProvider
    extends $FunctionalProvider<WikiRepository, WikiRepository, WikiRepository>
    with $Provider<WikiRepository> {
  WikiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wikiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wikiRepositoryHash();

  @$internal
  @override
  $ProviderElement<WikiRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WikiRepository create(Ref ref) {
    return wikiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WikiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WikiRepository>(value),
    );
  }
}

String _$wikiRepositoryHash() => r'9ea42dcdee9ba454c3091664e2d743ba86188d5a';

/// Pages publiées lisibles : toutes pour l'équipe, celles des audiences du joueur sinon.

@ProviderFor(wikiPages)
final wikiPagesProvider = WikiPagesProvider._();

/// Pages publiées lisibles : toutes pour l'équipe, celles des audiences du joueur sinon.

final class WikiPagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WikiPage>>,
          List<WikiPage>,
          Stream<List<WikiPage>>
        >
    with $FutureModifier<List<WikiPage>>, $StreamProvider<List<WikiPage>> {
  /// Pages publiées lisibles : toutes pour l'équipe, celles des audiences du joueur sinon.
  WikiPagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wikiPagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wikiPagesHash();

  @$internal
  @override
  $StreamProviderElement<List<WikiPage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WikiPage>> create(Ref ref) {
    return wikiPages(ref);
  }
}

String _$wikiPagesHash() => r'c3740d01c00431deae308ddbfa03d235c9eea1de';

@ProviderFor(wikiDrafts)
final wikiDraftsProvider = WikiDraftsProvider._();

final class WikiDraftsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WikiPage>>,
          List<WikiPage>,
          Stream<List<WikiPage>>
        >
    with $FutureModifier<List<WikiPage>>, $StreamProvider<List<WikiPage>> {
  WikiDraftsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wikiDraftsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wikiDraftsHash();

  @$internal
  @override
  $StreamProviderElement<List<WikiPage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WikiPage>> create(Ref ref) {
    return wikiDrafts(ref);
  }
}

String _$wikiDraftsHash() => r'0eb4f43c07f95754468c38ff637c67d829408324';

/// Recalcule `wikiAudiences` des comptes d'après les fiches et écrit les différences (conteur et principal).
/// Lancé par la liste des fiches et par le wiki du conte ; sans différence, rien n'est écrit.

@ProviderFor(wikiAudienceSync)
final wikiAudienceSyncProvider = WikiAudienceSyncProvider._();

/// Recalcule `wikiAudiences` des comptes d'après les fiches et écrit les différences (conteur et principal).
/// Lancé par la liste des fiches et par le wiki du conte ; sans différence, rien n'est écrit.

final class WikiAudienceSyncProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Recalcule `wikiAudiences` des comptes d'après les fiches et écrit les différences (conteur et principal).
  /// Lancé par la liste des fiches et par le wiki du conte ; sans différence, rien n'est écrit.
  WikiAudienceSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wikiAudienceSyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wikiAudienceSyncHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return wikiAudienceSync(ref);
  }
}

String _$wikiAudienceSyncHash() => r'7a151c1f568ac12ca835e743ebccce9351bae597';
