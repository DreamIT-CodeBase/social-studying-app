import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/celebration_overlay.dart'
    show CorrectAnswerCelebration;
import 'package:social_study_app/features/study_sessions/data/adaptive_session_repository.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';
import 'package:social_study_app/features/study_sessions/presentation/adaptive_session_legacy_ui.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

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

class _AdaptiveSessionScreenState
    extends ConsumerState<AdaptiveSessionScreen> {
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

  AdaptiveSessionRepository get _repository =>
      AdaptiveSessionRepository(ref.read(dioClientProvider).dio);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_prepare);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _xpIndicatorTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    _ticker?.cancel();
    setState(() {
      _phase = _SessionPhase.preparing;
      _error = null;
      _completionFailed = false;
      _plan = null;
      _summary = null;
      _index = 0;
      _sessionXp = 0;
      _questionAttempts.clear();
      _flashcardAttempts.clear();
    });
    try {
      final plan = await _repository.prepare(
        workspaceId: widget.workspaceId,
        mode: widget.mode,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _remainingSeconds = plan.durationMinutes * 60;
        _phase = _SessionPhase.ready;
      });
    } on AdaptiveSessionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _phase = _SessionPhase.error;
      });
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
      if (remaining == 0) {
        _ticker?.cancel();
        _finish('timed_out');
      } else {
        setState(() => _remainingSeconds = remaining);
      }
    });
  }

  int get _elapsedSeconds {
    final started = _startedAt;
    if (started == null) return 0;
    return math.max(0, DateTime.now().difference(started).inSeconds);
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
      setState(() {
        _summary = summary;
        _phase = _SessionPhase.complete;
      });
    } on AdaptiveSessionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _completionFailed = true;
        _phase = _SessionPhase.error;
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

  void _submitAnswer() {
    final plan = _plan!;
    final question = plan.questions[_index];
    final answer = _draftAnswer.trim();
    if (answer.isEmpty || _answerRevealed) return;

    final matched = _matchesPreparedAnswer(question, answer);
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
      return submitted.trim().toUpperCase() == question.answer.trim().toUpperCase();
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
    final candidates = [question.answer, ...question.gradingHints];
    return candidates.any((candidate) => normalized(candidate) == normalized(submitted));
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
      DateTime.now().difference(_itemStartedAt ?? DateTime.now()).inMilliseconds,
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
                onDragCancel: () =>
                    setState(() => _flashcardDragOffset = 0),
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
              Center(child: _LabelChip(label: card.topic, color: scheme.primary)),
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                      ),
                      if (_flashcardFlipped && card.explanation.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          card.explanation,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
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
  const _PreparingView({required this.mode, required this.onClose});

  final AdaptiveSessionMode mode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(strokeWidth: 5),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Preparing your adaptive session…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Loading every ${mode == AdaptiveSessionMode.flashcard ? 'card' : 'question'}, answer, and explanation before you begin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 4,
            child: IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
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
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 72, 24, 28),
          children: [
            Icon(
              isFlashcard ? Icons.style_rounded : Icons.auto_stories_rounded,
              size: 66,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              plan.mode.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Everything is ready. Your timer starts only when you press Start.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _PlanRow(
                      icon: Icons.psychology_alt_rounded,
                      label: 'Proficiency',
                      value: _capitalized(plan.level),
                    ),
                    _PlanRow(
                      icon: Icons.timer_outlined,
                      label: 'Session time',
                      value: '${plan.durationMinutes} minutes',
                    ),
                    _PlanRow(
                      icon: isFlashcard
                          ? Icons.style_outlined
                          : Icons.quiz_outlined,
                      label: isFlashcard ? 'Flashcards' : 'Questions',
                      value: '${plan.itemCount}',
                    ),
                    _PlanRow(
                      icon: Icons.bolt_rounded,
                      label: 'XP',
                      value:
                          '${_signed(plan.estimatedXpMin)} to ${_signed(plan.estimatedXpMax)}',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(plan.mode.startLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Positioned(
          left: 8,
          top: 4,
          child: IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(child: Text(label)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (!isLast) const Divider(height: 1),
        ],
      );
}

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({
    required this.current,
    required this.total,
    required this.remainingSeconds,
    required this.sessionXp,
    required this.showXp,
    required this.lastXpDelta,
    required this.onClose,
  });

  final int current;
  final int total;
  final int remainingSeconds;
  final int sessionXp;
  final bool showXp;
  final int? lastXpDelta;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final urgent = remainingSeconds <= 60;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Stop session',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    '$current of $total',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _HeaderPill(
                  icon: Icons.timer_outlined,
                  text: '$minutes:${seconds.toString().padLeft(2, '0')}',
                  color: urgent
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                if (showXp) ...[
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _HeaderPill(
                        icon: Icons.bolt_rounded,
                        text: '${_signed(sessionXp)} XP',
                        color: sessionXp < 0
                            ? Theme.of(context).colorScheme.error
                            : const Color(0xFF148A48),
                      ),
                      Positioned(
                        right: 4,
                        top: -18,
                        child: AnimatedOpacity(
                          opacity: lastXpDelta == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            '${_signed(lastXpDelta ?? 0)} XP',
                            style: TextStyle(
                              color: (lastXpDelta ?? 0) < 0
                                  ? Theme.of(context).colorScheme.error
                                  : const Color(0xFF148A48),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (current - 1) / total,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
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
    final accent = matched
        ? const Color(0xFF148A48)
        : Theme.of(context).colorScheme.error;
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
              Icon(matched ? Icons.check_circle_rounded : Icons.cancel_rounded, color: accent),
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
            Text('Correct answer', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 3),
            Text(correctAnswer, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: child,
      );
}

class _SavingView extends StatelessWidget {
  const _SavingView();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Saving your session…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'The backend is calculating your final result.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 28),
        Icon(
          summary.status == 'completed'
              ? Icons.celebration_rounded
              : Icons.bookmark_added_rounded,
          size: 70,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          summary.status == 'completed' ? 'Session Complete!' : 'Progress Saved',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryTile(
              label: isFlashcard ? 'Cards reviewed' : 'Answered',
              value: '${summary.completedCount}',
            ),
            if (!isFlashcard) ...[
              _SummaryTile(label: 'Correct', value: '${summary.correctCount}'),
              _SummaryTile(label: 'Wrong', value: '${summary.wrongCount}'),
              _SummaryTile(
                label: 'Accuracy',
                value: '${summary.accuracyPercentage?.toStringAsFixed(1) ?? '0.0'}%',
              ),
            ] else ...[
              _SummaryTile(label: 'Remembered', value: '${summary.rememberedCount}'),
              _SummaryTile(label: 'Needs review', value: '${summary.needsReviewCount}'),
            ],
            _SummaryTile(label: 'XP gained', value: '${_signed(summary.xpGained)} XP'),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _BreakdownRow(label: 'Learning actions', value: summary.actionXp),
                _BreakdownRow(label: 'Session completion', value: summary.completionBonus),
                _BreakdownRow(label: 'Achievements', value: summary.achievementXp),
              ],
            ),
          ),
        ),
        if (summary.achievementsUnlocked.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...summary.achievementsUnlocked.map(
            (achievement) => ListTile(
              leading: const Icon(Icons.emoji_events_rounded),
              title: Text(achievement.name),
              subtitle: Text(achievement.description),
              trailing: Text('+${achievement.xpReward} XP'),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mastery', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                Text(
                  '${(summary.masteryBefore * 100).round()}%  →  ${(summary.masteryAfter * 100).round()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Adaptive level: ${_capitalize(summary.level)}  •  App level ${summary.gamificationLevel}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(summary.performanceMessage, style: const TextStyle(height: 1.4)),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          child: const Text('Done'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onAnother, child: const Text('Prepare another session')),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text('${_signed(value)} XP', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: (MediaQuery.sizeOf(context).width - 58) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
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
              Icon(Icons.cloud_off_rounded, size: 60, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 18),
              Text(
                saving ? 'Your result is not saved yet' : 'Session could not be prepared',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
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
