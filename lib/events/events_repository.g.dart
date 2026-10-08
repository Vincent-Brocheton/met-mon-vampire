// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(eventsRepository)
final eventsRepositoryProvider = EventsRepositoryProvider._();

final class EventsRepositoryProvider
    extends
        $FunctionalProvider<
          EventsRepository,
          EventsRepository,
          EventsRepository
        >
    with $Provider<EventsRepository> {
  EventsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventsRepositoryHash();

  @$internal
  @override
  $ProviderElement<EventsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventsRepository create(Ref ref) {
    return eventsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventsRepository>(value),
    );
  }
}

String _$eventsRepositoryHash() => r'59110b09d6ce22f93e6491d6b17b1a63ffdb211a';

/// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.

@ProviderFor(characterEvents)
final characterEventsProvider = CharacterEventsFamily._();

/// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.

final class CharacterEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoryEvent>>,
          List<StoryEvent>,
          Stream<List<StoryEvent>>
        >
    with $FutureModifier<List<StoryEvent>>, $StreamProvider<List<StoryEvent>> {
  /// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.
  CharacterEventsProvider._({
    required CharacterEventsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'characterEventsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$characterEventsHash();

  @override
  String toString() {
    return r'characterEventsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<StoryEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StoryEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return characterEvents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterEventsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$characterEventsHash() => r'6fb667b1414cb90e25d93ed28206c8cb0e2c2a11';

/// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.

final class CharacterEventsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<StoryEvent>>, String> {
  CharacterEventsFamily._()
    : super(
        retry: null,
        name: r'characterEventsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Événements d'une fiche : tous pour l'équipe, ceux ouverts au joueur sinon.

  CharacterEventsProvider call(String characterId) =>
      CharacterEventsProvider._(argument: characterId, from: this);

  @override
  String toString() => r'characterEventsProvider';
}
