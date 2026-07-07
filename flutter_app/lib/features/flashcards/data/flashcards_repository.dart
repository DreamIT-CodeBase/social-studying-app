import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/data/real_flashcards_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'flashcards_repository.g.dart';

/// Source-of-truth for the student-facing flashcard loop.
///
/// Mirrors the dual-impl pattern used by the questions + documents +
/// taxonomy features: an abstract interface, a demo implementation that
/// runs fully in-process for offline development, and a real Dio-backed
/// implementation that hits the FastAPI endpoints from Sprint 3.12.
///
/// The notifier layer never touches Dio directly. In tests, override
/// this provider via [ProviderScope.overrides] with a fake.
abstract class FlashcardsRepository {
  /// Generate (or fetch) the next flashcard for the calling student in
  /// `workspaceId`.
  ///
  /// Maps the backend's `POST /api/v1/workspaces/{ws}/flashcards/next`.
  ///
  /// Returns the FULL flashcard (front + back + explanation) — unlike
  /// the question loop, flashcards reveal everything; the UI controls
  /// when the back becomes visible via the flip gesture.
  ///
  /// Throws:
  /// - [NoFlashcardTopicsException] (409) when the workspace has no
  ///   canonical topics yet — UI should surface "admin needs to upload
  ///   study material" rather than retrying.
  /// - [FlashcardGenerationUnavailableException] (503) when the
  ///   pipeline exhausted its retries. Carries `retryAfterSeconds`
  ///   from the `Retry-After` header so the UI can back off.
  Future<Flashcard> next({
    required String workspaceId,
    List<String>? selectedTopicIds,
    double? mastery,
  });

  /// Record a student's self-rating for a flashcard they've reviewed.
  ///
  /// Maps `POST /api/v1/workspaces/{ws}/flashcards/{fc}/rate`. Returns
  /// the stored [FlashcardRatingResponse] (rating + timestamp) so the
  /// UI can update local state without a refetch.
  ///
  /// Throws:
  /// - [FlashcardNotFoundException] (404) — the flashcard was deleted
  ///   between fetch and rating.
  /// - [FlashcardNotRatableException] (409) — the flashcard moved to a
  ///   non-approved state (admin flagged it mid-review).
  Future<FlashcardRatingResponse> rate({
    required String workspaceId,
    required String flashcardId,
    required FlashcardRatingSubmission submission,
  });
}

/// Selects between the demo (in-process state machine) and the real
/// (Dio → backend) implementation based on the authenticated user.
///
/// Mirrors the questions repository's selection logic so the demo
/// user (`usr_demo_001` / `demo@socialstudyapp.com`) gets the offline
/// flow and any other user is assumed to be authenticated against
/// the real API.
@Riverpod(keepAlive: true)
FlashcardsRepository flashcardsRepository(FlashcardsRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoFlashcardsRepository();
  }
  return RealFlashcardsRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
