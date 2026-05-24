// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_analytics_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workspaceAnalyticsHash() =>
    r'b1aae4919cffadb30e38b3e0f7f4c049d1257529';

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

/// See also [workspaceAnalytics].
@ProviderFor(workspaceAnalytics)
const workspaceAnalyticsProvider = WorkspaceAnalyticsFamily();

/// See also [workspaceAnalytics].
class WorkspaceAnalyticsFamily extends Family<AsyncValue<WorkspaceAnalytics>> {
  /// See also [workspaceAnalytics].
  const WorkspaceAnalyticsFamily();

  /// See also [workspaceAnalytics].
  WorkspaceAnalyticsProvider call(
    String workspaceId,
  ) {
    return WorkspaceAnalyticsProvider(
      workspaceId,
    );
  }

  @override
  WorkspaceAnalyticsProvider getProviderOverride(
    covariant WorkspaceAnalyticsProvider provider,
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
  String? get name => r'workspaceAnalyticsProvider';
}

/// See also [workspaceAnalytics].
class WorkspaceAnalyticsProvider
    extends AutoDisposeFutureProvider<WorkspaceAnalytics> {
  /// See also [workspaceAnalytics].
  WorkspaceAnalyticsProvider(
    String workspaceId,
  ) : this._internal(
          (ref) => workspaceAnalytics(
            ref as WorkspaceAnalyticsRef,
            workspaceId,
          ),
          from: workspaceAnalyticsProvider,
          name: r'workspaceAnalyticsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workspaceAnalyticsHash,
          dependencies: WorkspaceAnalyticsFamily._dependencies,
          allTransitiveDependencies:
              WorkspaceAnalyticsFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  WorkspaceAnalyticsProvider._internal(
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
    FutureOr<WorkspaceAnalytics> Function(WorkspaceAnalyticsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorkspaceAnalyticsProvider._internal(
        (ref) => create(ref as WorkspaceAnalyticsRef),
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
  AutoDisposeFutureProviderElement<WorkspaceAnalytics> createElement() {
    return _WorkspaceAnalyticsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceAnalyticsProvider &&
        other.workspaceId == workspaceId;
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
mixin WorkspaceAnalyticsRef
    on AutoDisposeFutureProviderRef<WorkspaceAnalytics> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _WorkspaceAnalyticsProviderElement
    extends AutoDisposeFutureProviderElement<WorkspaceAnalytics>
    with WorkspaceAnalyticsRef {
  _WorkspaceAnalyticsProviderElement(super.provider);

  @override
  String get workspaceId => (origin as WorkspaceAnalyticsProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
