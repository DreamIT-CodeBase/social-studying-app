// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_token_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationTokenRepositoryHash() =>
    r'a79fc8736d1b2787617715f1411f9ae668d6dcd4';

/// Routes between real (Dio → backend) and demo (no-op) based on the
/// authenticated user — same heuristic as every other repository.
///
/// Copied from [notificationTokenRepository].
@ProviderFor(notificationTokenRepository)
final notificationTokenRepositoryProvider =
    Provider<NotificationTokenRepository>.internal(
  notificationTokenRepository,
  name: r'notificationTokenRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationTokenRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationTokenRepositoryRef
    = ProviderRef<NotificationTokenRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
