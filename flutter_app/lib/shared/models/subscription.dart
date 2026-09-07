// Subscription models matching backend `/api/v1/subscriptions/*` endpoints.

enum SubscriptionStatus {
  active,
  trialing,
  pastDue,
  canceled,
  incomplete,
  unknown;

  static SubscriptionStatus fromWire(String? value) => switch (value) {
        'active' => SubscriptionStatus.active,
        'trialing' => SubscriptionStatus.trialing,
        'past_due' => SubscriptionStatus.pastDue,
        'canceled' => SubscriptionStatus.canceled,
        'incomplete' => SubscriptionStatus.incomplete,
        _ => SubscriptionStatus.unknown,
      };

  String get label => switch (this) {
        SubscriptionStatus.active => 'Active',
        SubscriptionStatus.trialing => 'Trialing',
        SubscriptionStatus.pastDue => 'Past Due',
        SubscriptionStatus.canceled => 'Canceled',
        SubscriptionStatus.incomplete => 'Incomplete',
        SubscriptionStatus.unknown => 'Inactive',
      };
}

enum SubscriptionPlan {
  monthly,
  annual,
  proAdmin;

  static SubscriptionPlan fromWire(String? value) => switch (value) {
        'annual' => SubscriptionPlan.annual,
        'pro_admin' => SubscriptionPlan.proAdmin,
        _ => SubscriptionPlan.monthly,
      };

  String get wire => switch (this) {
        SubscriptionPlan.annual => 'annual',
        SubscriptionPlan.proAdmin => 'pro_admin',
        SubscriptionPlan.monthly => 'monthly',
      };
}

class PlanOption {
  const PlanOption({
    required this.planId,
    required this.name,
    required this.description,
    required this.amount,
    required this.currency,
    required this.interval,
  });

  final String planId;
  final String name;
  final String description;
  final int amount; // in cents
  final String currency;
  final String interval;

  factory PlanOption.fromJson(Map<String, dynamic> json) => PlanOption(
        planId: json['plan_id'] as String? ?? 'monthly',
        name: json['name'] as String? ?? 'Admin Plan',
        description: json['description'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 1900,
        currency: json['currency'] as String? ?? 'usd',
        interval: json['interval'] as String? ?? 'month',
      );

  String get formattedPrice {
    final dollars = (amount / 100).toStringAsFixed(amount % 100 == 0 ? 0 : 2);
    final sym = currency.toLowerCase() == 'usd' ? '\$' : '${currency.toUpperCase()} ';
    return '$sym$dollars / $interval';
  }
}

class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.status,
    required this.planId,
    required this.amount,
    required this.currency,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String tenantId;
  final String stripeCustomerId;
  final String? stripeSubscriptionId;
  final SubscriptionStatus status;
  final SubscriptionPlan planId;
  final int amount;
  final String currency;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime createdAt;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        tenantId: json['tenant_id'] as String? ?? '',
        stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
        stripeSubscriptionId: json['stripe_subscription_id'] as String?,
        status: SubscriptionStatus.fromWire(json['status'] as String?),
        planId: SubscriptionPlan.fromWire(json['plan_id'] as String?),
        amount: (json['amount'] as num?)?.toInt() ?? 1900,
        currency: json['currency'] as String? ?? 'usd',
        currentPeriodStart: json['current_period_start'] != null
            ? DateTime.tryParse(json['current_period_start'] as String)
            : null,
        currentPeriodEnd: json['current_period_end'] != null
            ? DateTime.tryParse(json['current_period_end'] as String)
            : null,
        cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}

class SubscriptionMeResponse {
  const SubscriptionMeResponse({
    required this.hasActiveSubscription,
    required this.role,
    this.subscription,
    this.availablePlans = const [],
  });

  final bool hasActiveSubscription;
  final String role;
  final Subscription? subscription;
  final List<PlanOption> availablePlans;

  factory SubscriptionMeResponse.fromJson(Map<String, dynamic> json) =>
      SubscriptionMeResponse(
        hasActiveSubscription:
            json['has_active_subscription'] as bool? ?? false,
        role: json['role'] as String? ?? 'student',
        subscription: json['subscription'] != null
            ? Subscription.fromJson(
                json['subscription'] as Map<String, dynamic>)
            : null,
        availablePlans: (json['available_plans'] as List<dynamic>?)
                ?.map((item) => PlanOption.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class CheckoutSessionResponse {
  const CheckoutSessionResponse({
    required this.checkoutUrl,
    required this.sessionId,
  });

  final String checkoutUrl;
  final String sessionId;

  factory CheckoutSessionResponse.fromJson(Map<String, dynamic> json) =>
      CheckoutSessionResponse(
        checkoutUrl: json['checkout_url'] as String? ?? '',
        sessionId: json['session_id'] as String? ?? '',
      );
}
