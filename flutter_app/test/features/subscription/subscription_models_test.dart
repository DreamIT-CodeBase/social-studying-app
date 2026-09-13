import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/shared/models/subscription.dart';

void main() {
  group('Subscription Models & Enums', () {
    test('SubscriptionPlan supports studentMonthly', () {
      expect(
        SubscriptionPlan.fromWire('student_monthly'),
        SubscriptionPlan.studentMonthly,
      );
      expect(SubscriptionPlan.studentMonthly.wire, 'student_monthly');
    });

    test('StudentSubscriptionStatus parses trial active status', () {
      final json = {
        'is_active': false,
        'is_trial': true,
        'is_trial_expired': false,
        'days_remaining': 7,
        'can_access_study': true,
        'message': 'Trial active',
      };

      final status = StudentSubscriptionStatus.fromJson(json);
      expect(status.isActive, isFalse);
      expect(status.isTrial, isTrue);
      expect(status.isTrialExpired, isFalse);
      expect(status.daysRemaining, 7);
      expect(status.canAccessStudy, isTrue);
    });

    test('StudentSubscriptionStatus parses expired trial', () {
      final json = {
        'is_active': false,
        'is_trial': true,
        'is_trial_expired': true,
        'days_remaining': 0,
        'can_access_study': false,
        'message': 'Trial expired',
      };

      final status = StudentSubscriptionStatus.fromJson(json);
      expect(status.isActive, isFalse);
      expect(status.isTrialExpired, isTrue);
      expect(status.canAccessStudy, isFalse);
    });

    test('HandoffTokenResult deserializes properly', () {
      final json = {
        'handoff_token': 'test_tok_123',
        'redirect_url':
            'https://socialstudying.ai/student-subscribe?token=test_tok_123',
        'expires_in_seconds': 900,
      };

      final result = HandoffTokenResult.fromJson(json);
      expect(result.handoffToken, 'test_tok_123');
      expect(result.redirectUrl, contains('test_tok_123'));
      expect(result.expiresInSeconds, 900);
    });
  });
}
