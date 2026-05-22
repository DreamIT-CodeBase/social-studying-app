// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspaces_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workspacesRepositoryHash() =>
    r'2f6d216f4fde5e93d029afaec652c177f0bfe46f';

/// Selects demo vs. real implementation by authenticated user — the
/// same heuristic every repository in the app uses.
///
/// Copied from [workspacesRepository].
@ProviderFor(workspacesRepository)
final workspacesRepositoryProvider = Provider<WorkspacesRepository>.internal(
  workspacesRepository,
  name: r'workspacesRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$workspacesRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WorkspacesRepositoryRef = ProviderRef<WorkspacesRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
