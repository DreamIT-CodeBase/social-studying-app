import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart';
import 'package:social_study_app/shared/models/moderation.dart';

void main() {
  group('DemoModerationRepository.listFlagged', () {
    test('returns only the pending items (resolved seed excluded)', () async {
      final repo = DemoModerationRepository();
      final flagged = await repo.listFlagged('wsp_demo_001');
      expect(flagged, hasLength(2));
      expect(flagged.every((i) => i.isPending), isTrue);
    });

    test('returns an unmodifiable view', () async {
      final repo = DemoModerationRepository();
      final flagged = await repo.listFlagged('wsp_demo_001');
      expect(() => flagged.clear(), throwsUnsupportedError);
    });
  });

  group('DemoModerationRepository.resolve', () {
    test('approving sets the verdict and drops it from the queue', () async {
      final repo = DemoModerationRepository();
      final resolved = await repo.resolve(
        workspaceId: 'wsp_demo_001',
        itemId: 'mod_demo_001',
        approved: true,
      );
      expect(resolved.verdict, ModerationVerdict.approved);

      final flagged = await repo.listFlagged('wsp_demo_001');
      expect(flagged.map((i) => i.id), isNot(contains('mod_demo_001')));
    });

    test('rejecting sets the rejected verdict', () async {
      final repo = DemoModerationRepository();
      final resolved = await repo.resolve(
        workspaceId: 'wsp_demo_001',
        itemId: 'mod_demo_002',
        approved: false,
      );
      expect(resolved.verdict, ModerationVerdict.rejected);
    });

    test('throws FlaggedItemNotFoundException for an unknown id', () async {
      final repo = DemoModerationRepository();
      expect(
        () => repo.resolve(
          workspaceId: 'wsp_demo_001',
          itemId: 'mod_ghost',
          approved: true,
        ),
        throwsA(isA<FlaggedItemNotFoundException>()),
      );
    });
  });

  group('DemoModerationRepository.listLog', () {
    test('returns resolved items — including ones just resolved', () async {
      final repo = DemoModerationRepository();
      // Seeded with one already-approved item.
      expect(await repo.listLog('wsp_demo_001'), hasLength(1));

      await repo.resolve(
        workspaceId: 'wsp_demo_001',
        itemId: 'mod_demo_001',
        approved: false,
      );
      final log = await repo.listLog('wsp_demo_001');
      expect(log, hasLength(2));
      expect(log.every((i) => !i.isPending), isTrue);
    });
  });
}
