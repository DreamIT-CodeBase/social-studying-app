import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/features/subscription/data/subscription_repository.dart';
import 'package:social_study_app/shared/models/subscription.dart';

final studentSubscriptionStatusProvider =
    FutureProvider.autoDispose<StudentSubscriptionStatus>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return repo.getStudentStatus();
});
