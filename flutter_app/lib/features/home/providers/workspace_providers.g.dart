// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeWorkspaceMembershipHash() =>
    r'68509e5e0a238e9be8c9d329bd5bca252363668b';

/// See also [activeWorkspaceMembership].
@ProviderFor(activeWorkspaceMembership)
final activeWorkspaceMembershipProvider =
    AutoDisposeProvider<WorkspaceMembership?>.internal(
  activeWorkspaceMembership,
  name: r'activeWorkspaceMembershipProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeWorkspaceMembershipHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveWorkspaceMembershipRef
    = AutoDisposeProviderRef<WorkspaceMembership?>;
String _$isActiveWorkspaceAdminHash() =>
    r'e1734f8c88ac7bf7fbc01c7ce6fc6eb33d512abd';

/// See also [isActiveWorkspaceAdmin].
@ProviderFor(isActiveWorkspaceAdmin)
final isActiveWorkspaceAdminProvider = AutoDisposeProvider<bool>.internal(
  isActiveWorkspaceAdmin,
  name: r'isActiveWorkspaceAdminProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isActiveWorkspaceAdminHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsActiveWorkspaceAdminRef = AutoDisposeProviderRef<bool>;
String _$studentWorkspacesHash() => r'3ab02edbbc2504c856bc369123b019fc9e590aa5';

/// See also [studentWorkspaces].
@ProviderFor(studentWorkspaces)
final studentWorkspacesProvider =
    AutoDisposeFutureProvider<List<Workspace>>.internal(
  studentWorkspaces,
  name: r'studentWorkspacesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$studentWorkspacesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StudentWorkspacesRef = AutoDisposeFutureProviderRef<List<Workspace>>;
String _$activeStudentWorkspaceHash() =>
    r'555207ada451b1de39d90c70aae6d40e2c862daf';

/// See also [activeStudentWorkspace].
@ProviderFor(activeStudentWorkspace)
final activeStudentWorkspaceProvider = AutoDisposeProvider<Workspace?>.internal(
  activeStudentWorkspace,
  name: r'activeStudentWorkspaceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeStudentWorkspaceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveStudentWorkspaceRef = AutoDisposeProviderRef<Workspace?>;
String _$workspaceActivityHash() => r'7ffe996ba1ab366807c8b6bfac736dceb0395806';

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

/// See also [workspaceActivity].
@ProviderFor(workspaceActivity)
const workspaceActivityProvider = WorkspaceActivityFamily();

/// See also [workspaceActivity].
class WorkspaceActivityFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [workspaceActivity].
  const WorkspaceActivityFamily();

  /// See also [workspaceActivity].
  WorkspaceActivityProvider call(
    String workspaceId,
  ) {
    return WorkspaceActivityProvider(
      workspaceId,
    );
  }

  @override
  WorkspaceActivityProvider getProviderOverride(
    covariant WorkspaceActivityProvider provider,
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
  String? get name => r'workspaceActivityProvider';
}

/// See also [workspaceActivity].
class WorkspaceActivityProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [workspaceActivity].
  WorkspaceActivityProvider(
    String workspaceId,
  ) : this._internal(
          (ref) => workspaceActivity(
            ref as WorkspaceActivityRef,
            workspaceId,
          ),
          from: workspaceActivityProvider,
          name: r'workspaceActivityProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workspaceActivityHash,
          dependencies: WorkspaceActivityFamily._dependencies,
          allTransitiveDependencies:
              WorkspaceActivityFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  WorkspaceActivityProvider._internal(
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
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(WorkspaceActivityRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorkspaceActivityProvider._internal(
        (ref) => create(ref as WorkspaceActivityRef),
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
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _WorkspaceActivityProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceActivityProvider &&
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
mixin WorkspaceActivityRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _WorkspaceActivityProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with WorkspaceActivityRef {
  _WorkspaceActivityProviderElement(super.provider);

  @override
  String get workspaceId => (origin as WorkspaceActivityProvider).workspaceId;
}

String _$currentCollaborativeRoleHash() =>
    r'c501da18782404d69b779ccf9625ac8656ac83bf';

/// See also [currentCollaborativeRole].
@ProviderFor(currentCollaborativeRole)
const currentCollaborativeRoleProvider = CurrentCollaborativeRoleFamily();

/// See also [currentCollaborativeRole].
class CurrentCollaborativeRoleFamily extends Family<AsyncValue<String?>> {
  /// See also [currentCollaborativeRole].
  const CurrentCollaborativeRoleFamily();

  /// See also [currentCollaborativeRole].
  CurrentCollaborativeRoleProvider call(
    String workspaceId,
  ) {
    return CurrentCollaborativeRoleProvider(
      workspaceId,
    );
  }

  @override
  CurrentCollaborativeRoleProvider getProviderOverride(
    covariant CurrentCollaborativeRoleProvider provider,
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
  String? get name => r'currentCollaborativeRoleProvider';
}

/// See also [currentCollaborativeRole].
class CurrentCollaborativeRoleProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [currentCollaborativeRole].
  CurrentCollaborativeRoleProvider(
    String workspaceId,
  ) : this._internal(
          (ref) => currentCollaborativeRole(
            ref as CurrentCollaborativeRoleRef,
            workspaceId,
          ),
          from: currentCollaborativeRoleProvider,
          name: r'currentCollaborativeRoleProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$currentCollaborativeRoleHash,
          dependencies: CurrentCollaborativeRoleFamily._dependencies,
          allTransitiveDependencies:
              CurrentCollaborativeRoleFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  CurrentCollaborativeRoleProvider._internal(
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
  Override overrideWith(
    FutureOr<String?> Function(CurrentCollaborativeRoleRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CurrentCollaborativeRoleProvider._internal(
        (ref) => create(ref as CurrentCollaborativeRoleRef),
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
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _CurrentCollaborativeRoleProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentCollaborativeRoleProvider &&
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
mixin CurrentCollaborativeRoleRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _CurrentCollaborativeRoleProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with CurrentCollaborativeRoleRef {
  _CurrentCollaborativeRoleProviderElement(super.provider);

  @override
  String get workspaceId =>
      (origin as CurrentCollaborativeRoleProvider).workspaceId;
}

String _$activeWorkspaceIdHash() => r'3ebef2c00a9a4e8a3456de25f74f1a3668b2efa4';

/// See also [ActiveWorkspaceId].
@ProviderFor(ActiveWorkspaceId)
final activeWorkspaceIdProvider =
    NotifierProvider<ActiveWorkspaceId, String?>.internal(
  ActiveWorkspaceId.new,
  name: r'activeWorkspaceIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeWorkspaceIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveWorkspaceId = Notifier<String?>;
String _$workspaceMessagesHash() => r'1702a5d577abf8245d9ce454257440a28be85232';

abstract class _$WorkspaceMessages
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final String workspaceId;

  FutureOr<List<Map<String, dynamic>>> build(
    String workspaceId,
  );
}

/// See also [WorkspaceMessages].
@ProviderFor(WorkspaceMessages)
const workspaceMessagesProvider = WorkspaceMessagesFamily();

/// See also [WorkspaceMessages].
class WorkspaceMessagesFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [WorkspaceMessages].
  const WorkspaceMessagesFamily();

  /// See also [WorkspaceMessages].
  WorkspaceMessagesProvider call(
    String workspaceId,
  ) {
    return WorkspaceMessagesProvider(
      workspaceId,
    );
  }

  @override
  WorkspaceMessagesProvider getProviderOverride(
    covariant WorkspaceMessagesProvider provider,
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
  String? get name => r'workspaceMessagesProvider';
}

/// See also [WorkspaceMessages].
class WorkspaceMessagesProvider extends AutoDisposeAsyncNotifierProviderImpl<
    WorkspaceMessages, List<Map<String, dynamic>>> {
  /// See also [WorkspaceMessages].
  WorkspaceMessagesProvider(
    String workspaceId,
  ) : this._internal(
          () => WorkspaceMessages()..workspaceId = workspaceId,
          from: workspaceMessagesProvider,
          name: r'workspaceMessagesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workspaceMessagesHash,
          dependencies: WorkspaceMessagesFamily._dependencies,
          allTransitiveDependencies:
              WorkspaceMessagesFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  WorkspaceMessagesProvider._internal(
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
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant WorkspaceMessages notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(WorkspaceMessages Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorkspaceMessagesProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<WorkspaceMessages,
      List<Map<String, dynamic>>> createElement() {
    return _WorkspaceMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceMessagesProvider &&
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
mixin WorkspaceMessagesRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _WorkspaceMessagesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<WorkspaceMessages,
        List<Map<String, dynamic>>> with WorkspaceMessagesRef {
  _WorkspaceMessagesProviderElement(super.provider);

  @override
  String get workspaceId => (origin as WorkspaceMessagesProvider).workspaceId;
}

String _$workspaceMembersListHash() =>
    r'28a1cad0696161c2eb079c45f8121ce0dc5035d5';

abstract class _$WorkspaceMembersList
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final String workspaceId;

  FutureOr<List<Map<String, dynamic>>> build(
    String workspaceId,
  );
}

/// See also [WorkspaceMembersList].
@ProviderFor(WorkspaceMembersList)
const workspaceMembersListProvider = WorkspaceMembersListFamily();

/// See also [WorkspaceMembersList].
class WorkspaceMembersListFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [WorkspaceMembersList].
  const WorkspaceMembersListFamily();

  /// See also [WorkspaceMembersList].
  WorkspaceMembersListProvider call(
    String workspaceId,
  ) {
    return WorkspaceMembersListProvider(
      workspaceId,
    );
  }

  @override
  WorkspaceMembersListProvider getProviderOverride(
    covariant WorkspaceMembersListProvider provider,
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
  String? get name => r'workspaceMembersListProvider';
}

/// See also [WorkspaceMembersList].
class WorkspaceMembersListProvider extends AutoDisposeAsyncNotifierProviderImpl<
    WorkspaceMembersList, List<Map<String, dynamic>>> {
  /// See also [WorkspaceMembersList].
  WorkspaceMembersListProvider(
    String workspaceId,
  ) : this._internal(
          () => WorkspaceMembersList()..workspaceId = workspaceId,
          from: workspaceMembersListProvider,
          name: r'workspaceMembersListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workspaceMembersListHash,
          dependencies: WorkspaceMembersListFamily._dependencies,
          allTransitiveDependencies:
              WorkspaceMembersListFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  WorkspaceMembersListProvider._internal(
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
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant WorkspaceMembersList notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(WorkspaceMembersList Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorkspaceMembersListProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<WorkspaceMembersList,
      List<Map<String, dynamic>>> createElement() {
    return _WorkspaceMembersListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceMembersListProvider &&
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
mixin WorkspaceMembersListRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _WorkspaceMembersListProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<WorkspaceMembersList,
        List<Map<String, dynamic>>> with WorkspaceMembersListRef {
  _WorkspaceMembersListProviderElement(super.provider);

  @override
  String get workspaceId =>
      (origin as WorkspaceMembersListProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
