// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Vrai quand les parties viennent du cache de l'appareil : pas de réseau. Faux tant que rien n'est arrivé, et sans compte.

@ProviderFor(offline)
final offlineProvider = OfflineProvider._();

/// Vrai quand les parties viennent du cache de l'appareil : pas de réseau. Faux tant que rien n'est arrivé, et sans compte.

final class OfflineProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Vrai quand les parties viennent du cache de l'appareil : pas de réseau. Faux tant que rien n'est arrivé, et sans compte.
  OfflineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return offline(ref);
  }
}

String _$offlineHash() => r'b4065f4b2cd2c40e89c0a21204433780e71dfdc6';
