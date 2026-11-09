import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a standard confirmation dialog allowing the user to initiate and
/// complete permanent deletion of their account and all associated data,
/// complying with Apple App Store Review Guideline 5.1.1(v).
Future<void> showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  static const _webDeletionUrl =
      'https://www.socialstudying.ai/delete-account';

  Future<void> _launchWebDeletionPolicy() async {
    final uri = Uri.parse(_webDeletionUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to launch deletion URL: $e');
    }
  }

  Future<void> _handleDelete() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Your account and data have been deleted.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = 'Failed to delete account: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF172033) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete Account & Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This action cannot be undone. All data associated with your account will be permanently removed, including:',
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            _bulletPoint('Profile information and login credentials', secondaryTextColor),
            _bulletPoint('Study progress, quiz records, and flashcards', secondaryTextColor),
            _bulletPoint('Screen Time shields, stats, and focus history', secondaryTextColor),
            _bulletPoint('All workspace memberships and roles', secondaryTextColor),
            const SizedBox(height: 14),
            InkWell(
              onTap: _isDeleting ? null : _launchWebDeletionPolicy,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'View Account & Data Deletion Page',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isDeleting ? null : _handleDelete,
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Permanently Delete',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  Widget _bulletPoint(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

