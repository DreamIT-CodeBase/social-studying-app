// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studentProgressNotifierHash() =>
    r'd143efc1d6b464fd7beb167856c9cd926a11908d';

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

abstract class _$StudentProgressNotifier
    extends BuildlessAutoDisposeAsyncNotifier<StudentProgress> {
  late final String workspaceId;

  FutureOr<StudentProgress> build(
    String workspaceId,
  );
}

/// Loads the calling student's progress snapshot for one workspace.
///
/// Family-keyed by `workspaceId`. The user id is resolved from
/// [authNotifierProvider] rather than passed in — the progress screen
/// only ever shows the *current* student's data (the admin per-student
/// view is a separate Sprint 5.10 surface).
///
/// Exposes [refresh] for pull-to-refresh and for re-fetching after an
/// answer/rating elsewhere in the app bumps mastery.
///
/// Copied from [StudentProgressNotifier].
@ProviderFor(StudentProgressNotifier)
const studentProgressNotifierProvider = StudentProgressNotifierFamily();

/// Loads the calling student's progress snapshot for one workspace.
///
/// Family-keyed by `workspaceId`. The user id is resolved from
/// [authNotifierProvider] rather than passed in — the progress screen
/// only ever shows the *current* student's data (the admin per-student
/// view is a separate Sprint 5.10 surface).
///
/// Exposes [refresh] for pull-to-refresh and for re-fetching after an
/// answer/rating elsewhere in the app bumps mastery.
///
/// Copied from [StudentProgressNotifier].
class StudentProgressNotifierFamily
    extends Family<AsyncValue<StudentProgress>> {
  /// Loads the calling student's progress snapshot for one workspace.
  ///
  /// Family-keyed by `workspaceId`. The user id is resolved from
  /// [authNotifierProvider] rather than passed in — the progress screen
  /// only ever shows the *current* student's data (the admin per-student
  /// view is a separate Sprint 5.10 surface).
  ///
  /// Exposes [refresh] for pull-to-refresh and for re-fetching after an
  /// answer/rating elsewhere in the app bumps mastery.
  ///
  /// Copied from [StudentProgressNotifier].
  const StudentProgressNotifierFamily();

  /// Loads the calling student's progress snapshot for one workspace.
  ///
  /// Family-keyed by `workspaceId`. The user id is resolved from
  /// [authNotifierProvider] rather than passed in — the progress screen
  /// only ever shows the *current* student's data (the admin per-student
  /// view is a separate Sprint 5.10 surface).
  ///
  /// Exposes [refresh] for pull-to-refresh and for re-fetching after an
  /// answer/rating elsewhere in the app bumps mastery.
  ///
  /// Copied from [StudentProgressNotifier].
  StudentProgressNotifierProvider call(
    String workspaceId,
  ) {
    return StudentProgressNotifierProvider(
      workspaceId,
    );
  }

  @override
  StudentProgressNotifierProvider getProviderOverride(
    covariant StudentProgressNotifierProvider provider,
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
  String? get name => r'studentProgressNotifierProvider';
}

/// Loads the calling student's progress snapshot for one workspace.
///
/// Family-keyed by `workspaceId`. The user id is resolved from
/// [authNotifierProvider] rather than passed in — the progress screen
/// only ever shows the *current* student's data (the admin per-student
/// view is a separate Sprint 5.10 surface).
///
/// Exposes [refresh] for pull-to-refresh and for re-fetching after an
/// answer/rating elsewhere in the app bumps mastery.
///
/// Copied from [StudentProgressNotifier].
class StudentProgressNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<StudentProgressNotifier,
        StudentProgress> {
  /// Loads the calling student's progress snapshot for one workspace.
  ///
  /// Family-keyed by `workspaceId`. The user id is resolved from
  /// [authNotifierProvider] rather than passed in — the progress screen
  /// only ever shows the *current* student's data (the admin per-student
  /// view is a separate Sprint 5.10 surface).
  ///
  /// Exposes [refresh] for pull-to-refresh and for re-fetching after an
  /// answer/rating elsewhere in the app bumps mastery.
  ///
  /// Copied from [StudentProgressNotifier].
  StudentProgressNotifierProvider(
    String workspaceId,
  ) : this._internal(
          () => StudentProgressNotifier()..workspaceId = workspaceId,
          from: studentProgressNotifierProvider,
          name: r'studentProgressNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$studentProgressNotifierHash,
          dependencies: StudentProgressNotifierFamily._dependencies,
          allTransitiveDependencies:
              StudentProgressNotifierFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  StudentProgressNotifierProvider._internal(
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
  FutureOr<StudentProgress> runNotifierBuild(
    covariant StudentProgressNotifier notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(StudentProgressNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudentProgressNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<StudentProgressNotifier,
      StudentProgress> createElement() {
    return _StudentProgressNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudentProgressNotifierProvider &&
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
mixin StudentProgressNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<StudentProgress> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _StudentProgressNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<StudentProgressNotifier,
        StudentProgress> with StudentProgressNotifierRef {
  _StudentProgressNotifierProviderElement(super.provider);

  @override
  String get workspaceId =>
      (origin as StudentProgressNotifierProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
