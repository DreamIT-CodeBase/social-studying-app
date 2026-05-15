// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_polling_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$documentPollingHash() => r'b49ecea2f3e3ba70a25caa4d5f95be7a9cc05889';

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

abstract class _$DocumentPolling
    extends BuildlessAutoDisposeAsyncNotifier<Document> {
  late final String workspaceId;
  late final String documentId;

  FutureOr<Document> build({
    required String workspaceId,
    required String documentId,
  });
}

/// Polls a single document's state until it reaches a terminal status.
///
/// Lifecycle
/// ---------
/// 1. `build` does the first fetch and schedules a Timer.
/// 2. The Timer fires `_poll`, which fetches and reschedules — or
///    stops if the new status is terminal.
/// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
///    cancels the Timer to avoid a leak.
///
/// Why a Timer rather than a Stream/StreamProvider
/// -----------------------------------------------
/// We need the latest snapshot wrapped in `AsyncValue` (loading on
/// first fetch, error on transient failures, data otherwise) and we
/// need the ability to stop polling cleanly when status terminates.
/// `AsyncNotifier` + Timer covers both with simpler code than
/// `Stream.periodic` + a manual `StreamSubscription` would.
///
/// Copied from [DocumentPolling].
@ProviderFor(DocumentPolling)
const documentPollingProvider = DocumentPollingFamily();

/// Polls a single document's state until it reaches a terminal status.
///
/// Lifecycle
/// ---------
/// 1. `build` does the first fetch and schedules a Timer.
/// 2. The Timer fires `_poll`, which fetches and reschedules — or
///    stops if the new status is terminal.
/// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
///    cancels the Timer to avoid a leak.
///
/// Why a Timer rather than a Stream/StreamProvider
/// -----------------------------------------------
/// We need the latest snapshot wrapped in `AsyncValue` (loading on
/// first fetch, error on transient failures, data otherwise) and we
/// need the ability to stop polling cleanly when status terminates.
/// `AsyncNotifier` + Timer covers both with simpler code than
/// `Stream.periodic` + a manual `StreamSubscription` would.
///
/// Copied from [DocumentPolling].
class DocumentPollingFamily extends Family<AsyncValue<Document>> {
  /// Polls a single document's state until it reaches a terminal status.
  ///
  /// Lifecycle
  /// ---------
  /// 1. `build` does the first fetch and schedules a Timer.
  /// 2. The Timer fires `_poll`, which fetches and reschedules — or
  ///    stops if the new status is terminal.
  /// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
  ///    cancels the Timer to avoid a leak.
  ///
  /// Why a Timer rather than a Stream/StreamProvider
  /// -----------------------------------------------
  /// We need the latest snapshot wrapped in `AsyncValue` (loading on
  /// first fetch, error on transient failures, data otherwise) and we
  /// need the ability to stop polling cleanly when status terminates.
  /// `AsyncNotifier` + Timer covers both with simpler code than
  /// `Stream.periodic` + a manual `StreamSubscription` would.
  ///
  /// Copied from [DocumentPolling].
  const DocumentPollingFamily();

  /// Polls a single document's state until it reaches a terminal status.
  ///
  /// Lifecycle
  /// ---------
  /// 1. `build` does the first fetch and schedules a Timer.
  /// 2. The Timer fires `_poll`, which fetches and reschedules — or
  ///    stops if the new status is terminal.
  /// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
  ///    cancels the Timer to avoid a leak.
  ///
  /// Why a Timer rather than a Stream/StreamProvider
  /// -----------------------------------------------
  /// We need the latest snapshot wrapped in `AsyncValue` (loading on
  /// first fetch, error on transient failures, data otherwise) and we
  /// need the ability to stop polling cleanly when status terminates.
  /// `AsyncNotifier` + Timer covers both with simpler code than
  /// `Stream.periodic` + a manual `StreamSubscription` would.
  ///
  /// Copied from [DocumentPolling].
  DocumentPollingProvider call({
    required String workspaceId,
    required String documentId,
  }) {
    return DocumentPollingProvider(
      workspaceId: workspaceId,
      documentId: documentId,
    );
  }

  @override
  DocumentPollingProvider getProviderOverride(
    covariant DocumentPollingProvider provider,
  ) {
    return call(
      workspaceId: provider.workspaceId,
      documentId: provider.documentId,
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
  String? get name => r'documentPollingProvider';
}

/// Polls a single document's state until it reaches a terminal status.
///
/// Lifecycle
/// ---------
/// 1. `build` does the first fetch and schedules a Timer.
/// 2. The Timer fires `_poll`, which fetches and reschedules — or
///    stops if the new status is terminal.
/// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
///    cancels the Timer to avoid a leak.
///
/// Why a Timer rather than a Stream/StreamProvider
/// -----------------------------------------------
/// We need the latest snapshot wrapped in `AsyncValue` (loading on
/// first fetch, error on transient failures, data otherwise) and we
/// need the ability to stop polling cleanly when status terminates.
/// `AsyncNotifier` + Timer covers both with simpler code than
/// `Stream.periodic` + a manual `StreamSubscription` would.
///
/// Copied from [DocumentPolling].
class DocumentPollingProvider
    extends AutoDisposeAsyncNotifierProviderImpl<DocumentPolling, Document> {
  /// Polls a single document's state until it reaches a terminal status.
  ///
  /// Lifecycle
  /// ---------
  /// 1. `build` does the first fetch and schedules a Timer.
  /// 2. The Timer fires `_poll`, which fetches and reschedules — or
  ///    stops if the new status is terminal.
  /// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
  ///    cancels the Timer to avoid a leak.
  ///
  /// Why a Timer rather than a Stream/StreamProvider
  /// -----------------------------------------------
  /// We need the latest snapshot wrapped in `AsyncValue` (loading on
  /// first fetch, error on transient failures, data otherwise) and we
  /// need the ability to stop polling cleanly when status terminates.
  /// `AsyncNotifier` + Timer covers both with simpler code than
  /// `Stream.periodic` + a manual `StreamSubscription` would.
  ///
  /// Copied from [DocumentPolling].
  DocumentPollingProvider({
    required String workspaceId,
    required String documentId,
  }) : this._internal(
          () => DocumentPolling()
            ..workspaceId = workspaceId
            ..documentId = documentId,
          from: documentPollingProvider,
          name: r'documentPollingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$documentPollingHash,
          dependencies: DocumentPollingFamily._dependencies,
          allTransitiveDependencies:
              DocumentPollingFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
          documentId: documentId,
        );

  DocumentPollingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.workspaceId,
    required this.documentId,
  }) : super.internal();

  final String workspaceId;
  final String documentId;

  @override
  FutureOr<Document> runNotifierBuild(
    covariant DocumentPolling notifier,
  ) {
    return notifier.build(
      workspaceId: workspaceId,
      documentId: documentId,
    );
  }

  @override
  Override overrideWith(DocumentPolling Function() create) {
    return ProviderOverride(
      origin: this,
      override: DocumentPollingProvider._internal(
        () => create()
          ..workspaceId = workspaceId
          ..documentId = documentId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        workspaceId: workspaceId,
        documentId: documentId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<DocumentPolling, Document>
      createElement() {
    return _DocumentPollingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentPollingProvider &&
        other.workspaceId == workspaceId &&
        other.documentId == documentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, workspaceId.hashCode);
    hash = _SystemHash.combine(hash, documentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DocumentPollingRef on AutoDisposeAsyncNotifierProviderRef<Document> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;

  /// The parameter `documentId` of this provider.
  String get documentId;
}

class _DocumentPollingProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<DocumentPolling, Document>
    with DocumentPollingRef {
  _DocumentPollingProviderElement(super.provider);

  @override
  String get workspaceId => (origin as DocumentPollingProvider).workspaceId;
  @override
  String get documentId => (origin as DocumentPollingProvider).documentId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
