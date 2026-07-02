import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusTopicNotifier extends StateNotifier<String?> {
  FocusTopicNotifier(this._workspaceId) : super(null) {
    _load();
  }

  final String _workspaceId;

  String get _key => 'focus_topic_$_workspaceId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> setFocusTopic(String? topicId) async {
    state = topicId;
    final prefs = await SharedPreferences.getInstance();
    if (topicId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, topicId);
    }
  }
}

final focusTopicProvider = StateNotifierProvider.family<FocusTopicNotifier, String?, String>((ref, workspaceId) {
  return FocusTopicNotifier(workspaceId);
});
