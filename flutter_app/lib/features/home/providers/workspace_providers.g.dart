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
String _$studentWorkspacesHash() => r'70ad7ab12ee770a39661d232a86593aa7f83f0d0';

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
String _$activeWorkspaceIdHash() => r'b492f321b6ce08da946e0b6d992565fe30dd7852';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
