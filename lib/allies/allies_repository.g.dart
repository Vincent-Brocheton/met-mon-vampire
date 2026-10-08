// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allies_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(alliesRepository)
final alliesRepositoryProvider = AlliesRepositoryProvider._();

final class AlliesRepositoryProvider
    extends
        $FunctionalProvider<
          AlliesRepository,
          AlliesRepository,
          AlliesRepository
        >
    with $Provider<AlliesRepository> {
  AlliesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alliesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alliesRepositoryHash();

  @$internal
  @override
  $ProviderElement<AlliesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AlliesRepository create(Ref ref) {
    return alliesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlliesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlliesRepository>(value),
    );
  }
}

String _$alliesRepositoryHash() => r'c0d1105d42e92cd3c34756a234a2167edb530fe6';

@ProviderFor(allAllyFiles)
final allAllyFilesProvider = AllAllyFilesProvider._();

final class AllAllyFilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AllyFile>>,
          List<AllyFile>,
          Stream<List<AllyFile>>
        >
    with $FutureModifier<List<AllyFile>>, $StreamProvider<List<AllyFile>> {
  AllAllyFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allAllyFilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allAllyFilesHash();

  @$internal
  @override
  $StreamProviderElement<List<AllyFile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AllyFile>> create(Ref ref) {
    return allAllyFiles(ref);
  }
}

String _$allAllyFilesHash() => r'7399409b69f8bd0b64742e164d45d3e71a1363b1';

/// Suivi des alliés d'un personnage : requête de l'équipe, ou suivis du joueur filtrés par personnage.

@ProviderFor(characterAllyFiles)
final characterAllyFilesProvider = CharacterAllyFilesFamily._();

/// Suivi des alliés d'un personnage : requête de l'équipe, ou suivis du joueur filtrés par personnage.

final class CharacterAllyFilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AllyFile>>,
          List<AllyFile>,
          Stream<List<AllyFile>>
        >
    with $FutureModifier<List<AllyFile>>, $StreamProvider<List<AllyFile>> {
  /// Suivi des alliés d'un personnage : requête de l'équipe, ou suivis du joueur filtrés par personnage.
  CharacterAllyFilesProvider._({
    required CharacterAllyFilesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterAllyFilesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterAllyFilesHash();

  @override
  String toString() {
    return r'characterAllyFilesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<AllyFile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AllyFile>> create(Ref ref) {
    final argument = this.argument as String;
    return characterAllyFiles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterAllyFilesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterAllyFilesHash() =>
    r'95b85f35fe208b7e8abd549f6edf66a6de524a85';

/// Suivi des alliés d'un personnage : requête de l'équipe, ou suivis du joueur filtrés par personnage.

final class CharacterAllyFilesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<AllyFile>>, String> {
  CharacterAllyFilesFamily._()
    : super(
        retry: null,
        name: r'characterAllyFilesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Suivi des alliés d'un personnage : requête de l'équipe, ou suivis du joueur filtrés par personnage.

  CharacterAllyFilesProvider call(String characterId) =>
      CharacterAllyFilesProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterAllyFilesProvider';
}

@ProviderFor(allyHistory)
final allyHistoryProvider = AllyHistoryFamily._();

final class AllyHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TraceEntry>>,
          List<TraceEntry>,
          Stream<List<TraceEntry>>
        >
    with $FutureModifier<List<TraceEntry>>, $StreamProvider<List<TraceEntry>> {
  AllyHistoryProvider._({
    required AllyHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'allyHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$allyHistoryHash();

  @override
  String toString() {
    return r'allyHistoryProvider'
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
    return allyHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AllyHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$allyHistoryHash() => r'5ff644a17d49205747a05ae831bf39f69e83b569';

final class AllyHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TraceEntry>>, String> {
  AllyHistoryFamily._()
    : super(
        retry: null,
        name: r'allyHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AllyHistoryProvider call(String id) =>
      AllyHistoryProvider._(argument: id, from: this);

  @override
  String toString() => r'allyHistoryProvider';
}
