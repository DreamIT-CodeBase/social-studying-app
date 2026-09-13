import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/utils/subject_classifier.dart';
import 'package:social_study_app/features/documents/presentation/documents_notifier.dart';
import 'package:social_study_app/shared/models/document.dart';

/// Active subject category selected in the Self Study workspace (null = All Subjects).
final selfStudySubjectProvider = StateProvider<String?>((ref) => null);

/// Active subcategory/topic/test selected in the Self Study workspace (null = All Topics).
final selfStudySubcategoryProvider = StateProvider<String?>((ref) => null);

/// Active question format selected in the Self Study workspace.
/// null = All Formats, 'mcq' = Multiple Choice, 'short_answer' = Short Answer (one-short).
final selfStudyQuestionTypeProvider = StateProvider<String?>((ref) => null);

/// Mapping of subject name -> ready document count in the self study workspace.
final selfStudySubjectCountsProvider =
    Provider.family<Map<String, int>, String>((ref, workspaceId) {
  final docsAsync = ref.watch(documentsListProvider(workspaceId));
  final docs = docsAsync.valueOrNull ?? const <Document>[];
  final counts = <String, int>{};
  for (final doc in docs) {
    if (doc.status.isUsableForStudy) {
      final subject = subjectForDocument(doc);
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
  }
  return counts;
});

/// List of available distinct subjects for the given self study workspace.
final selfStudyAvailableSubjectsProvider =
    Provider.family<List<String>, String>((ref, workspaceId) {
  final counts = ref.watch(selfStudySubjectCountsProvider(workspaceId));
  final subjects = counts.keys.toList()..sort();
  return subjects;
});

/// List of available subcategories/topics detected from ready documents in the workspace.
/// If an active subject filter is applied, filters topics for that subject;
/// otherwise returns all distinct topics detected across all ready study materials.
final selfStudyAvailableSubcategoriesProvider =
    Provider.family<List<String>, String>((ref, workspaceId) {
  final activeSubject = ref.watch(selfStudySubjectProvider);
  final docsAsync = ref.watch(documentsListProvider(workspaceId));
  final docs = docsAsync.valueOrNull ?? const <Document>[];
  final extractedTopics = <String>{};

  for (final doc in docs) {
    if (!doc.status.isUsableForStudy) continue;

    final matchesSubject = activeSubject == null ||
        subjectForDocument(doc).toLowerCase() == activeSubject.toLowerCase();

    if (matchesSubject) {
      for (final tag in doc.topicTags) {
        final name = tag.name.trim();
        if (name.isNotEmpty) {
          extractedTopics.add(name);
        }
      }
    }
  }

  final sortedTopics = extractedTopics.toList()..sort();
  return sortedTopics;
});
