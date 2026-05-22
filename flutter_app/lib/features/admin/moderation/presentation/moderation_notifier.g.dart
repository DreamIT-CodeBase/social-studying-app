// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moderation_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$moderationQueueHash() => r'99c757af548476dbad6ecaf88b3ec3990e1212f0';

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

abstract class _$ModerationQueue
    extends BuildlessAutoDisposeAsyncNotifier<List<FlaggedItem>> {
  late final String workspaceId;

  FutureOr<List<FlaggedItem>> build(
    String workspaceId,
  );
}

/// The pending moderation queue for one workspace. Backs the flagged-
/// content list on the moderation dashboard (4.5). Family-keyed by
/// `workspaceId`.
///
/// Copied from [ModerationQueue].
@ProviderFor(ModerationQueue)
const moderationQueueProvider = ModerationQueueFamily();

/// The pending moderation queue for one workspace. Backs the flagged-
/// content list on the moderation dashboard (4.5). Family-keyed by
/// `workspaceId`.
///
/// Copied from [ModerationQueue].
class ModerationQueueFamily extends Family<AsyncValue<List<FlaggedItem>>> {
  /// The pending moderation queue for one workspace. Backs the flagged-
  /// content list on the moderation dashboard (4.5). Family-keyed by
  /// `workspaceId`.
  ///
  /// Copied from [ModerationQueue].
  const ModerationQueueFamily();

  /// The pending moderation queue for one workspace. Backs the flagged-
  /// content list on the moderation dashboard (4.5). Family-keyed by
  /// `workspaceId`.
  ///
  /// Copied from [ModerationQueue].
  ModerationQueueProvider call(
    String workspaceId,
  ) {
    return ModerationQueueProvider(
      workspaceId,
    );
  }

  @override
  ModerationQueueProvider getProviderOverride(
    covariant ModerationQueueProvider provider,
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
  String? get name => r'moderationQueueProvider';
}

/// The pending moderation queue for one workspace. Backs the flagged-
/// content list on the moderation dashboard (4.5). Family-keyed by
/// `workspaceId`.
///
/// Copied from [ModerationQueue].
class ModerationQueueProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ModerationQueue, List<FlaggedItem>> {
  /// The pending moderation queue for one workspace. Backs the flagged-
  /// content list on the moderation dashboard (4.5). Family-keyed by
  /// `workspaceId`.
  ///
  /// Copied from [ModerationQueue].
  ModerationQueueProvider(
    String workspaceId,
  ) : this._internal(
          () => ModerationQueue()..workspaceId = workspaceId,
          from: moderationQueueProvider,
          name: r'moderationQueueProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$moderationQueueHash,
          dependencies: ModerationQueueFamily._dependencies,
          allTransitiveDependencies:
              ModerationQueueFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  ModerationQueueProvider._internal(
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
  FutureOr<List<FlaggedItem>> runNotifierBuild(
    covariant ModerationQueue notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(ModerationQueue Function() create) {
    return ProviderOverride(
      origin: this,
      override: ModerationQueueProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ModerationQueue, List<FlaggedItem>>
      createElement() {
    return _ModerationQueueProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ModerationQueueProvider && other.workspaceId == workspaceId;
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
mixin ModerationQueueRef
    on AutoDisposeAsyncNotifierProviderRef<List<FlaggedItem>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _ModerationQueueProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ModerationQueue,
        List<FlaggedItem>> with ModerationQueueRef {
  _ModerationQueueProviderElement(super.provider);

  @override
  String get workspaceId => (origin as ModerationQueueProvider).workspaceId;
}

String _$moderationLogHash() => r'9ea59f4725ff634385cfe4cf098bf1b61b80175b';

abstract class _$ModerationLog
    extends BuildlessAutoDisposeAsyncNotifier<List<FlaggedItem>> {
  late final String workspaceId;

  FutureOr<List<FlaggedItem>> build(
    String workspaceId,
  );
}

/// The resolved-items audit log for one workspace — the second tab of
/// the moderation dashboard. Read-only; separate provider so opening
/// the log doesn't disturb the live queue's state.
///
/// Copied from [ModerationLog].
@ProviderFor(ModerationLog)
const moderationLogProvider = ModerationLogFamily();

/// The resolved-items audit log for one workspace — the second tab of
/// the moderation dashboard. Read-only; separate provider so opening
/// the log doesn't disturb the live queue's state.
///
/// Copied from [ModerationLog].
class ModerationLogFamily extends Family<AsyncValue<List<FlaggedItem>>> {
  /// The resolved-items audit log for one workspace — the second tab of
  /// the moderation dashboard. Read-only; separate provider so opening
  /// the log doesn't disturb the live queue's state.
  ///
  /// Copied from [ModerationLog].
  const ModerationLogFamily();

  /// The resolved-items audit log for one workspace — the second tab of
  /// the moderation dashboard. Read-only; separate provider so opening
  /// the log doesn't disturb the live queue's state.
  ///
  /// Copied from [ModerationLog].
  ModerationLogProvider call(
    String workspaceId,
  ) {
    return ModerationLogProvider(
      workspaceId,
    );
  }

  @override
  ModerationLogProvider getProviderOverride(
    covariant ModerationLogProvider provider,
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
  String? get name => r'moderationLogProvider';
}

/// The resolved-items audit log for one workspace — the second tab of
/// the moderation dashboard. Read-only; separate provider so opening
/// the log doesn't disturb the live queue's state.
///
/// Copied from [ModerationLog].
class ModerationLogProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ModerationLog, List<FlaggedItem>> {
  /// The resolved-items audit log for one workspace — the second tab of
  /// the moderation dashboard. Read-only; separate provider so opening
  /// the log doesn't disturb the live queue's state.
  ///
  /// Copied from [ModerationLog].
  ModerationLogProvider(
    String workspaceId,
  ) : this._internal(
          () => ModerationLog()..workspaceId = workspaceId,
          from: moderationLogProvider,
          name: r'moderationLogProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$moderationLogHash,
          dependencies: ModerationLogFamily._dependencies,
          allTransitiveDependencies:
              ModerationLogFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  ModerationLogProvider._internal(
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
  FutureOr<List<FlaggedItem>> runNotifierBuild(
    covariant ModerationLog notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(ModerationLog Function() create) {
    return ProviderOverride(
      origin: this,
      override: ModerationLogProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ModerationLog, List<FlaggedItem>>
      createElement() {
    return _ModerationLogProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ModerationLogProvider && other.workspaceId == workspaceId;
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
mixin ModerationLogRef
    on AutoDisposeAsyncNotifierProviderRef<List<FlaggedItem>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _ModerationLogProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ModerationLog,
        List<FlaggedItem>> with ModerationLogRef {
  _ModerationLogProviderElement(super.provider);

  @override
  String get workspaceId => (origin as ModerationLogProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
