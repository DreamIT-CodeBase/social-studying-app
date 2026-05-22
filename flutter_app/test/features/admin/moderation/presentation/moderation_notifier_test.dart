import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/data/moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_notifier.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

User _adminUser() => User(
      id: 'usr_demo_001',
      email: 'demo@socialstudyapp.com',
      displayName: 'Demo Admin',
      tenantId: 'ten_demo',
      role: UserRole.tenantAdmin,
      createdAt: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _container(ModerationRepository repo) async {
  final authRepo = _MockAuthRepo();
  when(() => authRepo.getStoredUser()).thenAnswer((_) async => _adminUser());
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      moderationRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authNotifierProvider.future);
  return container;
}

void main() {
  group('ModerationQueue', () {
    test('build loads the pending queue', () async {
      final container = await _container(DemoModerationRepository());
      final queue = await container
          .read(moderationQueueProvider('wsp_demo_001').future);
      expect(queue, hasLength(2));
    });

    test('resolve drops the item from the refreshed queue', () async {
      final container = await _container(DemoModerationRepository());
      await container.read(moderationQueueProvider('wsp_demo_001').future);

      await container
          .read(moderationQueueProvider('wsp_demo_001').notifier)
          .resolve(
            workspaceId: 'wsp_demo_001',
            itemId: 'mod_demo_001',
            approved: true,
          );

      final queue = await container
          .read(moderationQueueProvider('wsp_demo_001').future);
      expect(queue, hasLength(1));
    });
  });

  group('ModerationLog', () {
    test('build loads the resolved-items audit log', () async {
      final container = await _container(DemoModerationRepository());
      final log = await container
          .read(moderationLogProvider('wsp_demo_001').future);
      // Seeded with one already-resolved item.
      expect(log, hasLength(1));
    });
  });
}
