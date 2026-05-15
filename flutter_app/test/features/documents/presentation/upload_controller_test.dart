import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart';
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/features/documents/presentation/upload_controller.dart';
import 'package:social_study_app/shared/models/document.dart';

class _MockRepo extends Mock implements DocumentsRepository {}

Document _doc({String id = 'doc_uploaded'}) => Document(
      id: id,
      workspaceId: 'wsp_test',
      filename: 'study.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.pending,
      createdAt: '2026-05-15T00:00:00+00:00',
    );

FileSelection _selection({
  String filename = 'study.pdf',
  String contentType = 'application/pdf',
  Uint8List? bytes,
}) =>
    FileSelection(
      filename: filename,
      bytes: bytes ?? Uint8List.fromList([1, 2, 3, 4]),
      contentType: contentType,
    );

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWith((_) => repo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    // Reset the test-time picker override so one test's failure mode
    // doesn't bleed into the next test's setUp.
    UploadController.pickerOverride = _failIfReached;
  });

  test('initial state is AsyncData(null)', () {
    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncData<Document?>>());
    expect(state.valueOrNull, isNull);
  });

  test('pickAndUpload happy path returns doc and emits AsyncData', () async {
    UploadController.pickerOverride = () async => _selection();
    when(() => repo.upload(
          workspaceId: any(named: 'workspaceId'),
          filename: any(named: 'filename'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        )).thenAnswer((_) async => _doc());

    final result = await container
        .read(uploadControllerProvider.notifier)
        .pickAndUpload(workspaceId: 'wsp_test');

    expect(result, isNotNull);
    expect(result!.id, 'doc_uploaded');

    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncData<Document?>>());
    expect(state.valueOrNull?.id, 'doc_uploaded');

    // Repository called with the file_picker selection unchanged.
    verify(() => repo.upload(
          workspaceId: 'wsp_test',
          filename: 'study.pdf',
          bytes: any(named: 'bytes'),
          contentType: 'application/pdf',
        )).called(1);
  });

  test('user cancels picker → null result, state back to AsyncData(null), no upload',
      () async {
    UploadController.pickerOverride = () async => null;

    final result = await container
        .read(uploadControllerProvider.notifier)
        .pickAndUpload(workspaceId: 'wsp_test');

    expect(result, isNull);
    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncData<Document?>>());
    expect(state.valueOrNull, isNull);

    verifyNever(() => repo.upload(
          workspaceId: any(named: 'workspaceId'),
          filename: any(named: 'filename'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        ));
  });

  test('EmptyUploadException from repo surfaces as AsyncError', () async {
    UploadController.pickerOverride = () async => _selection();
    when(() => repo.upload(
          workspaceId: any(named: 'workspaceId'),
          filename: any(named: 'filename'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        )).thenThrow(const EmptyUploadException());

    final result = await container
        .read(uploadControllerProvider.notifier)
        .pickAndUpload(workspaceId: 'wsp_test');

    expect(result, isNull);
    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncError<Document?>>());
    expect((state as AsyncError).error, isA<EmptyUploadException>());
  });

  test('UnsupportedFileTypeException from repo surfaces as AsyncError', () async {
    UploadController.pickerOverride = () async => _selection();
    when(() => repo.upload(
          workspaceId: any(named: 'workspaceId'),
          filename: any(named: 'filename'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        )).thenThrow(const UnsupportedFileTypeException('xls is not supported'));

    await container
        .read(uploadControllerProvider.notifier)
        .pickAndUpload(workspaceId: 'wsp_test');

    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncError<Document?>>());
    expect(
      (state as AsyncError).error,
      isA<UnsupportedFileTypeException>(),
    );
  });

  test('generic Exception from repo surfaces as AsyncError', () async {
    UploadController.pickerOverride = () async => _selection();
    when(() => repo.upload(
          workspaceId: any(named: 'workspaceId'),
          filename: any(named: 'filename'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        )).thenThrow(Exception('network is down'));

    await container
        .read(uploadControllerProvider.notifier)
        .pickAndUpload(workspaceId: 'wsp_test');

    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncError<Document?>>());
    expect((state as AsyncError).error.toString(), contains('network is down'));
  });

  test('picker error is caught (does not crash the controller)', () async {
    // A platform-channel failure in file_picker should surface as
    // AsyncError, not as an unhandled exception — the screen listens for
    // AsyncError and shows a SnackBar.
    UploadController.pickerOverride = () async {
      throw StateError('picker plugin missing');
    };

    final result = await container
        .read(uploadControllerProvider.notifier)
        .pickAndUpload(workspaceId: 'wsp_test');

    expect(result, isNull);
    final state = container.read(uploadControllerProvider);
    expect(state, isA<AsyncError<Document?>>());
  });
}

/// Default picker override during tearDown — fails loudly if a test
/// forgets to set its own override.
Future<FileSelection?> _failIfReached() {
  throw StateError(
    'pickerOverride was not set for this test. Set '
    'UploadController.pickerOverride before reading the controller.',
  );
}
