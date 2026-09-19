import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/documents/presentation/documents_notifier.dart';
import 'package:social_study_app/features/home/providers/self_study_subject_providers.dart';
import 'package:social_study_app/shared/models/document.dart';

void main() {
  test('selfStudySubjectCountsProvider counts ready documents per subject',
      () async {
    final container = ProviderContainer(
      overrides: [
        documentsListProvider('wsp_self_1').overrideWith(
          () => _FakeDocumentsList([
            const Document(
              id: 'doc_1',
              workspaceId: 'wsp_self_1',
              filename: 'Physics_Thermodynamics.pdf',
              docType: DocumentType.pdf,
              status: DocumentStatus.ready,
              createdAt: '2026-05-01T00:00:00Z',
            ),
            const Document(
              id: 'doc_2',
              workspaceId: 'wsp_self_1',
              filename: 'Chemistry_Organic.pdf',
              docType: DocumentType.pdf,
              status: DocumentStatus.ready,
              createdAt: '2026-05-01T00:00:00Z',
            ),
            const Document(
              id: 'doc_3',
              workspaceId: 'wsp_self_1',
              filename: 'Physics_Mechanics.pdf',
              docType: DocumentType.pdf,
              status: DocumentStatus.ready,
              createdAt: '2026-05-01T00:00:00Z',
            ),
            const Document(
              id: 'doc_4',
              workspaceId: 'wsp_self_1',
              filename: 'Math_Calculus.pdf',
              docType: DocumentType.pdf,
              status: DocumentStatus.pending, // Not ready yet
              createdAt: '2026-05-01T00:00:00Z',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Wait for the async notifier to resolve
    await container.read(documentsListProvider('wsp_self_1').future);

    final counts = container.read(selfStudySubjectCountsProvider('wsp_self_1'));
    expect(counts['Physics'], 2);
    expect(counts['Chemistry'], 1);
    expect(counts['Mathematics'], isNull); // doc_4 was not ready

    final subjects =
        container.read(selfStudyAvailableSubjectsProvider('wsp_self_1'));
    expect(subjects, ['Chemistry', 'Physics']);
  });

  test('selfStudySubjectProvider defaults to null and can be changed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(selfStudySubjectProvider), isNull);

    container.read(selfStudySubjectProvider.notifier).state = 'Physics';
    expect(container.read(selfStudySubjectProvider), 'Physics');

    container.read(selfStudySubjectProvider.notifier).state = null;
    expect(container.read(selfStudySubjectProvider), isNull);
  });
}

class _FakeDocumentsList extends DocumentsList {
  _FakeDocumentsList(this.docs);
  final List<Document> docs;

  @override
  Future<List<Document>> build(String workspaceId) async => docs;
}
