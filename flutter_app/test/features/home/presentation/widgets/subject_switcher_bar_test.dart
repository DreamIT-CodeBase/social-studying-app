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

    // Initial pump and settle
    await tester.pumpAndSettle();

    // Verify "All Subjects" chip is removed
    expect(find.text('All Subjects'), findsNothing);

    // Verify header row is completely removed (no "Subjects", no "Mode", no "+ Add PDF" above chips)
    expect(find.text('Subjects'), findsNothing);
    expect(find.text('Self Study Subjects'), findsNothing);
    expect(find.text('Physics Mode'), findsNothing);
    expect(find.text('+ Add PDF'), findsNothing);

    // Verify "Physics" and "Chemistry" chips are present directly
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);

    // Initially without selecting a subject, topics should NOT appear
    expect(find.text('Topic Focus (Physics):'), findsNothing);

    // Tap "Physics" chip
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();

    // "Physics Mode" text should NOT exist (space reclaimed)
    expect(find.text('Physics Mode'), findsNothing);
  });

  testWidgets(
      'SubjectSwitcherBar dynamically reveals topics only after subject is selected',
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

    // Before tapping Biology, topics must NOT be visible on screen
    expect(find.text('Cell Membrane & Osmosis'), findsNothing);
    expect(find.text('Mitochondria ATP'), findsNothing);
    expect(find.text('All Biology Topics'), findsNothing);

    // Tap "Biology" subject chip
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();

    // Verify topic focus header dynamically appears for Biology
    expect(find.text('Topic Focus (Biology):'), findsOneWidget);

    // Verify detected topic chips are now visible
    expect(find.text('Cell Membrane & Osmosis'), findsOneWidget);
    expect(find.text('Mitochondria ATP'), findsOneWidget);
    expect(find.text('All Biology Topics'), findsOneWidget);

    // Tap on a specific topic chip
    await tester.tap(find.text('Cell Membrane & Osmosis'));
    await tester.pumpAndSettle();

    // Clear focus button should appear
    expect(find.text('Clear Focus'), findsOneWidget);
  });

  testWidgets(
      'SubjectSwitcherBar groups multiple math documents under a single Mathematics chip',
      (tester) async {
    const docs = [
      Document(
        id: 'doc_m1',
        workspaceId: 'wsp_self_1',
        filename: 'math1.pdf',
        docType: DocumentType.pdf,
        status: DocumentStatus.ready,
        createdAt: '2026-05-01T00:00:00Z',
        category: 'Class 11 Maths',
      ),
      Document(
        id: 'doc_m2',
        workspaceId: 'wsp_self_1',
        filename: 'algebra.pdf',
        docType: DocumentType.pdf,
        status: DocumentStatus.ready,
        createdAt: '2026-05-01T00:00:00Z',
        category: 'Algebra 1',
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

    // Only one "Mathematics" chip should exist with count 2
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Class 11 Maths'), findsNothing);
    expect(find.text('Algebra 1'), findsNothing);
  });
}

class _FakeDocumentsList extends DocumentsList {
  _FakeDocumentsList(this.docs);
  final List<Document> docs;

  @override
  Future<List<Document>> build(String workspaceId) async => docs;
}
