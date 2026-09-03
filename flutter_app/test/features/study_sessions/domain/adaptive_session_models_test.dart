import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';

Map<String, dynamic> _planJson({Map<String, dynamic> overrides = const {}}) => {
      'session_id': 'ses_1',
      'mode': 'study',
      'level': 'beginner',
      'mastery_score': 0.2,
      'duration_minutes': 12,
      'item_count': 5,
      'estimated_xp_min': -5,
      'estimated_xp_max': 13,
      'questions': const <Map<String, dynamic>>[],
      'flashcards': const <Map<String, dynamic>>[],
      ...overrides,
    };

void main() {
  group('AdaptiveSessionPlan.fromJson', () {
    test('parses the exhausted call-to-action plan', () {
      final plan = AdaptiveSessionPlan.fromJson(
        _planJson(
          overrides: {
            'duration_minutes': 0,
            'item_count': 0,
            'estimated_xp_min': 0,
            'estimated_xp_max': 0,
            'exhausted': true,
          },
        ),
      );

      expect(plan.exhausted, isTrue);
      expect(plan.itemCount, 0);
      expect(plan.durationMinutes, 0);
      expect(plan.questions, isEmpty);
      expect(plan.flashcards, isEmpty);
    });

    test('parses content_ready when the backend reports a warming pool', () {
      final plan =
          AdaptiveSessionPlan.fromJson(_planJson(overrides: {'content_ready': false}));

      expect(plan.contentReady, isFalse);
      expect(plan.exhausted, isFalse);
    });

    test('defaults exhausted to false and content_ready to true when absent', () {
      // Older backends omit both flags; a runnable session must not be
      // mistaken for a call-to-action.
      final plan = AdaptiveSessionPlan.fromJson(_planJson());

      expect(plan.exhausted, isFalse);
      expect(plan.contentReady, isTrue);
      expect(plan.itemCount, 5);
    });

    test('ignores non-boolean flag values instead of throwing', () {
      final plan = AdaptiveSessionPlan.fromJson(
        _planJson(overrides: {'exhausted': 'yes', 'content_ready': 0}),
      );

      expect(plan.exhausted, isFalse);
      expect(plan.contentReady, isTrue);
    });
  });
}
