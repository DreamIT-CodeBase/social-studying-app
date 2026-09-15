import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/progress/data/demo_progress_repository.dart';
import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/models/user.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

User _demoUser() => User(
      id: 'usr_demo_001',
      email: 'demo@socialstudyapp.com',
      displayName: 'Demo Student',
      tenantId: 'ten_demo',
      role: UserRole.student,
      createdAt: DateTime(2026, 1, 1),
      lastLogin: DateTime(2026, 1, 1),
    );

ProviderContainer _container({
  required AuthRepository authRepo,
  required ProgressRepository progressRepo,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      progressRepositoryProvider.overrideWithValue(progressRepo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('StudentProgressNotifier', () {
    test('fetches the snapshot for the authenticated student', () async {
      final authRepo = _MockAuthRepo();
      when(() => authRepo.getStoredUser()).thenAnswer((_) async => _demoUser());
      final container = _container(
        authRepo: authRepo,
        progressRepo: DemoProgressRepository(),
      );
      // Let auth settle before reading the progress notifier.
      await container.read(authNotifierProvider.future);

      final progress = await container.read(
        studentProgressNotifierProvider('wsp_a').future,
      );

      expect(progress.level, 3);
      expect(progress.hasActivity, isTrue);
    });

    test('falls back to the zero state when unauthenticated', () async {
      final authRepo = _MockAuthRepo();
      // No stored user → AuthNotifier resolves to unauthenticated.
      when(() => authRepo.getStoredUser()).thenAnswer((_) async => null);
      final container = _container(
        authRepo: authRepo,
        progressRepo: DemoProgressRepository(),
      );
      await container.read(authNotifierProvider.future);

      final progress = await container.read(
        studentProgressNotifierProvider('wsp_a').future,
      );

      expect(progress, StudentProgress.empty);
    });

    test('refresh re-runs the fetch and still resolves', () async {
      final authRepo = _MockAuthRepo();
      when(() => authRepo.getStoredUser()).thenAnswer((_) async => _demoUser());
      final container = _container(
        authRepo: authRepo,
        progressRepo: DemoProgressRepository(),
      );
      await container.read(authNotifierProvider.future);
      await container.read(studentProgressNotifierProvider('wsp_a').future);

      container
          .read(studentProgressNotifierProvider('wsp_a').notifier)
          .refresh();
      final reloaded = await container.read(
        studentProgressNotifierProvider('wsp_a').future,
      );

      expect(reloaded.level, 3);
    });
  });
}
