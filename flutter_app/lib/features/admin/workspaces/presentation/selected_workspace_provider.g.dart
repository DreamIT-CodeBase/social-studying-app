// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_workspace_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeWorkspaceHash() => r'18c2d20bbfd6182f2f36e5a14c3edcd6fc3b7f2f';

/// Returns the [Workspace] object for the currently selected workspace,
/// or null if no workspace is selected or the list hasn't loaded yet.
///
/// Copied from [activeWorkspace].
@ProviderFor(activeWorkspace)
final activeWorkspaceProvider = AutoDisposeProvider<Workspace?>.internal(
  activeWorkspace,
  name: r'activeWorkspaceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeWorkspaceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveWorkspaceRef = AutoDisposeProviderRef<Workspace?>;
String _$selectedWorkspaceHash() => r'5aa364542e69e90a3e18252cc5ff273d2dec3341';

/// Tracks the currently selected workspace ID.
///
/// Initializes from the user's first admin membership, then can be
/// changed manually via [selectWorkspace] to support switching.
///
/// Copied from [SelectedWorkspace].
@ProviderFor(SelectedWorkspace)
final selectedWorkspaceProvider =
    AutoDisposeNotifierProvider<SelectedWorkspace, String?>.internal(
  SelectedWorkspace.new,
  name: r'selectedWorkspaceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedWorkspaceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedWorkspace = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
