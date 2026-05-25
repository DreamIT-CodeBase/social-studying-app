import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/notifications/presentation/notification_service.dart';

void main() {
  group('deepLinkFor', () {
    test('returns null on missing type', () {
      expect(deepLinkFor({}), isNull);
      expect(deepLinkFor({'workspace_id': 'wsp_a'}), isNull);
    });

    test('returns null on missing workspace_id', () {
      expect(deepLinkFor({'type': 'study_reminder'}), isNull);
    });

    test('returns null on unknown type', () {
      expect(
        deepLinkFor({'type': 'unknown_kind', 'workspace_id': 'wsp_a'}),
        isNull,
      );
    });

    test('study_reminder routes to student home', () {
      expect(
        deepLinkFor({
          'type': 'study_reminder',
          'workspace_id': 'wsp_a',
        }),
        '/student/home',
      );
    });

    test('streak_warning routes to student home', () {
      expect(
        deepLinkFor({
          'type': 'streak_warning',
          'workspace_id': 'wsp_a',
        }),
        '/student/home',
      );
    });

    test('unanswered_reprompt routes to student home', () {
      expect(
        deepLinkFor({
          'type': 'unanswered_reprompt',
          'workspace_id': 'wsp_a',
          'question_id': 'qst_a',
        }),
        '/student/home',
      );
    });

    test('milestone routes to the badges screen with user + workspace id', () {
      expect(
        deepLinkFor({
          'type': 'milestone',
          'workspace_id': 'wsp_a',
          'user_id': 'usr_b',
          'badge_id': 'first_steps',
        }),
        '/student/badges/wsp_a/usr_b',
      );
    });

    test('milestone returns null without user_id (deep-link is per-user)', () {
      expect(
        deepLinkFor({
          'type': 'milestone',
          'workspace_id': 'wsp_a',
        }),
        isNull,
      );
    });
  });
}
