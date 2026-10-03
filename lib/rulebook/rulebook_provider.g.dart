// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rulebook_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Référentiel des moteurs : null tant que le référentiel ou les valeurs de création chargent.
/// Lecture en erreur : valeurs de base, la création reste possible.

@ProviderFor(rulebook)
final rulebookProvider = RulebookProvider._();

/// Référentiel des moteurs : null tant que le référentiel ou les valeurs de création chargent.
/// Lecture en erreur : valeurs de base, la création reste possible.

final class RulebookProvider
    extends $FunctionalProvider<Rulebook?, Rulebook?, Rulebook?>
    with $Provider<Rulebook?> {
  /// Référentiel des moteurs : null tant que le référentiel ou les valeurs de création chargent.
  /// Lecture en erreur : valeurs de base, la création reste possible.
  RulebookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rulebookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rulebookHash();

  @$internal
  @override
  $ProviderElement<Rulebook?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Rulebook? create(Ref ref) {
    return rulebook(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Rulebook? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Rulebook?>(value),
    );
  }
}

String _$rulebookHash() => r'3a97a9bd3cdf2a6c3a8710099160c453d27201b3';
