import 'package:social_study_app/shared/models/taxonomy.dart';

/// One row in the depth-ordered render list produced by [buildTopicTree].
///
/// The viewer screen renders these as indented cards. Keeping ``depth``
/// computed here (not in the widget) means the tree-building logic is
/// trivially unit-testable in isolation from any Widget machinery.
class TopicTreeRow {
  const TopicTreeRow({
    required this.topic,
    required this.depth,
    required this.childCount,
  });

  /// The canonical topic this row renders.
  final CanonicalTopic topic;

  /// Distance from the nearest root. 0 = root, 1 = direct child, etc.
  final int depth;

  /// How many direct children this topic has. Used by the viewer to
  /// show a "+N subtopics" hint or to gate disclosure indicators.
  final int childCount;
}

/// Turn a workspace's flat ``CanonicalTopic`` list into a depth-ordered
/// render list suitable for an indented ListView.
///
/// Rules
/// -----
/// - Topics with no parent (or whose parent isn't in the list) are
///   treated as roots. Stray refs becoming roots is intentional — it
///   matches what a re-render after a bad PUT would show, and the
///   backend's validation already rejects them at write time.
/// - Roots are emitted alphabetically by name so the viewer is stable
///   across re-fetches even when the backend's storage order isn't.
/// - Subtrees are walked depth-first; siblings sorted alphabetically.
/// - Cycle defense: a visited-set on each subtree walk catches
///   ``A → B → A`` even though the backend's sanitizer should have
///   blocked it. Cycle-closing rows are silently dropped (logged at
///   debug if Flutter's logger is wired in a higher layer).
///
/// Returns an empty list when ``topics`` is empty.
List<TopicTreeRow> buildTopicTree(List<CanonicalTopic> topics) {
  if (topics.isEmpty) return const <TopicTreeRow>[];

  final byId = <String, CanonicalTopic>{
    for (final t in topics) t.id: t,
  };

  // Children-by-parent index. ``null`` key holds roots.
  final childrenByParent = <String?, List<CanonicalTopic>>{};
  for (final t in topics) {
    // A non-null parent_id that doesn't resolve in this list is treated
    // as a root — the topic still gets rendered.
    final parent =
        t.parentId == null || !byId.containsKey(t.parentId!) ? null : t.parentId;
    childrenByParent.putIfAbsent(parent, () => []).add(t);
  }
  for (final list in childrenByParent.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }

  final out = <TopicTreeRow>[];
  final emitted = <String>{};
  for (final root in childrenByParent[null] ?? const <CanonicalTopic>[]) {
    _walk(root, 0, byId, childrenByParent, out, visited: {root.id},
        emitted: emitted);
  }

  // Pure cycles (A ↔ B with no real root anywhere) leave topics
  // unreached by the null-rooted walk above. Defense in depth: promote
  // any unreached topic to a root in alphabetical order so the viewer
  // still renders something instead of silently dropping the whole
  // cycle. Backend validation should have prevented this, but a stale
  // client cache shouldn't black-hole the screen.
  final unreached = topics.where((t) => !emitted.contains(t.id)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  for (final orphan in unreached) {
    if (emitted.contains(orphan.id)) continue; // covered by a prior walk
    _walk(orphan, 0, byId, childrenByParent, out, visited: {orphan.id},
        emitted: emitted);
  }
  return out;
}

void _walk(
  CanonicalTopic topic,
  int depth,
  Map<String, CanonicalTopic> byId,
  Map<String?, List<CanonicalTopic>> childrenByParent,
  List<TopicTreeRow> out, {
  required Set<String> visited,
  required Set<String> emitted,
}) {
  final children = childrenByParent[topic.id] ?? const <CanonicalTopic>[];
  out.add(TopicTreeRow(
    topic: topic,
    depth: depth,
    childCount: children.length,
  ));
  emitted.add(topic.id);
  for (final child in children) {
    if (visited.contains(child.id) || emitted.contains(child.id)) {
      // Cycle within this walk, or already emitted from a sibling walk.
      // Skip — the row already exists earlier in the render list.
      continue;
    }
    _walk(
      child,
      depth + 1,
      byId,
      childrenByParent,
      out,
      visited: {...visited, child.id},
      emitted: emitted,
    );
  }
}
