import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_notifier.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

class _MockRepo extends Mock implements TaxonomyRepository {}

Taxonomy _tax({int version = 1, List<CanonicalTopic>? topics}) => Taxonomy(
      taxonomyVersion: version,
      topics: topics ??
          const [
            CanonicalTopic(id: 'tpc_a', name: 'Cells'),
          ],
    );

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    TaxonomyViewer.debugPollInterval = const Duration(milliseconds: 5);
    TaxonomyViewer.debugMaxPollAttempts = 20;
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        taxonomyRepositoryProvider.overrideWith((_) => repo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    TaxonomyViewer.debugPollInterval = const Duration(seconds: 2);
    TaxonomyViewer.debugMaxPollAttempts = 60;
  });

  /// Subscribe AND read, keeping the subscription open in the test's
  /// scope. The @riverpod auto-dispose can tear down state between
  /// consecutive ``read`` calls otherwise — an earlier draft of these
  /// tests saw ``AsyncLoading`` where ``AsyncError`` was expected
  /// because the notifier was rebuilt between regenerate and the
  /// assertion. Each test calls this AFTER setting up its mocks.
  Future<TaxonomyViewerState> readState() async {
    // The subscription is intentionally never closed — the container's
    // dispose() in tearDown handles cleanup for the whole graph.
    container.listen<AsyncValue<TaxonomyViewerState>>(
      taxonomyViewerProvider(workspaceId: 'wsp_test'),
      (_, __) {},
    );
    return container.read(
      taxonomyViewerProvider(workspaceId: 'wsp_test').future,
    );
  }

  test('build returns the repo taxonomy with isRegenerating=false', () async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax(version: 3));

    final state = await readState();
    expect(state.taxonomy.taxonomyVersion, 3);
    expect(state.isRegenerating, isFalse);
  });

  test('refresh re-fetches without losing the previous data on the wire',
      () async {
    var callCount = 0;
    when(() => repo.get(workspaceId: 'wsp_test')).thenAnswer((_) async {
      callCount++;
      return _tax(version: callCount);
    });

    await readState();
    await container
        .read(
            taxonomyViewerProvider(workspaceId: 'wsp_test').notifier)
        .refresh();

    final state = await readState();
    expect(state.taxonomy.taxonomyVersion, 2);
    verify(() => repo.get(workspaceId: 'wsp_test')).called(2);
  });

  test('regenerate polls until version bumps, then surfaces the new taxonomy',
      () async {
    var pollCount = 0;
    when(() => repo.get(workspaceId: 'wsp_test')).thenAnswer((_) async {
      pollCount++;
      // First read = build (version 1). After regenerate fires, the
      // first 2 polls still see version 1; the 3rd poll sees version 2.
      if (pollCount <= 3) return _tax(version: 1);
      return _tax(version: 2);
    });
    when(() => repo.regenerate(workspaceId: 'wsp_test'))
        .thenAnswer((_) async {});

    await readState();
    await container
        .read(
            taxonomyViewerProvider(workspaceId: 'wsp_test').notifier)
        .regenerate();

    final state = await readState();
    expect(state.taxonomy.taxonomyVersion, 2);
    expect(state.isRegenerating, isFalse);
    verify(() => repo.regenerate(workspaceId: 'wsp_test')).called(1);
  });

  test('regenerate surfaces TimeoutException when version never bumps',
      () async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax(version: 1));
    when(() => repo.regenerate(workspaceId: 'wsp_test'))
        .thenAnswer((_) async {});
    TaxonomyViewer.debugMaxPollAttempts = 3;

    await readState();
    await container
        .read(
            taxonomyViewerProvider(workspaceId: 'wsp_test').notifier)
        .regenerate();

    final raw = container.read(
        taxonomyViewerProvider(workspaceId: 'wsp_test'));
    expect(raw, isA<AsyncError<TaxonomyViewerState>>());
  });

  test('regenerate failure during the POST surfaces as AsyncError', () async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax(version: 1));
    when(() => repo.regenerate(workspaceId: 'wsp_test'))
        .thenThrow(Exception('backend exploded'));

    await readState();
    await container
        .read(
            taxonomyViewerProvider(workspaceId: 'wsp_test').notifier)
        .regenerate();

    final raw = container.read(
        taxonomyViewerProvider(workspaceId: 'wsp_test'));
    expect(raw, isA<AsyncError<TaxonomyViewerState>>());
    expect(
      (raw as AsyncError).error.toString(),
      contains('backend exploded'),
    );
  });

  test(
      'TaxonomyWorkspaceNotFoundException from the repo propagates to AsyncError',
      () async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenThrow(const TaxonomyWorkspaceNotFoundException());

    expect(
      () => container
          .read(taxonomyViewerProvider(workspaceId: 'wsp_test').future),
      throwsA(isA<TaxonomyWorkspaceNotFoundException>()),
    );
  });
}
