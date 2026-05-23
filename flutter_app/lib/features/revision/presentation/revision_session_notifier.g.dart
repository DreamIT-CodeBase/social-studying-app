// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revision_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$revisionSessionNotifierHash() =>
    r'ee85c2bc6a51e3d44d90fe828d0cc103635cd731';

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

abstract class _$RevisionSessionNotifier
    extends BuildlessAutoDisposeNotifier<RevisionSession> {
  late final String workspaceId;

  RevisionSession build(
    String workspaceId,
  );
}

/// Owns the state machine for a bounded revision session.
///
/// The plan is built at [start] and alternates question / flashcard
/// items, starting with a question. After each item is answered or
/// rated, [advance] either fetches the next item or transitions to the
/// `complete` state with a summary when the plan is exhausted.
///
/// All transitions are guarded — calling [submitAnswer] from a
/// flashcard state, or [rate] from a question state, is a no-op rather
/// than an error, so a stale UI tap can't corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId`, with
/// its own `keepAlive: false` (the default) so leaving the revision
/// screen disposes the session and a fresh launch starts a new plan.
///
/// Copied from [RevisionSessionNotifier].
@ProviderFor(RevisionSessionNotifier)
const revisionSessionNotifierProvider = RevisionSessionNotifierFamily();

/// Owns the state machine for a bounded revision session.
///
/// The plan is built at [start] and alternates question / flashcard
/// items, starting with a question. After each item is answered or
/// rated, [advance] either fetches the next item or transitions to the
/// `complete` state with a summary when the plan is exhausted.
///
/// All transitions are guarded — calling [submitAnswer] from a
/// flashcard state, or [rate] from a question state, is a no-op rather
/// than an error, so a stale UI tap can't corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId`, with
/// its own `keepAlive: false` (the default) so leaving the revision
/// screen disposes the session and a fresh launch starts a new plan.
///
/// Copied from [RevisionSessionNotifier].
class RevisionSessionNotifierFamily extends Family<RevisionSession> {
  /// Owns the state machine for a bounded revision session.
  ///
  /// The plan is built at [start] and alternates question / flashcard
  /// items, starting with a question. After each item is answered or
  /// rated, [advance] either fetches the next item or transitions to the
  /// `complete` state with a summary when the plan is exhausted.
  ///
  /// All transitions are guarded — calling [submitAnswer] from a
  /// flashcard state, or [rate] from a question state, is a no-op rather
  /// than an error, so a stale UI tap can't corrupt the state.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId`, with
  /// its own `keepAlive: false` (the default) so leaving the revision
  /// screen disposes the session and a fresh launch starts a new plan.
  ///
  /// Copied from [RevisionSessionNotifier].
  const RevisionSessionNotifierFamily();

  /// Owns the state machine for a bounded revision session.
  ///
  /// The plan is built at [start] and alternates question / flashcard
  /// items, starting with a question. After each item is answered or
  /// rated, [advance] either fetches the next item or transitions to the
  /// `complete` state with a summary when the plan is exhausted.
  ///
  /// All transitions are guarded — calling [submitAnswer] from a
  /// flashcard state, or [rate] from a question state, is a no-op rather
  /// than an error, so a stale UI tap can't corrupt the state.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId`, with
  /// its own `keepAlive: false` (the default) so leaving the revision
  /// screen disposes the session and a fresh launch starts a new plan.
  ///
  /// Copied from [RevisionSessionNotifier].
  RevisionSessionNotifierProvider call(
    String workspaceId,
  ) {
    return RevisionSessionNotifierProvider(
      workspaceId,
    );
  }

  @override
  RevisionSessionNotifierProvider getProviderOverride(
    covariant RevisionSessionNotifierProvider provider,
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
  String? get name => r'revisionSessionNotifierProvider';
}

/// Owns the state machine for a bounded revision session.
///
/// The plan is built at [start] and alternates question / flashcard
/// items, starting with a question. After each item is answered or
/// rated, [advance] either fetches the next item or transitions to the
/// `complete` state with a summary when the plan is exhausted.
///
/// All transitions are guarded — calling [submitAnswer] from a
/// flashcard state, or [rate] from a question state, is a no-op rather
/// than an error, so a stale UI tap can't corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId`, with
/// its own `keepAlive: false` (the default) so leaving the revision
/// screen disposes the session and a fresh launch starts a new plan.
///
/// Copied from [RevisionSessionNotifier].
class RevisionSessionNotifierProvider extends AutoDisposeNotifierProviderImpl<
    RevisionSessionNotifier, RevisionSession> {
  /// Owns the state machine for a bounded revision session.
  ///
  /// The plan is built at [start] and alternates question / flashcard
  /// items, starting with a question. After each item is answered or
  /// rated, [advance] either fetches the next item or transitions to the
  /// `complete` state with a summary when the plan is exhausted.
  ///
  /// All transitions are guarded — calling [submitAnswer] from a
  /// flashcard state, or [rate] from a question state, is a no-op rather
  /// than an error, so a stale UI tap can't corrupt the state.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId`, with
  /// its own `keepAlive: false` (the default) so leaving the revision
  /// screen disposes the session and a fresh launch starts a new plan.
  ///
  /// Copied from [RevisionSessionNotifier].
  RevisionSessionNotifierProvider(
    String workspaceId,
  ) : this._internal(
          () => RevisionSessionNotifier()..workspaceId = workspaceId,
          from: revisionSessionNotifierProvider,
          name: r'revisionSessionNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$revisionSessionNotifierHash,
          dependencies: RevisionSessionNotifierFamily._dependencies,
          allTransitiveDependencies:
              RevisionSessionNotifierFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  RevisionSessionNotifierProvider._internal(
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
  RevisionSession runNotifierBuild(
    covariant RevisionSessionNotifier notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(RevisionSessionNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: RevisionSessionNotifierProvider._internal(
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
  AutoDisposeNotifierProviderElement<RevisionSessionNotifier, RevisionSession>
      createElement() {
    return _RevisionSessionNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RevisionSessionNotifierProvider &&
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
mixin RevisionSessionNotifierRef
    on AutoDisposeNotifierProviderRef<RevisionSession> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _RevisionSessionNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<RevisionSessionNotifier,
        RevisionSession> with RevisionSessionNotifierRef {
  _RevisionSessionNotifierProviderElement(super.provider);

  @override
  String get workspaceId =>
      (origin as RevisionSessionNotifierProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
