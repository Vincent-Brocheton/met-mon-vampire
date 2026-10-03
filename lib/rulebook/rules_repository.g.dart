// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(rulesRepository)
final rulesRepositoryProvider = RulesRepositoryProvider._();

final class RulesRepositoryProvider
    extends
        $FunctionalProvider<RulesRepository, RulesRepository, RulesRepository>
    with $Provider<RulesRepository> {
  RulesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rulesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rulesRepositoryHash();

  @$internal
  @override
  $ProviderElement<RulesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RulesRepository create(Ref ref) {
    return rulesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RulesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RulesRepository>(value),
    );
  }
}

String _$rulesRepositoryHash() => r'a22b295fb2c4d7e0a3b378d4c8313e9b279d2098';

@ProviderFor(allRuleEntries)
final allRuleEntriesProvider = AllRuleEntriesProvider._();

final class AllRuleEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<RuleEntry>>>,
          Map<String, List<RuleEntry>>,
          Stream<Map<String, List<RuleEntry>>>
        >
    with
        $FutureModifier<Map<String, List<RuleEntry>>>,
        $StreamProvider<Map<String, List<RuleEntry>>> {
  AllRuleEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allRuleEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allRuleEntriesHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, List<RuleEntry>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, List<RuleEntry>>> create(Ref ref) {
    return allRuleEntries(ref);
  }
}

String _$allRuleEntriesHash() => r'5c9a862233bacb204a2f6fce14cac390108489eb';

@ProviderFor(allRuleSettings)
final allRuleSettingsProvider = AllRuleSettingsProvider._();

final class AllRuleSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Map<String, dynamic>>>,
          Map<String, Map<String, dynamic>>,
          Stream<Map<String, Map<String, dynamic>>>
        >
    with
        $FutureModifier<Map<String, Map<String, dynamic>>>,
        $StreamProvider<Map<String, Map<String, dynamic>>> {
  AllRuleSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allRuleSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allRuleSettingsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, Map<String, dynamic>>> create(Ref ref) {
    return allRuleSettings(ref);
  }
}

String _$allRuleSettingsHash() => r'd99dbad9b5a883981565fca4f5472158454aae59';
