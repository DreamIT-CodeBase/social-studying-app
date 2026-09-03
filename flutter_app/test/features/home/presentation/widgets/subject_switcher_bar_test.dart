import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/documents/presentation/documents_notifier.dart';
import 'package:social_study_app/features/home/presentation/widgets/subject_switcher_bar.dart';
import 'package:social_study_app/shared/models/document.dart';

void main() {
  testWidgets('SubjectSwitcherBar renders subject chips and responds to taps',
      (tester) async {
    final docs = [
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
    ];

    var addMaterialClicked = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsListProvider('wsp_self_1').overrideWith(
            () => _FakeDocumentsList(docs),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SubjectSwitcherBar(
              workspaceId: 'wsp_self_1',
              onAddMaterial: () => addMaterialClicked = true,
            ),
          ),
        ),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    // Verify "All Subjects" chip is present
    expect(find.text('All Subjects'), findsOneWidget);

    // Verify "Physics" and "Chemistry" chips are present
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);

    // Verify "+ Add PDF" button is present and clickable
    expect(find.text('+ Add PDF'), findsOneWidget);
    await tester.tap(find.text('+ Add PDF'));
    await tester.pump();
    expect(addMaterialClicked, isTrue);

    // Tap "Physics" chip
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();

    // Verify "Physics Mode" header title appears
    expect(find.text('Physics Mode'), findsOneWidget);
  });

  testWidgets('SubjectSwitcherBar renders detected topics from document topicTags',
      (tester) async {
    const docs = [
      Document(
        id: 'doc_1',
        workspaceId: 'wsp_self_1',
        filename: 'Biology_Cell.pdf',
        docType: DocumentType.pdf,
        status: DocumentStatus.ready,
        createdAt: '2026-05-01T00:00:00Z',
        topicTags: [
          TopicTag(
            name: 'Cell Membrane & Osmosis',
            description: 'Transport across cell membrane',
            complexityLevel: 2,
            pageRefs: [1, 2],
          ),
          TopicTag(
            name: 'Mitochondria ATP',
            description: 'Energy production in cell',
            complexityLevel: 3,
            pageRefs: [3, 4],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsListProvider('wsp_self_1').overrideWith(
            () => _FakeDocumentsList(docs),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SubjectSwitcherBar(
              workspaceId: 'wsp_self_1',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify detected topics header is present
    expect(find.text('Topics from Study Material:'), findsOneWidget);

    // Verify detected topic chips are present
    expect(find.text('Cell Membrane & Osmosis'), findsOneWidget);
    expect(find.text('Mitochondria ATP'), findsOneWidget);
    expect(find.text('All Topics'), findsOneWidget);

    // Tap on a specific topic chip
    await tester.tap(find.text('Cell Membrane & Osmosis'));
    await tester.pumpAndSettle();

    // Clear focus button should appear
    expect(find.text('Clear Focus'), findsOneWidget);
  });
}

class _FakeDocumentsList extends DocumentsList {
  _FakeDocumentsList(this.docs);
  final List<Document> docs;

  @override
  Future<List<Document>> build(String workspaceId) async => docs;
}
