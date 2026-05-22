import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/progress/data/demo_progress_repository.dart';
import 'package:social_study_app/features/progress/data/real_progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'progress_repository.g.dart';

/// Source-of-truth for student progress (per-topic mastery, level/XP,
/// recent activity timeline). Backs the student progress view (4.11).
///
/// **Contract note.** `GET /workspaces/{ws}/users/{uid}/progress` is a
/// Sprint 5.9 endpoint and is not implemented yet. [RealProgressRepository]
/// is coded against the documented contract (plan §5.7) and will work
/// once 5.9 ships; [DemoProgressRepository] serves a plausible snapshot
/// fully offline today so the screen and its tests are complete now.
abstract class ProgressRepository {
  /// Fetch the progress snapshot for `userId` in `workspaceId`.
  ///
  /// Maps `GET /api/v1/workspaces/{ws}/users/{uid}/progress`. A student
  /// with no interaction history yields [StudentProgress.empty] rather
  /// than an error — "no data yet" is a normal state, not a failure.
  Future<StudentProgress> fetch({
    required String workspaceId,
    required String userId,
  });
}

/// Selects between the demo (in-process) and real (Dio → backend)
/// implementation based on the authenticated user — same heuristic as
/// every other repository in the app.
@Riverpod(keepAlive: true)
ProgressRepository progressRepository(ProgressRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoProgressRepository();
  }
  return RealProgressRepository(dio: ref.read(dioClientProvider).dio);
}

bool _isDemoUser(User user) =>
    user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com';
