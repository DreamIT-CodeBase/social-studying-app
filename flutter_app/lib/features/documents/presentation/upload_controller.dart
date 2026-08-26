import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

part 'upload_controller.g.dart';

/// Encapsulates the "pick a file → POST it → return the new doc" flow.
///
/// Why a controller instead of doing this inline in the screen
/// ------------------------------------------------------------
/// - The flow has three steps (pick, upload, navigate-or-error).
/// - Each step has its own failure mode the UI needs to react to
///   (cancelled picker, empty file, unsupported type, transport error).
/// - Tests can drive `pickAndUpload` with an injected file picker,
///   skipping the platform plugin entirely.
@riverpod
class UploadController extends _$UploadController {
  @override
  AsyncValue<Document?> build() => const AsyncData<Document?>(null);

  /// Open the system file picker, then upload the selection. Returns
  /// the newly-created `Document` (also surfaced via `state`) so the
  /// caller can navigate to the polling screen with the id.
  ///
  /// Returns `null` when the user cancels the picker.
  Future<Document?> pickAndUpload({required String workspaceId}) async {
    state = const AsyncLoading();
    try {
      final selection = await _pickFile();
      if (selection == null) {
        state = const AsyncData<Document?>(null);
        return null;
      }
      final doc = await ref.read(documentsRepositoryProvider).upload(
            workspaceId: workspaceId,
            filename: selection.filename,
            contentType: selection.contentType,
            upload: selection.upload,
          );
      ref.read(workspacesListProvider.notifier).refresh();
      state = AsyncData<Document?>(doc);
      return doc;
    } catch (e, st) {
      state = AsyncError<Document?>(e, st);
      return null;
    }
  }

  /// Capture a photo from the device camera, then upload it.
  ///
  /// Returns `null` when the user cancels the camera.
  Future<Document?> pickFromCamera({required String workspaceId}) async {
    state = const AsyncLoading();
    try {
      final selection = await _pickImageFromSource(ImageSource.camera);
      if (selection == null) {
        state = const AsyncData<Document?>(null);
        return null;
      }
      final doc = await ref.read(documentsRepositoryProvider).upload(
            workspaceId: workspaceId,
            filename: selection.filename,
            contentType: selection.contentType,
            upload: selection.upload,
          );
      ref.read(workspacesListProvider.notifier).refresh();
      state = AsyncData<Document?>(doc);
      return doc;
    } catch (e, st) {
      state = AsyncError<Document?>(e, st);
      return null;
    }
  }

  /// Select an image from the device gallery, then upload it.
  ///
  /// Returns `null` when the user cancels the gallery.
  Future<Document?> pickImageFromGallery({required String workspaceId}) async {
    state = const AsyncLoading();
    try {
      final selection = await _pickImageFromSource(ImageSource.gallery);
      if (selection == null) {
        state = const AsyncData<Document?>(null);
        return null;
      }
      final doc = await ref.read(documentsRepositoryProvider).upload(
            workspaceId: workspaceId,
            filename: selection.filename,
            contentType: selection.contentType,
            upload: selection.upload,
          );
      ref.read(workspacesListProvider.notifier).refresh();
      state = AsyncData<Document?>(doc);
      return doc;
    } catch (e, st) {
      state = AsyncError<Document?>(e, st);
      return null;
    }
  }

  /// Initiates website URL scraping and registers it as a document.
  Future<Document?> scrapeAndUpload({
    required String workspaceId,
    required String url,
  }) async {
    state = const AsyncLoading();
    try {
      final doc = await ref.read(documentsRepositoryProvider).scrape(
            workspaceId: workspaceId,
            url: url,
          );
      ref.read(workspacesListProvider.notifier).refresh();
      state = AsyncData<Document?>(doc);
      return doc;
    } catch (e, st) {
      state = AsyncError<Document?>(e, st);
      return null;
    }
  }

  /// Hook for tests: replace the file_picker call with a synthetic
  /// selection. Production path goes through `_filePickerAdapter`.
  @visibleForTesting
  static FilePickerAdapter pickerOverride = _filePickerAdapter;

  Future<FileSelection?> _pickFile() async {
    final result = await pickerOverride();
    return result;
  }

  /// Use image_picker for camera/gallery sources.
  Future<FileSelection?> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null) return null;
    final extension = image.name.split('.').last.toLowerCase();
    return FileSelection.fromXFile(
      filename: image.name,
      contentType: _contentTypeFor(extension),
      file: image,
      sizeBytes: await image.length(),
    );
  }
}

/// What the picker returns, normalised across platforms (mobile/web/desktop).
/// Public so test adapters can construct synthetic selections without
/// going through the file_picker plugin.
class FileSelection {
  FileSelection({
    required this.filename,
    required this.contentType,
    required Uint8List bytes,
  }) : upload = DocumentUpload.fromBytes(bytes);

  FileSelection.fromXFile({
    required this.filename,
    required this.contentType,
    required XFile file,
    required int sizeBytes,
  }) : upload = DocumentUpload(
          sizeBytes: sizeBytes,
          readRange: (start, end) async {
            final builder = BytesBuilder(copy: false);
            await for (final part in file.openRead(start, end)) {
              builder.add(part);
            }
            return builder.takeBytes();
          },
        );

  final String filename;
  final String contentType;
  final DocumentUpload upload;
}

typedef FilePickerAdapter = Future<FileSelection?> Function();

/// Production adapter that drives the `file_picker` plugin. Returns
/// null when the user cancels. Sets a sensible content_type fallback
/// for platforms that don't expose MIME info.
Future<FileSelection?> _filePickerAdapter() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'docx', 'jpg', 'jpeg', 'png', 'webp', 'txt'],
    // Native paths let us read one upload block at a time. Flutter Web does
    // not expose a local path, so it retains the current in-memory fallback
    // while still sending blocks directly to Blob Storage.
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.single;
  final contentType = _contentTypeFor(picked.extension ?? '');
  if (kIsWeb) {
    final bytes = picked.bytes;
    if (bytes == null) return null;
    return FileSelection(
      filename: picked.name,
      bytes: bytes,
      contentType: contentType,
    );
  }
  final path = picked.path;
  if (path == null) return null;
  return FileSelection.fromXFile(
    filename: picked.name,
    contentType: contentType,
    file: XFile(path),
    sizeBytes: picked.size,
  );
}

String _contentTypeFor(String extension) => switch (extension.toLowerCase()) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
