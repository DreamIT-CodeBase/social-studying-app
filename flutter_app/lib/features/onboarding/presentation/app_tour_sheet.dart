import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

/// A modal onboarding walkthrough that explains how the learning platform works:
/// material uploads, strict question formats, active recall flashcards, and progress/screen time tracking.
/// Shown only once to new users, with an instant "Skip" option.
class AppTourSheet extends StatefulWidget {
  const AppTourSheet({
    super.key,
    required this.userId,
    this.onComplete,
  });

  final String userId;
  final VoidCallback? onComplete;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    VoidCallback? onComplete,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (sheetContext) => AppTourSheet(
        userId: userId,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<AppTourSheet> createState() => _AppTourSheetState();
}

class _AppTourSheetState extends State<AppTourSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_TourSlideData> _slides = const [
    _TourSlideData(
      icon: Icons.cloud_upload_rounded,
      badgeText: 'STEP 1',
      badgeColor: Color(0xFF6366F1),
      title: 'Upload Study Materials',
      subtitle:
          'Add your lecture slides, notes, PDFs, or handwritten pictures. The AI engine automatically parses formulas, key definitions, and core concepts.',
      gradientColors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      previewType: _PreviewType.upload,
    ),
    _TourSlideData(
      icon: Icons.tune_rounded,
      badgeText: 'STEP 2',
      badgeColor: Color(0xFF3B82F6),
      title: 'Choose Question Formats',
      subtitle:
          'Filter precisely by Multiple Choice (MCQ), True/False, Short Answer, or Long Answer. The generator strictly serves only your selected format with no repetition.',
      gradientColors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
      previewType: _PreviewType.formats,
    ),
    _TourSlideData(
      icon: Icons.style_rounded,
      badgeText: 'STEP 3',
      badgeColor: Color(0xFFF59E0B),
      title: 'Active Recall Flashcards',
      subtitle:
          'Reinforce long-term memory with front-and-back flashcard flips. Challenge yourself before revealing answers to master difficult topics.',
      gradientColors: [Color(0xFFD97706), Color(0xFFEA580C)],
      previewType: _PreviewType.flashcards,
    ),
    _TourSlideData(
      icon: Icons.rocket_launch_rounded,
      badgeText: 'STEP 4',
      badgeColor: Color(0xFF10B981),
      title: 'Mastery & Screen Time',
      subtitle:
          'Level up, build streaks, and earn XP. As you complete study sessions, earn unlocked minutes to unshield your favorite apps.',
      gradientColors: [Color(0xFF059669), Color(0xFF0D9488)],
      previewType: _PreviewType.progress,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _markSeenAndDismiss() {
    SessionPersistenceService.instance.setAppTourSeen(widget.userId, seen: true);
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      widget.onComplete?.call();
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _markSeenAndDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = (mediaQuery.size.height * 0.82).clamp(520.0, 700.0);

    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surfaceBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: surfaceBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header row with step indicator and Skip button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _slides[_currentPage].badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _slides[_currentPage].badgeColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_currentPage + 1} of ${_slides.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _slides[_currentPage].badgeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _markSeenAndDismiss,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // PageView contents
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return _TourSlideWidget(
                      slide: slide,
                      isDark: isDark,
                    );
                  },
                ),
              ),

              // Bottom control bar: dots and Next / Get Started button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    // Smooth indicator dots
                    Row(
                      children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: _currentPage == i ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? _slides[_currentPage].badgeColor
                                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Action button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _slides[_currentPage].gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _slides[_currentPage].gradientColors.first.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage == _slides.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _slides.length - 1
                                  ? Icons.check_circle_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PreviewType { upload, formats, flashcards, progress }

class _TourSlideData {
  const _TourSlideData({
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.previewType,
  });

  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final _PreviewType previewType;
}

class _TourSlideWidget extends StatelessWidget {
  const _TourSlideWidget({
    required this.slide,
    required this.isDark,
  });

  final _TourSlideData slide;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Interactive Visual Preview Card
          _buildPreviewCard(context),

          const SizedBox(height: 22),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: titleCol,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 10),

          // Subtitle / Description
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: subCol,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 195,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            slide.gradientColors.first.withValues(alpha: isDark ? 0.25 : 0.12),
            slide.gradientColors.last.withValues(alpha: isDark ? 0.15 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: slide.gradientColors.first.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.5,
        ),
      ),
      child: switch (slide.previewType) {
        _PreviewType.upload => _buildUploadVisual(isDark),
        _PreviewType.formats => _buildFormatsVisual(isDark),
        _PreviewType.flashcards => _buildFlashcardsVisual(isDark),
        _PreviewType.progress => _buildProgressVisual(isDark),
      },
    );
  }

  Widget _buildUploadVisual(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.upload_file_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            _chipBadge(Icons.picture_as_pdf_rounded, 'PDF Notes', const Color(0xFFEF4444)),
            _chipBadge(Icons.camera_alt_rounded, 'Photo / Scan', const Color(0xFF10B981)),
            _chipBadge(Icons.functions_rounded, 'Math & Formulas', const Color(0xFF6366F1)),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatsVisual(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(child: _formatOptionCard('MCQ', 'Multiple Choice', Icons.radio_button_checked_rounded, true)),
            const SizedBox(width: 8),
            Expanded(child: _formatOptionCard('T / F', 'True / False', Icons.check_circle_outline_rounded, false)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _formatOptionCard('Short', 'One Word / Phrase', Icons.edit_note_rounded, false)),
            const SizedBox(width: 8),
            Expanded(child: _formatOptionCard('Long', 'Explanations & Proofs', Icons.article_rounded, false)),
          ],
        ),
      ],
    );
  }

  Widget _formatOptionCard(String tag, String label, IconData icon, bool highlighted) {
    final cardBg = highlighted
        ? const Color(0xFF2563EB)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textCol = highlighted ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? const Color(0xFF60A5FA) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: highlighted ? Colors.white : const Color(0xFF3B82F6)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textCol),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: highlighted ? Colors.white70 : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardsVisual(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FLASHCARD • FRONT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.flip_camera_android_rounded, size: 15, color: Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'What is Newton’s 2nd Law?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to flip and verify your answer...',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressVisual(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(child: _metricPill(Icons.local_fire_department_rounded, '3 Days', 'Streak', const Color(0xFFEF4444))),
            const SizedBox(width: 6),
            Expanded(child: _metricPill(Icons.star_rounded, '250 XP', 'Earned', const Color(0xFFF59E0B))),
            const SizedBox(width: 6),
            Expanded(child: _metricPill(Icons.hourglass_bottom_rounded, '+30 Mins', 'Screen Time', const Color(0xFF10B981))),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_open_rounded, size: 14, color: Color(0xFF10B981)),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Apps Unlocked Through Study!',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _metricPill(IconData icon, String value, String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
