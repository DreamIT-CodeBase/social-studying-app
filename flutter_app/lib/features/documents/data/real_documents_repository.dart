import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart'
    show
        DocumentNotFoundException,
        EmptyUploadException,
        UnsupportedFileTypeException;
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
  RealDocumentsRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

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
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw const EmptyUploadException();
    }
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/documents',
        data: form,
      );
      return Document.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
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

  /// Map Dio errors into typed exceptions the UI layer can branch on.
  Exception _translate(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) return const DocumentNotFoundException();
    if (status == 422) {
      final detail = _detailMessage(e.response?.data);
      if (detail != null && detail.toLowerCase().contains('unsupported')) {
        return UnsupportedFileTypeException(detail);
      }
      if (detail != null && detail.toLowerCase().contains('empty')) {
        return const EmptyUploadException();
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
