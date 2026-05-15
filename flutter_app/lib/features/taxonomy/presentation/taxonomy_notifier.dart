import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

part 'taxonomy_notifier.g.dart';

/// State for the taxonomy viewer screen.
///
/// ``isRegenerating`` is separate from the AsyncValue's loading flag so
/// the UI can keep showing the previous taxonomy while the rebuild runs
/// in the background — admins want to see the old tree until the new
/// one is ready, not a blanking spinner.
@immutable
class TaxonomyViewerState {
  const TaxonomyViewerState({
    required this.taxonomy,
    required this.isRegenerating,
  });

  final Taxonomy taxonomy;
  final bool isRegenerating;

  TaxonomyViewerState copyWith({
    Taxonomy? taxonomy,
    bool? isRegenerating,
  }) =>
      TaxonomyViewerState(
        taxonomy: taxonomy ?? this.taxonomy,
        isRegenerating: isRegenerating ?? this.isRegenerating,
      );
}

/// AsyncNotifier for the workspace taxonomy.
///
/// Build does the first fetch. ``refresh`` re-fetches. ``regenerate``
/// fires the backend's POST /regenerate and then polls the GET endpoint
/// until ``taxonomy_version`` bumps — at which point the rebuild has
/// completed and we surface the new tree.
@riverpod
class TaxonomyViewer extends _$TaxonomyViewer {
  /// Cadence between polls during a regenerate. Overridable by tests so
  /// they don't burn real seconds.
  @visibleForTesting
  static Duration debugPollInterval = const Duration(seconds: 2);

  /// Cap the regenerate poll so a busted backend doesn't loop forever.
  /// Production: 60 attempts × 2s = 2 minutes. More than enough for a
  /// demo-scale workspace; bigger workspaces should switch to a real
  /// queue in v2 anyway (see sprint_2_11_decisions when written).
  @visibleForTesting
  static int debugMaxPollAttempts = 60;

  late String _workspaceId;

  @override
  Future<TaxonomyViewerState> build({required String workspaceId}) async {
    _workspaceId = workspaceId;
    final taxonomy = await ref
        .read(taxonomyRepositoryProvider)
        .get(workspaceId: workspaceId);
    return TaxonomyViewerState(taxonomy: taxonomy, isRegenerating: false);
  }

  /// Pull-to-refresh: re-fetch without showing a full-screen spinner.
  Future<void> refresh() async {
    final repo = ref.read(taxonomyRepositoryProvider);
    final fresh = await repo.get(workspaceId: _workspaceId);
    final current = state.valueOrNull;
    state = AsyncData(
      TaxonomyViewerState(
        taxonomy: fresh,
        isRegenerating: current?.isRegenerating ?? false,
      ),
    );
  }

  /// Fire the backend rebuild and poll until the version bumps.
  ///
  /// While polling, ``state.value.isRegenerating`` is true and
  /// ``state.value.taxonomy`` keeps showing the OLD tree so the screen
  /// doesn't blink. When the new version arrives we replace both.
  ///
  /// Errors surface via the AsyncValue: any failure (network, timeout)
  /// flips the notifier to AsyncError and the UI shows the standard
  /// error view.
  Future<void> regenerate() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final startingVersion = current.taxonomy.taxonomyVersion;
    state = AsyncData(current.copyWith(isRegenerating: true));

    final repo = ref.read(taxonomyRepositoryProvider);
    try {
      await repo.regenerate(workspaceId: _workspaceId);

      for (var attempt = 0; attempt < debugMaxPollAttempts; attempt++) {
        await Future<void>.delayed(debugPollInterval);
        final fresh = await repo.get(workspaceId: _workspaceId);
        if (fresh.taxonomyVersion > startingVersion) {
          state = AsyncData(
            TaxonomyViewerState(taxonomy: fresh, isRegenerating: false),
          );
          return;
        }
      }

      // Timed out — surface as an error so the UI can offer a retry.
      state = AsyncError(
        TimeoutException(
          'Regenerate did not complete within '
          '${debugPollInterval * debugMaxPollAttempts}',
        ),
        StackTrace.current,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
