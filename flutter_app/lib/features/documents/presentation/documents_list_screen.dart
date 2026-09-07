import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart';
import 'package:social_study_app/features/documents/presentation/documents_notifier.dart';
import 'package:social_study_app/features/documents/presentation/upload_controller.dart';
import 'package:social_study_app/features/documents/presentation/widgets/status_chip.dart';
import 'package:social_study_app/shared/models/document.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Workspace documents list. Shows every doc with its current status
/// chip; tapping a row pushes the polling/details screen.
///
/// Renders inside the Documents tab of the admin home Scaffold, so it
/// has no AppBar of its own. The parent Scaffold already provides one
/// titled "Documents".
class DocumentsListScreen extends ConsumerWidget {
  const DocumentsListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsListProvider(workspaceId));
    final uploadState = ref.watch(uploadControllerProvider);
    final isUploading = uploadState.isLoading;

    // Surface upload errors via SnackBar so the list view stays put.
    ref.listen<AsyncValue<Document?>>(uploadControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (error, _) => _showUploadError(context, error),
      );
    });

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.read(documentsListProvider(workspaceId).notifier).refresh();
            await ref.read(documentsListProvider(workspaceId).future);
          },
          child: docsAsync.when(
            data: (docs) => docs.isEmpty
                ? _EmptyState(
                    onUpload:
                        isUploading ? null : () => _handleUpload(context, ref),
                  )
                : _DocsList(
                    docs: docs,
                    workspaceId: workspaceId,
                    canDelete: currentFlavor == AppFlavor.admin ||
                        workspaceId.startsWith('wsp_self_'),
                  ),
            loading: () => const LoadingIndicator(),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref
                  .read(documentsListProvider(workspaceId).notifier)
                  .refresh(),
            ),
          ),
        ),
        // FAB only shows once we've rendered a list (so it doesn't
        // overlap the empty-state CTA).
        if (docsAsync.valueOrNull?.isNotEmpty ?? false)
          Positioned(
            bottom: Spacing.lg,
            right: Spacing.lg,
            child: FloatingActionButton.extended(
              onPressed: isUploading ? null : () => _handleUpload(context, ref),
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isUploading ? 'Uploading…' : 'Upload'),
            ),
          ),
      ],
    );

    if (currentFlavor == AppFlavor.student) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Study Materials',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: content,
      );
    }

    return content;
  }

  Future<void> _handleUpload(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<_UploadSource>(
      context: context,
      builder: (_) => const _UploadSourceSheet(),
    );
    if (source == null) return;

    final Document? doc;
    if (source == _UploadSource.website) {
      if (!context.mounted) return;
      final url = await _showUrlInputDialog(context);
      if (url == null || url.isEmpty) return;
      doc = await ref
          .read(uploadControllerProvider.notifier)
          .scrapeAndUpload(workspaceId: workspaceId, url: url);
    } else {
      doc = await switch (source) {
        _UploadSource.camera => ref
            .read(uploadControllerProvider.notifier)
            .pickFromCamera(workspaceId: workspaceId),
        _UploadSource.gallery => ref
            .read(uploadControllerProvider.notifier)
            .pickImageFromGallery(workspaceId: workspaceId),
        _UploadSource.file => ref
            .read(uploadControllerProvider.notifier)
            .pickAndUpload(workspaceId: workspaceId),
        _UploadSource.website => throw StateError('Unreachable'),
      };
    }

    if (doc != null) {
      // List view should reflect the new doc; provider invalidate
      // re-runs the list fetch.
      ref.read(documentsListProvider(workspaceId).notifier).refresh();
      if (context.mounted) {
        context.push(_pollingRouteFor(workspaceId, doc.id));
      }
    }
  }

  Future<String?> _showUrlInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Website Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/article',
            labelText: 'Website URL',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(context).pop(val);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showUploadError(BuildContext context, Object error) {
    final message = switch (error) {
      EmptyUploadException() => 'That file is empty.',
      UploadTooLargeException() => error.message,
      UnsupportedFileTypeException() => 'That file type isn\'t supported. '
          'Try a PDF, DOCX, image, or plain text file.',
      _ => 'Upload failed: $error',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _pollingRouteFor(String workspaceId, String documentId) {
  if (currentFlavor == AppFlavor.student) {
    return '/student/documents/$workspaceId/$documentId';
  }
  return '${AppRoutes.adminDocuments}/$workspaceId/$documentId';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});

  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView so RefreshIndicator can pull-to-refresh on the empty state.
      children: [
        SizedBox(
          height: context.screenHeight * 0.7,
          child: EmptyStateView(
            icon: Icons.description_rounded,
            title: 'No documents yet',
            subtitle: 'Upload PDFs, Word documents, or images to generate '
                'AI-powered study questions.',
            action: FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload Document'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocsList extends StatelessWidget {
  const _DocsList({
    required this.docs,
    required this.workspaceId,
    required this.canDelete,
  });

  final List<Document> docs;
  final String workspaceId;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        // Bottom padding leaves room for the floating Upload button so
        // the last row isn't covered.
        96,
      ),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _DocRow(
        doc: docs[i],
        workspaceId: workspaceId,
        canDelete: canDelete,
      ),
    );
  }
}

class _DocRow extends ConsumerStatefulWidget {
  const _DocRow({
    required this.doc,
    required this.workspaceId,
    required this.canDelete,
  });

  final Document doc;
  final String workspaceId;
  final bool canDelete;

  @override
  ConsumerState<_DocRow> createState() => _DocRowState();
}

class _DocRowState extends ConsumerState<_DocRow> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isDeleting
            ? null
            : () => context.push(
                  _pollingRouteFor(widget.workspaceId, doc.id),
                ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocTypeIcon(type: doc.docType),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.filename,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      _detailLine(doc),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    StatusChip(status: doc.status),
                  ],
                ),
              ),
              if (widget.canDelete)
                IconButton(
                  key: ValueKey('delete-document-${doc.id}'),
                  tooltip: 'Delete study material',
                  onPressed: _isDeleting ? null : _confirmAndDelete,
                  color: context.colorScheme.error,
                  icon: _isDeleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Permanently delete material?'),
            content: Text(
              '"${widget.doc.filename}" and all of its processed study '
              'content will be completely erased. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Delete permanently'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(documentsListProvider(widget.workspaceId).notifier)
          .deleteDocument(widget.doc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${widget.doc.filename} was permanently deleted.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not delete study material: $error'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String _detailLine(Document doc) {
    final parts = <String>[];
    if (doc.pageCount != null) parts.add('${doc.pageCount} pages');
    if (doc.chunkCount > 0) parts.add('${doc.chunkCount} chunks');
    if (doc.topicTags.isNotEmpty) parts.add('${doc.topicTags.length} topics');
    if (parts.isEmpty) return doc.docType.name.toUpperCase();
    return parts.join(' • ');
  }
}

class _DocTypeIcon extends StatelessWidget {
  const _DocTypeIcon({required this.type});

  final DocumentType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      DocumentType.pdf => Icons.picture_as_pdf_rounded,
      DocumentType.docx => Icons.description_rounded,
      DocumentType.image => Icons.image_rounded,
      DocumentType.text => Icons.notes_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: context.colorScheme.onPrimaryContainer),
    );
  }
}

enum _UploadSource { camera, gallery, file, website }

class _UploadSourceSheet extends StatelessWidget {
  const _UploadSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Text(
              'Upload Document',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Take Photo'),
            onTap: () => Navigator.of(context).pop(_UploadSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(context).pop(_UploadSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.folder_rounded),
            title: const Text('Choose File'),
            onTap: () => Navigator.of(context).pop(_UploadSource.file),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Add Website Link'),
            onTap: () => Navigator.of(context).pop(_UploadSource.website),
          ),
        ],
      ),
    );
  }
}
