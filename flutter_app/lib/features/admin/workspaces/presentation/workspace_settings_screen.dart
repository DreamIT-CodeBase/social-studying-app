import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// The selectable question formats. Each pair is `(wire string, label)`
/// — the wire string mirrors `QuestionType`'s `@JsonValue` exactly,
/// which is what `WorkspaceSettings.questionTypes` stores.
const List<(String, String)> _typeOptions = [
  ('mcq', 'Multiple choice'),
  ('short_answer', 'Short answer'),
  ('long_answer', 'Long answer'),
  ('true_false', 'True / false'),
  ('mathematical', 'Mathematical'),
];

/// Workspace settings (Sprint 4.4).
///
/// A standalone pushed screen that reads one workspace out of
/// [WorkspacesList] and edits its [WorkspaceSettings] — question
/// frequency, allowed formats, content moderation, and gamification.
/// Saving routes through `WorkspacesList.updateSettings`.
///
/// Handles all four states (Boil the Lake): loading, error, the
/// workspace-not-found case, and the editable form.
class WorkspaceSettingsScreen extends ConsumerWidget {
  const WorkspaceSettingsScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workspace Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: workspacesAsync.when(
        data: (workspaces) {
          final workspace =
              workspaces.where((w) => w.id == workspaceId).firstOrNull;
          if (workspace == null) {
            return const EmptyStateView(
              icon: Icons.workspaces_outline,
              title: 'Workspace not found',
              subtitle: 'This workspace may have been deleted.',
            );
          }
          // Key by id+name+settings so an external change (or a switch
          // to a different workspace) re-seeds the form's local state.
          return _SettingsForm(
            key: ValueKey('${workspace.id}:${workspace.settings.hashCode}'),
            workspace: workspace,
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading settings…'),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(workspacesListProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late int _questionsPerDay;
  late Set<String> _questionTypes;
  late bool _autoApprove;
  late bool _leaderboard;
  late bool _adaptive;
  bool _saving = false;

  WorkspaceSettings get _settings => widget.workspace.settings;

  @override
  void initState() {
    super.initState();
    _questionsPerDay = _settings.questionsPerDay;
    _questionTypes = _settings.questionTypes.toSet();
    _autoApprove = _settings.autoApproveContent;
    _leaderboard = _settings.leaderboardVisible;
    _adaptive = _settings.adaptiveDifficulty;
  }

  bool get _isDirty =>
      _questionsPerDay != _settings.questionsPerDay ||
      _autoApprove != _settings.autoApproveContent ||
      _leaderboard != _settings.leaderboardVisible ||
      _adaptive != _settings.adaptiveDifficulty ||
      !setEquals(_questionTypes, _settings.questionTypes.toSet());

  /// At least one question format must stay enabled — the generator has
  /// nothing to produce otherwise.
  bool get _isValid => _questionTypes.isNotEmpty;

  WorkspaceSettings _draft() => WorkspaceSettings(
        questionsPerDay: _questionsPerDay,
        // Preserve canonical order regardless of toggle sequence.
        questionTypes: [
          for (final option in _typeOptions)
            if (_questionTypes.contains(option.$1)) option.$1,
        ],
        autoApproveContent: _autoApprove,
        leaderboardVisible: _leaderboard,
        adaptiveDifficulty: _adaptive,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              const _SectionHeader(title: 'Questions'),
              _QuestionsPerDayTile(
                value: _questionsPerDay,
                enabled: !_saving,
                onChanged: (v) => setState(() => _questionsPerDay = v),
              ),
              const SizedBox(height: Spacing.lg),
              _QuestionTypesTile(
                selected: _questionTypes,
                enabled: !_saving,
                onToggle: _toggleType,
              ),
              const SizedBox(height: Spacing.xl),
              const _SectionHeader(title: 'Content moderation'),
              _SettingSwitch(
                title: 'Auto-approve content',
                subtitle:
                    'Serve AI-generated content that passes safety checks '
                    'without manual review.',
                value: _autoApprove,
                enabled: !_saving,
                onChanged: (v) => setState(() => _autoApprove = v),
              ),
              const SizedBox(height: Spacing.xl),
              const _SectionHeader(title: 'Gamification'),
              _SettingSwitch(
                title: 'Leaderboard visible',
                subtitle: 'Show the workspace leaderboard to students.',
                value: _leaderboard,
                enabled: !_saving,
                onChanged: (v) => setState(() => _leaderboard = v),
              ),
              _SettingSwitch(
                title: 'Adaptive difficulty',
                subtitle: 'Calibrate question difficulty to each student’s '
                    'mastery.',
                value: _adaptive,
                enabled: !_saving,
                onChanged: (v) => setState(() => _adaptive = v),
              ),
              if (!_isValid) ...[
                const SizedBox(height: Spacing.md),
                Text(
                  'Select at least one question format.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        _SaveBar(
          enabled: _isDirty && _isValid && !_saving,
          saving: _saving,
          onSave: _save,
        ),
      ],
    );
  }

  void _toggleType(String type) {
    setState(() {
      if (_questionTypes.contains(type)) {
        _questionTypes.remove(type);
      } else {
        _questionTypes.add(type);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(workspacesListProvider.notifier).updateSettings(
            workspaceId: widget.workspace.id,
            settings: _draft(),
          );
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, 'Settings saved');
    } on WorkspaceNotFoundException {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, 'This workspace is no longer available');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, 'Could not save settings: $error');
    }
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Text(
        title.toUpperCase(),
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _QuestionsPerDayTile extends StatelessWidget {
  const _QuestionsPerDayTile({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Questions per day',
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$value',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$value',
              onChanged: enabled ? (v) => onChanged(v.round()) : null,
            ),
            Text(
              'How many questions a student is expected to answer daily.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTypesTile extends StatelessWidget {
  const _QuestionTypesTile({
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question formats',
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Formats the AI generator is allowed to produce.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                for (final option in _typeOptions)
                  FilterChip(
                    label: Text(option.$2),
                    selected: selected.contains(option.$1),
                    onSelected: enabled ? (_) => onToggle(option.$1) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        title: Text(
          title,
          style: context.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// Persistent bottom save bar. The button is disabled until the form is
/// both dirty and valid so a no-op save can't fire.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: enabled ? onSave : null,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Changes'),
          ),
        ),
      ),
    );
  }
}
