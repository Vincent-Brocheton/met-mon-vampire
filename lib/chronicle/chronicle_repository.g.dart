// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chronicle_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(chronicleRepository)
final chronicleRepositoryProvider = ChronicleRepositoryProvider._();

final class ChronicleRepositoryProvider
    extends
        $FunctionalProvider<
          ChronicleRepository,
          ChronicleRepository,
          ChronicleRepository
        >
    with $Provider<ChronicleRepository> {
  ChronicleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chronicleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chronicleRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChronicleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChronicleRepository create(Ref ref) {
    return chronicleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChronicleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChronicleRepository>(value),
    );
  }
}

String _$chronicleRepositoryHash() =>
    r'620da29962f093b3950e842494578e44187c0774';

@ProviderFor(pendingUsers)
final pendingUsersProvider = PendingUsersProvider._();

final class PendingUsersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppUser>>,
          List<AppUser>,
          Stream<List<AppUser>>
        >
    with $FutureModifier<List<AppUser>>, $StreamProvider<List<AppUser>> {
  PendingUsersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingUsersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingUsersHash();

  @$internal
  @override
  $StreamProviderElement<List<AppUser>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AppUser>> create(Ref ref) {
    return pendingUsers(ref);
  }
}

String _$pendingUsersHash() => r'c3bf8a2b636a28e99d88937e64bfe705fa5d398a';

@ProviderFor(allUsers)
final allUsersProvider = AllUsersProvider._();

final class AllUsersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppUser>>,
          List<AppUser>,
          Stream<List<AppUser>>
        >
    with $FutureModifier<List<AppUser>>, $StreamProvider<List<AppUser>> {
  AllUsersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allUsersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allUsersHash();

  @$internal
  @override
  $StreamProviderElement<List<AppUser>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AppUser>> create(Ref ref) {
    return allUsers(ref);
  }
}

String _$allUsersHash() => r'ceda980c13b4d7813b7e00ff5695b9712a9cbe16';

@ProviderFor(invitations)
final invitationsProvider = InvitationsProvider._();

final class InvitationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Invitation>>,
          List<Invitation>,
          Stream<List<Invitation>>
        >
    with $FutureModifier<List<Invitation>>, $StreamProvider<List<Invitation>> {
  InvitationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invitationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invitationsHash();

  @$internal
  @override
  $StreamProviderElement<List<Invitation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Invitation>> create(Ref ref) {
    return invitations(ref);
  }
}

String _$invitationsHash() => r'542a6d536908820546b423f364654425a4803349';
