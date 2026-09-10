import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/subscription/data/subscription_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentPaywallDialog extends ConsumerStatefulWidget {
  const StudentPaywallDialog({
    super.key,
    required this.daysRemaining,
    required this.isExpired,
  });

  final int daysRemaining;
  final bool isExpired;

  static Future<void> show(
    BuildContext context, {
    required int daysRemaining,
    required bool isExpired,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !isExpired,
      builder: (ctx) => StudentPaywallDialog(
        daysRemaining: daysRemaining,
        isExpired: isExpired,
      ),
    );
  }

  @override
  ConsumerState<StudentPaywallDialog> createState() =>
      _StudentPaywallDialogState();
}

class _StudentPaywallDialogState extends ConsumerState<StudentPaywallDialog> {
  bool _isLaunching = false;
  String? _errorMessage;

  Future<void> _handleUpgrade() async {
    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final handoff = await repo.getHandoffToken();
      final uri = Uri.parse(handoff.redirectUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        setState(() {
          _errorMessage = 'Unable to launch browser for website payment.';
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback directly to student subscribe URL
        final fallbackUri =
            Uri.parse('https://socialstudying.ai/student-subscribe');
        final launched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          setState(() {
            _errorMessage = 'Could not open subscription page. Please visit socialstudying.ai/student-subscribe';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon header
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF059669),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),

            // Title
            Text(
              widget.isExpired
                  ? '7-Day Free Trial Ended'
                  : '${widget.daysRemaining} Days Left in Free Trial',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: Spacing.xs),

            // Subtitle
            Text(
              widget.isExpired
                  ? 'Your 7-day free trial has expired. Subscribe to continue unlimited self-study question generation and flashcards.'
                  : 'Upgrade now to keep uninterrupted access to personal adaptive learning and question generation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Pricing box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Self-Study Learning',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Recurring monthly auto-pay',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '\$10',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const Text(
                    '/mo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),

            // Features list
            _buildFeature('Unlimited AI adaptive questions & explanations'),
            _buildFeature('Automatic spaced-repetition flashcards'),
            _buildFeature('Document OCR & textbook chapter ingestion'),
            _buildFeature('Personal topic mastery analytics'),
            const SizedBox(height: Spacing.lg),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(Spacing.xs),
                margin: const EdgeInsets.only(bottom: Spacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            // Action button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isLaunching ? null : _handleUpgrade,
              child: _isLaunching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade on Website (\$10/mo)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),

            if (!widget.isExpired) ...[
              const SizedBox(height: Spacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue Free Trial'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
