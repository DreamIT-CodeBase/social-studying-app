import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/taxonomy/data/demo_taxonomy_repository.dart';

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
}
