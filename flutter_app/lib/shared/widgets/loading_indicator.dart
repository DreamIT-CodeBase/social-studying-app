import 'package:flutter/material.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';
import 'package:social_study_app/features/mascot/widgets/study_buddy.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.useMascot = true,
  });

  final String? message;
  final bool useMascot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (useMascot)
            const StudyBuddy(state: MascotState.loading, size: 88)
          else
            const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
