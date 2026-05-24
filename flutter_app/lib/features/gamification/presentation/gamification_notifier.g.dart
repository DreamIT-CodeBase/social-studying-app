// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gamificationProfileHash() =>
    r'b9608e16dbcb5c086255b1f61d9608327f80e854';

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

/// Full gamification profile — XP, level, streak, per-topic XP,
/// earned badges, daily activity.
///
/// Copied from [gamificationProfile].
@ProviderFor(gamificationProfile)
const gamificationProfileProvider = GamificationProfileFamily();

/// Full gamification profile — XP, level, streak, per-topic XP,
/// earned badges, daily activity.
///
/// Copied from [gamificationProfile].
class GamificationProfileFamily
    extends Family<AsyncValue<GamificationProfile>> {
  /// Full gamification profile — XP, level, streak, per-topic XP,
  /// earned badges, daily activity.
  ///
  /// Copied from [gamificationProfile].
  const GamificationProfileFamily();

  /// Full gamification profile — XP, level, streak, per-topic XP,
  /// earned badges, daily activity.
  ///
  /// Copied from [gamificationProfile].
  GamificationProfileProvider call(
    ({String userId, String workspaceId}) key,
  ) {
    return GamificationProfileProvider(
      key,
    );
  }

  @override
  GamificationProfileProvider getProviderOverride(
    covariant GamificationProfileProvider provider,
  ) {
    return call(
      provider.key,
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
  String? get name => r'gamificationProfileProvider';
}

/// Full gamification profile — XP, level, streak, per-topic XP,
/// earned badges, daily activity.
///
/// Copied from [gamificationProfile].
class GamificationProfileProvider
    extends AutoDisposeFutureProvider<GamificationProfile> {
  /// Full gamification profile — XP, level, streak, per-topic XP,
  /// earned badges, daily activity.
  ///
  /// Copied from [gamificationProfile].
  GamificationProfileProvider(
    ({String userId, String workspaceId}) key,
  ) : this._internal(
          (ref) => gamificationProfile(
            ref as GamificationProfileRef,
            key,
          ),
          from: gamificationProfileProvider,
          name: r'gamificationProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gamificationProfileHash,
          dependencies: GamificationProfileFamily._dependencies,
          allTransitiveDependencies:
              GamificationProfileFamily._allTransitiveDependencies,
          key: key,
        );

  GamificationProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.key,
  }) : super.internal();

  final ({String userId, String workspaceId}) key;

  @override
  Override overrideWith(
    FutureOr<GamificationProfile> Function(GamificationProfileRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GamificationProfileProvider._internal(
        (ref) => create(ref as GamificationProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        key: key,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<GamificationProfile> createElement() {
    return _GamificationProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GamificationProfileProvider && other.key == key;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, key.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GamificationProfileRef
    on AutoDisposeFutureProviderRef<GamificationProfile> {
  /// The parameter `key` of this provider.
  ({String userId, String workspaceId}) get key;
}

class _GamificationProfileProviderElement
    extends AutoDisposeFutureProviderElement<GamificationProfile>
    with GamificationProfileRef {
  _GamificationProfileProviderElement(super.provider);

  @override
  ({String userId, String workspaceId}) get key =>
      (origin as GamificationProfileProvider).key;
}

String _$streakSummaryHash() => r'af925a956a1b0f05ac4be91af275f522d40dd6c9';

/// Cheap streak-only fetch — used by the home page streak card so the
/// home tab doesn't pay for the full profile load on every visit.
///
/// Copied from [streakSummary].
@ProviderFor(streakSummary)
const streakSummaryProvider = StreakSummaryFamily();

/// Cheap streak-only fetch — used by the home page streak card so the
/// home tab doesn't pay for the full profile load on every visit.
///
/// Copied from [streakSummary].
class StreakSummaryFamily extends Family<AsyncValue<StreakSummary>> {
  /// Cheap streak-only fetch — used by the home page streak card so the
  /// home tab doesn't pay for the full profile load on every visit.
  ///
  /// Copied from [streakSummary].
  const StreakSummaryFamily();

  /// Cheap streak-only fetch — used by the home page streak card so the
  /// home tab doesn't pay for the full profile load on every visit.
  ///
  /// Copied from [streakSummary].
  StreakSummaryProvider call(
    ({String userId, String workspaceId}) key,
  ) {
    return StreakSummaryProvider(
      key,
    );
  }

  @override
  StreakSummaryProvider getProviderOverride(
    covariant StreakSummaryProvider provider,
  ) {
    return call(
      provider.key,
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
  String? get name => r'streakSummaryProvider';
}

/// Cheap streak-only fetch — used by the home page streak card so the
/// home tab doesn't pay for the full profile load on every visit.
///
/// Copied from [streakSummary].
class StreakSummaryProvider extends AutoDisposeFutureProvider<StreakSummary> {
  /// Cheap streak-only fetch — used by the home page streak card so the
  /// home tab doesn't pay for the full profile load on every visit.
  ///
  /// Copied from [streakSummary].
  StreakSummaryProvider(
    ({String userId, String workspaceId}) key,
  ) : this._internal(
          (ref) => streakSummary(
            ref as StreakSummaryRef,
            key,
          ),
          from: streakSummaryProvider,
          name: r'streakSummaryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$streakSummaryHash,
          dependencies: StreakSummaryFamily._dependencies,
          allTransitiveDependencies:
              StreakSummaryFamily._allTransitiveDependencies,
          key: key,
        );

  StreakSummaryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.key,
  }) : super.internal();

  final ({String userId, String workspaceId}) key;

  @override
  Override overrideWith(
    FutureOr<StreakSummary> Function(StreakSummaryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StreakSummaryProvider._internal(
        (ref) => create(ref as StreakSummaryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        key: key,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<StreakSummary> createElement() {
    return _StreakSummaryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StreakSummaryProvider && other.key == key;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, key.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StreakSummaryRef on AutoDisposeFutureProviderRef<StreakSummary> {
  /// The parameter `key` of this provider.
  ({String userId, String workspaceId}) get key;
}

class _StreakSummaryProviderElement
    extends AutoDisposeFutureProviderElement<StreakSummary>
    with StreakSummaryRef {
  _StreakSummaryProviderElement(super.provider);

  @override
  ({String userId, String workspaceId}) get key =>
      (origin as StreakSummaryProvider).key;
}

String _$badgesSummaryHash() => r'8ea508af3d19571c211110bc043dcda5ce3cd794';

/// Earned + available badges in a single payload.
///
/// Copied from [badgesSummary].
@ProviderFor(badgesSummary)
const badgesSummaryProvider = BadgesSummaryFamily();

/// Earned + available badges in a single payload.
///
/// Copied from [badgesSummary].
class BadgesSummaryFamily extends Family<AsyncValue<BadgesSummary>> {
  /// Earned + available badges in a single payload.
  ///
  /// Copied from [badgesSummary].
  const BadgesSummaryFamily();

  /// Earned + available badges in a single payload.
  ///
  /// Copied from [badgesSummary].
  BadgesSummaryProvider call(
    ({String userId, String workspaceId}) key,
  ) {
    return BadgesSummaryProvider(
      key,
    );
  }

  @override
  BadgesSummaryProvider getProviderOverride(
    covariant BadgesSummaryProvider provider,
  ) {
    return call(
      provider.key,
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
  String? get name => r'badgesSummaryProvider';
}

/// Earned + available badges in a single payload.
///
/// Copied from [badgesSummary].
class BadgesSummaryProvider extends AutoDisposeFutureProvider<BadgesSummary> {
  /// Earned + available badges in a single payload.
  ///
  /// Copied from [badgesSummary].
  BadgesSummaryProvider(
    ({String userId, String workspaceId}) key,
  ) : this._internal(
          (ref) => badgesSummary(
            ref as BadgesSummaryRef,
            key,
          ),
          from: badgesSummaryProvider,
          name: r'badgesSummaryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$badgesSummaryHash,
          dependencies: BadgesSummaryFamily._dependencies,
          allTransitiveDependencies:
              BadgesSummaryFamily._allTransitiveDependencies,
          key: key,
        );

  BadgesSummaryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.key,
  }) : super.internal();

  final ({String userId, String workspaceId}) key;

  @override
  Override overrideWith(
    FutureOr<BadgesSummary> Function(BadgesSummaryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BadgesSummaryProvider._internal(
        (ref) => create(ref as BadgesSummaryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        key: key,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<BadgesSummary> createElement() {
    return _BadgesSummaryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BadgesSummaryProvider && other.key == key;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, key.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BadgesSummaryRef on AutoDisposeFutureProviderRef<BadgesSummary> {
  /// The parameter `key` of this provider.
  ({String userId, String workspaceId}) get key;
}

class _BadgesSummaryProviderElement
    extends AutoDisposeFutureProviderElement<BadgesSummary>
    with BadgesSummaryRef {
  _BadgesSummaryProviderElement(super.provider);

  @override
  ({String userId, String workspaceId}) get key =>
      (origin as BadgesSummaryProvider).key;
}

String _$leaderboardHash() => r'1c25267a2c66d4fdb3e5781d6ef34e882d0bf223';

/// Workspace leaderboard.
///
/// Copied from [leaderboard].
@ProviderFor(leaderboard)
const leaderboardProvider = LeaderboardFamily();

/// Workspace leaderboard.
///
/// Copied from [leaderboard].
class LeaderboardFamily extends Family<AsyncValue<LeaderboardResponse>> {
  /// Workspace leaderboard.
  ///
  /// Copied from [leaderboard].
  const LeaderboardFamily();

  /// Workspace leaderboard.
  ///
  /// Copied from [leaderboard].
  LeaderboardProvider call(
    String workspaceId,
  ) {
    return LeaderboardProvider(
      workspaceId,
    );
  }

  @override
  LeaderboardProvider getProviderOverride(
    covariant LeaderboardProvider provider,
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
  String? get name => r'leaderboardProvider';
}

/// Workspace leaderboard.
///
/// Copied from [leaderboard].
class LeaderboardProvider
    extends AutoDisposeFutureProvider<LeaderboardResponse> {
  /// Workspace leaderboard.
  ///
  /// Copied from [leaderboard].
  LeaderboardProvider(
    String workspaceId,
  ) : this._internal(
          (ref) => leaderboard(
            ref as LeaderboardRef,
            workspaceId,
          ),
          from: leaderboardProvider,
          name: r'leaderboardProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$leaderboardHash,
          dependencies: LeaderboardFamily._dependencies,
          allTransitiveDependencies:
              LeaderboardFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  LeaderboardProvider._internal(
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
    FutureOr<LeaderboardResponse> Function(LeaderboardRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeaderboardProvider._internal(
        (ref) => create(ref as LeaderboardRef),
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
  AutoDisposeFutureProviderElement<LeaderboardResponse> createElement() {
    return _LeaderboardProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeaderboardProvider && other.workspaceId == workspaceId;
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
mixin LeaderboardRef on AutoDisposeFutureProviderRef<LeaderboardResponse> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _LeaderboardProviderElement
    extends AutoDisposeFutureProviderElement<LeaderboardResponse>
    with LeaderboardRef {
  _LeaderboardProviderElement(super.provider);

  @override
  String get workspaceId => (origin as LeaderboardProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
