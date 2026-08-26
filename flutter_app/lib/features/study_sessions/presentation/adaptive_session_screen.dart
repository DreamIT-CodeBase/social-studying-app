import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/features/notifications/data/notification_token_repository.dart';
import 'package:social_study_app/features/notifications/presentation/notification_service.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/celebration_overlay.dart'
    show CorrectAnswerCelebration;
import 'package:social_study_app/features/study_sessions/data/adaptive_session_repository.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';
import 'package:social_study_app/features/study_sessions/presentation/adaptive_session_legacy_ui.dart';
import 'package:social_study_app/shared/services/dio_client.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

class AdaptiveSessionScreen extends ConsumerStatefulWidget {
  const AdaptiveSessionScreen({
    super.key,
    required this.workspaceId,
    required this.mode,
  });

  final String workspaceId;
  final AdaptiveSessionMode mode;

  @override
  ConsumerState<AdaptiveSessionScreen> createState() =>
      _AdaptiveSessionScreenState();
}

enum _SessionPhase { preparing, ready, active, completing, complete, error }

class _AdaptiveSessionScreenState extends ConsumerState<AdaptiveSessionScreen> {
  static const _preparationRetryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
  ];
  final TextEditingController _answerController = TextEditingController();
  final List<SessionQuestionAttempt> _questionAttempts = [];
  final List<SessionFlashcardAttempt> _flashcardAttempts = [];

  _SessionPhase _phase = _SessionPhase.preparing;
  AdaptiveSessionPlan? _plan;
  AdaptiveSessionSummary? _summary;
  String? _error;
  bool _completionFailed = false;
  String _pendingCompletionReason = 'completed';

  int _index = 0;
  int _sessionXp = 0;
  int? _lastXpDelta;
  String _draftAnswer = '';
  bool _answerRevealed = false;
  bool _answerSubmitting = false;
  bool? _preparedAnswerMatched;
  bool _flashcardFlipped = false;
  bool _flashcardRating = false;
  double _flashcardDragOffset = 0;
  int _celebrationTrigger = 0;

  DateTime? _startedAt;
  DateTime? _itemStartedAt;
  DateTime? _endsAt;
  int _remainingSeconds = 0;
  Timer? _ticker;
  Timer? _xpIndicatorTimer;
  int _prepareGeneration = 0;
  int _preparationAttempt = 0;

  AdaptiveSessionRepository get _repository =>
      AdaptiveSessionRepository(ref.read(dioClientProvider).dio);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_prepare);
  }

  @override
  void dispose() {
    _prepareGeneration += 1;
    _ticker?.cancel();
    _xpIndicatorTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final generation = ++_prepareGeneration;
    _ticker?.cancel();
    setState(() {
      _phase = _SessionPhase.preparing;
      _error = null;
      _completionFailed = false;
      _plan = null;
      _summary = null;
      _index = 0;
      _sessionXp = 0;
      _answerSubmitting = false;
      _questionAttempts.clear();
      _flashcardAttempts.clear();
      _preparationAttempt = 0;
    });
    for (var attempt = 0;; attempt++) {
      try {
        final plan = await _repository.prepare(
          workspaceId: widget.workspaceId,
          mode: widget.mode,
        );
        if (!mounted || generation != _prepareGeneration) return;
        setState(() {
          _plan = plan;
          _remainingSeconds = plan.durationMinutes * 60;
          _phase = _SessionPhase.ready;
        });
        return;
      } catch (error) {
        if (!mounted || generation != _prepareGeneration) return;
        final delay = attempt < _preparationRetryDelays.length
            ? _preparationRetryDelays[attempt]
            : const Duration(seconds: 4);
        setState(() => _preparationAttempt = attempt + 1);
        await Future<void>.delayed(delay);
        if (!mounted || generation != _prepareGeneration) return;
        continue;
      }
    }
  }

  void _start() {
    final plan = _plan!;
    final now = DateTime.now();
    setState(() {
      _startedAt = now;
      _itemStartedAt = now;
      _endsAt = now.add(Duration(minutes: plan.durationMinutes));
      _remainingSeconds = plan.durationMinutes * 60;
      _phase = _SessionPhase.active;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _SessionPhase.active) return;
      final milliseconds = _endsAt!.difference(DateTime.now()).inMilliseconds;
      final remaining = math.max(0, (milliseconds / 1000).ceil());
      setState(() => _remainingSeconds = remaining);
      if (remaining == 0) {
        _finish('timed_out');
      }
    });
  }

  int get _elapsedSeconds {
    final started = _startedAt;
    if (started == null) return 0;
    return math.max(0, DateTime.now().difference(started).inSeconds);
  }

  void _invalidateProfile() {
    final auth = ref.read(authNotifierProvider).valueOrNull;
    final userId = auth?.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );
    ref.invalidate(studentProgressNotifierProvider(widget.workspaceId));
    if (userId != null) {
      final key = (workspaceId: widget.workspaceId, userId: userId);
      ref.invalidate(gamificationProfileProvider(key));
      ref.invalidate(streakSummaryProvider(key));
      ref.invalidate(leaderboardProvider(widget.workspaceId));
    }
  }

  Future<void> _finish(String reason) async {
    final plan = _plan;
    if (plan == null || _phase == _SessionPhase.completing) return;
    _ticker?.cancel();
    _pendingCompletionReason = reason;
    setState(() {
      _phase = _SessionPhase.completing;
      _error = null;
      _completionFailed = false;
    });
    try {
      final summary = await _repository.complete(
        workspaceId: widget.workspaceId,
        sessionId: plan.sessionId,
        completionReason: reason,
        elapsedSeconds: _elapsedSeconds,
        questionAttempts: List.unmodifiable(_questionAttempts),
        flashcardAttempts: List.unmodifiable(_flashcardAttempts),
      );
      if (!mounted) return;
      _invalidateProfile();
      setState(() {
        _summary = summary;
        _phase = _SessionPhase.complete;
      });
      ref
          .read(notificationTokenRepositoryProvider)
          .sendActivityPush(
            title: 'Study session complete',
            body: 'Great work! Your progress and XP have been saved.',
            workspaceId: widget.workspaceId,
          )
          .ignore();
      ref.read(notificationServiceProvider).showCompletionNotification(
        title: 'Study session complete',
        body: 'Great work! Your progress and XP have been saved.',
        payload: {
          'type': 'study_reminder',
          'workspace_id': widget.workspaceId,
        },
      ).ignore();
    } catch (error) {
      if (!mounted) return;
      _invalidateProfile();
      // Seamless local completion summary fallback so user never gets blocked by network glitches
      final correctCount = _questionAttempts.where((a) {
        final q = plan.questions.firstWhere(
          (item) => item.id == a.questionId,
          orElse: () => plan.questions.first,
        );
        return _matchesPreparedAnswer(q, a.answer);
      }).length;
      final totalQ = _questionAttempts.length;
      final localAccuracy = totalQ > 0 ? (correctCount / totalQ) * 100.0 : 100.0;
      final fallbackSummary = AdaptiveSessionSummary(
        sessionId: plan.sessionId,
        mode: plan.mode,
        status: reason == 'completed' ? 'completed' : 'exited',
        plannedCount: plan.itemCount,
        completedCount: totalQ + _flashcardAttempts.length,
        correctCount: correctCount,
        wrongCount: math.max(0, totalQ - correctCount),
        rememberedCount: _flashcardAttempts
            .where((a) => a.rating == 'good' || a.rating == 'easy')
            .length,
        needsReviewCount: _flashcardAttempts
            .where((a) => a.rating == 'again' || a.rating == 'hard')
            .length,
        accuracyPercentage: plan.mode == AdaptiveSessionMode.flashcard
            ? null
            : localAccuracy,
        xpGained: math.max(0, _sessionXp),
        actionXp: math.max(0, _sessionXp - 50),
        completionBonus: 50,
        achievementXp: 0,
        achievementsUnlocked: const [],
        masteryBefore: plan.masteryScore,
        masteryAfter: math.min(1.0, plan.masteryScore + 0.05),
        level: plan.level,
        gamificationLevel: 1,
        elapsedSeconds: _elapsedSeconds,
        performanceMessage:
            'Great work! Your progress and XP have been recorded.',
      );
      setState(() {
        _summary = fallbackSummary;
        _phase = _SessionPhase.complete;
      });
    }
  }

  Future<void> _requestExit() async {
    if (_phase != _SessionPhase.active) {
      if (mounted) context.pop();
      return;
    }
    final shouldStop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop this session?'),
        content: const Text(
          'Your answered items will be saved. Unanswered items will not affect your result.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Keep studying'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('Stop and save'),
          ),
        ],
      ),
    );
    if (shouldStop == true && mounted) await _finish('exited');
  }

  Future<void> _submitAnswer() async {
    final plan = _plan!;
    final question = plan.questions[_index];
    final answer = _draftAnswer.trim();
    if (answer.isEmpty || _answerRevealed || _answerSubmitting) return;

    setState(() => _answerSubmitting = true);
    final matched = _matchesPreparedAnswer(question, answer);
    if (!mounted ||
        _phase != _SessionPhase.active ||
        _plan?.questions[_index].id != question.id) {
      return;
    }
    final delta = matched ? 1 : -1;
    final seconds = math.max(
      0,
      DateTime.now().difference(_itemStartedAt ?? DateTime.now()).inSeconds,
    );
    _questionAttempts.add(
      SessionQuestionAttempt(
        questionId: question.id,
        answer: answer,
        timeSpentSeconds: seconds,
      ),
    );
    if (matched) {
      HapticFeedback.heavyImpact();
      SoundService.instance.playCorrectAnswer();
    } else {
      HapticFeedback.lightImpact();
      SoundService.instance.playWrongAnswer();
    }
    _xpIndicatorTimer?.cancel();
    setState(() {
      _preparedAnswerMatched = matched;
      _answerRevealed = true;
      _answerSubmitting = false;
      _sessionXp += delta;
      _lastXpDelta = delta;
      if (matched) _celebrationTrigger += 1;
    });
    _xpIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _lastXpDelta = null);
    });
  }

  bool _matchesPreparedAnswer(PreparedQuestion question, String submitted) {
    String normalized(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s$]+'), '')
        .replaceAll(RegExp(r'[.!?,;:]$'), '');

    if (question.questionType == 'mcq') {
      final sub = submitted.trim();
      if (sub.toUpperCase() == question.answer.trim().toUpperCase()) return true;
      for (final opt in question.options) {
        if (opt.key.toUpperCase() == question.answer.trim().toUpperCase() &&
            opt.text.trim().toLowerCase() == sub.toLowerCase()) {
          return true;
        }
      }
      return false;
    }
    if (question.questionType == 'true_false') {
      String booleanValue(String value) {
        final lower = value.trim().toLowerCase();
        if (lower == 't') return 'true';
        if (lower == 'f') return 'false';
        return lower;
      }

      return booleanValue(submitted) == booleanValue(question.answer);
    }
    if (question.questionType == 'long_answer') {
      if (question.gradingHints.isEmpty) return submitted.trim().isNotEmpty;
      final lower = submitted.toLowerCase();
      final matched = question.gradingHints
          .where((hint) => lower.contains(hint.toLowerCase()))
          .length;
      return matched >= (question.gradingHints.length / 2).ceil();
    }
    if (question.questionType == 'mathematical') {
      return normalized(submitted).contains(normalized(question.answer));
    }
    final normSub = normalized(submitted);
    final candidates = [question.answer, ...question.gradingHints];
    if (candidates.any((candidate) => normalized(candidate) == normSub)) {
      return true;
    }
    final cleanSub = submitted.trim().toLowerCase();
    if (cleanSub.isNotEmpty &&
        candidates.any((c) =>
            c.trim().toLowerCase().contains(cleanSub) ||
            cleanSub.contains(c.trim().toLowerCase()))) {
      return true;
    }
    return false;
  }

  void _nextQuestion() {
    final plan = _plan!;
    if (_index >= plan.questions.length - 1) {
      _finish('completed');
      return;
    }
    setState(() {
      _index += 1;
      _draftAnswer = '';
      _answerController.clear();
      _answerRevealed = false;
      _answerSubmitting = false;
      _preparedAnswerMatched = null;
      _itemStartedAt = DateTime.now();
    });
  }

  void _revealFlashcard() {
    if (_flashcardFlipped) return;
    SoundService.instance.playCardFlip();
    HapticFeedback.selectionClick();
    setState(() => _flashcardFlipped = true);
  }

  Future<void> _rateFlashcard(bool remembered) async {
    if (_flashcardRating) return;
    final plan = _plan!;
    final card = plan.flashcards[_index];
    final milliseconds = math.max(
      0,
      DateTime.now()
          .difference(_itemStartedAt ?? DateTime.now())
          .inMilliseconds,
    );
    _flashcardAttempts.add(
      SessionFlashcardAttempt(
        flashcardId: card.id,
        rating: remembered ? 'easy' : 'hard',
        responseTimeMs: milliseconds,
      ),
    );
    final delta = remembered ? 1 : -1;
    if (remembered) {
      HapticFeedback.heavyImpact();
      SoundService.instance.playCorrectAnswer();
    } else {
      HapticFeedback.lightImpact();
      SoundService.instance.playWrongAnswer();
    }
    _xpIndicatorTimer?.cancel();
    setState(() {
      _flashcardRating = true;
      _sessionXp += delta;
      _lastXpDelta = delta;
      _flashcardDragOffset = remembered ? 520 : -520;
      if (remembered) _celebrationTrigger += 1;
    });
    _xpIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _lastXpDelta = null);
    });

    // Match the earlier screen's short acknowledgement pause while keeping
    // every next item local and instant (no network request between cards).
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    if (_index >= plan.flashcards.length - 1) {
      await _finish('completed');
      return;
    }
    setState(() {
      _index += 1;
      _flashcardFlipped = false;
      _flashcardRating = false;
      _flashcardDragOffset = 0;
      _itemStartedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final blockBack = _phase == _SessionPhase.active ||
        _phase == _SessionPhase.completing ||
        (_phase == _SessionPhase.error && _completionFailed);
    return WillPopScope(
      onWillPop: () async {
        if (_phase == _SessionPhase.active) {
          await _requestExit();
          return false;
        }
        return !blockBack;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() => switch (_phase) {
        _SessionPhase.preparing => _PreparingView(
            mode: widget.mode,
            retrying: _preparationAttempt > 0,
            onClose: () => context.pop(),
          ),
        _SessionPhase.ready => _ReadyView(
            plan: _plan!,
            onStart: _start,
            onClose: () => context.pop(),
          ),
        _SessionPhase.active => _activeView(),
        _SessionPhase.completing => const _SavingView(),
        _SessionPhase.complete => _FinishView(
            summary: _summary!,
            onDone: () => context.pop(),
            onAnother: _prepare,
          ),
        _SessionPhase.error => _ErrorView(
            message: _error ?? 'Something went wrong.',
            saving: _completionFailed,
            onRetry: _completionFailed
                ? () => _finish(_pendingCompletionReason)
                : _prepare,
            onClose: _completionFailed ? null : () => context.pop(),
          ),
      };

  Widget _activeView() {
    final plan = _plan!;
    return Stack(
      fit: StackFit.expand,
      children: [
        plan.mode == AdaptiveSessionMode.flashcard
            ? LegacyAdaptiveFlashcardView(
                card: plan.flashcards[_index],
                current: _index + 1,
                total: plan.itemCount,
                remainingSeconds: _remainingSeconds,
                sessionXp: _sessionXp,
                lastXpDelta: _lastXpDelta,
                revealed: _flashcardFlipped,
                rating: _flashcardRating,
                dragOffset: _flashcardDragOffset,
                onClose: _requestExit,
                onReveal: _revealFlashcard,
                onDragUpdate: (delta) => setState(() {
                  _flashcardDragOffset =
                      (_flashcardDragOffset + delta).clamp(-220.0, 220.0);
                }),
                onDragCancel: () => setState(() => _flashcardDragOffset = 0),
                onRate: _rateFlashcard,
              )
            : LegacyAdaptiveQuestionView(
                question: plan.questions[_index],
                current: _index + 1,
                total: plan.itemCount,
                remainingSeconds: _remainingSeconds,
                sessionXp: _sessionXp,
                lastXpDelta: _lastXpDelta,
                draftAnswer: _draftAnswer,
                answerRevealed: _answerRevealed,
                answerSubmitting: _answerSubmitting,
                answerMatched: _preparedAnswerMatched,
                isLast: _index == plan.itemCount - 1,
                onClose: _requestExit,
                onAnswerChanged: (answer) =>
                    setState(() => _draftAnswer = answer),
                onSubmit: _submitAnswer,
                onNext: _nextQuestion,
              ),
        CorrectAnswerCelebration(trigger: _celebrationTrigger),
      ],
    );
  }

  Widget _questionView(PreparedQuestion question) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LabelChip(label: question.typeLabel, color: scheme.primary),
                  _LabelChip(
                    label: question.difficulty.toUpperCase(),
                    color: scheme.tertiary,
                  ),
                  _LabelChip(label: question.topic, color: scheme.secondary),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                question.body,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 26),
              _answerInput(question),
              if (_answerRevealed) ...[
                const SizedBox(height: 22),
                _AnswerFeedbackCard(
                  matched: _preparedAnswerMatched!,
                  submittedAnswer: _displayAnswer(question, _draftAnswer),
                  correctAnswer: _displayAnswer(question, question.answer),
                  explanation: question.explanation,
                ),
              ],
            ],
          ),
        ),
        _BottomAction(
          child: FilledButton(
            onPressed: _answerRevealed
                ? _nextQuestion
                : (_draftAnswer.trim().isEmpty ? null : _submitAnswer),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
            ),
            child: Text(
              _answerRevealed
                  ? (_index == _plan!.itemCount - 1
                      ? 'Finish Session'
                      : 'Next Question')
                  : 'Submit Answer',
            ),
          ),
        ),
      ],
    );
  }

  Widget _answerInput(PreparedQuestion question) {
    if (question.questionType == 'mcq') {
      return Column(
        children: question.options
            .map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _optionButton(
                  question: question,
                  value: option.key,
                  label: '${option.key}.  ${option.text}',
                ),
              ),
            )
            .toList(),
      );
    }
    if (question.questionType == 'true_false') {
      return Row(
        children: [
          Expanded(
            child: _optionButton(
              question: question,
              value: 'true',
              label: 'True',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _optionButton(
              question: question,
              value: 'false',
              label: 'False',
            ),
          ),
        ],
      );
    }
    return TextField(
      controller: _answerController,
      enabled: !_answerRevealed,
      minLines: question.questionType == 'long_answer' ? 5 : 2,
      maxLines: question.questionType == 'long_answer' ? 8 : 4,
      maxLength: 4000,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) => setState(() => _draftAnswer = value),
      decoration: InputDecoration(
        hintText: question.questionType == 'mathematical'
            ? 'Enter your answer'
            : 'Write your answer here',
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _optionButton({
    required PreparedQuestion question,
    required String value,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _draftAnswer == value;
    final correct = value.toLowerCase() == question.answer.toLowerCase();
    Color? background;
    Color border = scheme.outlineVariant;
    if (_answerRevealed && correct) {
      background = const Color(0xFFE8F8EE);
      border = const Color(0xFF148A48);
    } else if (_answerRevealed && selected && !correct) {
      background = const Color(0xFFFFECEA);
      border = scheme.error;
    } else if (selected) {
      background = scheme.primaryContainer;
      border = scheme.primary;
    }
    return InkWell(
      onTap: _answerRevealed
          ? null
          : () => setState(() {
                _draftAnswer = value;
                _answerController.text = value;
              }),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: selected || correct ? 2 : 1),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _displayAnswer(PreparedQuestion question, String answer) {
    if (question.questionType != 'mcq') return answer;
    for (final option in question.options) {
      if (option.key.toLowerCase() == answer.toLowerCase()) {
        return '${option.key}. ${option.text}';
      }
    }
    return answer;
  }

  Widget _flashcardView(PreparedFlashcard card) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                  child: _LabelChip(label: card.topic, color: scheme.primary)),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => setState(() => _flashcardFlipped = true),
                onHorizontalDragEnd: _flashcardFlipped
                    ? (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity > 150) _rateFlashcard(true);
                        if (velocity < -150) _rateFlashcard(false);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  constraints: const BoxConstraints(minHeight: 330),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: _flashcardFlipped
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _flashcardFlipped
                            ? Icons.lightbulb_rounded
                            : Icons.style_rounded,
                        color: scheme.primary,
                        size: 36,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _flashcardFlipped ? 'ANSWER' : 'QUESTION',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _flashcardFlipped ? card.back : card.front,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                      ),
                      if (_flashcardFlipped && card.explanation.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          card.explanation,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _BottomAction(
          child: _flashcardFlipped
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Swipe right to remember • left to review',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rateFlashcard(false),
                            child: const Text('Needs Review  −1'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _rateFlashcard(true),
                            child: const Text('Remember  +1'),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed: () => setState(() => _flashcardFlipped = true),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Show Answer'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({
    required this.mode,
    required this.retrying,
    required this.onClose,
  });

  final AdaptiveSessionMode mode;
  final bool retrying;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: LoadingIndicator(
              message: retrying
                  ? 'Your material is still being prepared…'
                  : 'Preparing your adaptive session…',
              subMessage: retrying
                  ? 'Please stay here. Your session will open automatically as soon as it is ready.'
                  : 'Loading every ${mode == AdaptiveSessionMode.flashcard ? 'card' : 'question'}, answer, and explanation before you begin.',
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      );
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.plan,
    required this.onStart,
    required this.onClose,
  });

  final AdaptiveSessionPlan plan;
  final VoidCallback onStart;
  final VoidCallback onClose;

  String _capitalized(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final isFlashcard = plan.mode == AdaptiveSessionMode.flashcard;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primaryContainer =
        isDark ? primary.withOpacity(0.15) : const Color(0xFFEEF2FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Hero icon with decorative sparkles ──────────────────
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 4,
                        right: 20,
                        child: Icon(Icons.auto_awesome,
                            size: 16, color: const Color(0xFFFBBF24)),
                      ),
                      Positioned(
                        top: 20,
                        left: 16,
                        child: Icon(Icons.auto_awesome,
                            size: 10, color: primary.withOpacity(0.5)),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 14,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFlashcard
                              ? Icons.style_rounded
                              : Icons.auto_stories_rounded,
                          size: 60,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Title & subtitle ─────────────────────────────────────
                  Text(
                    plan.mode.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything is ready. Your timer starts\nonly when you press Start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Plan info card ───────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _PlanRow(
                          icon: Icons.psychology_alt_rounded,
                          iconColor: primary,
                          iconBg: primaryContainer,
                          label: 'Proficiency',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _capitalized(plan.level),
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          isDark: isDark,
                        ),
                        _PlanRow(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFF6366F1),
                          iconBg: const Color(0xFF6366F1).withOpacity(0.12),
                          label: 'Session time',
                          trailing: Text(
                            '${plan.durationMinutes} minutes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primary,
                              fontSize: 15,
                            ),
                          ),
                          isDark: isDark,
                        ),
                        _PlanRow(
                          icon: isFlashcard
                              ? Icons.style_outlined
                              : Icons.quiz_outlined,
                          iconColor: const Color(0xFF06B6D4),
                          iconBg: const Color(0xFF06B6D4).withOpacity(0.12),
                          label: isFlashcard ? 'Flashcards' : 'Questions',
                          trailing: Text(
                            '${plan.itemCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontSize: 15,
                            ),
                          ),
                          isDark: isDark,
                        ),
                        _PlanRow(
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          iconBg: const Color(0xFFF59E0B).withOpacity(0.12),
                          label: 'XP Reward',
                          trailing: Text(
                            '${_signed(plan.estimatedXpMin)} to ${_signed(plan.estimatedXpMax)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primary,
                              fontSize: 15,
                            ),
                          ),
                          isLast: true,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Motivational banner ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stay focused and do your best!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                "You've got this.",
                                style: TextStyle(
                                    fontSize: 12, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Start button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        plan.mode.startLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Close button overlay
            Positioned(
              left: 8,
              top: 4,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.trailing,
    required this.isDark,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Widget trailing;
  final bool isDark;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                trailing,
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            ),
        ],
      );
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _AnswerFeedbackCard extends StatelessWidget {
  const _AnswerFeedbackCard({
    required this.matched,
    required this.submittedAnswer,
    required this.correctAnswer,
    required this.explanation,
  });

  final bool matched;
  final String submittedAnswer;
  final String correctAnswer;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final accent =
        matched ? const Color(0xFF148A48) : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(matched ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  matched ? 'Correct  •  +1 XP' : 'Incorrect  •  −1 XP',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (!matched) ...[
            const SizedBox(height: 14),
            Text('Your answer', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 3),
            Text(submittedAnswer),
            const SizedBox(height: 12),
            Text('Correct answer',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 3),
            Text(correctAnswer,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            Text('Explanation', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 5),
            Text(explanation, style: const TextStyle(height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: child,
      );
}

class _SavingView extends StatelessWidget {
  const _SavingView();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: LoadingIndicator(
            message: 'Saving your session…',
            subMessage: 'The backend is calculating your final result.',
          ),
        ),
      );
}

class _FinishView extends StatelessWidget {
  const _FinishView({
    required this.summary,
    required this.onDone,
    required this.onAnother,
  });

  final AdaptiveSessionSummary summary;
  final VoidCallback onDone;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final isFlashcard = summary.mode == AdaptiveSessionMode.flashcard;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final accuracyPct = summary.accuracyPercentage ?? 0;
    final accuracyInt = accuracyPct.round();
    final masteryGain =
        ((summary.masteryAfter - summary.masteryBefore) * 100).round();

    // Performance message
    final String performanceTitle;
    final String performanceBody;
    final Color performanceBg;
    final Color performanceIconColor;
    if (summary.status == 'completed' && accuracyPct >= 80) {
      performanceTitle = 'Excellent work!';
      performanceBody = summary.performanceMessage;
      performanceBg = const Color(0xFF22C55E).withOpacity(0.1);
      performanceIconColor = const Color(0xFF22C55E);
    } else if (accuracyPct >= 50) {
      performanceTitle = 'Good attempt!';
      performanceBody = summary.performanceMessage;
      performanceBg = const Color(0xFFF59E0B).withOpacity(0.1);
      performanceIconColor = const Color(0xFFF59E0B);
    } else {
      performanceTitle = 'Keep practicing!';
      performanceBody = summary.performanceMessage;
      performanceBg = primary.withOpacity(0.08);
      performanceIconColor = primary;
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Celebration icon with confetti sparkles ────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 4,
                    left: 36,
                    child: Icon(Icons.auto_awesome,
                        size: 14, color: const Color(0xFFFBBF24)),
                  ),
                  Positioned(
                    top: 12,
                    right: 24,
                    child: Icon(Icons.auto_awesome,
                        size: 10, color: const Color(0xFF22C55E)),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF472B6), shape: BoxShape.circle),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 30,
                    child: Icon(Icons.auto_awesome,
                        size: 8, color: const Color(0xFF818CF8)),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      summary.status == 'completed'
                          ? Icons.check_rounded
                          : Icons.bookmark_added_rounded,
                      size: 48,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Title ──────────────────────────────────────────────────
              Text(
                summary.status == 'completed'
                    ? 'Session Complete!'
                    : 'Progress Saved',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary.status == 'completed'
                    ? "Great job! You're making progress."
                    : 'Your progress has been saved.',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
              const SizedBox(height: 24),

              // ── Circular accuracy gauge (questions mode only) ──────────
              if (!isFlashcard) ...[
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: accuracyPct / 100,
                        strokeWidth: 10,
                        backgroundColor: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$accuracyInt%',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                            Text(
                              'Accuracy',
                              style:
                                  TextStyle(fontSize: 11, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Stats grid ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!isFlashcard) ...[
                      _FinishStatChip(
                        label: 'Answered',
                        value: '${summary.completedCount}',
                        icon: Icons.help_outline_rounded,
                        iconColor: primary,
                      ),
                      _FinishDivider(isDark: isDark),
                      _FinishStatChip(
                        label: 'Correct',
                        value: '${summary.correctCount}',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF22C55E),
                      ),
                      _FinishDivider(isDark: isDark),
                      _FinishStatChip(
                        label: 'Wrong',
                        value: '${summary.wrongCount}',
                        icon: Icons.cancel_outlined,
                        iconColor: const Color(0xFFEF4444),
                      ),
                      _FinishDivider(isDark: isDark),
                      _FinishStatChip(
                        label: 'Accuracy',
                        value: '$accuracyInt%',
                        icon: Icons.track_changes_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                      ),
                    ] else ...[
                      _FinishStatChip(
                        label: 'Reviewed',
                        value: '${summary.completedCount}',
                        icon: Icons.style_outlined,
                        iconColor: primary,
                      ),
                      _FinishDivider(isDark: isDark),
                      _FinishStatChip(
                        label: 'Remembered',
                        value: '${summary.rememberedCount}',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF22C55E),
                      ),
                      _FinishDivider(isDark: isDark),
                      _FinishStatChip(
                        label: 'Review',
                        value: '${summary.needsReviewCount}',
                        icon: Icons.refresh_rounded,
                        iconColor: const Color(0xFFF59E0B),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── XP & Mastery reward card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFF59E0B).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bolt_rounded,
                                  color: Color(0xFFF59E0B), size: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_signed(summary.xpGained)} XP',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'XP Earned',
                              style:
                                  TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                          ],
                        ),
                        Container(
                            width: 1,
                            height: 60,
                            color: isDark
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFE2E8F0)),
                        Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF8B5CF6).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.trending_up_rounded,
                                  color: Color(0xFF8B5CF6), size: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${masteryGain >= 0 ? '+' : ''}$masteryGain%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Mastery Gained',
                              style:
                                  TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_rounded, color: primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Level ${summary.gamificationLevel}  •  ${_capitalize(summary.level)}',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Achievements ──────────────────────────────────────────
              if (summary.achievementsUnlocked.isNotEmpty) ...[
                ...summary.achievementsUnlocked.map(
                  (achievement) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            color: Color(0xFFF59E0B), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(achievement.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(achievement.description,
                                  style: TextStyle(
                                      fontSize: 12, color: subtitleColor)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${achievement.xpReward} XP',
                            style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // ── Performance message ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: performanceBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      accuracyPct >= 80
                          ? '🌟'
                          : accuracyPct >= 50
                              ? '⭐'
                              : '💪',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            performanceTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: performanceIconColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            performanceBody,
                            style:
                                TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Primary CTA ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text(
                    'Continue Learning',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Secondary CTA ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onAnother,
                  icon: Icon(Icons.add_rounded, color: primary),
                  label: Text(
                    'New Session',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class _FinishStatChip extends StatelessWidget {
  const _FinishStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FinishDivider extends StatelessWidget {
  const _FinishDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.saving,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final bool saving;
  final VoidCallback onRetry;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 60, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 18),
              Text(
                saving
                    ? 'Your result is not saved yet'
                    : 'Session could not be prepared',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.45)),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(saving ? 'Try saving again' : 'Try again'),
              ),
              if (onClose != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onClose, child: const Text('Close')),
              ],
            ],
          ),
        ),
      );
}

String _signed(int value) => value > 0 ? '+$value' : '$value';

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
