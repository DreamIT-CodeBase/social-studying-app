// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_progress_detail_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$adminStudentProgressHash() =>
    r'ed692ce0dd38e11aac6f48f6be6fe4172540a511';

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

/// Loads any student's progress snapshot for the admin detail view.
///
/// Copied from [adminStudentProgress].
@ProviderFor(adminStudentProgress)
const adminStudentProgressProvider = AdminStudentProgressFamily();

/// Loads any student's progress snapshot for the admin detail view.
///
/// Copied from [adminStudentProgress].
class AdminStudentProgressFamily extends Family<AsyncValue<StudentProgress>> {
  /// Loads any student's progress snapshot for the admin detail view.
  ///
  /// Copied from [adminStudentProgress].
  const AdminStudentProgressFamily();

  /// Loads any student's progress snapshot for the admin detail view.
  ///
  /// Copied from [adminStudentProgress].
  AdminStudentProgressProvider call(
    ({String userId, String workspaceId}) key,
  ) {
    return AdminStudentProgressProvider(
      key,
    );
  }

  @override
  AdminStudentProgressProvider getProviderOverride(
    covariant AdminStudentProgressProvider provider,
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
  String? get name => r'adminStudentProgressProvider';
}

/// Loads any student's progress snapshot for the admin detail view.
///
/// Copied from [adminStudentProgress].
class AdminStudentProgressProvider
    extends AutoDisposeFutureProvider<StudentProgress> {
  /// Loads any student's progress snapshot for the admin detail view.
  ///
  /// Copied from [adminStudentProgress].
  AdminStudentProgressProvider(
    ({String userId, String workspaceId}) key,
  ) : this._internal(
          (ref) => adminStudentProgress(
            ref as AdminStudentProgressRef,
            key,
          ),
          from: adminStudentProgressProvider,
          name: r'adminStudentProgressProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$adminStudentProgressHash,
          dependencies: AdminStudentProgressFamily._dependencies,
          allTransitiveDependencies:
              AdminStudentProgressFamily._allTransitiveDependencies,
          key: key,
        );

  AdminStudentProgressProvider._internal(
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
    FutureOr<StudentProgress> Function(AdminStudentProgressRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AdminStudentProgressProvider._internal(
        (ref) => create(ref as AdminStudentProgressRef),
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
  AutoDisposeFutureProviderElement<StudentProgress> createElement() {
    return _AdminStudentProgressProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminStudentProgressProvider && other.key == key;
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
mixin AdminStudentProgressRef on AutoDisposeFutureProviderRef<StudentProgress> {
  /// The parameter `key` of this provider.
  ({String userId, String workspaceId}) get key;
}

class _AdminStudentProgressProviderElement
    extends AutoDisposeFutureProviderElement<StudentProgress>
    with AdminStudentProgressRef {
  _AdminStudentProgressProviderElement(super.provider);

  @override
  ({String userId, String workspaceId}) get key =>
      (origin as AdminStudentProgressProvider).key;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
