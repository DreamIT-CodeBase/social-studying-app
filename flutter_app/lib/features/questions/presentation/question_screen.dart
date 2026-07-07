import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/celebration_overlay.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/features/questions/presentation/question_session_notifier.dart';
import 'package:social_study_app/shared/models/question.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';

/// Question-answering interface (Sprint 4.7) and answer feedback
/// (Sprint 4.8) — unified into a single visual page style.
class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  QuestionSessionNotifier get _notifier =>
      ref.read(questionSessionNotifierProvider(widget.workspaceId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.start();
      }
    });
  }

  @override
  void didUpdateWidget(QuestionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspaceId != oldWidget.workspaceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifier.start();
        }
      });
    }
  }

  void _restart() {
    ref.invalidate(questionSessionNotifierProvider(widget.workspaceId));
    _notifier.start();
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(questionSessionNotifierProvider(widget.workspaceId));
    final isAdmin = ref.watch(isActiveWorkspaceAdminProvider);

    return session.when(
      idle: () => EmptyStateView(
        icon: Icons.quiz_rounded,
        title: 'Ready to study?',
        subtitle: 'Tap below to start a new question session.',
        action: FilledButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Study Session'),
        ),
      ),
      loading: () =>
          const LoadingIndicator(message: 'Generating your question…'),
      ready: (question, draftAnswer) => _UnifiedQuestionView(
        workspaceId: widget.workspaceId,
        question: question,
        selectedAnswer: draftAnswer,
        onAnswerChanged: _notifier.setDraftAnswer,
        submitting: false,
        feedback: null,
        onSubmit: _notifier.submit,
      ),
      submitting: (question, draftAnswer) => _UnifiedQuestionView(
        workspaceId: widget.workspaceId,
        question: question,
        selectedAnswer: draftAnswer,
        onAnswerChanged: null,
        submitting: true,
        feedback: null,
        onSubmit: _notifier.submit,
      ),
      feedback: (question, submittedAnswer, feedback) => _UnifiedQuestionView(
        workspaceId: widget.workspaceId,
        question: question,
        selectedAnswer: submittedAnswer,
        onAnswerChanged: null,
        submitting: false,
        feedback: feedback,
        onNext: _notifier.next,
        onEndSession: _notifier.endSession,
      ),
      unavailable: (message, isNoTopics, retryAfterSeconds) => EmptyStateView(
        icon: isNoTopics
            ? Icons.menu_book_rounded
            : Icons.hourglass_empty_rounded,
        title: isNoTopics ? 'No questions yet' : 'Generator is busy',
        subtitle: isNoTopics
            ? (isAdmin
                ? 'Upload study material in the Home tab before '
                    'questions can be generated.'
                : 'Your teacher needs to upload study material before '
                    'questions can be generated.')
            : message,
        action: isNoTopics
            ? null
            : FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
      ),
      error: (message) => ErrorView(message: message, onRetry: _restart),
    );
  }
}

// Helper methods for subject mapping based on topic
String _getSubjectFromTopic(String topic) {
  final lowercase = topic.toLowerCase();
  if (lowercase.contains('cell') || lowercase.contains('bio') || lowercase.contains('gene') || lowercase.contains('dna') || lowercase.contains('mitosis')) {
    return 'Biology';
  }
  if (lowercase.contains('chem') || lowercase.contains('atom') || lowercase.contains('bond') || lowercase.contains('molec')) {
    return 'Chemistry';
  }
  if (lowercase.contains('phys') || lowercase.contains('force') || lowercase.contains('grav') || lowercase.contains('motion') || lowercase.contains('wave')) {
    return 'Physics';
  }
  return 'Study';
}

IconData _getIconForSubject(String subject) {
  switch (subject) {
    case 'Biology':
      return Icons.biotech_rounded;
    case 'Chemistry':
      return Icons.science_rounded;
    case 'Physics':
      return Icons.bolt_rounded;
    default:
      return Icons.menu_book_rounded;
  }
}

Color _getSubjectColor(String subject) {
  switch (subject) {
    case 'Biology':
      return const Color(0xFF7E22CE);
    case 'Chemistry':
      return const Color(0xFF0369A1);
    case 'Physics':
      return const Color(0xFFB45309);
    default:
      return const Color(0xFF2563EB);
  }
}

Color _getSubjectBgColor(String subject) {
  switch (subject) {
    case 'Biology':
      return const Color(0xFFF3E8FF);
    case 'Chemistry':
      return const Color(0xFFE0F2FE);
    case 'Physics':
      return const Color(0xFFFEF3C7);
    default:
      return const Color(0xFFEFF6FF);
  }
}


// ─────────────────────────────────────────────────────────────────────────
// Unified Answering & Feedback layout matching mockup
// ─────────────────────────────────────────────────────────────────────────
class _UnifiedQuestionView extends ConsumerStatefulWidget {
  const _UnifiedQuestionView({
    required this.workspaceId,
    required this.question,
    this.selectedAnswer,
    this.onAnswerChanged,
    required this.submitting,
    this.feedback,
    this.onSubmit,
    this.onNext,
    this.onEndSession,
  });

  final String workspaceId;
  final Question question;
  final String? selectedAnswer;
  final ValueChanged<String>? onAnswerChanged;
  final bool submitting;
  final AnswerFeedback? feedback;
  final Future<void> Function()? onSubmit;
  final Future<void> Function()? onNext;
  final VoidCallback? onEndSession;

  @override
  ConsumerState<_UnifiedQuestionView> createState() => _UnifiedQuestionViewState();
}

class _UnifiedQuestionViewState extends ConsumerState<_UnifiedQuestionView> {
  bool _triggerConfetti = false;

  @override
  void initState() {
    super.initState();
    _updateMascotAndTriggers();
  }

  @override
  void didUpdateWidget(covariant _UnifiedQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedback != oldWidget.feedback) {
      _updateMascotAndTriggers();
    }
  }

  void _updateMascotAndTriggers() {
    if (widget.feedback != null) {
      if (widget.feedback!.isCorrect) {
        _triggerConfetti = true;
        HapticFeedback.heavyImpact();
        SoundService.instance.playCorrectAnswer();
        
        WidgetsBinding.instance.addPostFrameCallback((_) => _runCelebrations());
      } else {
        _triggerConfetti = false;
        HapticFeedback.lightImpact();
        SoundService.instance.playWrongAnswer();
      }
    } else {
      _triggerConfetti = false;
    }
  }

  Future<void> _runCelebrations() async {
    final feedback = widget.feedback;
    if (feedback == null) return;
    if (feedback.leveledUp && mounted) {
      await showLevelUpBurst(context, newLevel: feedback.newLevel);
    }
    for (final unlock in feedback.badgesUnlocked) {
      if (!mounted) break;
      await showBadgeUnlockSheet(
        context,
        badgeId: unlock.badgeId,
        name: unlock.name,
        description: unlock.description,
        icon: unlock.icon,
      );
    }
  }

  void _showWorkspaceSwitcher(BuildContext context, WidgetRef ref) {
    final authValue = ref.read(authNotifierProvider).valueOrNull;
    final user = authValue?.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    final memberships = user?.workspaceMemberships ?? [];
    final activeId = widget.workspaceId;
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StudentWorkspaceSwitcherSheet(
          memberships: memberships,
          selectedId: activeId,
          onSelect: (id) {
            ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(id);
            Navigator.of(context).pop();
          },
          onCreateWorkspace: () {
            Navigator.of(context).pop();
            showStudentCreateWorkspaceDialog(context);
          },
          onJoinWorkspace: () {
            Navigator.of(context).pop();
            showStudentJoinWorkspaceDialog(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = widget.question;
    final feedback = widget.feedback;
    final isFeedbackState = feedback != null;
    
    final canSubmit = !widget.submitting &&
        widget.selectedAnswer != null &&
        widget.selectedAnswer!.trim().isNotEmpty;
        
    final subject = _getSubjectFromTopic(question.topic);
    final subjectColor = _getSubjectColor(subject);
    final subjectBgColor = _getSubjectBgColor(subject);
    final subjectIcon = _getIconForSubject(subject);
    
    final authValue = ref.watch(authNotifierProvider).valueOrNull;
    final user = authValue?.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    final memberships = user?.workspaceMemberships ?? [];
    final activeId = widget.workspaceId;
    final activeWorkspace = memberships.where((m) => m.workspaceId == activeId).firstOrNull;
    final workspaceName = activeWorkspace?.workspaceName ?? 'Switch';
    
    final userInitial = user?.displayName.isNotEmpty == true
        ? user!.displayName[0].toUpperCase()
        : 'S';

    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 230,
            child: themeMode == AppThemeMode.mature
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/mascot/studytabbackgroundimage.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                  ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Custom Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () {
                          ref.read(studentHomeTabProvider.notifier).state = 0;
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Workspace Switcher Pill
                      if (memberships.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showWorkspaceSwitcher(context, ref),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people_alt_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      workspaceName,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Profile Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                        child: Text(
                          userInitial,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Question / Input Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (themeMode == AppThemeMode.mature)
                        // ── Teen & College theme: clean card, no topic/level pills ──
                        Container(
                          margin: EdgeInsets.only(top: math.max(0.0, 60.0 - MediaQuery.of(context).padding.top)),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: subjectBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(subjectIcon, color: subjectColor, size: 28),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: subjectBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      subject.toUpperCase(),
                                      style: TextStyle(
                                        color: subjectColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  question.body,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // ── Kids theme: original layout with topic + level pills ──
                        Container(
                          margin: EdgeInsets.only(top: math.max(0.0, 105.0 - MediaQuery.of(context).padding.top)),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: subjectBgColor,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(subjectIcon, color: subjectColor, size: 28),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: subjectBgColor,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          subject.toUpperCase(),
                                          style: TextStyle(
                                            color: subjectColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      question.body,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
                                ),
                              ),
                              _UnifiedQuestionHeader(question: question),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Option Cards / Text Input
                      AnswerInput(
                        key: ValueKey('input:${question.id}'),
                        question: question,
                        draftAnswer: widget.selectedAnswer,
                        enabled: !isFeedbackState && !widget.submitting,
                        onChanged: widget.onAnswerChanged ?? (_) {},
                        feedback: feedback,
                      ),
                      // Inline Feedback Card
                      if (isFeedbackState) ...[
                        const SizedBox(height: 12),
                        _UnifiedFeedbackCard(question: question, feedback: feedback),
                      ],
                    ],
                  ),
                ),
                
                // Bottom Submit / Next Button Bar
                _UnifiedSubmitBar(
                  enabled: canSubmit || isFeedbackState,
                  submitting: widget.submitting,
                  isFeedbackState: isFeedbackState,
                  onSubmit: widget.onSubmit ?? () async {},
                  onNext: widget.onNext ?? () async {},
                  onEndSession: widget.onEndSession,
                ),
              ],
            ),
          ),
          // Confetti particle rain overlay
          _ConfettiLayer(trigger: _triggerConfetti),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// UI Header Pills below the question card
// ─────────────────────────────────────────────────────────────────────────
class _UnifiedQuestionHeader extends StatelessWidget {
  const _UnifiedQuestionHeader({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final topicColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final topicBgColor = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
    
    final (diffLabel, diffColor, diffBgColor, diffIcon) = switch (question.difficulty) {
      DifficultyLevel.beginner => (
          'Beginner',
          isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
          isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
          Icons.grade_outlined
        ),
      DifficultyLevel.intermediate => (
          'Intermediate',
          isDark ? const Color(0xFFFB923C) : const Color(0xFFD97706),
          isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
          Icons.star_half_rounded
        ),
      DifficultyLevel.advanced => (
          'Advanced',
          isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
          isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
          Icons.star_rounded
        ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Topic Pill
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: topicBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 14, color: topicColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    question.topic,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: topicColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Difficulty Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: diffBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(diffIcon, size: 14, color: diffColor),
              const SizedBox(width: 6),
              Text(
                diffLabel,
                style: TextStyle(
                  color: diffColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

(Color, Color, Color) _getCircleColors(String label, bool isDark) {
  final cleanLabel = label.trim().toUpperCase();
  if (cleanLabel == 'A' || cleanLabel == 'T' || cleanLabel == 'TRUE') {
    return (
      isDark ? const Color(0xFF064E3B) : const Color(0xFFEFFDF5),
      isDark ? const Color(0xFF047857) : const Color(0xFFD1FAE5),
      isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    );
  } else if (cleanLabel == 'B' || cleanLabel == 'F' || cleanLabel == 'FALSE') {
    return (
      isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
      isDark ? const Color(0xFF1D4ED8) : const Color(0xFFDBEAFE),
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    );
  } else if (cleanLabel == 'C') {
    return (
      isDark ? const Color(0xFF4C1D95) : const Color(0xFFF5F3FF),
      isDark ? const Color(0xFF6D28D9) : const Color(0xFFEDE9FE),
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
    );
  } else if (cleanLabel == 'D') {
    return (
      isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED),
      isDark ? const Color(0xFFC2410C) : const Color(0xFFFFEDD5),
      isDark ? const Color(0xFFFDBA74) : const Color(0xFFEA580C),
    );
  } else {
    return (
      isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
      isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Premium Option Card
// ─────────────────────────────────────────────────────────────────────────
class _OptionCard extends StatefulWidget {
  const _OptionCard({
    required this.label,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.isCorrect = false,
    this.isIncorrect = false,
  });

  final String label;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool isCorrect;
  final bool isIncorrect;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  void _startAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(_pulseController!);

    bool isTest = false;
    try {
      isTest = Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {}

    if (isTest) {
      _pulseController!.forward();
    } else {
      _pulseController!.repeat(reverse: true);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isCorrect) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant _OptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCorrect && _pulseController == null) {
      _startAnimation();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pulseAnim = _pulseAnimation;
    
    Color cardBgColor = Colors.white;
    if (isDark) {
      cardBgColor = const Color(0xFF1E293B);
    }
    
    if (widget.isCorrect) {
      cardBgColor = isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
    } else if (widget.isIncorrect) {
      cardBgColor = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2);
    } else if (widget.selected) {
      cardBgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
    }

    Color borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    if (widget.isCorrect) {
      borderColor = const Color(0xFF22C55E);
    } else if (widget.isIncorrect) {
      borderColor = const Color(0xFFEF4444);
    } else if (widget.selected) {
      borderColor = const Color(0xFF2563EB);
    }

    Color circleBgColor;
    Color circleBorderColor;
    Color circleTextColor;

    if (widget.isCorrect) {
      circleBgColor = const Color(0xFF22C55E);
      circleBorderColor = const Color(0xFF22C55E);
      circleTextColor = Colors.white;
    } else if (widget.isIncorrect) {
      circleBgColor = const Color(0xFFEF4444);
      circleBorderColor = const Color(0xFFEF4444);
      circleTextColor = Colors.white;
    } else if (widget.selected) {
      circleBgColor = const Color(0xFF2563EB);
      circleBorderColor = const Color(0xFF2563EB);
      circleTextColor = Colors.white;
    } else {
      final (bg, border, text) = _getCircleColors(widget.label, isDark);
      circleBgColor = bg;
      circleBorderColor = border;
      circleTextColor = text;
    }

    Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    if (widget.isCorrect) {
      textColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    } else if (widget.isIncorrect) {
      textColor = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    }

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      } : null,
      onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 6.0),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: widget.selected || widget.isCorrect || widget.isIncorrect ? 2.0 : 1.5),
            boxShadow: [
              if (widget.isCorrect && pulseAnim != null)
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  blurRadius: pulseAnim.value,
                  spreadRadius: pulseAnim.value * 0.2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: circleBorderColor, width: 1.5),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: circleTextColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontWeight: widget.selected || widget.isCorrect || widget.isIncorrect ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (widget.isCorrect)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22C55E),
                  size: 24,
                )
              else if (widget.isIncorrect)
                const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                )
              else
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayAnswer(Question question, String raw) {
  final trimmed = raw.trim();
  switch (question.questionType) {
    case QuestionType.mcq:
      final match = question.options
          .where((o) => o.key.toLowerCase() == trimmed.toLowerCase())
          .firstOrNull;
      return match == null ? trimmed : '${match.key}.  ${match.text}';
    case QuestionType.trueFalse:
      if (trimmed.toLowerCase() == 'true') return 'True';
      if (trimmed.toLowerCase() == 'false') return 'False';
      return trimmed;
    case QuestionType.shortAnswer:
    case QuestionType.longAnswer:
    case QuestionType.mathematical:
      return trimmed;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Inline Feedback Card
// ─────────────────────────────────────────────────────────────────────────
class _UnifiedFeedbackCard extends StatelessWidget {
  const _UnifiedFeedbackCard({required this.question, required this.feedback});

  final Question question;
  final AnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final correct = feedback.isCorrect;
    
    final cardBgColor = correct
        ? (isDark ? const Color(0xFF062F1D) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2));
        
    final borderColor = correct
        ? (isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0))
        : (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5));
        
    final titleColor = correct
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444));
        
    final titleText = correct ? 'Correct!' : 'Not quite';
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, 20 * (1.0 - t)),
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeedbackShieldBadge(correct: correct),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _FeedbackActionIcon(
                        icon: Icons.share_rounded,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: feedback.explanation));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Explanation copied to clipboard!')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _FeedbackActionIcon(
                        icon: Icons.flag_rounded,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Question reported. Thank you!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!correct) ...[
                    Text(
                      'CORRECT ANSWER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displayAnswer(question, feedback.canonicalAnswer),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    feedback.explanation,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackActionIcon extends StatelessWidget {
  const _FeedbackActionIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _FeedbackShieldBadge extends StatefulWidget {
  const _FeedbackShieldBadge({required this.correct});

  final bool correct;

  @override
  State<_FeedbackShieldBadge> createState() => _FeedbackShieldBadgeState();
}

class _FeedbackShieldBadgeState extends State<_FeedbackShieldBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    
    final color = widget.correct ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: scale.value,
        child: child,
      ),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.correct) ...[
              const Positioned(
                top: 4,
                left: 6,
                child: Icon(Icons.star_rounded, size: 8, color: Color(0xFFFFD700)),
              ),
              const Positioned(
                bottom: 8,
                left: 2,
                child: Icon(Icons.star_rounded, size: 10, color: Color(0xFFFFD700)),
              ),
              const Positioned(
                top: 12,
                right: 4,
                child: Icon(Icons.star_rounded, size: 6, color: Color(0xFFFFD700)),
              ),
              const Positioned(
                bottom: 12,
                right: 2,
                child: Icon(Icons.star_rounded, size: 8, color: Color(0xFFFFD700)),
              ),
            ],
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.correct ? const Color(0xFF22C55E).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.correct ? Icons.shield_rounded : Icons.cancel_presentation_rounded,
                color: color,
                size: 28,
              ),
            ),
            if (widget.correct)
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFD700),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Animated Confetti rain overlay on right answer
// ─────────────────────────────────────────────────────────────────────────
class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.trigger});

  final bool trigger;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.trigger) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ConfettiLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.isAnimating) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _LocalConfettiPainter(progress: _controller.value),
          );
        },
      ),
    );
  }
}

class _LocalConfettiPainter extends CustomPainter {
  _LocalConfettiPainter({required this.progress}) : _particles = _seedParticles();

  final double progress;
  final List<_LocalParticle> _particles;

  static List<_LocalParticle> _seedParticles() {
    final rng = math.Random(42);
    return List.generate(70, (_) {
      return _LocalParticle(
        xFraction: rng.nextDouble(),
        delay: rng.nextDouble() * 0.4,
        color: _palette[rng.nextInt(_palette.length)],
        rotationSpeed: 4 + rng.nextDouble() * 8,
        size: 8 + rng.nextDouble() * 10,
      );
    });
  }

  static const List<Color> _palette = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = p.xFraction * size.width;
      final y = -20 + (size.height + 40) * (t * t * 0.4 + t * 0.6);
      final opacity = (t < 0.1) ? (t / 0.1) : (t > 0.8 ? (1.0 - (t - 0.8) / 0.2) : 1.0);
      paint.color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LocalConfettiPainter old) => old.progress != progress;
}

class _LocalParticle {
  const _LocalParticle({
    required this.xFraction,
    required this.delay,
    required this.color,
    required this.rotationSpeed,
    required this.size,
  });

  final double xFraction;
  final double delay;
  final Color color;
  final double rotationSpeed;
  final double size;
}

// ─────────────────────────────────────────────────────────────────────────
// Animated Mascot jump bounce wrapper
// ─────────────────────────────────────────────────────────────────────────
class _MascotBounceWrapper extends StatefulWidget {
  const _MascotBounceWrapper({required this.child, required this.trigger});

  final Widget child;
  final bool trigger;

  @override
  State<_MascotBounceWrapper> createState() => _MascotBounceWrapperState();
}

class _MascotBounceWrapperState extends State<_MascotBounceWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -20.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -20.0, end: 8.0).chain(CurveTween(curve: Curves.easeIn)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 25),
    ]).animate(_controller);

    if (widget.trigger) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _MascotBounceWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Inputs delegation based on Question format
// ─────────────────────────────────────────────────────────────────────────
class AnswerInput extends StatelessWidget {
  const AnswerInput({
    super.key,
    required this.question,
    required this.draftAnswer,
    required this.enabled,
    required this.onChanged,
    this.feedback,
  });

  final Question question;
  final String? draftAnswer;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final AnswerFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    return switch (question.questionType) {
      QuestionType.mcq => _McqInput(
          options: question.options,
          selectedKey: draftAnswer,
          enabled: enabled,
          onSelect: onChanged,
          feedback: feedback,
        ),
      QuestionType.trueFalse => _TrueFalseInput(
          selected: draftAnswer,
          enabled: enabled,
          onSelect: onChanged,
          feedback: feedback,
        ),
      QuestionType.shortAnswer => _TextAnswerInput(
          initialValue: draftAnswer,
          enabled: enabled,
          onChanged: onChanged,
          hintText: 'Type your answer',
          minLines: 1,
          maxLines: 2,
        ),
      QuestionType.longAnswer => _TextAnswerInput(
          initialValue: draftAnswer,
          enabled: enabled,
          onChanged: onChanged,
          hintText: 'Write your full answer',
          minLines: 5,
          maxLines: 10,
        ),
      QuestionType.mathematical => _TextAnswerInput(
          initialValue: draftAnswer,
          enabled: enabled,
          onChanged: onChanged,
          hintText: 'Enter your answer — LaTeX notation is supported',
          minLines: 1,
          maxLines: 3,
          monospace: true,
        ),
    };
  }
}

class _McqInput extends StatelessWidget {
  const _McqInput({
    required this.options,
    required this.selectedKey,
    required this.enabled,
    required this.onSelect,
    this.feedback,
  });

  final List<McqOption> options;
  final String? selectedKey;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final AnswerFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(
            label: option.key,
            text: option.text,
            selected: option.key.toLowerCase() == selectedKey?.toLowerCase(),
            enabled: enabled,
            onTap: () => onSelect(option.key),
            isCorrect: feedback != null && option.key.toLowerCase() == feedback!.canonicalAnswer.toLowerCase(),
            isIncorrect: feedback != null && !feedback!.isCorrect && option.key.toLowerCase() == selectedKey?.toLowerCase(),
          ),
        ],
      ],
    );
  }
}

class _TrueFalseInput extends StatelessWidget {
  const _TrueFalseInput({
    required this.selected,
    required this.enabled,
    required this.onSelect,
    this.feedback,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final AnswerFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OptionCard(
            label: 'T',
            text: 'True',
            selected: selected == 'true',
            enabled: enabled,
            onTap: () => onSelect('true'),
            isCorrect: feedback != null && feedback!.canonicalAnswer.toLowerCase() == 'true',
            isIncorrect: feedback != null && !feedback!.isCorrect && selected == 'true',
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _OptionCard(
            label: 'F',
            text: 'False',
            selected: selected == 'false',
            enabled: enabled,
            onTap: () => onSelect('false'),
            isCorrect: feedback != null && feedback!.canonicalAnswer.toLowerCase() == 'false',
            isIncorrect: feedback != null && !feedback!.isCorrect && selected == 'false',
          ),
        ),
      ],
    );
  }
}

class _TextAnswerInput extends StatefulWidget {
  const _TextAnswerInput({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    this.monospace = false,
  });

  final String? initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool monospace;

  @override
  State<_TextAnswerInput> createState() => _TextAnswerInputState();
}

class _TextAnswerInputState extends State<_TextAnswerInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      autocorrect: !widget.monospace,
      textCapitalization: widget.monospace
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      style: widget.monospace
          ? const TextStyle(fontFamily: 'monospace')
          : null,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2.0,
          ),
        ),
        alignLabelWithHint: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Unified Submit / Next persistent bar
// ─────────────────────────────────────────────────────────────────────────
class _UnifiedSubmitBar extends StatelessWidget {
  const _UnifiedSubmitBar({
    required this.enabled,
    required this.submitting,
    required this.isFeedbackState,
    required this.onSubmit,
    required this.onNext,
    this.onEndSession,
  });

  final bool enabled;
  final bool submitting;
  final bool isFeedbackState;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onNext;
  final VoidCallback? onEndSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final label = isFeedbackState ? 'Next Question' : 'Submit Answer';
    final buttonColor = isFeedbackState
        ? const Color(0xFF10B981)
        : const Color(0xFF4F46E5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isFeedbackState && onEndSession != null) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                onPressed: onEndSession,
                child: Text(
                  'End Session',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: enabled && !submitting
                      ? buttonColor
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  shadowColor: enabled && !submitting ? buttonColor.withValues(alpha: 0.3) : Colors.transparent,
                  elevation: enabled && !submitting ? 4 : 0,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: enabled && !submitting
                    ? (isFeedbackState ? onNext : onSubmit)
                    : null,
                child: submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: enabled && !submitting
                                  ? Colors.white
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: enabled && !submitting
                                ? Colors.white
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
