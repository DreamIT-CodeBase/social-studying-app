import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart'
    show DocumentNotFoundException;
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

part 'document_polling_notifier.g.dart';

/// Default cadence between status polls. Two seconds is responsive
/// enough that the demo's per-stage transitions feel live without
/// hammering the backend on a real run.
const Duration kDocumentPollInterval = Duration(seconds: 2);

/// Polls a single document's state until it reaches a terminal status.
///
/// Lifecycle
/// ---------
/// 1. `build` does the first fetch and schedules a Timer.
/// 2. The Timer fires `_poll`, which fetches and reschedules — or
///    stops if the new status is terminal.
/// 3. Provider auto-disposes when the screen leaves; `ref.onDispose`
///    cancels the Timer to avoid a leak.
///
/// Why a Timer rather than a Stream/StreamProvider
/// -----------------------------------------------
/// We need the latest snapshot wrapped in `AsyncValue` (loading on
/// first fetch, error on transient failures, data otherwise) and we
/// need the ability to stop polling cleanly when status terminates.
/// `AsyncNotifier` + Timer covers both with simpler code than
/// `Stream.periodic` + a manual `StreamSubscription` would.
@riverpod
class DocumentPolling extends _$DocumentPolling {
  Timer? _timer;
  late String _workspaceId;
  late String _documentId;

  /// Hook for tests to override the cadence without sleeping for
  /// real seconds in unit tests.
  @visibleForTesting
  static Duration debugInterval = kDocumentPollInterval;

  @override
  Future<Document> build({
    required String workspaceId,
    required String documentId,
  }) async {
    _workspaceId = workspaceId;
    _documentId = documentId;
    ref.onDispose(_cancelTimer);
    final doc = await _fetch();
    _scheduleNext(doc);
    return doc;
  }

  /// Trigger an out-of-band refresh (e.g. user taps "check now").
  /// Does NOT change cadence — the regular timer keeps running.
  Future<void> pollNow() async {
    _cancelTimer();
    state = await AsyncValue.guard(() async {
      final doc = await _fetch();
      _scheduleNext(doc);
      return doc;
    });
  }

  void _scheduleNext(Document doc) {
    _cancelTimer();
    if (doc.status.isTerminal) return;
    _timer = Timer(debugInterval, _poll);
  }

  Future<void> _poll() async {
    state = await AsyncValue.guard(() async {
      try {
        final doc = await _fetch();
        _scheduleNext(doc);
        return doc;
      } on DocumentNotFoundException {
        // The doc was deleted between polls. Stop polling — the screen
        // will surface the AsyncError and offer a back button.
        _cancelTimer();
        rethrow;
      }
    });
  }

  Future<Document> _fetch() {
    return ref.read(documentsRepositoryProvider).get(
          workspaceId: _workspaceId,
          documentId: _documentId,
        );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
