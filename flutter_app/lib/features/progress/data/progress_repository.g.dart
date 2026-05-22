// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$progressRepositoryHash() =>
    r'922851966c11f698e3eb72a221f0e30cef84367a';

/// Selects between the demo (in-process) and real (Dio → backend)
/// implementation based on the authenticated user — same heuristic as
/// every other repository in the app.
///
/// Copied from [progressRepository].
@ProviderFor(progressRepository)
final progressRepositoryProvider = Provider<ProgressRepository>.internal(
  progressRepository,
  name: r'progressRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$progressRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProgressRepositoryRef = ProviderRef<ProgressRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
