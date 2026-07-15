enum AdaptiveSessionMode { study, revision, flashcard }

AdaptiveSessionMode adaptiveSessionModeFromWire(String? value) =>
    switch (value) {
      'revision' => AdaptiveSessionMode.revision,
      'flashcard' => AdaptiveSessionMode.flashcard,
      _ => AdaptiveSessionMode.study,
    };

extension AdaptiveSessionModeView on AdaptiveSessionMode {
  String get wire => name;

  String get title => switch (this) {
        AdaptiveSessionMode.study => 'Study Session',
        AdaptiveSessionMode.revision => 'Quick Revision',
        AdaptiveSessionMode.flashcard => 'Flashcard Session',
      };

  String get startLabel => switch (this) {
        AdaptiveSessionMode.study => 'Start Study Session',
        AdaptiveSessionMode.revision => 'Start Revision Session',
        AdaptiveSessionMode.flashcard => 'Start Flashcard Session',
      };
}

class PreparedOption {
  const PreparedOption({required this.key, required this.text});

  factory PreparedOption.fromJson(Map<String, dynamic> json) => PreparedOption(
        key: json['key'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  final String key;
  final String text;
}

class PreparedQuestion {
  const PreparedQuestion({
    required this.id,
    required this.topic,
    required this.questionType,
    required this.difficulty,
    required this.body,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.gradingHints,
  });

  factory PreparedQuestion.fromJson(Map<String, dynamic> json) =>
      PreparedQuestion(
        id: json['id'] as String? ?? '',
        topic: json['topic'] as String? ?? '',
        questionType: json['question_type'] as String? ?? 'short_answer',
        difficulty: json['difficulty'] as String? ?? 'beginner',
        body: json['body'] as String? ?? '',
        options: (json['options'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PreparedOption.fromJson)
            .toList(growable: false),
        answer: json['answer'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        gradingHints: (json['grading_hints'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  final String id;
  final String topic;
  final String questionType;
  final String difficulty;
  final String body;
  final List<PreparedOption> options;
  final String answer;
  final String explanation;
  final List<String> gradingHints;

  String get typeLabel => switch (questionType) {
        'mcq' => 'MULTIPLE CHOICE',
        'true_false' => 'TRUE OR FALSE',
        'long_answer' => 'LONG ANSWER',
        'mathematical' => 'MATHEMATICAL',
        _ => 'SHORT ANSWER',
      };
}

class PreparedFlashcard {
  const PreparedFlashcard({
    required this.id,
    required this.topic,
    required this.front,
    required this.back,
    required this.explanation,
  });

  factory PreparedFlashcard.fromJson(Map<String, dynamic> json) =>
      PreparedFlashcard(
        id: json['id'] as String? ?? '',
        topic: json['topic'] as String? ?? '',
        front: json['front'] as String? ?? '',
        back: json['back'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
      );

  final String id;
  final String topic;
  final String front;
  final String back;
  final String explanation;
}

class AdaptiveSessionPlan {
  const AdaptiveSessionPlan({
    required this.sessionId,
    required this.mode,
    required this.level,
    required this.masteryScore,
    required this.durationMinutes,
    required this.itemCount,
    required this.estimatedXpMin,
    required this.estimatedXpMax,
    required this.questions,
    required this.flashcards,
  });

  factory AdaptiveSessionPlan.fromJson(Map<String, dynamic> json) =>
      AdaptiveSessionPlan(
        sessionId: json['session_id'] as String? ?? '',
        mode: adaptiveSessionModeFromWire(json['mode'] as String?),
        level: json['level'] as String? ?? 'beginner',
        masteryScore: (json['mastery_score'] as num?)?.toDouble() ?? 0,
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 15,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        estimatedXpMin: (json['estimated_xp_min'] as num?)?.toInt() ?? 0,
        estimatedXpMax: (json['estimated_xp_max'] as num?)?.toInt() ?? 0,
        questions: (json['questions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PreparedQuestion.fromJson)
            .toList(growable: false),
        flashcards: (json['flashcards'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PreparedFlashcard.fromJson)
            .toList(growable: false),
      );

  final String sessionId;
  final AdaptiveSessionMode mode;
  final String level;
  final double masteryScore;
  final int durationMinutes;
  final int itemCount;
  final int estimatedXpMin;
  final int estimatedXpMax;
  final List<PreparedQuestion> questions;
  final List<PreparedFlashcard> flashcards;
}

class SessionQuestionAttempt {
  const SessionQuestionAttempt({
    required this.questionId,
    required this.answer,
    required this.timeSpentSeconds,
  });

  final String questionId;
  final String answer;
  final int timeSpentSeconds;

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'answer': answer,
        'time_spent_seconds': timeSpentSeconds,
      };
}

class AdaptiveAnswerEvaluation {
  const AdaptiveAnswerEvaluation({
    required this.isCorrect,
    required this.canonicalAnswer,
    required this.rubricScore,
    required this.matchedHints,
  });

  factory AdaptiveAnswerEvaluation.fromJson(Map<String, dynamic> json) =>
      AdaptiveAnswerEvaluation(
        isCorrect: json['is_correct'] as bool? ?? false,
        canonicalAnswer: json['canonical_answer'] as String? ?? '',
        rubricScore: (json['rubric_score'] as num?)?.toDouble(),
        matchedHints: (json['matched_hints'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  final bool isCorrect;
  final String canonicalAnswer;
  final double? rubricScore;
  final List<String> matchedHints;
}

class SessionFlashcardAttempt {
  const SessionFlashcardAttempt({
    required this.flashcardId,
    required this.rating,
    required this.responseTimeMs,
  });

  final String flashcardId;
  final String rating;
  final int responseTimeMs;

  Map<String, dynamic> toJson() => {
        'flashcard_id': flashcardId,
        'rating': rating,
        'response_time_ms': responseTimeMs,
      };
}

class AdaptiveSessionSummary {
  const AdaptiveSessionSummary({
    required this.sessionId,
    required this.mode,
    required this.status,
    required this.plannedCount,
    required this.completedCount,
    required this.correctCount,
    required this.wrongCount,
    required this.rememberedCount,
    required this.needsReviewCount,
    required this.accuracyPercentage,
    required this.xpGained,
    required this.actionXp,
    required this.completionBonus,
    required this.achievementXp,
    required this.achievementsUnlocked,
    required this.masteryBefore,
    required this.masteryAfter,
    required this.level,
    required this.gamificationLevel,
    required this.elapsedSeconds,
    required this.performanceMessage,
  });

  factory AdaptiveSessionSummary.fromJson(Map<String, dynamic> json) =>
      AdaptiveSessionSummary(
        sessionId: json['session_id'] as String? ?? '',
        mode: adaptiveSessionModeFromWire(json['mode'] as String?),
        status: json['status'] as String? ?? 'completed',
        plannedCount: (json['planned_count'] as num?)?.toInt() ?? 0,
        completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
        correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
        wrongCount: (json['wrong_count'] as num?)?.toInt() ?? 0,
        rememberedCount: (json['remembered_count'] as num?)?.toInt() ?? 0,
        needsReviewCount: (json['needs_review_count'] as num?)?.toInt() ?? 0,
        accuracyPercentage: (json['accuracy_percentage'] as num?)?.toDouble(),
        xpGained: (json['xp_gained'] as num?)?.toInt() ?? 0,
        actionXp: (json['action_xp'] as num?)?.toInt() ?? 0,
        completionBonus: (json['completion_bonus'] as num?)?.toInt() ?? 0,
        achievementXp: (json['achievement_xp'] as num?)?.toInt() ?? 0,
        achievementsUnlocked:
            (json['achievements_unlocked'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(SessionAchievementUnlock.fromJson)
                .toList(growable: false),
        masteryBefore: (json['mastery_before'] as num?)?.toDouble() ?? 0,
        masteryAfter: (json['mastery_after'] as num?)?.toDouble() ?? 0,
        level: json['level'] as String? ?? 'beginner',
        gamificationLevel: (json['gamification_level'] as num?)?.toInt() ?? 1,
        elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
        performanceMessage: json['performance_message'] as String? ?? '',
      );

  final String sessionId;
  final AdaptiveSessionMode mode;
  final String status;
  final int plannedCount;
  final int completedCount;
  final int correctCount;
  final int wrongCount;
  final int rememberedCount;
  final int needsReviewCount;
  final double? accuracyPercentage;
  final int xpGained;
  final int actionXp;
  final int completionBonus;
  final int achievementXp;
  final List<SessionAchievementUnlock> achievementsUnlocked;
  final double masteryBefore;
  final double masteryAfter;
  final String level;
  final int gamificationLevel;
  final int elapsedSeconds;
  final String performanceMessage;
}

class SessionAchievementUnlock {
  const SessionAchievementUnlock({
    required this.name,
    required this.description,
    required this.xpReward,
  });

  factory SessionAchievementUnlock.fromJson(Map<String, dynamic> json) =>
      SessionAchievementUnlock(
        name: json['name'] as String? ?? 'Achievement',
        description: json['description'] as String? ?? '',
        xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final String description;
  final int xpReward;
}
