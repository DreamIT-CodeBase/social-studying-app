import 'package:flutter/material.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/theme/app_colors.dart';

/// Shows Google Play compliant Prominent In-App Disclosure for AccessibilityService
Future<bool?> showAccessibilityProminentDisclosureDialog(
  BuildContext context, {
  required VoidCallback onAccept,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final subtextColor =
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      icon: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.accessibility_new_rounded,
          color: AppColors.primary,
          size: 36,
        ),
      ),
      title: Text(
        'Accessibility Service Disclosure',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Social Studying AI uses the Android AccessibilityServices API strictly to support students during study sessions.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Why It Is Used:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• To detect when study sessions are active and track focused study time.\n'
                    '• To temporarily block selected distracting social apps when daily study minutes expire.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Privacy & Data Protection:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Social Studying AI does NOT read screen text, passwords, or personal messages.\n'
                    '• Social Studying AI does NOT collect, store, or share ANY personal or sensitive data.\n'
                    '• All foreground app checks run strictly locally on this device.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'You can turn this off at any time in Android Accessibility Settings.',
              style: TextStyle(
                fontSize: 12,
                color: subtextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Not now',
            style: TextStyle(color: subtextColor),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop(true);
            onAccept();
          },
          child: const Text('Agree & Enable'),
        ),
      ],
    ),
  );
}
