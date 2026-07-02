import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/features/questions/data/real_questions_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/question.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'questions_repository.g.dart';

/// Source-of-truth for the student-facing question loop.
///
/// Mirrors the dual-impl pattern used by the documents + taxonomy
/// features: an abstract interface, a demo implementation that runs
/// fully in-process for offline development, and a real Dio-backed
/// implementation that hits the FastAPI endpoints from Sprint 3.9 /
/// 3.10.
///
/// The notifier layer never touches Dio directly. In tests, override
/// this provider via [ProviderScope.overrides] with a fake.
abstract class QuestionsRepository {
  /// Generate (or fetch from prefetch queue) the next adaptive question
  /// for the calling student in `workspaceId`.
  ///
  /// Maps the backend's `POST /api/v1/workspaces/{ws}/questions/next`.
  ///
  /// Throws:
  /// - [NoTopicsAvailableException] (409) when the workspace has no
  ///   canonical topics yet — UI should surface "admin needs to upload
  ///   study material" rather than retrying.
  /// - [QuestionGenerationUnavailableException] (503) when the
  ///   pipeline exhausted its retries. Include `retryAfterSeconds`
  ///   from the `Retry-After` header so the UI can back off intelligently.
  Future<Question> next({required String workspaceId, bool revision = false});

  /// Submit a student's answer to a previously-served question.
  ///
  /// Maps `POST /api/v1/workspaces/{ws}/questions/{qst}/answer`.
  /// Returns the full [AnswerFeedback] with correctness + explanation
  /// + XP + new mastery scores.
  ///
  /// Throws:
  /// - [QuestionNotFoundException] (404) — the question was deleted
  ///   between fetch and submit.
  /// - [QuestionNotAnswerableException] (409) — the question is in
  ///   `pending_review` or similar non-answerable state.
  Future<AnswerFeedback> submitAnswer({
    required String workspaceId,
    required String questionId,
    required AnswerSubmission submission,
  });
}

/// Selects between the demo (in-process state machine) and the real
/// (Dio → backend) implementation based on the authenticated user.
///
/// Mirrors the documents repository's selection logic so the demo
/// user (`usr_demo_001` / `demo@socialstudyapp.com`) gets the offline
/// flow and any other user is assumed to be authenticated against
/// the real API.
@Riverpod(keepAlive: true)
QuestionsRepository questionsRepository(QuestionsRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoQuestionsRepository();
  }
  return RealQuestionsRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
