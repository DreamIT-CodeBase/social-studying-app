import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/taxonomy/data/demo_taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/data/real_taxonomy_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'taxonomy_repository.g.dart';

/// Source-of-truth for the workspace taxonomy CRUD endpoints (Sprint 2.11).
///
/// Mirrors ``DocumentsRepository``'s interface-with-two-impls pattern so
/// the viewer screen can run in either demo or real mode without
/// branching on auth state itself.
abstract class TaxonomyRepository {
  /// GET /api/v1/workspaces/{workspaceId}/taxonomy.
  Future<Taxonomy> get({required String workspaceId});

  /// POST /api/v1/workspaces/{workspaceId}/taxonomy/regenerate.
  /// Returns immediately (202 Accepted) — the rebuild runs server-side.
  /// Callers poll ``get`` until ``taxonomyVersion`` bumps.
  Future<void> regenerate({required String workspaceId});

  /// PUT /api/v1/workspaces/{workspaceId}/taxonomy — the Sprint 4.3
  /// editor save path. Replaces the entire topic list with [topics],
  /// using optimistic concurrency: [expectedVersion] is the
  /// `taxonomy_version` the editor loaded; the backend rejects the write
  /// if the stored version has moved on.
  ///
  /// Throws:
  /// - [TaxonomyWorkspaceNotFoundException] (404) — workspace deleted.
  /// - [TaxonomyVersionConflictException] (409) — someone else saved
  ///   first; the editor should re-fetch and let the admin redo edits.
  /// - [TaxonomyValidationException] (422) — payload would corrupt the
  ///   graph (duplicate id/name, dangling parent, cycle).
  Future<Taxonomy> update({
    required String workspaceId,
    required int expectedVersion,
    required List<CanonicalTopic> topics,
  });
}

/// Thrown when the workspace doesn't exist on the backend. The notifier
/// surfaces this as an explicit "no workspace yet" empty state rather
/// than a generic error.
class TaxonomyWorkspaceNotFoundException implements Exception {
  const TaxonomyWorkspaceNotFoundException();

  @override
  String toString() => 'TaxonomyWorkspaceNotFoundException';
}

/// 409 from PUT /taxonomy — the stored `taxonomy_version` no longer
/// matches what the editor loaded. Someone else saved first. The editor
/// re-fetches and surfaces a "your edits are out of date" notice.
class TaxonomyVersionConflictException implements Exception {
  const TaxonomyVersionConflictException([
    this.message = 'Taxonomy was modified by another writer',
  ]);
  final String message;
  @override
  String toString() => 'TaxonomyVersionConflictException: $message';
}

/// 422 from PUT /taxonomy — the payload would corrupt the graph
/// (duplicate id/name, dangling parent, cycle, empty name). The editor
/// surfaces [message] inline so the admin can see exactly what's wrong.
class TaxonomyValidationException implements Exception {
  const TaxonomyValidationException([
    this.message = 'Taxonomy payload is invalid',
  ]);
  final String message;
  @override
  String toString() => 'TaxonomyValidationException: $message';
}

/// Provider selects between demo and real impl based on the authenticated
/// user — same heuristic as ``documentsRepositoryProvider``.
@Riverpod(keepAlive: true)
TaxonomyRepository taxonomyRepository(TaxonomyRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoTaxonomyRepository();
  }
  return RealTaxonomyRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
