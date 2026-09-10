import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/shared/models/subscription.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dio = ref.read(dioClientProvider).dio;
  return SubscriptionRepository(dio: dio);
});

class SubscriptionRepository {
  SubscriptionRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Fetch all available subscription plans.
  Future<List<PlanOption>> getPlans() async {
    final response = await _dio.get('/api/v1/subscriptions/plans');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => PlanOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch the current user's subscription status.
  Future<SubscriptionMeResponse> getMySubscription() async {
    final response = await _dio.get('/api/v1/subscriptions/me');
    return SubscriptionMeResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Request a hosted Stripe checkout session for a selected plan.
  Future<CheckoutSessionResponse> createCheckoutSession({
    required SubscriptionPlan plan,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final response = await _dio.post(
      '/api/v1/subscriptions/checkout-session',
      data: {
        'plan_id': plan.wire,
        if (successUrl != null) 'success_url': successUrl,
        if (cancelUrl != null) 'cancel_url': cancelUrl,
      },
    );
    return CheckoutSessionResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Verify session completion upon deep-link return from browser.
  Future<Subscription> verifyCheckoutSession(String sessionId) async {
    final response = await _dio.post(
      '/api/v1/subscriptions/verify-session',
      data: {'session_id': sessionId},
    );
    return Subscription.fromJson(response.data as Map<String, dynamic>);
  }

  /// Check student 7-day free trial & subscription status.
  Future<StudentSubscriptionStatus> getStudentStatus() async {
    final response = await _dio.get('/api/v1/subscriptions/student/status');
    return StudentSubscriptionStatus.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Generate secure short-lived handoff token for mobile -> website checkout.
  Future<HandoffTokenResult> getHandoffToken() async {
    final response = await _dio.post('/api/v1/subscriptions/handoff-token');
    return HandoffTokenResult.fromJson(
        response.data as Map<String, dynamic>);
  }
}
