// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'moderation.freezed.dart';
part 'moderation.g.dart';

/// Moderation models — back the admin moderation dashboard (4.5).
///
/// **Contract note.** The moderation endpoints (plan §5.8 —
/// `GET /workspaces/{ws}/moderation/flagged`, `.../resolve`,
/// `.../log`) are a Sprint 6 surface and are not implemented yet.
/// These models define the wire contract; the demo repository serves
/// them fully offline today and the real repository is coded against
/// the documented shape, ready for the backend to land.

/// What kind of content got flagged.
enum FlaggedContentKind {
  @JsonValue('question')
  question,
  @JsonValue('flashcard')
  flashcard,
  @JsonValue('document')
  document,
}

/// The resolution state of a flagged item.
enum ModerationVerdict {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

/// One item in the moderation queue or audit log.
///
/// Mirrors a `moderation_log` record projected for the dashboard: the
/// scanned content (a reference + excerpt, never the full text), the
/// Content Safety verdict, and the resolution.
@freezed
class FlaggedItem with _$FlaggedItem {
  const FlaggedItem._();

  const factory FlaggedItem({
    required String id,
    @JsonKey(name: 'content_kind') required FlaggedContentKind contentKind,

    /// The topic the flagged content belongs to.
    required String topic,

    /// A short snippet of the flagged content for the admin to judge —
    /// never the full document text.
    required String excerpt,

    /// Human-readable reason — the Content Safety category that tripped
    /// (e.g. "Violence", "Hate").
    required String reason,

    /// Azure Content Safety severity, 0–6. Higher is more severe.
    @Default(0) int severity,
    @JsonKey(name: 'flagged_at') required String flaggedAt,
    @Default(ModerationVerdict.pending) ModerationVerdict verdict,
  }) = _FlaggedItem;

  factory FlaggedItem.fromJson(Map<String, dynamic> json) =>
      _$FlaggedItemFromJson(json);

  /// True while the item still needs an admin decision.
  bool get isPending => verdict == ModerationVerdict.pending;
}
