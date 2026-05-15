// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documents_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$documentsListHash() => r'a29c038c8d5a832474cc71d3afd655456d4a67a6';

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

abstract class _$DocumentsList
    extends BuildlessAutoDisposeAsyncNotifier<List<Document>> {
  late final String workspaceId;

  FutureOr<List<Document>> build(
    String workspaceId,
  );
}

/// List of documents in a workspace. Refreshable on pull-to-refresh and
/// after upload completes — the list is invalidated to pick up the new
/// row.
///
/// Copied from [DocumentsList].
@ProviderFor(DocumentsList)
const documentsListProvider = DocumentsListFamily();

/// List of documents in a workspace. Refreshable on pull-to-refresh and
/// after upload completes — the list is invalidated to pick up the new
/// row.
///
/// Copied from [DocumentsList].
class DocumentsListFamily extends Family<AsyncValue<List<Document>>> {
  /// List of documents in a workspace. Refreshable on pull-to-refresh and
  /// after upload completes — the list is invalidated to pick up the new
  /// row.
  ///
  /// Copied from [DocumentsList].
  const DocumentsListFamily();

  /// List of documents in a workspace. Refreshable on pull-to-refresh and
  /// after upload completes — the list is invalidated to pick up the new
  /// row.
  ///
  /// Copied from [DocumentsList].
  DocumentsListProvider call(
    String workspaceId,
  ) {
    return DocumentsListProvider(
      workspaceId,
    );
  }

  @override
  DocumentsListProvider getProviderOverride(
    covariant DocumentsListProvider provider,
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
  String? get name => r'documentsListProvider';
}

/// List of documents in a workspace. Refreshable on pull-to-refresh and
/// after upload completes — the list is invalidated to pick up the new
/// row.
///
/// Copied from [DocumentsList].
class DocumentsListProvider extends AutoDisposeAsyncNotifierProviderImpl<
    DocumentsList, List<Document>> {
  /// List of documents in a workspace. Refreshable on pull-to-refresh and
  /// after upload completes — the list is invalidated to pick up the new
  /// row.
  ///
  /// Copied from [DocumentsList].
  DocumentsListProvider(
    String workspaceId,
  ) : this._internal(
          () => DocumentsList()..workspaceId = workspaceId,
          from: documentsListProvider,
          name: r'documentsListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$documentsListHash,
          dependencies: DocumentsListFamily._dependencies,
          allTransitiveDependencies:
              DocumentsListFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  DocumentsListProvider._internal(
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
  FutureOr<List<Document>> runNotifierBuild(
    covariant DocumentsList notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(DocumentsList Function() create) {
    return ProviderOverride(
      origin: this,
      override: DocumentsListProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<DocumentsList, List<Document>>
      createElement() {
    return _DocumentsListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentsListProvider && other.workspaceId == workspaceId;
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
mixin DocumentsListRef on AutoDisposeAsyncNotifierProviderRef<List<Document>> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _DocumentsListProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<DocumentsList,
        List<Document>> with DocumentsListRef {
  _DocumentsListProviderElement(super.provider);

  @override
  String get workspaceId => (origin as DocumentsListProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
