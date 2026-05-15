import 'dart:async';

import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

/// In-process demo repository so the viewer screen renders something
/// useful when the app runs against the synthetic auth flow (no backend).
///
/// Why a synthetic three-topic tree
/// --------------------------------
/// The demo flow's documents repository can't realistically produce a
/// taxonomy on its own — the canonical taxonomy on the backend is built
/// by the topic-extraction worker against GPT-4o. Faking the whole AI
/// pipeline in the demo is out of scope. Instead, we seed a small
/// hand-shaped taxonomy at construction time so the viewer screen has
/// content to render and the regenerate button has something to "rebuild".
class DemoTaxonomyRepository implements TaxonomyRepository {
  DemoTaxonomyRepository({
    Duration networkDelay = const Duration(milliseconds: 350),
  }) : _networkDelay = networkDelay;

  final Duration _networkDelay;

  /// Workspace id → current taxonomy. Mutable so regenerate can bump
  /// ``taxonomyVersion`` and force the viewer to re-render.
  final Map<String, Taxonomy> _byWorkspace = {};

  @override
  Future<Taxonomy> get({required String workspaceId}) async {
    await Future<void>.delayed(_networkDelay);
    return _byWorkspace.putIfAbsent(workspaceId, _seedTaxonomy);
  }

  @override
  Future<void> regenerate({required String workspaceId}) async {
    await Future<void>.delayed(_networkDelay);
    // "Rebuild" by bumping the version and reshuffling the source-doc
    // counts so the UI has a visible diff after polling.
    final current = _byWorkspace[workspaceId] ?? _seedTaxonomy();
    _byWorkspace[workspaceId] = current.copyWith(
      taxonomyVersion: current.taxonomyVersion + 1,
      lastMergedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Taxonomy _seedTaxonomy() {
    return Taxonomy(
      taxonomyVersion: 1,
      lastMergedAt: DateTime.now().toUtc().toIso8601String(),
      topics: const [
        CanonicalTopic(
          id: 'tpc_demo_cells',
          name: 'Cells',
          description: 'The basic structural and functional units of life.',
          complexityLevel: 2,
          sourceDocumentIds: ['doc_demo_001'],
        ),
        CanonicalTopic(
          id: 'tpc_demo_photo',
          name: 'Photosynthesis',
          parentId: 'tpc_demo_cells',
          aliases: ['Plant Energy'],
          description:
              'How plants convert light energy into chemical energy stored in sugars.',
          complexityLevel: 3,
          sourceDocumentIds: ['doc_demo_001'],
        ),
        CanonicalTopic(
          id: 'tpc_demo_respir',
          name: 'Cellular Respiration',
          parentId: 'tpc_demo_cells',
          description:
              'How cells release the energy stored in glucose to power their activities.',
          complexityLevel: 4,
          sourceDocumentIds: ['doc_demo_001'],
        ),
      ],
    );
  }
}
