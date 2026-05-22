// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspaces_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workspacesListHash() => r'02a402b23ac1d93aa221422a1f2322dea5b72f7f';

/// The admin's list of workspaces. Backs the workspace management
/// screen (4.1).
///
/// Mutations ([createWorkspace], [updateWorkspace], [deleteWorkspace])
/// go through the repository and then [refresh] the list so the screen
/// always reflects server truth — no optimistic local patching, which
/// keeps the count fields (`studentCount`, `documentCount`) honest.
///
/// Copied from [WorkspacesList].
@ProviderFor(WorkspacesList)
final workspacesListProvider =
    AutoDisposeAsyncNotifierProvider<WorkspacesList, List<Workspace>>.internal(
  WorkspacesList.new,
  name: r'workspacesListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$workspacesListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WorkspacesList = AutoDisposeAsyncNotifier<List<Workspace>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
