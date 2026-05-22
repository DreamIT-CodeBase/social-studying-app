import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';

void main() {
  group('DemoWorkspacesRepository.list', () {
    test('is seeded with the Demo Classroom workspace', () async {
      final repo = DemoWorkspacesRepository();
      final list = await repo.list();
      expect(list, hasLength(1));
      expect(list.single.id, 'wsp_demo_001');
      expect(list.single.name, 'Demo Classroom');
    });

    test('returns an unmodifiable view — callers cannot mutate it',
        () async {
      final repo = DemoWorkspacesRepository();
      final list = await repo.list();
      expect(() => list.clear(), throwsUnsupportedError);
    });
  });

  group('DemoWorkspacesRepository.create', () {
    test('adds a workspace the next list call reflects', () async {
      final repo = DemoWorkspacesRepository();
      final created = await repo.create(name: 'Biology 101');
      expect(created.name, 'Biology 101');
      expect(created.id, startsWith('wsp_demo_'));

      final list = await repo.list();
      expect(list, hasLength(2));
      expect(list.map((w) => w.name), contains('Biology 101'));
    });

    test('trims the name and stores an empty description by default',
        () async {
      final repo = DemoWorkspacesRepository();
      final created = await repo.create(name: '  Chemistry  ');
      expect(created.name, 'Chemistry');
      expect(created.description, isEmpty);
    });

    test('throws WorkspaceNameConflictException on a duplicate name',
        () async {
      final repo = DemoWorkspacesRepository();
      // Case-insensitive clash with the seeded "Demo Classroom".
      expect(
        () => repo.create(name: 'demo classroom'),
        throwsA(isA<WorkspaceNameConflictException>()),
      );
    });
  });

  group('DemoWorkspacesRepository.update', () {
    test('patches name and description, leaving settings untouched',
        () async {
      final repo = DemoWorkspacesRepository();
      final updated = await repo.update(
        workspaceId: 'wsp_demo_001',
        name: 'Renamed Classroom',
        description: 'Updated blurb',
      );
      expect(updated.name, 'Renamed Classroom');
      expect(updated.description, 'Updated blurb');
      expect(updated.settings, isNotNull);
    });

    test('throws WorkspaceNotFoundException for an unknown id', () async {
      final repo = DemoWorkspacesRepository();
      expect(
        () => repo.update(workspaceId: 'wsp_ghost', name: 'X'),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });

    test('rejects renaming onto another workspace name', () async {
      final repo = DemoWorkspacesRepository();
      await repo.create(name: 'Physics');
      expect(
        () => repo.update(workspaceId: 'wsp_demo_001', name: 'Physics'),
        throwsA(isA<WorkspaceNameConflictException>()),
      );
    });
  });

  group('DemoWorkspacesRepository.delete', () {
    test('removes the workspace from the list', () async {
      final repo = DemoWorkspacesRepository();
      await repo.delete('wsp_demo_001');
      expect(await repo.list(), isEmpty);
    });

    test('throws WorkspaceNotFoundException for an unknown id', () async {
      final repo = DemoWorkspacesRepository();
      expect(
        () => repo.delete('wsp_ghost'),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });
  });

  group('DemoWorkspacesRepository.generateInviteCode', () {
    test('produces an 8-char uppercase code', () async {
      final repo = DemoWorkspacesRepository();
      final invite = await repo.generateInviteCode('wsp_demo_001');
      expect(invite.code, hasLength(8));
      expect(invite.code, equals(invite.code.toUpperCase()));
      expect(invite.expiresAt, isNotNull);
    });

    test('throws WorkspaceNotFoundException for an unknown id', () async {
      final repo = DemoWorkspacesRepository();
      expect(
        () => repo.generateInviteCode('wsp_ghost'),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });
  });
}
