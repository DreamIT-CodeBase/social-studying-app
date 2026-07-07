import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Difficulty level for study, revision, and flashcard sessions.
enum SessionLevel {
  beginner,
  intermediate,
  expert,
}

/// Selected session difficulty level, defaults to beginner.
final sessionLevelProvider = StateProvider<SessionLevel>((ref) => SessionLevel.beginner);
