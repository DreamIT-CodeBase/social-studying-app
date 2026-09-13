import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart'
    show
        DocumentNotFoundException,
        EmptyUploadException,
        UnsupportedFileTypeException,
        UploadTooLargeException;
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

/// Backend-backed implementation. Hits the `/api/v1/workspaces/...`
/// routes defined in `backend/app/api/documents.py`.
///
/// Error mapping
/// -------------
/// The Dio error interceptor (see [DioClient]) already rewrites HTTP
/// errors with friendly messages. We layer typed exceptions on top so
/// the polling notifier can stop polling on 404 (the doc was deleted
/// between polls — UI should not retry forever).
class RealDocumentsRepository implements DocumentsRepository {
  RealDocumentsRepository({required this.dio, Dio? blobDio})
      : _blobDio = blobDio ?? _buildBlobDio();

  final Dio dio;
  final Dio _blobDio;

  static const _apiPrefix = '/api/v1';
  static const _storageApiVersion = '2023-11-03';
  // Upload 8 blocks in parallel for maximum throughput.
  static const _parallelBlockUploads = 8;
  // Override the server-sent block size with 4 MB for better parallelism.
  // A 5 MB PDF becomes 2 blocks (instead of 1 with 8 MB), allowing two
  // concurrent PUT calls. Larger files benefit even more.
  static const _clientBlockSizeBytes = 4 * 1024 * 1024; // 4 MB

  /// Blob Dio instance with explicit timeouts so a stalled Azure Blob PUT
  /// fails fast instead of hanging the upload indefinitely.
  static Dio _buildBlobDio() {
    return Dio(
      BaseOptions(
        // 60 seconds to connect to Azure Blob Storage.
        connectTimeout: const Duration(seconds: 60),
        // 60 seconds per block send — enough for a 4 MB block on a ~500 kB/s
        // connection, but fast enough to fail hard if the connection stalls.
        sendTimeout: const Duration(seconds: 60),
        // 60 seconds to receive the PUT 201 response.
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  @override
  Future<List<Document>> list({required String workspaceId}) async {
    try {
      final response = await dio.get<List<dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/documents',
      );
      final raw = response.data ?? const <dynamic>[];
      return raw
          .map((d) => Document.fromJson(d as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<Document> get({
    required String workspaceId,
    required String documentId,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/documents/$documentId',
      );
      return Document.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<Document> upload({
    required String workspaceId,
    required String filename,
    required String contentType,
    DocumentUpload? upload,
    Uint8List? bytes,
  }) async {
    final file = resolveDocumentUpload(upload: upload, bytes: bytes);
    if (file.sizeBytes == 0) {
      throw const EmptyUploadException();
    }
    try {
      final authorization = await _createDirectUpload(
        workspaceId: workspaceId,
        filename: filename,
        contentType: contentType,
        fileSizeBytes: file.sizeBytes,
      );
      await _stageAndCommitBlocks(
        authorization: authorization,
        file: file,
        contentType: contentType,
      );
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/documents/uploads/'
        '${authorization.documentId}/complete',
        data: {'upload_token': authorization.uploadToken},
      );
      return Document.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Future<_DirectUploadAuthorization> _createDirectUpload({
    required String workspaceId,
    required String filename,
    required String contentType,
    required int fileSizeBytes,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/documents/uploads',
      data: {
        'filename': filename,
        'content_type': contentType,
        'file_size_bytes': fileSizeBytes,
      },
    );
    return _DirectUploadAuthorization.fromJson(response.data!);
  }

  Future<void> _stageAndCommitBlocks({
    required _DirectUploadAuthorization authorization,
    required DocumentUpload file,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    // Use the client-side 4 MB block size rather than the server-sent value.
    // This gives more blocks to upload in parallel and keeps individual block
    // PUT timeouts well within the 60-second window even on slow connections.
    const blockSize = _clientBlockSizeBytes;
    final blockCount = (file.sizeBytes + blockSize - 1) ~/ blockSize;
    int bytesStaged = 0;
    final blockIds = List<String>.generate(
      blockCount,
      (index) => base64Encode(
        utf8.encode('social-study-${index.toString().padLeft(8, '0')}'),
      ),
      growable: false,
    );

    for (var batchStart = 0;
        batchStart < blockCount;
        batchStart += _parallelBlockUploads) {
      final batchEnd = batchStart + _parallelBlockUploads < blockCount
          ? batchStart + _parallelBlockUploads
          : blockCount;
      await Future.wait([
        for (var index = batchStart; index < batchEnd; index++)
          _stageFileBlock(
            uploadUrl: authorization.uploadUrl,
            blockId: blockIds[index],
            file: file,
            start: index * blockSize,
            end: (index + 1) * blockSize < file.sizeBytes
                ? (index + 1) * blockSize
                : file.sizeBytes,
          ).then((_) {
            // Report cumulative progress after each block completes.
            final blockEnd =
                (blockIds.indexOf(blockIds[index]) + 1) * blockSize;
            bytesStaged = blockEnd < file.sizeBytes ? blockEnd : file.sizeBytes;
            onProgress?.call(bytesStaged, file.sizeBytes);
          }),
      ]);
    }

    final blockList = StringBuffer('<BlockList>');
    for (final blockId in blockIds) {
      // A base64 block ID contains no XML-reserved characters.
      blockList.write('<Latest>$blockId</Latest>');
    }
    blockList.write('</BlockList>');
    await _retryStorageRequest(() {
      return _blobDio.putUri<void>(
        _storageUri(authorization.uploadUrl, {'comp': 'blocklist'}),
        data: blockList.toString(),
        options: Options(
          headers: {
            'x-ms-version': _storageApiVersion,
            'x-ms-blob-content-type': contentType,
            'Content-Type': 'application/xml',
          },
        ),
      );
    });
  }

  Future<void> _stageBlock({
    required String uploadUrl,
    required String blockId,
    required Uint8List content,
  }) =>
      _retryStorageRequest(() {
        return _blobDio.putUri<void>(
          _storageUri(uploadUrl, {'comp': 'block', 'blockid': blockId}),
          data: content,
          options: Options(
            headers: {
              'x-ms-version': _storageApiVersion,
              'Content-Type': 'application/octet-stream',
            },
          ),
        );
      });

  Future<void> _stageFileBlock({
    required String uploadUrl,
    required String blockId,
    required DocumentUpload file,
    required int start,
    required int end,
  }) async {
    final content = await file.readRange(start, end);
    await _stageBlock(uploadUrl: uploadUrl, blockId: blockId, content: content);
  }

  Uri _storageUri(String uploadUrl, Map<String, String> additions) {
    final uri = Uri.parse(uploadUrl);
    return uri.replace(queryParameters: {...uri.queryParameters, ...additions});
  }

  Future<void> _retryStorageRequest(
      Future<Response<void>> Function() operation) async {
    const retryableStatuses = {408, 429, 500, 502, 503, 504};
    for (var attempt = 0;; attempt++) {
      try {
        await operation();
        return;
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        final isRetryable =
            status == null || retryableStatuses.contains(status);
        if (!isRetryable || attempt == 3) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 300 * (1 << attempt)),
        );
      }
    }
  }

  @override
  Future<Document> scrape({
    required String workspaceId,
    required String url,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/documents/scrape',
        data: {'url': url},
      );
      return Document.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> delete({
    required String workspaceId,
    required String documentId,
  }) async {
    try {
      await dio.delete<void>(
        '$_apiPrefix/workspaces/$workspaceId/documents/$documentId',
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<Document> approve({
    required String workspaceId,
    required String documentId,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/documents/$documentId/approve',
      );
      return Document.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Map Dio errors into typed exceptions the UI layer can branch on.
  Exception _translate(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) return const DocumentNotFoundException();
    if (status == 413) return const UploadTooLargeException();
    if (status == 422) {
      final detail = _detailMessage(e.response?.data);
      if (detail != null && detail.toLowerCase().contains('unsupported')) {
        return UnsupportedFileTypeException(detail);
      }
      if (detail != null && detail.toLowerCase().contains('empty')) {
        return const EmptyUploadException();
      }
      if (detail != null && detail.toLowerCase().contains('exceeds')) {
        return UploadTooLargeException(detail);
      }
    }
    // Fall through — caller surfaces e.message via the Dio error
    // interceptor's friendly text.
    return e;
  }

  String? _detailMessage(Object? body) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is String) return detail;
    }
    return null;
  }
}

class _DirectUploadAuthorization {
  const _DirectUploadAuthorization({
    required this.documentId,
    required this.uploadUrl,
    required this.uploadToken,
    required this.blockSizeBytes,
  });

  factory _DirectUploadAuthorization.fromJson(Map<String, dynamic> json) =>
      _DirectUploadAuthorization(
        documentId: json['document_id'] as String,
        uploadUrl: json['upload_url'] as String,
        uploadToken: json['upload_token'] as String,
        blockSizeBytes: json['block_size_bytes'] as int,
      );

  final String documentId;
  final String uploadUrl;
  final String uploadToken;
  final int blockSizeBytes;
}
