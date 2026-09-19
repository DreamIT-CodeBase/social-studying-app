import 'package:social_study_app/shared/models/document.dart';

/// User-visible stages of the ingestion pipeline.
///
/// The backend has nine non-terminal statuses. Showing all nine to admins
/// is noise — half of them are "waiting for the next worker to pick up"
/// transitions that resolve in milliseconds. We collapse them into five
/// meaningful stages, plus a final "Ready" terminal stage.
enum PipelineStage {
  uploaded(label: 'Uploaded', detail: 'File saved to storage'),
  extracting(label: 'Reading text', detail: 'Pulling text from your file'),
  topics(
      label: 'Identifying topics', detail: 'Spotting concepts in the content'),
  chunking(
      label: 'Splitting content',
      detail: 'Breaking text into searchable pieces'),
  vectorizing(
      label: 'Building search index', detail: 'Embedding chunks for retrieval'),
  ready(label: 'Ready', detail: 'Questions can now be generated');

  const PipelineStage({required this.label, required this.detail});

  final String label;
  final String detail;
}

/// State of a single stage row in the stepper.
enum StageRowState { done, active, upcoming, error }

/// One row in the stepper's render list.
class StageRow {
  const StageRow({required this.stage, required this.state});
  final PipelineStage stage;
  final StageRowState state;
}

/// Compute the stage-by-stage progress to render given the current
/// document status. Pure function — no Riverpod, no widgets — so it's
/// trivial to unit test.
///
/// Mapping rules
/// -------------
/// Each non-terminal `DocumentStatus` maps to (a) the index of the
/// latest **completed** stage and (b) the stage currently **active**.
/// Intermediate "queued for next worker" statuses (`text_extracted`,
/// `topics_extracted`, `chunked`) read as "the stage that just
/// finished is done; the next stage is queued (active with a small
/// spinner)" — that visual matches reality, since the next worker will
/// usually pick up within a few seconds.
///
/// On terminal `ready`: every stage is done.
///
/// On terminal `failed`: rows up to the last stage we have evidence
/// for (via side-effect fields like `textCharCount` / `topicTags` /
/// `chunkCount`) render as done; the next stage renders with the
/// `error` state; further stages render as `upcoming`.
///
/// On terminal `flagged`: same idea but the failure reason is
/// content-safety, so the error always lands on stage `extracting`
/// (the only stage that runs content safety).
List<StageRow> buildStageRows(Document doc) {
  switch (doc.status) {
    case DocumentStatus.ready:
      return PipelineStage.values
          .map((s) => StageRow(stage: s, state: StageRowState.done))
          .toList();
    case DocumentStatus.failed:
      return _failedRows(doc);
    case DocumentStatus.flagged:
      return _flaggedRows();
    case DocumentStatus.pending ||
          DocumentStatus.extracting ||
          DocumentStatus.textExtracted ||
          DocumentStatus.extractingTopics ||
          DocumentStatus.topicsExtracted ||
          DocumentStatus.chunking ||
          DocumentStatus.chunked ||
          DocumentStatus.vectorizing:
      return _inFlightRows(doc.status);
  }
}

List<StageRow> _inFlightRows(DocumentStatus status) {
  final activeIndex = _activeStageIndex(status);
  return [
    for (int i = 0; i < PipelineStage.values.length; i++)
      StageRow(
        stage: PipelineStage.values[i],
        state: i < activeIndex
            ? StageRowState.done
            : i == activeIndex
                ? StageRowState.active
                : StageRowState.upcoming,
      ),
  ];
}

/// Index of the stage that should render as "active" for a given
/// in-flight status. Listed inline rather than via a Map so the
/// compiler complains if a new status lands without a mapping.
int _activeStageIndex(DocumentStatus status) {
  return switch (status) {
    DocumentStatus.pending => 0,
    DocumentStatus.extracting => 1,
    // Text done, topic worker about to pick up → show topic stage as
    // active (queued). One stepper row pulsing is less confusing than
    // zero rows pulsing during the brief handoff window.
    DocumentStatus.textExtracted => 2,
    DocumentStatus.extractingTopics => 2,
    DocumentStatus.topicsExtracted => 3,
    DocumentStatus.chunking => 3,
    DocumentStatus.chunked => 4,
    DocumentStatus.vectorizing => 4,
    // Terminal — never reached via this path. Fail loudly.
    DocumentStatus.ready ||
    DocumentStatus.flagged ||
    DocumentStatus.failed =>
      throw StateError('Terminal status passed to _activeStageIndex: $status'),
  };
}

/// For a `failed` doc, infer how far we got from side-effect fields.
List<StageRow> _failedRows(Document doc) {
  // Walk backwards through "definitely happened" markers.
  int lastDoneIndex;
  if (doc.chunkCount > 0) {
    lastDoneIndex = 3; // chunking complete → fail in vectorize
  } else if (doc.topicTags.isNotEmpty) {
    lastDoneIndex = 2; // topics complete → fail in chunk
  } else if (doc.textCharCount != null && doc.textCharCount! > 0) {
    lastDoneIndex = 1; // text complete → fail in topic
  } else {
    lastDoneIndex = 0; // only upload happened
  }
  final errorIndex = lastDoneIndex + 1;
  return [
    for (int i = 0; i < PipelineStage.values.length; i++)
      StageRow(
        stage: PipelineStage.values[i],
        state: i <= lastDoneIndex
            ? StageRowState.done
            : i == errorIndex
                ? StageRowState.error
                : StageRowState.upcoming,
      ),
  ];
}

/// `flagged` is content-safety on the extraction worker. Upload is
/// done; extraction was attempted but the doc was rejected.
List<StageRow> _flaggedRows() {
  return [
    const StageRow(stage: PipelineStage.uploaded, state: StageRowState.done),
    const StageRow(stage: PipelineStage.extracting, state: StageRowState.error),
    const StageRow(stage: PipelineStage.topics, state: StageRowState.upcoming),
    const StageRow(
        stage: PipelineStage.chunking, state: StageRowState.upcoming),
    const StageRow(
        stage: PipelineStage.vectorizing, state: StageRowState.upcoming),
    const StageRow(stage: PipelineStage.ready, state: StageRowState.upcoming),
  ];
}
