// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$questionSessionNotifierHash() =>
    r'0071d48382a7d19a64c8990bbdfb912efdbcdfb7';

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

abstract class _$QuestionSessionNotifier
    extends BuildlessAutoDisposeNotifier<QuestionSession> {
  late final String workspaceId;

  QuestionSession build(
    String workspaceId,
  );
}

/// Owns the state machine for one question-answering session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]   — fetch the next question (idle → loading → ready)
/// - [setDraftAnswer]   — store the student's in-progress response
/// - [submit]           — send the answer (ready → submitting → feedback)
///
/// All transitions are guarded — calling [submit] when not in the
/// ``ready`` state is a no-op, not an error, so a stale UI tap can't
/// corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
///
/// Copied from [QuestionSessionNotifier].
@ProviderFor(QuestionSessionNotifier)
const questionSessionNotifierProvider = QuestionSessionNotifierFamily();

/// Owns the state machine for one question-answering session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]   — fetch the next question (idle → loading → ready)
/// - [setDraftAnswer]   — store the student's in-progress response
/// - [submit]           — send the answer (ready → submitting → feedback)
///
/// All transitions are guarded — calling [submit] when not in the
/// ``ready`` state is a no-op, not an error, so a stale UI tap can't
/// corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
///
/// Copied from [QuestionSessionNotifier].
class QuestionSessionNotifierFamily extends Family<QuestionSession> {
  /// Owns the state machine for one question-answering session.
  ///
  /// Methods correspond to user actions in the UI:
  ///
  /// - [start] / [next]   — fetch the next question (idle → loading → ready)
  /// - [setDraftAnswer]   — store the student's in-progress response
  /// - [submit]           — send the answer (ready → submitting → feedback)
  ///
  /// All transitions are guarded — calling [submit] when not in the
  /// ``ready`` state is a no-op, not an error, so a stale UI tap can't
  /// corrupt the state.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId` so
  /// switching workspaces yields a fresh session rather than carrying
  /// state across boundaries.
  ///
  /// Copied from [QuestionSessionNotifier].
  const QuestionSessionNotifierFamily();

  /// Owns the state machine for one question-answering session.
  ///
  /// Methods correspond to user actions in the UI:
  ///
  /// - [start] / [next]   — fetch the next question (idle → loading → ready)
  /// - [setDraftAnswer]   — store the student's in-progress response
  /// - [submit]           — send the answer (ready → submitting → feedback)
  ///
  /// All transitions are guarded — calling [submit] when not in the
  /// ``ready`` state is a no-op, not an error, so a stale UI tap can't
  /// corrupt the state.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId` so
  /// switching workspaces yields a fresh session rather than carrying
  /// state across boundaries.
  ///
  /// Copied from [QuestionSessionNotifier].
  QuestionSessionNotifierProvider call(
    String workspaceId,
  ) {
    return QuestionSessionNotifierProvider(
      workspaceId,
    );
  }

  @override
  QuestionSessionNotifierProvider getProviderOverride(
    covariant QuestionSessionNotifierProvider provider,
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
  String? get name => r'questionSessionNotifierProvider';
}

/// Owns the state machine for one question-answering session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]   — fetch the next question (idle → loading → ready)
/// - [setDraftAnswer]   — store the student's in-progress response
/// - [submit]           — send the answer (ready → submitting → feedback)
///
/// All transitions are guarded — calling [submit] when not in the
/// ``ready`` state is a no-op, not an error, so a stale UI tap can't
/// corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
///
/// Copied from [QuestionSessionNotifier].
class QuestionSessionNotifierProvider extends AutoDisposeNotifierProviderImpl<
    QuestionSessionNotifier, QuestionSession> {
  /// Owns the state machine for one question-answering session.
  ///
  /// Methods correspond to user actions in the UI:
  ///
  /// - [start] / [next]   — fetch the next question (idle → loading → ready)
  /// - [setDraftAnswer]   — store the student's in-progress response
  /// - [submit]           — send the answer (ready → submitting → feedback)
  ///
  /// All transitions are guarded — calling [submit] when not in the
  /// ``ready`` state is a no-op, not an error, so a stale UI tap can't
  /// corrupt the state.
  ///
  /// Lifecycle: this is a family provider keyed by `workspaceId` so
  /// switching workspaces yields a fresh session rather than carrying
  /// state across boundaries.
  ///
  /// Copied from [QuestionSessionNotifier].
  QuestionSessionNotifierProvider(
    String workspaceId,
  ) : this._internal(
          () => QuestionSessionNotifier()..workspaceId = workspaceId,
          from: questionSessionNotifierProvider,
          name: r'questionSessionNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$questionSessionNotifierHash,
          dependencies: QuestionSessionNotifierFamily._dependencies,
          allTransitiveDependencies:
              QuestionSessionNotifierFamily._allTransitiveDependencies,
          workspaceId: workspaceId,
        );

  QuestionSessionNotifierProvider._internal(
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
  QuestionSession runNotifierBuild(
    covariant QuestionSessionNotifier notifier,
  ) {
    return notifier.build(
      workspaceId,
    );
  }

  @override
  Override overrideWith(QuestionSessionNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: QuestionSessionNotifierProvider._internal(
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
  AutoDisposeNotifierProviderElement<QuestionSessionNotifier, QuestionSession>
      createElement() {
    return _QuestionSessionNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is QuestionSessionNotifierProvider &&
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
mixin QuestionSessionNotifierRef
    on AutoDisposeNotifierProviderRef<QuestionSession> {
  /// The parameter `workspaceId` of this provider.
  String get workspaceId;
}

class _QuestionSessionNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<QuestionSessionNotifier,
        QuestionSession> with QuestionSessionNotifierRef {
  _QuestionSessionNotifierProviderElement(super.provider);

  @override
  String get workspaceId =>
      (origin as QuestionSessionNotifierProvider).workspaceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
