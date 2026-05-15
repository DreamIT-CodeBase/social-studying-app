import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

part 'documents_notifier.g.dart';

/// List of documents in a workspace. Refreshable on pull-to-refresh and
/// after upload completes — the list is invalidated to pick up the new
/// row.
@riverpod
class DocumentsList extends _$DocumentsList {
  @override
  Future<List<Document>> build(String workspaceId) async {
    return ref
        .read(documentsRepositoryProvider)
        .list(workspaceId: workspaceId);
  }

  /// Re-fetch the list. Used by pull-to-refresh and after upload success.
  /// `invalidateSelf` re-runs `build` with the same arguments — cheaper
  /// than dropping into AsyncLoading + manual refetch.
  void refresh() => ref.invalidateSelf();
}
