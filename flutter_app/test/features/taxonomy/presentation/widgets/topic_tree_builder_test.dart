import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/taxonomy/presentation/widgets/topic_tree_builder.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

CanonicalTopic _t(
  String id,
  String name, {
  String? parentId,
}) =>
    CanonicalTopic(id: id, name: name, parentId: parentId);

void main() {
  test('empty input → empty output', () {
    expect(buildTopicTree(const []), isEmpty);
  });

  test('single root → one row at depth 0 with zero children', () {
    final rows = buildTopicTree([_t('a', 'Cells')]);
    expect(rows, hasLength(1));
    expect(rows.first.topic.id, 'a');
    expect(rows.first.depth, 0);
    expect(rows.first.childCount, 0);
  });

  test('parent + two children render parent first then alphabetical children',
      () {
    final rows = buildTopicTree([
      _t('parent', 'Cells'),
      _t('beta', 'Bacteria', parentId: 'parent'),
      _t('alpha', 'Animals', parentId: 'parent'),
    ]);

    expect(rows.map((r) => r.topic.id), ['parent', 'alpha', 'beta']);
    expect(rows.map((r) => r.depth), [0, 1, 1]);
    expect(rows.first.childCount, 2);
  });

  test('multi-level tree gets correct depths', () {
    final rows = buildTopicTree([
      _t('root', 'Biology'),
      _t('mid', 'Cells', parentId: 'root'),
      _t('leaf', 'Mitochondria', parentId: 'mid'),
    ]);
    final byId = {for (final r in rows) r.topic.id: r};

    expect(byId['root']!.depth, 0);
    expect(byId['mid']!.depth, 1);
    expect(byId['leaf']!.depth, 2);
    expect(byId['root']!.childCount, 1);
    expect(byId['mid']!.childCount, 1);
    expect(byId['leaf']!.childCount, 0);
  });

  test('multiple roots are emitted alphabetically', () {
    final rows = buildTopicTree([
      _t('a', 'Zeta'),
      _t('b', 'Alpha'),
      _t('c', 'Mu'),
    ]);
    expect(rows.map((r) => r.topic.name), ['Alpha', 'Mu', 'Zeta']);
    expect(rows.every((r) => r.depth == 0), isTrue);
  });

  test('topic with parent_id pointing outside the list is treated as root', () {
    // The backend can return this after a doc deletion that left a
    // dangling parent ref. The viewer must still render the topic.
    final rows = buildTopicTree([
      _t('orphan', 'Standalone', parentId: 'tpc_ghost'),
    ]);
    expect(rows, hasLength(1));
    expect(rows.first.depth, 0);
  });

  test('cycle is broken: A → B → A renders both topics without infinite loop',
      () {
    // Backend validation should prevent this, but defense in depth — a
    // stale frontend cache that pre-dates the cycle break shouldn't
    // crash the viewer.
    final rows = buildTopicTree([
      _t('a', 'A', parentId: 'b'),
      _t('b', 'B', parentId: 'a'),
    ]);
    // Both topics are present; total rows is bounded.
    expect(rows.length, lessThanOrEqualTo(3));
    final ids = rows.map((r) => r.topic.id).toSet();
    expect(ids, {'a', 'b'});
  });

  test('child of a "dangling parent" still appears under its real root', () {
    // root → mid (mid has dangling parent_id) → leaf
    // The dangling ref converts `mid` into a root; `leaf` should sit
    // under `mid`, not under the unresolvable parent.
    final rows = buildTopicTree([
      _t('mid', 'Mid', parentId: 'tpc_ghost'),
      _t('leaf', 'Leaf', parentId: 'mid'),
    ]);
    final byId = {for (final r in rows) r.topic.id: r};
    expect(byId['mid']!.depth, 0);
    expect(byId['leaf']!.depth, 1);
  });

  test('child counts reflect only direct children, not descendants', () {
    final rows = buildTopicTree([
      _t('root', 'Root'),
      _t('mid', 'Mid', parentId: 'root'),
      _t('leaf', 'Leaf', parentId: 'mid'),
    ]);
    final byId = {for (final r in rows) r.topic.id: r};
    expect(byId['root']!.childCount, 1); // only `mid` is direct
  });
}
