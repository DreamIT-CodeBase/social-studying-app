import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/moderation/data/moderation_repository.dart';
import 'package:social_study_app/shared/models/moderation.dart';

part 'moderation_notifier.g.dart';

/// The pending moderation queue for one workspace. Backs the flagged-
/// content list on the moderation dashboard (4.5). Family-keyed by
/// `workspaceId`.
@riverpod
class ModerationQueue extends _$ModerationQueue {
  @override
  Future<List<FlaggedItem>> build(String workspaceId) {
    return ref.read(moderationRepositoryProvider).listFlagged(workspaceId);
  }

  /// Re-fetch the queue. Used by pull-to-refresh.
  void refresh() => ref.invalidateSelf();

  /// Approve or reject a flagged item, then refresh the queue so the
  /// resolved row drops out of the pending list.
  Future<FlaggedItem> resolve({
    required String workspaceId,
    required String itemId,
    required bool approved,
  }) async {
    final resolved = await ref.read(moderationRepositoryProvider).resolve(
          workspaceId: workspaceId,
          itemId: itemId,
          approved: approved,
        );
    refresh();
    return resolved;
  }
}

/// The resolved-items audit log for one workspace — the second tab of
/// the moderation dashboard. Read-only; separate provider so opening
/// the log doesn't disturb the live queue's state.
@riverpod
class ModerationLog extends _$ModerationLog {
  @override
  Future<List<FlaggedItem>> build(String workspaceId) {
    return ref.read(moderationRepositoryProvider).listLog(workspaceId);
  }

  /// Re-fetch the log — invoked after a resolve so the audit trail
  /// reflects the just-resolved item.
  void refresh() => ref.invalidateSelf();
}
