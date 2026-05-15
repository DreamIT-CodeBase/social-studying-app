import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/taxonomy/data/demo_taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/data/real_taxonomy_repository.dart';
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
}

/// Thrown when the workspace doesn't exist on the backend. The notifier
/// surfaces this as an explicit "no workspace yet" empty state rather
/// than a generic error.
class TaxonomyWorkspaceNotFoundException implements Exception {
  const TaxonomyWorkspaceNotFoundException();

  @override
  String toString() => 'TaxonomyWorkspaceNotFoundException';
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

bool _isDemoUser(User user) =>
    user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com';
