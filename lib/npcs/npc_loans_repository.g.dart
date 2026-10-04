// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'npc_loans_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(npcLoansRepository)
final npcLoansRepositoryProvider = NpcLoansRepositoryProvider._();

final class NpcLoansRepositoryProvider
    extends
        $FunctionalProvider<
          NpcLoansRepository,
          NpcLoansRepository,
          NpcLoansRepository
        >
    with $Provider<NpcLoansRepository> {
  NpcLoansRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'npcLoansRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$npcLoansRepositoryHash();

  @$internal
  @override
  $ProviderElement<NpcLoansRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NpcLoansRepository create(Ref ref) {
    return npcLoansRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NpcLoansRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NpcLoansRepository>(value),
    );
  }
}

String _$npcLoansRepositoryHash() =>
    r'ba3a2c942437d23f7e590e7a690b9574ce2f5782';

@ProviderFor(allNpcLoans)
final allNpcLoansProvider = AllNpcLoansProvider._();

final class AllNpcLoansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NpcLoan>>,
          List<NpcLoan>,
          Stream<List<NpcLoan>>
        >
    with $FutureModifier<List<NpcLoan>>, $StreamProvider<List<NpcLoan>> {
  AllNpcLoansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allNpcLoansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allNpcLoansHash();

  @$internal
  @override
  $StreamProviderElement<List<NpcLoan>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NpcLoan>> create(Ref ref) {
    return allNpcLoans(ref);
  }
}

String _$allNpcLoansHash() => r'615f3eeed7964ab144fddf39cf8fed9a9c2abe79';

@ProviderFor(myNpcLoans)
final myNpcLoansProvider = MyNpcLoansProvider._();

final class MyNpcLoansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NpcLoan>>,
          List<NpcLoan>,
          Stream<List<NpcLoan>>
        >
    with $FutureModifier<List<NpcLoan>>, $StreamProvider<List<NpcLoan>> {
  MyNpcLoansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myNpcLoansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myNpcLoansHash();

  @$internal
  @override
  $StreamProviderElement<List<NpcLoan>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NpcLoan>> create(Ref ref) {
    return myNpcLoans(ref);
  }
}

String _$myNpcLoansHash() => r'bc12c0ec58c207008462094a7ae5d20b15dafb65';

@ProviderFor(characterNpcLoans)
final characterNpcLoansProvider = CharacterNpcLoansFamily._();

final class CharacterNpcLoansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NpcLoan>>,
          List<NpcLoan>,
          Stream<List<NpcLoan>>
        >
    with $FutureModifier<List<NpcLoan>>, $StreamProvider<List<NpcLoan>> {
  CharacterNpcLoansProvider._({
    required CharacterNpcLoansFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterNpcLoansProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterNpcLoansHash();

  @override
  String toString() {
    return r'characterNpcLoansProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<NpcLoan>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NpcLoan>> create(Ref ref) {
    final argument = this.argument as String;
    return characterNpcLoans(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterNpcLoansProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterNpcLoansHash() => r'6a6dc3d124b8b2dbc3b94c1294b904b54a034401';

final class CharacterNpcLoansFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<NpcLoan>>, String> {
  CharacterNpcLoansFamily._()
    : super(
        retry: null,
        name: r'characterNpcLoansProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CharacterNpcLoansProvider call(String characterId) =>
      CharacterNpcLoansProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterNpcLoansProvider';
}

@ProviderFor(npcLoanSheet)
final npcLoanSheetProvider = NpcLoanSheetFamily._();

final class NpcLoanSheetProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>?>,
          Map<String, dynamic>?,
          Stream<Map<String, dynamic>?>
        >
    with
        $FutureModifier<Map<String, dynamic>?>,
        $StreamProvider<Map<String, dynamic>?> {
  NpcLoanSheetProvider._({
    required NpcLoanSheetFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'npcLoanSheetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$npcLoanSheetHash();

  @override
  String toString() {
    return r'npcLoanSheetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Map<String, dynamic>?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, dynamic>?> create(Ref ref) {
    final argument = this.argument as String;
    return npcLoanSheet(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NpcLoanSheetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$npcLoanSheetHash() => r'064864f7a0bf0758876e43af4cab503682ac6780';

final class NpcLoanSheetFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Map<String, dynamic>?>, String> {
  NpcLoanSheetFamily._()
    : super(
        retry: null,
        name: r'npcLoanSheetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NpcLoanSheetProvider call(String loanId) =>
      NpcLoanSheetProvider._(argument: loanId, from: this);

  @override
  String toString() => r'npcLoanSheetProvider';
}
