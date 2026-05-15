import 'package:flutter/material.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/documents/presentation/widgets/pipeline_stages.dart';

/// Vertical stepper that renders one row per pipeline stage with
/// done / active / upcoming / error icons. Stateless: parent passes a
/// pre-computed `List<StageRow>` (see `buildStageRows` in
/// `pipeline_stages.dart`) so this widget never has to know what a
/// `Document` is — keeps it golden-test friendly.
class StageStepper extends StatelessWidget {
  const StageStepper({super.key, required this.rows});

  final List<StageRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++)
          _StageRowView(
            row: rows[i],
            isLast: i == rows.length - 1,
          ),
      ],
    );
  }
}

class _StageRowView extends StatelessWidget {
  const _StageRowView({required this.row, required this.isLast});

  final StageRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailColumn(state: row.state, isLast: isLast),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.stage.label,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _labelColor(context, row.state),
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    row.stage.detail,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _labelColor(BuildContext context, StageRowState state) {
    return switch (state) {
      StageRowState.done => context.colorScheme.onSurface,
      StageRowState.active => context.colorScheme.primary,
      StageRowState.upcoming => context.colorScheme.onSurfaceVariant,
      StageRowState.error => context.colorScheme.error,
    };
  }
}

class _RailColumn extends StatelessWidget {
  const _RailColumn({required this.state, required this.isLast});

  final StageRowState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Column(
        children: [
          _StageIcon(state: state),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
                color: state == StageRowState.done
                    ? context.colorScheme.primary
                    : context.colorScheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.state});

  final StageRowState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      StageRowState.done => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      StageRowState.active => SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      StageRowState.upcoming => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
      StageRowState.error => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.colorScheme.error,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
    };
  }
}
