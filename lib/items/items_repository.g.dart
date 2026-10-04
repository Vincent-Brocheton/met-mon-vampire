// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'items_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(itemsRepository)
final itemsRepositoryProvider = ItemsRepositoryProvider._();

final class ItemsRepositoryProvider
    extends
        $FunctionalProvider<ItemsRepository, ItemsRepository, ItemsRepository>
    with $Provider<ItemsRepository> {
  ItemsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'itemsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$itemsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ItemsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ItemsRepository create(Ref ref) {
    return itemsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ItemsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ItemsRepository>(value),
    );
  }
}

String _$itemsRepositoryHash() => r'f0e009d15ea7d204fa5e679c3645ff3c212ec686';

@ProviderFor(allItems)
final allItemsProvider = AllItemsProvider._();

final class AllItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Item>>,
          List<Item>,
          Stream<List<Item>>
        >
    with $FutureModifier<List<Item>>, $StreamProvider<List<Item>> {
  AllItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<Item>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Item>> create(Ref ref) {
    return allItems(ref);
  }
}

String _$allItemsHash() => r'1bef8a616e357ae801bc1b811e1ed1ac563cae37';

/// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.

@ProviderFor(characterItems)
final characterItemsProvider = CharacterItemsFamily._();

/// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.

final class CharacterItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Item>>,
          List<Item>,
          Stream<List<Item>>
        >
    with $FutureModifier<List<Item>>, $StreamProvider<List<Item>> {
  /// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.
  CharacterItemsProvider._({
    required CharacterItemsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterItemsHash();

  @override
  String toString() {
    return r'characterItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Item>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Item>> create(Ref ref) {
    final argument = this.argument as String;
    return characterItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterItemsHash() => r'0d47d6648079dbd1c799da21ffe8d0472dc1cc22';

/// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.

final class CharacterItemsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Item>>, String> {
  CharacterItemsFamily._()
    : super(
        retry: null,
        name: r'characterItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Objets d'un personnage : requête de l'équipe, ou objets du joueur filtrés par personnage.

  CharacterItemsProvider call(String characterId) =>
      CharacterItemsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterItemsProvider';
}

@ProviderFor(itemNote)
final itemNoteProvider = ItemNoteFamily._();

final class ItemNoteProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  ItemNoteProvider._({
    required ItemNoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'itemNoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemNoteHash();

  @override
  String toString() {
    return r'itemNoteProvider'
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
    return itemNote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemNoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemNoteHash() => r'895cced2903b845256ab3a7e73b7af7b3931534d';

final class ItemNoteFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String>, String> {
  ItemNoteFamily._()
    : super(
        retry: null,
        name: r'itemNoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ItemNoteProvider call(String id) =>
      ItemNoteProvider._(argument: id, from: this);

  @override
  String toString() => r'itemNoteProvider';
}

@ProviderFor(itemHistory)
final itemHistoryProvider = ItemHistoryFamily._();

final class ItemHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TraceEntry>>,
          List<TraceEntry>,
          Stream<List<TraceEntry>>
        >
    with $FutureModifier<List<TraceEntry>>, $StreamProvider<List<TraceEntry>> {
  ItemHistoryProvider._({
    required ItemHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'itemHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemHistoryHash();

  @override
  String toString() {
    return r'itemHistoryProvider'
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
    return itemHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemHistoryHash() => r'867ffbe3158d1f8cbdc241c70d91a416433b5db3';

final class ItemHistoryFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TraceEntry>>, String> {
  ItemHistoryFamily._()
    : super(
        retry: null,
        name: r'itemHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ItemHistoryProvider call(String id) =>
      ItemHistoryProvider._(argument: id, from: this);

  @override
  String toString() => r'itemHistoryProvider';
}
