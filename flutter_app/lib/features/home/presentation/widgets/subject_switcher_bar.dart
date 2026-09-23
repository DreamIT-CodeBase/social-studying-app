import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/utils/subject_classifier.dart';
import 'package:social_study_app/features/home/providers/self_study_subject_providers.dart';
import 'package:social_study_app/features/questions/presentation/question_session_notifier.dart';

/// Interactive Subject Switcher Bar for the Self Study Workspace.
///
/// Displays available subjects dynamically extracted from the learner's uploaded
/// materials (Physics, Mathematics, Chemistry, Biology, etc.) with count badges
/// and theme colors.
class SubjectSwitcherBar extends ConsumerWidget {
  const SubjectSwitcherBar({
    required this.workspaceId,
    this.onAddMaterial,
    super.key,
  });

  final String workspaceId;
  final VoidCallback? onAddMaterial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSubject = ref.watch(selfStudySubjectProvider);
    final activeSubcategory = ref.watch(selfStudySubcategoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final counts = ref.watch(selfStudySubjectCountsProvider(workspaceId));
    final subcategories =
        ref.watch(selfStudySubcategoriesProvider(workspaceId));
    final subjects = counts.keys.toList()..sort();
    final totalDocs = counts.values.fold<int>(0, (a, b) => a + b);

    // If no materials uploaded yet, show quick prompt
    if (subjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload study material to organize by subject',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (onAddMaterial != null)
                TextButton(
                  onPressed: onAddMaterial,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Upload',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Subject Chips
                ...subjects.map((subject) {
                  final isSelected =
                      activeSubject?.toLowerCase() == subject.toLowerCase();
                  final count = counts[subject] ?? 0;
                  final color = subjectColor(subject);
                  final emoji = subjectEmoji(subject);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SubjectChip(
                      label: subject,
                      emoji: emoji,
                      count: count,
                      isSelected: isSelected,
                      accentColor: color,
                      onTap: () {
                        ref.read(selfStudySubjectProvider.notifier).state =
                            isSelected ? null : subject;
                        ref.read(selfStudySubcategoryProvider.notifier).state =
                            null;
                        ref.invalidate(
                            questionSessionNotifierProvider(workspaceId));
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          if (activeSubject != null && subcategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Topic Focus ($activeSubject):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  if (activeSubcategory != null)
                    GestureDetector(
                      onTap: () {
                        ref.read(selfStudySubcategoryProvider.notifier).state =
                            null;
                        ref.invalidate(
                            questionSessionNotifierProvider(workspaceId));
                      },
                      child: Text(
                        'Clear Focus',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF818CF8)
                              : const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SubcategoryChip(
                    label: 'All $activeSubject Topics',
                    isSelected: activeSubcategory == null,
                    accentColor: subjectColor(activeSubject),
                    onTap: () {
                      ref.read(selfStudySubcategoryProvider.notifier).state =
                          null;
                      ref.invalidate(
                          questionSessionNotifierProvider(workspaceId));
                    },
                  ),
                  const SizedBox(width: 6),
                  ...subcategories.map((subcat) {
                    final isSubSelected = activeSubcategory?.toLowerCase() ==
                        subcat.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _SubcategoryChip(
                        label: subcat,
                        isSelected: isSubSelected,
                        accentColor: subjectColor(activeSubject),
                        onTap: () {
                          ref
                              .read(selfStudySubcategoryProvider.notifier)
                              .state = isSubSelected ? null : subcat;
                          ref.invalidate(
                              questionSessionNotifierProvider(workspaceId));
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final int count;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? accentColor
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.22)
            : (isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? accentColor
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: accentColor,
                  ),
                  const SizedBox(width: 4.5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : accentColor)
                        : (isDark ? Colors.white60 : const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
