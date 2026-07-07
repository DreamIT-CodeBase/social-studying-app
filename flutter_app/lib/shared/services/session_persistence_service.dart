import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle persistence of workspace, tab, topic, chapter, lesson,
/// active session questions/cards, and filters across application restarts.
class SessionPersistenceService {
  SessionPersistenceService._();
  static final SessionPersistenceService instance = SessionPersistenceService._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getWorkspaceSync() => _prefs?.getString(_keyWorkspace);
  int? getTabSync() => _prefs?.getInt(_keyTab);
  String? getChapterSync() => _prefs?.getString(_keyChapter);
  String? getTopicSync() => _prefs?.getString(_keyTopic);
  String? getLessonSync() => _prefs?.getString(_keyLesson);
  String? getQuestionIdSync() => _prefs?.getString(_keyQuestion);
  String? getFlashcardIdSync() => _prefs?.getString(_keyFlashcard);
  double? getScrollPositionSync() => _prefs?.getDouble(_keyScroll);

  Map<String, dynamic>? getFiltersSync() {
    final raw = _prefs?.getString(_keyFilters);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? getSessionProgressSync() {
    final raw = _prefs?.getString(_keyProgress);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static const String _keyWorkspace = 'persisted_workspace_id';
  static const String _keyTab = 'persisted_tab_index';
  static const String _keyChapter = 'persisted_chapter';
  static const String _keyTopic = 'persisted_topic';
  static const String _keyLesson = 'persisted_lesson';
  static const String _keyQuestion = 'persisted_question_id';
  static const String _keyFlashcard = 'persisted_flashcard_id';
  static const String _keyScroll = 'persisted_scroll_position';
  static const String _keyFilters = 'persisted_filters';
  static const String _keyProgress = 'persisted_session_progress';

  Future<void> saveWorkspace(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWorkspace, workspaceId);
  }

  Future<String?> getWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWorkspace);
  }

  Future<void> saveTab(int tabIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTab, tabIndex);
  }

  Future<int?> getTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTab);
  }

  Future<void> saveChapter(String chapter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChapter, chapter);
  }

  Future<String?> getChapter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyChapter);
  }

  Future<void> saveTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTopic, topic);
  }

  Future<String?> getTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTopic);
  }

  Future<void> saveLesson(String lesson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLesson, lesson);
  }

  Future<String?> getLesson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLesson);
  }

  Future<void> saveQuestionId(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuestion, questionId);
  }

  Future<String?> getQuestionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQuestion);
  }

  Future<void> saveFlashcardId(String flashcardId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFlashcard, flashcardId);
  }

  Future<String?> getFlashcardId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFlashcard);
  }

  Future<void> saveScrollPosition(double position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScroll, position);
  }

  Future<double?> getScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyScroll);
  }

  Future<void> saveFilters(Map<String, dynamic> filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFilters, json.encode(filters));
  }

  Future<Map<String, dynamic>?> getFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFilters);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSessionProgress(Map<String, dynamic> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProgress, json.encode(progress));
  }

  Future<Map<String, dynamic>?> getSessionProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProgress);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWorkspace);
    await prefs.remove(_keyTab);
    await prefs.remove(_keyChapter);
    await prefs.remove(_keyTopic);
    await prefs.remove(_keyLesson);
    await prefs.remove(_keyQuestion);
    await prefs.remove(_keyFlashcard);
    await prefs.remove(_keyScroll);
    await prefs.remove(_keyFilters);
    await prefs.remove(_keyProgress);
  }
}
