// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'servants_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(servantsRepository)
final servantsRepositoryProvider = ServantsRepositoryProvider._();

final class ServantsRepositoryProvider
    extends
        $FunctionalProvider<
          ServantsRepository,
          ServantsRepository,
          ServantsRepository
        >
    with $Provider<ServantsRepository> {
  ServantsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'servantsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$servantsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ServantsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ServantsRepository create(Ref ref) {
    return servantsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServantsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServantsRepository>(value),
    );
  }
}

String _$servantsRepositoryHash() =>
    r'0b9638d54bf4a92d3168bbc95012a3bafcfd71fe';

@ProviderFor(allServantFiles)
final allServantFilesProvider = AllServantFilesProvider._();

final class AllServantFilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServantFile>>,
          List<ServantFile>,
          Stream<List<ServantFile>>
        >
    with
        $FutureModifier<List<ServantFile>>,
        $StreamProvider<List<ServantFile>> {
  AllServantFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allServantFilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allServantFilesHash();

  @$internal
  @override
  $StreamProviderElement<List<ServantFile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ServantFile>> create(Ref ref) {
    return allServantFiles(ref);
  }
}

String _$allServantFilesHash() => r'cf93eb0c2a860c97be613cf96f4b6b1ed210bc35';

/// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.

@ProviderFor(characterServantFiles)
final characterServantFilesProvider = CharacterServantFilesFamily._();

/// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.

final class CharacterServantFilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ServantFile>>,
          List<ServantFile>,
          Stream<List<ServantFile>>
        >
    with
        $FutureModifier<List<ServantFile>>,
        $StreamProvider<List<ServantFile>> {
  /// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.
  CharacterServantFilesProvider._({
    required CharacterServantFilesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterServantFilesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterServantFilesHash();

  @override
  String toString() {
    return r'characterServantFilesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ServantFile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ServantFile>> create(Ref ref) {
    final argument = this.argument as String;
    return characterServantFiles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterServantFilesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterServantFilesHash() =>
    r'c44c19ee538745d739b4383ce7adbe2a218d57be';

/// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.

final class CharacterServantFilesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ServantFile>>, String> {
  CharacterServantFilesFamily._()
    : super(
        retry: null,
        name: r'characterServantFilesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fiches détaillées des serviteurs d'un personnage : requête de l'équipe, ou fiches du joueur filtrées.

  CharacterServantFilesProvider call(String characterId) =>
      CharacterServantFilesProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterServantFilesProvider';
}

@ProviderFor(servantNote)
final servantNoteProvider = ServantNoteFamily._();

final class ServantNoteProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  ServantNoteProvider._({
    required ServantNoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'servantNoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$servantNoteHash();

  @override
  String toString() {
    return r'servantNoteProvider'
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
    return servantNote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ServantNoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$servantNoteHash() => r'6b0df4dcfca1882ec0ef98c2802f750f81aaa943';

final class ServantNoteFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String>, String> {
  ServantNoteFamily._()
    : super(
        retry: null,
        name: r'servantNoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ServantNoteProvider call(String id) =>
      ServantNoteProvider._(argument: id, from: this);

  @override
  String toString() => r'servantNoteProvider';
}

@ProviderFor(servantHistory)
final servantHistoryProvider = ServantHistoryFamily._();

final class ServantHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TraceEntry>>,
          List<TraceEntry>,
          Stream<List<TraceEntry>>
        >
    with $FutureModifier<List<TraceEntry>>, $StreamProvider<List<TraceEntry>> {
  ServantHistoryProvider._({
    required ServantHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'servantHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$servantHistoryHash();

  @override
  String toString() {
    return r'servantHistoryProvider'
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
    return servantHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ServantHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$servantHistoryHash() => r'2e356a8f870ce482240670676a03ed660ffebe2a';

final class ServantHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TraceEntry>>, String> {
  ServantHistoryFamily._()
    : super(
        retry: null,
        name: r'servantHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ServantHistoryProvider call(String id) =>
      ServantHistoryProvider._(argument: id, from: this);

  @override
  String toString() => r'servantHistoryProvider';
}
