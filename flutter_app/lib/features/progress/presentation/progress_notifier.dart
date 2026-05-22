import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';

part 'progress_notifier.g.dart';

/// Loads the calling student's progress snapshot for one workspace.
///
/// Family-keyed by `workspaceId`. The user id is resolved from
/// [authNotifierProvider] rather than passed in — the progress screen
/// only ever shows the *current* student's data (the admin per-student
/// view is a separate Sprint 5.10 surface).
///
/// Exposes [refresh] for pull-to-refresh and for re-fetching after an
/// answer/rating elsewhere in the app bumps mastery.
@riverpod
class StudentProgressNotifier extends _$StudentProgressNotifier {
  @override
  Future<StudentProgress> build(String workspaceId) async {
    final userId = ref.watch(authNotifierProvider).valueOrNull?.maybeWhen(
          authenticated: (user) => user.id,
          orElse: () => null,
        );
    // No authenticated user — a guarded route should make this
    // unreachable, but returning the zero state beats throwing.
    if (userId == null) return StudentProgress.empty;

    return ref.read(progressRepositoryProvider).fetch(
          workspaceId: workspaceId,
          userId: userId,
        );
  }

  /// Re-fetch. `invalidateSelf` re-runs [build] with the same workspace
  /// argument — used by pull-to-refresh and the error-state retry.
  void refresh() => ref.invalidateSelf();
}
