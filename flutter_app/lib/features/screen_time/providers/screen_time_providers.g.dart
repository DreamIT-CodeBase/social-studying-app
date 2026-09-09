// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_time_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$xpToMinuteRatioHash() => r'81be2034b5f0f9937b531684d871b4de3358f2e5';

/// See also [xpToMinuteRatio].
@ProviderFor(xpToMinuteRatio)
final xpToMinuteRatioProvider = AutoDisposeFutureProvider<int>.internal(
  xpToMinuteRatio,
  name: r'xpToMinuteRatioProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$xpToMinuteRatioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef XpToMinuteRatioRef = AutoDisposeFutureProviderRef<int>;
String _$enableBlockingHash() => r'a7804551446ddd0d980050e2bc78c49c1614ddb1';

/// See also [enableBlocking].
@ProviderFor(enableBlocking)
final enableBlockingProvider = AutoDisposeFutureProvider<bool>.internal(
  enableBlocking,
  name: r'enableBlockingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$enableBlockingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EnableBlockingRef = AutoDisposeFutureProviderRef<bool>;
String _$blockedPackagesHash() => r'd403e9693022044994ddd4e5a59db67497995844';

/// See also [blockedPackages].
@ProviderFor(blockedPackages)
final blockedPackagesProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
  blockedPackages,
  name: r'blockedPackagesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$blockedPackagesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BlockedPackagesRef = AutoDisposeFutureProviderRef<List<String>>;
String _$screenTimeNotifierHash() =>
    r'1850df6943842cfecaceeb057ef8adc69393b1fb';

/// See also [ScreenTimeNotifier].
@ProviderFor(ScreenTimeNotifier)
final screenTimeNotifierProvider =
    AsyncNotifierProvider<ScreenTimeNotifier, ScreenTimeWallet>.internal(
  ScreenTimeNotifier.new,
  name: r'screenTimeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$screenTimeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ScreenTimeNotifier = AsyncNotifier<ScreenTimeWallet>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
