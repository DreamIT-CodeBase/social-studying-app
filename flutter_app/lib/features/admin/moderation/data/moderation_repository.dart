import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/data/real_moderation_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/moderation.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'moderation_repository.g.dart';

/// Source-of-truth for the moderation dashboard (4.5) — the queue of
/// flagged content, the approve/reject action, and the audit log.
///
/// **Contract note.** The moderation endpoints (plan §5.8) are a
/// Sprint 6 surface, not yet implemented. [RealModerationRepository] is
/// coded against the documented contract; [DemoModerationRepository]
/// serves a working queue offline today so the dashboard and its tests
/// are complete now.
abstract class ModerationRepository {
  /// Items still awaiting an admin decision.
  ///
  /// Maps `GET /workspaces/{ws}/moderation/flagged`.
  Future<List<FlaggedItem>> listFlagged(String workspaceId);

  /// Resolve a flagged item — `approved: true` clears it for use,
  /// `false` rejects it. Returns the item with its updated verdict.
  ///
  /// Maps `PUT /workspaces/{ws}/moderation/{itemId}/resolve`.
  /// Throws [FlaggedItemNotFoundException] (404).
  Future<FlaggedItem> resolve({
    required String workspaceId,
    required String itemId,
    required bool approved,
  });

  /// The audit trail of already-resolved items.
  ///
  /// Maps `GET /workspaces/{ws}/moderation/log`.
  Future<List<FlaggedItem>> listLog(String workspaceId);
}

/// Selects demo vs. real implementation by authenticated user.
@Riverpod(keepAlive: true)
ModerationRepository moderationRepository(ModerationRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoModerationRepository();
  }
  return RealModerationRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
