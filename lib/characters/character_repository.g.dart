// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(characterRepository)
final characterRepositoryProvider = CharacterRepositoryProvider._();

final class CharacterRepositoryProvider
    extends
        $FunctionalProvider<
          CharacterRepository,
          CharacterRepository,
          CharacterRepository
        >
    with $Provider<CharacterRepository> {
  CharacterRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'characterRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$characterRepositoryHash();

  @$internal
  @override
  $ProviderElement<CharacterRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CharacterRepository create(Ref ref) {
    return characterRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CharacterRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CharacterRepository>(value),
    );
  }
}

String _$characterRepositoryHash() =>
    r'4f7b8cfa25dbfdb927e8c98db58c71f95abd4b65';

@ProviderFor(myCharacters)
final myCharactersProvider = MyCharactersProvider._();

final class MyCharactersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Character>>,
          List<Character>,
          Stream<List<Character>>
        >
    with $FutureModifier<List<Character>>, $StreamProvider<List<Character>> {
  MyCharactersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myCharactersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myCharactersHash();

  @$internal
  @override
  $StreamProviderElement<List<Character>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Character>> create(Ref ref) {
    return myCharacters(ref);
  }
}

String _$myCharactersHash() => r'1fd253f5fcd762b79181b331a401ecd8e78a07f3';

@ProviderFor(allCharacters)
final allCharactersProvider = AllCharactersProvider._();

final class AllCharactersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Character>>,
          List<Character>,
          Stream<List<Character>>
        >
    with $FutureModifier<List<Character>>, $StreamProvider<List<Character>> {
  AllCharactersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allCharactersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allCharactersHash();

  @$internal
  @override
  $StreamProviderElement<List<Character>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Character>> create(Ref ref) {
    return allCharacters(ref);
  }
}

String _$allCharactersHash() => r'67e2bbbfef42e6a8c430578cff1e0fd2312cb66b';

@ProviderFor(character)
final characterProvider = CharacterFamily._();

final class CharacterProvider
    extends
        $FunctionalProvider<
          AsyncValue<Character?>,
          Character?,
          Stream<Character?>
        >
    with $FutureModifier<Character?>, $StreamProvider<Character?> {
  CharacterProvider._({
    required CharacterFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterHash();

  @override
  String toString() {
    return r'characterProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Character?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Character?> create(Ref ref) {
    final argument = this.argument as String;
    return character(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterHash() => r'1fdf7bcae03b8c54553663b4035478fe15f47d0f';

final class CharacterFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Character?>, String> {
  CharacterFamily._()
    : super(
        retry: null,
        name: r'characterProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CharacterProvider call(String id) =>
      CharacterProvider._(argument: id, from: this);

  @override
  String toString() => r'characterProvider';
}

@ProviderFor(characterHistory)
final characterHistoryProvider = CharacterHistoryFamily._();

final class CharacterHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HistoryEntry>>,
          List<HistoryEntry>,
          Stream<List<HistoryEntry>>
        >
    with
        $FutureModifier<List<HistoryEntry>>,
        $StreamProvider<List<HistoryEntry>> {
  CharacterHistoryProvider._({
    required CharacterHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterHistoryHash();

  @override
  String toString() {
    return r'characterHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<HistoryEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HistoryEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return characterHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterHistoryHash() => r'857c015b540d409212fa88daeb3f08d7b089435c';

final class CharacterHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<HistoryEntry>>, String> {
  CharacterHistoryFamily._()
    : super(
        retry: null,
        name: r'characterHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CharacterHistoryProvider call(String id) =>
      CharacterHistoryProvider._(argument: id, from: this);

  @override
  String toString() => r'characterHistoryProvider';
}

@ProviderFor(characterNotes)
final characterNotesProvider = CharacterNotesFamily._();

final class CharacterNotesProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  CharacterNotesProvider._({
    required CharacterNotesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterNotesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterNotesHash();

  @override
  String toString() {
    return r'characterNotesProvider'
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
    return characterNotes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterNotesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterNotesHash() => r'487991ff35523b8fa450b38c859a5a35c2720027';

final class CharacterNotesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String>, String> {
  CharacterNotesFamily._()
    : super(
        retry: null,
        name: r'characterNotesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CharacterNotesProvider call(String id) =>
      CharacterNotesProvider._(argument: id, from: this);

  @override
  String toString() => r'characterNotesProvider';
}

@ProviderFor(reviewQueue)
final reviewQueueProvider = ReviewQueueProvider._();

final class ReviewQueueProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Character>>,
          List<Character>,
          Stream<List<Character>>
        >
    with $FutureModifier<List<Character>>, $StreamProvider<List<Character>> {
  ReviewQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewQueueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewQueueHash();

  @$internal
  @override
  $StreamProviderElement<List<Character>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Character>> create(Ref ref) {
    return reviewQueue(ref);
  }
}

String _$reviewQueueHash() => r'ad9bc18b2f161d002db6a0d7e43a817ff5d26e5a';
