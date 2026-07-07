import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'dart:convert';

/// A service to track user local analytics: recall score and study time spent per topic.
class RecallService {
  RecallService._();
  static final RecallService instance = RecallService._();

  static const String _recallScoresKey = 'local_recall_scores_list';
  static const String _timeSpentKey = 'local_time_spent_by_topic_map';
  static const String _questionsCountKey = 'local_questions_answered_count';

  /// Calculate the recall score (0 to 100) based on rating and time spent (in milliseconds).
  int calculateRecallScore(FlashcardRating rating, int durationMs) {
    final seconds = durationMs / 1000.0;
    if (rating == FlashcardRating.easy) {
      return (100 - (seconds * 2.5)).clamp(60, 100).round();
    } else if (rating == FlashcardRating.medium) {
      return (80 - (seconds * 2.0)).clamp(40, 80).round();
    } else {
      return (40 - (seconds * 1.5)).clamp(10, 40).round();
    }
  }

  /// Records a new recall event and time spent on a topic.
  Future<void> recordCardReview({
    required String topic,
    required FlashcardRating rating,
    required int durationMs,
  }) async {
    final score = calculateRecallScore(rating, durationMs);
    final prefs = await SharedPreferences.getInstance();

    // 1. Save recall score to list
    final List<String> rawScores = prefs.getStringList(_recallScoresKey) ?? [];
    rawScores.add(score.toString());
    // Keep last 200 reviews to avoid excessive storage growth
    if (rawScores.length > 200) {
      rawScores.removeAt(0);
    }
    await prefs.setStringList(_recallScoresKey, rawScores);

    // 2. Save time spent on topic
    final seconds = (durationMs / 1000).ceil();
    final String rawTimeSpent = prefs.getString(_timeSpentKey) ?? '{}';
    Map<String, dynamic> timeMap = {};
    try {
      timeMap = jsonDecode(rawTimeSpent) as Map<String, dynamic>;
    } catch (_) {}
    
    final currentVal = timeMap[topic] as int? ?? 0;
    timeMap[topic] = currentVal + seconds;
    await prefs.setString(_timeSpentKey, jsonEncode(timeMap));
  }

  /// Records time spent answering a question on a topic.
  Future<void> recordQuestionAnswered({
    required String topic,
    required int durationMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Increment total questions answered count
    final count = prefs.getInt(_questionsCountKey) ?? 0;
    await prefs.setInt(_questionsCountKey, count + 1);

    // Save time spent on topic
    final seconds = (durationMs / 1000).ceil();
    final String rawTimeSpent = prefs.getString(_timeSpentKey) ?? '{}';
    Map<String, dynamic> timeMap = {};
    try {
      timeMap = jsonDecode(rawTimeSpent) as Map<String, dynamic>;
    } catch (_) {}
    
    final currentVal = timeMap[topic] as int? ?? 0;
    timeMap[topic] = currentVal + seconds;
    await prefs.setString(_timeSpentKey, jsonEncode(timeMap));
  }

  /// Get the average recall score (defaults to 85% if no records yet).
  Future<int> getAverageRecallScore() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawScores = prefs.getStringList(_recallScoresKey) ?? [];
    if (rawScores.isEmpty) return 85; // Default average fallback

    final sum = rawScores.fold<int>(0, (prev, element) => prev + (int.tryParse(element) ?? 0));
    return (sum / rawScores.length).round();
  }

  /// Get time spent by topic in seconds.
  Future<Map<String, int>> getTimeSpentByTopic() async {
    final prefs = await SharedPreferences.getInstance();
    final String rawTimeSpent = prefs.getString(_timeSpentKey) ?? '{}';
    try {
      final Map<String, dynamic> decoded = jsonDecode(rawTimeSpent) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (_) {
      return {};
    }
  }

  /// Get total questions answered locally.
  Future<int> getQuestionsAnsweredCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_questionsCountKey) ?? 0;
  }
}
