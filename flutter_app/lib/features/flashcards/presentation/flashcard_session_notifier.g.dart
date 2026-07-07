// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$flashcardSessionNotifierHash() =>
    r'a567a6eff6200d9968a972ab3b4d47ad291af461';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$FlashcardSessionNotifier
    extends BuildlessAutoDisposeNotifier<FlashcardSession> {
  late final String workspaceId;

  FlashcardSession build(
    String workspaceId,
  );
}

/// Owns the state machine for one flashcard-review session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
/// - [flip]            — reveal the back (viewingFront → revealed)
/// - [rate]            — submit a self-rating (revealed → rating → rated)
///
/// All transitions are guarded — calling [rate] before [flip], or
/// [flip] before a card has loaded, is a no-op rather than an error,
/// so a stale UI tap can't corrupt the state. In particular [rate] is
/// only valid from `revealed`: a student cannot rate recall on a card
/// whose back they never saw.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
///
/// Copied from [FlashcardSessionNotifier].
@ProviderFor(FlashcardSessionNotifier)
const flashcardSessionNotifierProvider = FlashcardSessionNotifierFamily();

/// Owns the state machine for one flashcard-review session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
/// - [flip]            — reveal the back (viewingFront → revealed)
/// - [rate]            — submit a self-rating (revealed → rating → rated)
///
/// All transitions are guarded — calling [rate] before [flip], or
/// [flip] before a card has loaded, is a no-op rather than an error,
/// so a stale UI tap can't corrupt the state. In particular [rate] is
/// only valid from `revealed`: a student cannot rate recall on a card
/// whose back they never saw.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
///
/// Copied from [FlashcardSessionNotifier].
class FlashcardSessionNotifierFamily extends Family<FlashcardSession> {
  /// Owns the state machine for one flashcard-review session.
  ///
  /// Methods correspond to user actions in the UI:
  ///
  /// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
  /// - [flip]            — reveal the back (viewingFront → revealed)
  /// - [rate]            — submit a self-rating (revealed → rating → rated)
  ///
  /// All transitions are guarded — calling [rate] before [flip], or
  /// [flip] before a card has loaded, is a no-op rather than an error,
  /// so a stale UI tap can't corrupt the state. In particular [rate] is
  /// only valid from `revealed`: a student cannot rate recall on a card
  /// whose back they never saw.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId` so
  /// switching workspaces yields a fresh session rather than carrying
  /// state across boundaries.
  ///
  /// Copied from [FlashcardSessionNotifier].
  const FlashcardSessionNotifierFamily();

  /// Owns the state machine for one flashcard-review session.
  ///
  /// Methods correspond to user actions in the UI:
  ///
  /// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
  /// - [flip]            — reveal the back (viewingFront → revealed)
  /// - [rate]            — submit a self-rating (revealed → rating → rated)
  ///
  /// All transitions are guarded — calling [rate] before [flip], or
  /// [flip] before a card has loaded, is a no-op rather than an error,
  /// so a stale UI tap can't corrupt the state. In particular [rate] is
  /// only valid from `revealed`: a student cannot rate recall on a card
  /// whose back they never saw.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId` so
  /// switching workspaces yields a fresh session rather than carrying
  /// state across boundaries.
  ///
  /// Copied from [FlashcardSessionNotifier].
  FlashcardSessionNotifierProvider call(
    String workspaceId,
  ) {
    return FlashcardSessionNotifierProvider(
      workspaceId,
    );
  }

  @override
  FlashcardSessionNotifierProvider getProviderOverride(
    covariant FlashcardSessionNotifierProvider provider,
  ) {
    return call(
      provider.workspaceId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'flashcardSessionNotifierProvider';
}

/// Owns the state machine for one flashcard-review session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
/// - [flip]            — reveal the back (viewingFront → revealed)
/// - [rate]            — submit a self-rating (revealed → rating → rated)
///
/// All transitions are guarded — calling [rate] before [flip], or
/// [flip] before a card has loaded, is a no-op rather than an error,
/// so a stale UI tap can't corrupt the state. In particular [rate] is
/// only valid from `revealed`: a student cannot rate recall on a card
/// whose back they never saw.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
///
/// Copied from [FlashcardSessionNotifier].
class FlashcardSessionNotifierProvider extends AutoDisposeNotifierProviderImpl<
    FlashcardSessionNotifier, FlashcardSession> {
  /// Owns the state machine for one flashcard-review session.
  ///
  /// Methods correspond to user actions in the UI:
  ///
  /// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
  /// - [flip]            — reveal the back (viewingFront → revealed)
  /// - [rate]            — submit a self-rating (revealed → rating → rated)
  ///
  /// All transitions are guarded — calling [rate] before [flip], or
  /// [flip] before a card has loaded, is a no-op rather than an error,
  /// so a stale UI tap can't corrupt the state. In particular [rate] is
  /// only valid from `revealed`: a student cannot rate recall on a card
  /// whose back they never saw.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId` so
  /// switching workspaces yields a fresh session rather than carrying
  /// state across boundaries.
  ///
  /// Copied from [FlashcardSessionNotifier].
  FlashcardSessionNotifierProvider(
    String workspaceId,
  ) : this._internal(
          () => FlashcardSessionNotifier()..workspaceId = workspaceId,
          from: flashcardSessionNotifierProvider,
          name: r'flashcardSessionNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$flashcardSessionNotifierHash,
          dependencies: FlashcardSessionNotifierFamily._dependencies,
          allTransitiveDependencies:
              FlashcardSessionNotifierFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  FlashcardSessionNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.workspaceId,
  }) : super.internal();

  final String workspaceId;

  @override
  FlashcardSession runNotifierBuild(
    covariant FlashcardSessionNotifier notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(FlashcardSessionNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FlashcardSessionNotifierProvider._internal(
        () => create()..workspaceId = workspaceId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        workspaceId: workspaceId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<FlashcardSessionNotifier, FlashcardSession>
      createElement() {
    return _FlashcardSessionNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FlashcardSessionNotifierProvider &&
        other.workspaceId == workspaceId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, workspaceId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FlashcardSessionNotifierRef
    on AutoDisposeNotifierProviderRef<FlashcardSession> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _FlashcardSessionNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<FlashcardSessionNotifier,
        FlashcardSession> with FlashcardSessionNotifierRef {
  _FlashcardSessionNotifierProviderElement(super.provider);

  @override
  String get workspaceId =>
      (origin as FlashcardSessionNotifierProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
