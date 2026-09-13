import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';
import 'package:social_study_app/core/config/app_flavor.dart';

class ScreenTimeDashboardCard extends ConsumerWidget {
  const ScreenTimeDashboardCard({
    super.key,
    required this.onStudyMore,
  });

  final VoidCallback onStudyMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(screenTimeNotifierProvider);

    return walletAsync.when(
      data: (wallet) {
        final total = wallet.totalEarnedMinutes;
        final available = wallet.availableMinutes;
        final usedToday = wallet.consumedToday;

        final double progress =
            total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;

        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF312E81), // deep indigo
                  Color(0xFF4338CA), // indigo
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Spacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.screen_lock_portrait_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        const Text(
                          'Screen Time Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (currentFlavor == AppFlavor.admin)
                      IconButton(
                        icon: const Icon(Icons.settings_rounded,
                            color: Colors.white70, size: 20),
                        onPressed: () =>
                            context.push('/student/screen-time-settings'),
                        tooltip: 'Manage Settings',
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    const Text(
                      'min available',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    minHeight: 8,
                  ),
                ),
                if (available <= 0) ...[
                  const SizedBox(height: Spacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Social Media Blocked",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "You have consumed your all time for social media. Study more to unlock apps!",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatItem(
                      label: 'Earned This Week',
                      value: '$total m',
                    ),
                    _StatItem(
                      label: 'Used Today',
                      value: '$usedToday m',
                    ),
                    _StatItem(
                      label: 'Remaining',
                      value: '$available m',
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    if (currentFlavor == AppFlavor.admin) ...[
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: Spacing.md),
                          ),
                          icon: const Icon(Icons.settings_suggest_outlined,
                              size: 18),
                          label: const Text(
                            'Manage Apps',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () =>
                              context.push('/student/screen-time-settings'),
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.white24,
                      ),
                    ],
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          padding:
                              const EdgeInsets.symmetric(vertical: Spacing.md),
                        ),
                        icon: const Icon(Icons.school_outlined, size: 18),
                        label: const Text(
                          'Study More',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: onStudyMore,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Card(
        color: AppColors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Text(
            'Failed to load screen time details: $err',
            style: const TextStyle(color: AppColors.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
