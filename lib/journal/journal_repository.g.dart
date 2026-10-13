// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(journalRepository)
final journalRepositoryProvider = JournalRepositoryProvider._();

final class JournalRepositoryProvider
    extends
        $FunctionalProvider<
          JournalRepository,
          JournalRepository,
          JournalRepository
        >
    with $Provider<JournalRepository> {
  JournalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journalRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journalRepositoryHash();

  @$internal
  @override
  $ProviderElement<JournalRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  JournalRepository create(Ref ref) {
    return journalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JournalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JournalRepository>(value),
    );
  }
}

String _$journalRepositoryHash() => r'9ab80c2f3157dda82a3bc24379409c488931b1a2';

@ProviderFor(journalHistory)
final journalHistoryProvider = JournalHistoryFamily._();

final class JournalHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RawHistory>>,
          List<RawHistory>,
          Stream<List<RawHistory>>
        >
    with $FutureModifier<List<RawHistory>>, $StreamProvider<List<RawHistory>> {
  JournalHistoryProvider._({
    required JournalHistoryFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'journalHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$journalHistoryHash();

  @override
  String toString() {
    return r'journalHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<RawHistory>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RawHistory>> create(Ref ref) {
    final argument = this.argument as DateTime?;
    return journalHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journalHistoryHash() => r'c0ae3f3bd22e5c4a658924f14a70393d5f6106e3';

final class JournalHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<RawHistory>>, DateTime?> {
  JournalHistoryFamily._()
    : super(
        retry: null,
        name: r'journalHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JournalHistoryProvider call(DateTime? since) =>
      JournalHistoryProvider._(argument: since, from: this);

  @override
  String toString() => r'journalHistoryProvider';
}

@ProviderFor(journalVersions)
final journalVersionsProvider = JournalVersionsFamily._();

final class JournalVersionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RawVersion>>,
          List<RawVersion>,
          Stream<List<RawVersion>>
        >
    with $FutureModifier<List<RawVersion>>, $StreamProvider<List<RawVersion>> {
  JournalVersionsProvider._({
    required JournalVersionsFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'journalVersionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$journalVersionsHash();

  @override
  String toString() {
    return r'journalVersionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<RawVersion>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RawVersion>> create(Ref ref) {
    final argument = this.argument as DateTime?;
    return journalVersions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalVersionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journalVersionsHash() => r'd6f98d9670c0b17677e763ebf1ab0e8b8c9b3701';

final class JournalVersionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<RawVersion>>, DateTime?> {
  JournalVersionsFamily._()
    : super(
        retry: null,
        name: r'journalVersionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JournalVersionsProvider call(DateTime? since) =>
      JournalVersionsProvider._(argument: since, from: this);

  @override
  String toString() => r'journalVersionsProvider';
}

@ProviderFor(journalStored)
final journalStoredProvider = JournalStoredFamily._();

final class JournalStoredProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JournalLine>>,
          List<JournalLine>,
          Stream<List<JournalLine>>
        >
    with
        $FutureModifier<List<JournalLine>>,
        $StreamProvider<List<JournalLine>> {
  JournalStoredProvider._({
    required JournalStoredFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'journalStoredProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$journalStoredHash();

  @override
  String toString() {
    return r'journalStoredProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<JournalLine>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<JournalLine>> create(Ref ref) {
    final argument = this.argument as DateTime?;
    return journalStored(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalStoredProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journalStoredHash() => r'47f9b4699b1c62446058072bb78687519f9a6205';

final class JournalStoredFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<JournalLine>>, DateTime?> {
  JournalStoredFamily._()
    : super(
        retry: null,
        name: r'journalStoredProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JournalStoredProvider call(DateTime? since) =>
      JournalStoredProvider._(argument: since, from: this);

  @override
  String toString() => r'journalStoredProvider';
}

/// Journal depuis [since] (tout si null) : historiques, versions du wiki, parties et lignes stockées, avec les noms.

@ProviderFor(journal)
final journalProvider = JournalFamily._();

/// Journal depuis [since] (tout si null) : historiques, versions du wiki, parties et lignes stockées, avec les noms.

final class JournalProvider
    extends $FunctionalProvider<JournalFeed, JournalFeed, JournalFeed>
    with $Provider<JournalFeed> {
  /// Journal depuis [since] (tout si null) : historiques, versions du wiki, parties et lignes stockées, avec les noms.
  JournalProvider._({
    required JournalFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'journalProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$journalHash();

  @override
  String toString() {
    return r'journalProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<JournalFeed> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JournalFeed create(Ref ref) {
    final argument = this.argument as DateTime?;
    return journal(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JournalFeed value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JournalFeed>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JournalProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journalHash() => r'2dd9d2a9f48b5deac3b0f58518e4e33388f4ea94';

/// Journal depuis [since] (tout si null) : historiques, versions du wiki, parties et lignes stockées, avec les noms.

final class JournalFamily extends $Family
    with $FunctionalFamilyOverride<JournalFeed, DateTime?> {
  JournalFamily._()
    : super(
        retry: null,
        name: r'journalProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Journal depuis [since] (tout si null) : historiques, versions du wiki, parties et lignes stockées, avec les noms.

  JournalProvider call(DateTime? since) =>
      JournalProvider._(argument: since, from: this);

  @override
  String toString() => r'journalProvider';
}
