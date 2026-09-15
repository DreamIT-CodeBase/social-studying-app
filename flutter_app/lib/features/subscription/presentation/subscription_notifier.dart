import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/subscription/data/subscription_repository.dart';
import 'package:social_study_app/shared/models/subscription.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionState {
  const SubscriptionState({
    this.isLoading = false,
    this.isCheckingOut = false,
    this.isVerifying = false,
    this.error,
    this.selectedPlan = SubscriptionPlan.annual,
    this.plans = const [],
    this.mySubscription,
    this.hasActiveSubscription = false,
    this.verifiedSubscription,
  });

  final bool isLoading;
  final bool isCheckingOut;
  final bool isVerifying;
  final String? error;
  final SubscriptionPlan selectedPlan;
  final List<PlanOption> plans;
  final Subscription? mySubscription;
  final bool hasActiveSubscription;
  final Subscription? verifiedSubscription;

  SubscriptionState copyWith({
    bool? isLoading,
    bool? isCheckingOut,
    bool? isVerifying,
    String? error,
    bool clearError = false,
    SubscriptionPlan? selectedPlan,
    List<PlanOption>? plans,
    Subscription? mySubscription,
    bool? hasActiveSubscription,
    Subscription? verifiedSubscription,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      isVerifying: isVerifying ?? this.isVerifying,
      error: clearError ? null : (error ?? this.error),
      selectedPlan: selectedPlan ?? this.selectedPlan,
      plans: plans ?? this.plans,
      mySubscription: mySubscription ?? this.mySubscription,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      verifiedSubscription: verifiedSubscription ?? this.verifiedSubscription,
    );
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final repo = ref.read(subscriptionRepositoryProvider);
  return SubscriptionNotifier(ref: ref, repository: repo);
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier({
    required Ref ref,
    required SubscriptionRepository repository,
  })  : _ref = ref,
        _repository = repository,
        super(const SubscriptionState()) {
    load();
  }

  final Ref _ref;
  final SubscriptionRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final me = await _repository.getMySubscription();
      final plans = me.availablePlans.isNotEmpty
          ? me.availablePlans
          : await _repository.getPlans();

      state = state.copyWith(
        isLoading: false,
        plans: plans,
        mySubscription: me.subscription,
        hasActiveSubscription: me.hasActiveSubscription,
      );
    } catch (e) {
      // Fallback default plans if offline or dev
      final fallbackPlans = [
        const PlanOption(
          planId: 'monthly',
          name: 'Social Studying Admin (Monthly)',
          description:
              'Full access to create & manage classrooms, AI questions, and screen time rules.',
          amount: 1900,
          currency: 'usd',
          interval: 'month',
        ),
        const PlanOption(
          planId: 'annual',
          name: 'Social Studying Admin (Annual)',
          description: 'Full access for 1 full year with 2 months free.',
          amount: 19000,
          currency: 'usd',
          interval: 'year',
        ),
      ];
      state = state.copyWith(
        isLoading: false,
        plans: fallbackPlans,
        error: e.toString(),
      );
    }
  }

  void selectPlan(SubscriptionPlan plan) {
    state = state.copyWith(selectedPlan: plan);
  }

  /// Launch external browser with Stripe Hosted Checkout session.
  Future<bool> startCheckout() async {
    state = state.copyWith(isCheckingOut: true, clearError: true);
    try {
      final session = await _repository.createCheckoutSession(
        plan: state.selectedPlan,
      );
      state = state.copyWith(isCheckingOut: false);

      final uri = Uri.parse(session.checkoutUrl);
      if (await canLaunchUrl(uri) ||
          defaultTargetPlatform != TargetPlatform.windows) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return launched;
      } else {
        state = state.copyWith(
          error:
              'Could not launch browser for checkout URL: ${session.checkoutUrl}',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isCheckingOut: false,
        error: 'Failed to start checkout: $e',
      );
      return false;
    }
  }

  /// Launch website subscription flow in external mobile browser.
  Future<bool> openWebsiteOnboarding() async {
    state = state.copyWith(isCheckingOut: true, clearError: true);
    try {
      final handoff = await _repository.getHandoffToken();
      state = state.copyWith(isCheckingOut: false);
      final uri = Uri.parse(handoff.redirectUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final user = _ref.read(authNotifierProvider).valueOrNull?.maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );
      final emailParam = user?.email != null
          ? '?email=${Uri.encodeComponent(user!.email)}'
          : '';
      final uri = Uri.parse('https://socialstudying.ai/subscribe$emailParam');
      state = state.copyWith(isCheckingOut: false);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Verifies checkout session, upgrades role, and refreshes auth user state.
  Future<Subscription?> verifySession(String sessionId) async {
    state = state.copyWith(isVerifying: true, clearError: true);
    try {
      final sub = await _repository.verifyCheckoutSession(sessionId);

      // Force refresh user auth state so workspace creation role gate is lifted immediately
      await _ref.read(authNotifierProvider.notifier).refresh();

      state = state.copyWith(
        isVerifying: false,
        hasActiveSubscription: true,
        verifiedSubscription: sub,
        mySubscription: sub,
      );
      return sub;
    } catch (e) {
      state = state.copyWith(
        isVerifying: false,
        error: 'Verification failed: $e',
      );
      return null;
    }
  }
}
