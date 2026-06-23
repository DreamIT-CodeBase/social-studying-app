// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$routerHash() => r'5260ecde1a4e96bfc32446f011832144c6cd9ea4';

/// See also [router].
@ProviderFor(router)
final routerProvider = Provider<GoRouter>.internal(
  router,
  name: r'routerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$routerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RouterRef = ProviderRef<GoRouter>;
String _$pendingInviteCodeHash() => r'2df786c4f3ddde7404cb853a28a3fed84f0cf13e';

/// See also [PendingInviteCode].
@ProviderFor(PendingInviteCode)
final pendingInviteCodeProvider =
    AutoDisposeNotifierProvider<PendingInviteCode, String?>.internal(
  PendingInviteCode.new,
  name: r'pendingInviteCodeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingInviteCodeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PendingInviteCode = AutoDisposeNotifier<String?>;
String _$routerNotifierHash() => r'c0e6ee7839b4ca954c8fe01a135faff59a8c9b46';

/// See also [RouterNotifier].
@ProviderFor(RouterNotifier)
final routerNotifierProvider = NotifierProvider<RouterNotifier, void>.internal(
  RouterNotifier.new,
  name: r'routerNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$routerNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RouterNotifier = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
