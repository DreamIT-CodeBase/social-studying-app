import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/documents/presentation/widgets/pipeline_stages.dart';
import 'package:social_study_app/shared/models/document.dart';

Document _doc({
  required DocumentStatus status,
  int chunkCount = 0,
  List<TopicTag> topicTags = const [],
  int? textCharCount,
}) {
  return Document(
    id: 'doc_test',
    workspaceId: 'wsp_test',
    filename: 'study.pdf',
    docType: DocumentType.pdf,
    status: status,
    chunkCount: chunkCount,
    topicTags: topicTags,
    createdAt: '2026-05-15T00:00:00+00:00',
    textCharCount: textCharCount,
  );
}

void main() {
  group('buildStageRows — in flight', () {
    test('pending → uploaded stage active, rest upcoming', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.pending));
      expect(rows[0].state, StageRowState.active);
      expect(rows[0].stage, PipelineStage.uploaded);
      expect(rows.skip(1).every((r) => r.state == StageRowState.upcoming), true);
    });

    test('extracting → uploaded done, extracting active', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.extracting));
      expect(rows[0].state, StageRowState.done);
      expect(rows[1].state, StageRowState.active);
      expect(rows[2].state, StageRowState.upcoming);
    });

    test(
      'text_extracted (handoff state) → topics stage shows as active queued',
      () {
        final rows = buildStageRows(_doc(status: DocumentStatus.textExtracted));
        expect(rows[0].state, StageRowState.done);
        expect(rows[1].state, StageRowState.done);
        expect(rows[2].state, StageRowState.active);
      },
    );

    test('extracting_topics → topics active', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.extractingTopics));
      expect(rows[2].stage, PipelineStage.topics);
      expect(rows[2].state, StageRowState.active);
    });

    test('chunking → chunking active', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.chunking));
      expect(rows[3].stage, PipelineStage.chunking);
      expect(rows[3].state, StageRowState.active);
    });

    test('vectorizing → vectorizing active', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.vectorizing));
      expect(rows[4].stage, PipelineStage.vectorizing);
      expect(rows[4].state, StageRowState.active);
      expect(rows[5].state, StageRowState.upcoming);
    });
  });

  group('buildStageRows — terminal', () {
    test('ready → every stage done', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.ready));
      expect(rows.every((r) => r.state == StageRowState.done), true);
    });

    test('failed with no progress → upload done, extracting errored', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.failed));
      expect(rows[0].state, StageRowState.done);
      expect(rows[1].state, StageRowState.error);
      expect(rows[2].state, StageRowState.upcoming);
    });

    test('failed with text but no topics → text done, topics errored', () {
      final rows = buildStageRows(
        _doc(status: DocumentStatus.failed, textCharCount: 1000),
      );
      expect(rows[1].state, StageRowState.done);
      expect(rows[2].state, StageRowState.error);
    });

    test('failed with topics but no chunks → topics done, chunking errored', () {
      final rows = buildStageRows(_doc(
        status: DocumentStatus.failed,
        textCharCount: 1000,
        topicTags: const [TopicTag(name: 'X')],
      ));
      expect(rows[2].state, StageRowState.done);
      expect(rows[3].state, StageRowState.error);
    });

    test('failed with chunks → chunking done, vectorizing errored', () {
      final rows = buildStageRows(_doc(
        status: DocumentStatus.failed,
        textCharCount: 1000,
        topicTags: const [TopicTag(name: 'X')],
        chunkCount: 5,
      ));
      expect(rows[3].state, StageRowState.done);
      expect(rows[4].state, StageRowState.error);
    });

    test('flagged → upload done, extraction errored, rest upcoming', () {
      final rows = buildStageRows(_doc(status: DocumentStatus.flagged));
      expect(rows[0].state, StageRowState.done);
      expect(rows[1].state, StageRowState.error);
      expect(rows.skip(2).every((r) => r.state == StageRowState.upcoming), true);
    });
  });

  test('PipelineStage values are stable in render order', () {
    expect(PipelineStage.values, [
      PipelineStage.uploaded,
      PipelineStage.extracting,
      PipelineStage.topics,
      PipelineStage.chunking,
      PipelineStage.vectorizing,
      PipelineStage.ready,
    ]);
  });

  test('DocumentStatus.isTerminal matches the terminal trio', () {
    final terminal = DocumentStatus.values.where((s) => s.isTerminal).toSet();
    expect(terminal, {
      DocumentStatus.ready,
      DocumentStatus.failed,
      DocumentStatus.flagged,
    });
  });
}
