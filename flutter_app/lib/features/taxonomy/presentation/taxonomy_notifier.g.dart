// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taxonomyViewerHash() => r'f98ceb8e09e56253020ca7b3ff878bd0de5c9a8b';

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

abstract class _$TaxonomyViewer
    extends BuildlessAutoDisposeAsyncNotifier<TaxonomyViewerState> {
  late final String workspaceId;

  FutureOr<TaxonomyViewerState> build({
    required String workspaceId,
  });
}

/// AsyncNotifier for the workspace taxonomy.
///
/// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
/// fires the backend's POST /regenerate and then polls the GET endpoint
/// until ``taxonomy_version`` bumps — at which point the rebuild has
/// completed and we surface the new tree.
///
/// Copied from [TaxonomyViewer].
@ProviderFor(TaxonomyViewer)
const taxonomyViewerProvider = TaxonomyViewerFamily();

/// AsyncNotifier for the workspace taxonomy.
///
/// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
/// fires the backend's POST /regenerate and then polls the GET endpoint
/// until ``taxonomy_version`` bumps — at which point the rebuild has
/// completed and we surface the new tree.
///
/// Copied from [TaxonomyViewer].
class TaxonomyViewerFamily extends Family<AsyncValue<TaxonomyViewerState>> {
  /// AsyncNotifier for the workspace taxonomy.
  ///
  /// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
  /// fires the backend's POST /regenerate and then polls the GET endpoint
  /// until ``taxonomy_version`` bumps — at which point the rebuild has
  /// completed and we surface the new tree.
  ///
  /// Copied from [TaxonomyViewer].
  const TaxonomyViewerFamily();

  /// AsyncNotifier for the workspace taxonomy.
  ///
  /// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
  /// fires the backend's POST /regenerate and then polls the GET endpoint
  /// until ``taxonomy_version`` bumps — at which point the rebuild has
  /// completed and we surface the new tree.
  ///
  /// Copied from [TaxonomyViewer].
  TaxonomyViewerProvider call({
    required String workspaceId,
  }) {
    return TaxonomyViewerProvider(
      workspaceId: workspaceId,
    );
  }

  @override
  TaxonomyViewerProvider getProviderOverride(
    covariant TaxonomyViewerProvider provider,
  ) {
    return call(
      workspaceId: provider.workspaceId,
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
  String? get name => r'taxonomyViewerProvider';
}

/// AsyncNotifier for the workspace taxonomy.
///
/// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
/// fires the backend's POST /regenerate and then polls the GET endpoint
/// until ``taxonomy_version`` bumps — at which point the rebuild has
/// completed and we surface the new tree.
///
/// Copied from [TaxonomyViewer].
class TaxonomyViewerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TaxonomyViewer, TaxonomyViewerState> {
  /// AsyncNotifier for the workspace taxonomy.
  ///
  /// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
  /// fires the backend's POST /regenerate and then polls the GET endpoint
  /// until ``taxonomy_version`` bumps — at which point the rebuild has
  /// completed and we surface the new tree.
  ///
  /// Copied from [TaxonomyViewer].
  TaxonomyViewerProvider({
    required String workspaceId,
  }) : this._internal(
          () => TaxonomyViewer()..workspaceId = workspaceId,
          from: taxonomyViewerProvider,
          name: r'taxonomyViewerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taxonomyViewerHash,
          dependencies: TaxonomyViewerFamily._dependencies,
          allTransitiveDependencies:
              TaxonomyViewerFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  TaxonomyViewerProvider._internal(
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
  FutureOr<TaxonomyViewerState> runNotifierBuild(
    covariant TaxonomyViewer notifier,
  ) {
    return notifier.build(
      workspaceId: workspaceId,
    );
  }

  @override
  Override overrideWith(TaxonomyViewer Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaxonomyViewerProvider._internal(
        () => create()..workspaceId = workspaceId,
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
  AutoDisposeAsyncNotifierProviderElement<TaxonomyViewer, TaxonomyViewerState>
      createElement() {
    return _TaxonomyViewerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaxonomyViewerProvider && other.workspaceId == workspaceId;
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
mixin TaxonomyViewerRef
    on AutoDisposeAsyncNotifierProviderRef<TaxonomyViewerState> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _TaxonomyViewerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaxonomyViewer,
        TaxonomyViewerState> with TaxonomyViewerRef {
  _TaxonomyViewerProviderElement(super.provider);

  @override
  String get workspaceId => (origin as TaxonomyViewerProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
