import 'dart:async';

import 'package:social_study_app/features/admin/moderation/data/moderation_repository.dart';
import 'package:social_study_app/shared/models/moderation.dart';

/// 404 — the flagged item was already resolved or never existed.
class FlaggedItemNotFoundException implements Exception {
  const FlaggedItemNotFoundException([
    this.message = 'Flagged item not found',
  ]);
  final String message;
  @override
  String toString() => 'FlaggedItemNotFoundException: $message';
}

/// Offline, in-process implementation of the moderation queue.
///
/// Backs the demo user so an offline dev can exercise the full
/// review / approve / reject flow without a live backend (the
/// moderation endpoints don't exist yet — Sprint 6).
///
/// Seeded with two pending items and one already-resolved item, so the
/// queue, the approve/reject action, and the audit log all have content
/// on first open. State is in-process; restarting resets to the seed.
class DemoModerationRepository implements ModerationRepository {
  DemoModerationRepository();

  final List<FlaggedItem> _items = [
    const FlaggedItem(
      id: 'mod_demo_001',
      contentKind: FlaggedContentKind.question,
      topic: 'Cellular Respiration',
      excerpt: 'Which process violently destroys the cell to release energy?',
      reason: 'Violence',
      severity: 2,
      flaggedAt: '2026-05-22T08:30:00Z',
    ),
    const FlaggedItem(
      id: 'mod_demo_002',
      contentKind: FlaggedContentKind.flashcard,
      topic: 'Genetics',
      excerpt: 'Front: Define a dominant allele. Back: …',
      reason: 'Self-harm',
      severity: 1,
      flaggedAt: '2026-05-21T16:05:00Z',
    ),
    const FlaggedItem(
      id: 'mod_demo_003',
      contentKind: FlaggedContentKind.document,
      topic: 'Photosynthesis',
      excerpt: 'Chapter 4 — Light-dependent reactions (page 2 excerpt)',
      reason: 'Hate',
      severity: 3,
      flaggedAt: '2026-05-20T11:20:00Z',
      verdict: ModerationVerdict.approved,
    ),
  ];

  @override
  Future<List<FlaggedItem>> listFlagged(String workspaceId) async {
    await _latency();
    return List.unmodifiable(_items.where((i) => i.isPending));
  }

  @override
  Future<FlaggedItem> resolve({
    required String workspaceId,
    required String itemId,
    required bool approved,
  }) async {
    await _latency();
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) throw const FlaggedItemNotFoundException();
    final resolved = _items[index].copyWith(
      verdict:
          approved ? ModerationVerdict.approved : ModerationVerdict.rejected,
    );
    _items[index] = resolved;
    return resolved;
  }

  @override
  Future<List<FlaggedItem>> listLog(String workspaceId) async {
    await _latency();
    // The audit log is everything that has been resolved either way.
    return List.unmodifiable(_items.where((i) => !i.isPending));
  }

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 200));
}
