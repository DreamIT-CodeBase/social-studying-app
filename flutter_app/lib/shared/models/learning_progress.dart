class LearningTrendPoint {
  const LearningTrendPoint({
    required this.date,
    required this.overallMastery,
    required this.quizAccuracy,
    required this.flashcardRecall,
    required this.activityCount,
  });

  factory LearningTrendPoint.fromJson(Map<String, dynamic> json) =>
      LearningTrendPoint(
        date: DateTime.parse(json['date'] as String),
        overallMastery: (json['overall_mastery'] as num).toDouble(),
        quizAccuracy: (json['quiz_accuracy'] as num).toDouble(),
        flashcardRecall: (json['flashcard_recall'] as num).toDouble(),
        activityCount: json['activity_count'] as int,
      );

  final DateTime date;
  final double overallMastery;
  final double quizAccuracy;
  final double flashcardRecall;
  final int activityCount;
}

class LearningTrendKpis {
  const LearningTrendKpis({
    required this.overallMastery,
    required this.masteryChange,
    required this.quizAccuracy,
    required this.studentsNeedingAttention,
  });

  factory LearningTrendKpis.fromJson(Map<String, dynamic> json) =>
      LearningTrendKpis(
        overallMastery: (json['overall_mastery'] as num).toDouble(),
        masteryChange: (json['mastery_change'] as num).toDouble(),
        quizAccuracy: (json['quiz_accuracy'] as num).toDouble(),
        studentsNeedingAttention: json['students_needing_attention'] as int,
      );

  final double overallMastery;
  final double masteryChange;
  final double quizAccuracy;
  final int studentsNeedingAttention;
}

class LearningTrendStudent {
  const LearningTrendStudent({
    required this.studentId,
    required this.displayName,
    required this.overallMastery,
    required this.masteryChange,
    required this.quizAccuracy,
    required this.flashcardRecall,
    required this.activityCount,
    required this.needsAttention,
  });

  factory LearningTrendStudent.fromJson(Map<String, dynamic> json) =>
      LearningTrendStudent(
        studentId: json['student_id'] as String,
        displayName: json['display_name'] as String,
        overallMastery: (json['overall_mastery'] as num).toDouble(),
        masteryChange: (json['mastery_change'] as num).toDouble(),
        quizAccuracy: (json['quiz_accuracy'] as num).toDouble(),
        flashcardRecall: (json['flashcard_recall'] as num).toDouble(),
        activityCount: json['activity_count'] as int,
        needsAttention: json['needs_attention'] as bool,
      );

  final String studentId;
  final String displayName;
  final double overallMastery;
  final double masteryChange;
  final double quizAccuracy;
  final double flashcardRecall;
  final int activityCount;
  final bool needsAttention;
}

class LearningProgressTrend {
  const LearningProgressTrend({
    required this.workspaceId,
    required this.scope,
    required this.startDate,
    required this.endDate,
    required this.availableTopics,
    required this.kpis,
    required this.points,
    required this.workspaceComparison,
    required this.students,
    this.studentId,
    this.studentName,
    this.topic,
  });

  factory LearningProgressTrend.fromJson(Map<String, dynamic> json) =>
      LearningProgressTrend(
        workspaceId: json['workspace_id'] as String,
        scope: json['scope'] as String,
        studentId: json['student_id'] as String?,
        studentName: json['student_name'] as String?,
        topic: json['topic'] as String?,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        availableTopics:
            (json['available_topics'] as List<dynamic>).cast<String>(),
        kpis: LearningTrendKpis.fromJson(
          json['kpis'] as Map<String, dynamic>,
        ),
        points: (json['points'] as List<dynamic>)
            .map((item) => LearningTrendPoint.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
        workspaceComparison: (json['workspace_comparison'] as List<dynamic>)
            .map((item) => LearningTrendPoint.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
        students: (json['students'] as List<dynamic>)
            .map((item) => LearningTrendStudent.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(),
      );

  final String workspaceId;
  final String scope;
  final String? studentId;
  final String? studentName;
  final String? topic;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> availableTopics;
  final LearningTrendKpis kpis;
  final List<LearningTrendPoint> points;
  final List<LearningTrendPoint> workspaceComparison;
  final List<LearningTrendStudent> students;
}
