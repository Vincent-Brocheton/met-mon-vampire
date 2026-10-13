// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationsRepository)
final notificationsRepositoryProvider = NotificationsRepositoryProvider._();

final class NotificationsRepositoryProvider
    extends
        $FunctionalProvider<
          NotificationsRepository,
          NotificationsRepository,
          NotificationsRepository
        >
    with $Provider<NotificationsRepository> {
  NotificationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<NotificationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationsRepository create(Ref ref) {
    return notificationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationsRepository>(value),
    );
  }
}

String _$notificationsRepositoryHash() =>
    r'fb3a00c48b2db3ba5db1ffbd16bb2e5e79dbb639';

/// Fil du lecteur, calculé à partir des données que l'application lit déjà (conte ou joueur selon le rôle).

@ProviderFor(notifications)
final notificationsProvider = NotificationsProvider._();

/// Fil du lecteur, calculé à partir des données que l'application lit déjà (conte ou joueur selon le rôle).

final class NotificationsProvider
    extends
        $FunctionalProvider<
          List<AppNotification>,
          List<AppNotification>,
          List<AppNotification>
        >
    with $Provider<List<AppNotification>> {
  /// Fil du lecteur, calculé à partir des données que l'application lit déjà (conte ou joueur selon le rôle).
  NotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsHash();

  @$internal
  @override
  $ProviderElement<List<AppNotification>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<AppNotification> create(Ref ref) {
    return notifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<AppNotification> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<AppNotification>>(value),
    );
  }
}

String _$notificationsHash() => r'db8e885b45fe1694a68243b6929ffc3c4ac0cccb';

/// Nombre de notifications non lues (point rouge de la cloche).

@ProviderFor(unreadNotifications)
final unreadNotificationsProvider = UnreadNotificationsProvider._();

/// Nombre de notifications non lues (point rouge de la cloche).

final class UnreadNotificationsProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Nombre de notifications non lues (point rouge de la cloche).
  UnreadNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNotificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNotificationsHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadNotificationsHash() =>
    r'96b855153d4a7594c7adc7d6089b04dc1f770e0c';
