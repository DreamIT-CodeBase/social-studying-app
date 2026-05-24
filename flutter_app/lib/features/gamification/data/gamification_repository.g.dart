// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gamificationRepositoryHash() =>
    r'ebb37cb479bc840437bd46fc52bf296d524e4915';

/// Selects between the demo (in-process) and real (Dio → backend)
/// implementation based on the authenticated user. Same heuristic as
/// every other repository in the app.
///
/// Copied from [gamificationRepository].
@ProviderFor(gamificationRepository)
final gamificationRepositoryProvider =
    Provider<GamificationRepository>.internal(
  gamificationRepository,
  name: r'gamificationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$gamificationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GamificationRepositoryRef = ProviderRef<GamificationRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
