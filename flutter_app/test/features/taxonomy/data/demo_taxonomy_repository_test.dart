import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/taxonomy/data/demo_taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

void main() {
  test('first get seeds a small canonical taxonomy', () async {
    final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);

    final taxonomy = await repo.get(workspaceId: 'wsp_demo');
    expect(taxonomy.topics, isNotEmpty);
    expect(taxonomy.taxonomyVersion, 1);
    final names = taxonomy.topics.map((t) => t.name).toSet();
    expect(names.contains('Cells'), isTrue);
  });

  test('regenerate bumps the version and writes lastMergedAt', () async {
    final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);

    final before = await repo.get(workspaceId: 'wsp_demo');
    await repo.regenerate(workspaceId: 'wsp_demo');
    final after = await repo.get(workspaceId: 'wsp_demo');

    // The version bump is the canonical "regenerate happened" signal.
    // lastMergedAt is also written but DateTime.now() with no network
    // delay can collide within a microsecond, so we don't assert on it.
    expect(after.taxonomyVersion, before.taxonomyVersion + 1);
    expect(after.lastMergedAt, isNotNull);
  });

  test('different workspaces get independent taxonomies', () async {
    final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);

    await repo.get(workspaceId: 'wsp_one');
    await repo.regenerate(workspaceId: 'wsp_one');

    final two = await repo.get(workspaceId: 'wsp_two');
    expect(two.taxonomyVersion, 1,
        reason: 'wsp_two should not inherit wsp_one\'s version bump');
  });

  group('update (Sprint 4.3)', () {
    test('successful update bumps the version and persists the topics',
        () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      final renamed = [
        for (final t in loaded.topics)
          if (t.id == 'tpc_demo_cells') t.copyWith(name: 'Cell Structure') else t,
      ];

      final updated = await repo.update(
        workspaceId: 'wsp_demo',
        expectedVersion: loaded.taxonomyVersion,
        topics: renamed,
      );

      expect(updated.taxonomyVersion, loaded.taxonomyVersion + 1);
      expect(
        updated.topics.firstWhere((t) => t.id == 'tpc_demo_cells').name,
        'Cell Structure',
      );

      // Re-fetch reflects the same version.
      final reread = await repo.get(workspaceId: 'wsp_demo');
      expect(reread.taxonomyVersion, updated.taxonomyVersion);
    });

    test('a version mismatch throws TaxonomyVersionConflictException',
        () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      // Someone else saved in the meantime.
      await repo.update(
        workspaceId: 'wsp_demo',
        expectedVersion: loaded.taxonomyVersion,
        topics: loaded.topics,
      );

      expect(
        () => repo.update(
          workspaceId: 'wsp_demo',
          expectedVersion: loaded.taxonomyVersion,
          topics: loaded.topics,
        ),
        throwsA(isA<TaxonomyVersionConflictException>()),
      );
    });

    test('unknown workspace throws TaxonomyWorkspaceNotFoundException',
        () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);

      expect(
        () => repo.update(
          workspaceId: 'wsp_never_loaded',
          expectedVersion: 1,
          topics: const [],
        ),
        throwsA(isA<TaxonomyWorkspaceNotFoundException>()),
      );
    });

    test('duplicate topic id triggers validation', () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      final dup = [
        ...loaded.topics,
        // Same id as an existing topic.
        const CanonicalTopic(id: 'tpc_demo_cells', name: 'Decoy'),
      ];

      expect(
        () => repo.update(
          workspaceId: 'wsp_demo',
          expectedVersion: loaded.taxonomyVersion,
          topics: dup,
        ),
        throwsA(isA<TaxonomyValidationException>()),
      );
    });

    test('duplicate name (case-insensitive) triggers validation', () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      final dup = [
        ...loaded.topics,
        const CanonicalTopic(id: 'tpc_extra', name: 'cells'),
      ];

      expect(
        () => repo.update(
          workspaceId: 'wsp_demo',
          expectedVersion: loaded.taxonomyVersion,
          topics: dup,
        ),
        throwsA(isA<TaxonomyValidationException>()),
      );
    });

    test('empty name triggers validation', () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      final renamed = [
        for (final t in loaded.topics)
          if (t.id == 'tpc_demo_cells') t.copyWith(name: '   ') else t,
      ];

      expect(
        () => repo.update(
          workspaceId: 'wsp_demo',
          expectedVersion: loaded.taxonomyVersion,
          topics: renamed,
        ),
        throwsA(isA<TaxonomyValidationException>()),
      );
    });

    test('dangling parent_id triggers validation', () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      final dangling = [
        for (final t in loaded.topics)
          if (t.id == 'tpc_demo_photo')
            t.copyWith(parentId: 'tpc_never_existed')
          else
            t,
      ];

      expect(
        () => repo.update(
          workspaceId: 'wsp_demo',
          expectedVersion: loaded.taxonomyVersion,
          topics: dangling,
        ),
        throwsA(isA<TaxonomyValidationException>()),
      );
    });

    test('cycle in parent chain triggers validation', () async {
      final repo = DemoTaxonomyRepository(networkDelay: Duration.zero);
      final loaded = await repo.get(workspaceId: 'wsp_demo');

      // Make tpc_demo_cells point to its own child — A → B → A.
      final cyclic = [
        for (final t in loaded.topics)
          if (t.id == 'tpc_demo_cells')
            t.copyWith(parentId: 'tpc_demo_photo')
          else
            t,
      ];

      expect(
        () => repo.update(
          workspaceId: 'wsp_demo',
          expectedVersion: loaded.taxonomyVersion,
          topics: cyclic,
        ),
        throwsA(isA<TaxonomyValidationException>()),
      );
    });
  });
}
