// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workspaceUsersListHash() =>
    r'73688a984a4b13a98e178afc60d40c688b73a511';

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

abstract class _$WorkspaceUsersList
    extends BuildlessAutoDisposeAsyncNotifier<List<User>> {
  late final String workspaceId;

  FutureOr<List<User>> build(
    String workspaceId,
  );
}

/// The roster of users in one workspace. Backs the user management
/// screen (4.2). Family-keyed by `workspaceId`.
///
/// Mutations route through the repository and then [refresh] the list
/// so the screen always reflects server truth.
///
/// Copied from [WorkspaceUsersList].
@ProviderFor(WorkspaceUsersList)
const workspaceUsersListProvider = WorkspaceUsersListFamily();

/// The roster of users in one workspace. Backs the user management
/// screen (4.2). Family-keyed by `workspaceId`.
///
/// Mutations route through the repository and then [refresh] the list
/// so the screen always reflects server truth.
///
/// Copied from [WorkspaceUsersList].
class WorkspaceUsersListFamily extends Family<AsyncValue<List<User>>> {
  /// The roster of users in one workspace. Backs the user management
  /// screen (4.2). Family-keyed by `workspaceId`.
  ///
  /// Mutations route through the repository and then [refresh] the list
  /// so the screen always reflects server truth.
  ///
  /// Copied from [WorkspaceUsersList].
  const WorkspaceUsersListFamily();

  /// The roster of users in one workspace. Backs the user management
  /// screen (4.2). Family-keyed by `workspaceId`.
  ///
  /// Mutations route through the repository and then [refresh] the list
  /// so the screen always reflects server truth.
  ///
  /// Copied from [WorkspaceUsersList].
  WorkspaceUsersListProvider call(
    String workspaceId,
  ) {
    return WorkspaceUsersListProvider(
      workspaceId,
    );
  }

  @override
  WorkspaceUsersListProvider getProviderOverride(
    covariant WorkspaceUsersListProvider provider,
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
  String? get name => r'workspaceUsersListProvider';
}

/// The roster of users in one workspace. Backs the user management
/// screen (4.2). Family-keyed by `workspaceId`.
///
/// Mutations route through the repository and then [refresh] the list
/// so the screen always reflects server truth.
///
/// Copied from [WorkspaceUsersList].
class WorkspaceUsersListProvider extends AutoDisposeAsyncNotifierProviderImpl<
    WorkspaceUsersList, List<User>> {
  /// The roster of users in one workspace. Backs the user management
  /// screen (4.2). Family-keyed by `workspaceId`.
  ///
  /// Mutations route through the repository and then [refresh] the list
  /// so the screen always reflects server truth.
  ///
  /// Copied from [WorkspaceUsersList].
  WorkspaceUsersListProvider(
    String workspaceId,
  ) : this._internal(
          () => WorkspaceUsersList()..workspaceId = workspaceId,
          from: workspaceUsersListProvider,
          name: r'workspaceUsersListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workspaceUsersListHash,
          dependencies: WorkspaceUsersListFamily._dependencies,
          allTransitiveDependencies:
              WorkspaceUsersListFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  WorkspaceUsersListProvider._internal(
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
  FutureOr<List<User>> runNotifierBuild(
    covariant WorkspaceUsersList notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(WorkspaceUsersList Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorkspaceUsersListProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<WorkspaceUsersList, List<User>>
      createElement() {
    return _WorkspaceUsersListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceUsersListProvider &&
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
mixin WorkspaceUsersListRef on AutoDisposeAsyncNotifierProviderRef<List<User>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _WorkspaceUsersListProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<WorkspaceUsersList,
        List<User>> with WorkspaceUsersListRef {
  _WorkspaceUsersListProviderElement(super.provider);

  @override
  String get workspaceId => (origin as WorkspaceUsersListProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
