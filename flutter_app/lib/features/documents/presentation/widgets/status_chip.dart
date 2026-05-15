import 'package:flutter/material.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/shared/models/document.dart';

/// Compact pill that summarises a document's status for the list view.
/// Self-contained: takes a `DocumentStatus` and picks a color +
/// human-readable label.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (palette.showSpinner)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.foreground,
              ),
            )
          else
            Icon(palette.icon, size: 14, color: palette.foreground),
          const SizedBox(width: Spacing.xs),
          Text(
            _label(status),
            style: context.textTheme.labelSmall?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipPalette {
  const _ChipPalette({
    required this.foreground,
    required this.background,
    required this.icon,
    required this.showSpinner,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
  final bool showSpinner;
}

_ChipPalette _paletteFor(BuildContext context, DocumentStatus status) {
  if (status.isTerminal) {
    return switch (status) {
      DocumentStatus.ready => const _ChipPalette(
          foreground: AppColors.onTertiaryContainer,
          background: AppColors.tertiaryContainer,
          icon: Icons.check_rounded,
          showSpinner: false,
        ),
      DocumentStatus.failed => const _ChipPalette(
          foreground: AppColors.onErrorContainer,
          background: AppColors.errorContainer,
          icon: Icons.error_outline_rounded,
          showSpinner: false,
        ),
      DocumentStatus.flagged => const _ChipPalette(
          foreground: AppColors.onSecondaryContainer,
          background: AppColors.secondaryContainer,
          icon: Icons.shield_outlined,
          showSpinner: false,
        ),
      _ => throw StateError('unreachable: terminal palette branch'),
    };
  }
  // In flight — primary palette + spinner.
  return const _ChipPalette(
    foreground: AppColors.onPrimaryContainer,
    background: AppColors.primaryContainer,
    icon: Icons.hourglass_top_rounded,
    showSpinner: true,
  );
}

String _label(DocumentStatus status) => switch (status) {
      DocumentStatus.pending => 'Queued',
      DocumentStatus.extracting => 'Reading text',
      DocumentStatus.textExtracted => 'Text ready',
      DocumentStatus.extractingTopics => 'Finding topics',
      DocumentStatus.topicsExtracted => 'Topics ready',
      DocumentStatus.chunking => 'Splitting',
      DocumentStatus.chunked => 'Chunks ready',
      DocumentStatus.vectorizing => 'Indexing',
      DocumentStatus.ready => 'Ready',
      DocumentStatus.flagged => 'Flagged',
      DocumentStatus.failed => 'Failed',
    };
