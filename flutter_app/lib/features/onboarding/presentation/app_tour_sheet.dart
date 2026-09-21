import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

/// An interactive, spotlight coachmark tour with pointing arrows and compact,
/// professional floating tooltip cards that highlight:
/// 1. Session Format & Manage Study
/// 2. Study Tab (in lower navigation bar)
/// 3. Flashcards Tab (in lower navigation bar)
///
/// Designed with minimal, high-signal information that does not obscure the screen.
class AppTourSheet extends StatefulWidget {
  const AppTourSheet({
    super.key,
    required this.userId,
    this.onComplete,
    this.formatKey,
    this.studyTabKey,
    this.flashcardsTabKey,
  });

  final String userId;
  final VoidCallback? onComplete;
  final GlobalKey? formatKey;
  final GlobalKey? studyTabKey;
  final GlobalKey? flashcardsTabKey;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    VoidCallback? onComplete,
    GlobalKey? formatKey,
    GlobalKey? studyTabKey,
    GlobalKey? flashcardsTabKey,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, anim, _) => AppTourSheet(
        userId: userId,
        onComplete: onComplete,
        formatKey: formatKey,
        studyTabKey: studyTabKey,
        flashcardsTabKey: flashcardsTabKey,
      ),
    );
  }

  @override
  State<AppTourSheet> createState() => _AppTourSheetState();
}

class _TourStepData {
  const _TourStepData({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.arrowPointsUp,
  });

  final int stepNumber;
  final String title;
  final String description;
  final bool arrowPointsUp;
}

class _AppTourSheetState extends State<AppTourSheet>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  AnimationController? _pulseController;

  static const List<_TourStepData> _steps = [
    _TourStepData(
      stepNumber: 1,
      title: 'Study Format & Materials',
      description:
          'Choose your question format (MCQ, True/False, Short, or Long) or manage uploaded materials here.',
      arrowPointsUp: true,
    ),
    _TourStepData(
      stepNumber: 2,
      title: 'Study Sessions',
      description:
          'Tap the Study tab to practice adaptive questions calibrated directly to your mastery level.',
      arrowPointsUp: false,
    ),
    _TourStepData(
      stepNumber: 3,
      title: 'Active Recall Flashcards',
      description:
          'Tap the Flashcards tab to review spaced-repetition cards that strengthen long-term memory.',
      arrowPointsUp: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  void _dismissTour() {
    SessionPersistenceService.instance.setAppTourSeen(widget.userId, seen: true);
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      widget.onComplete?.call();
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _dismissTour();
    }
  }

  Rect _calculateTargetRect(int stepIndex, Size screenSize) {
    GlobalKey? targetKey;
    if (stepIndex == 0) targetKey = widget.formatKey;
    if (stepIndex == 1) targetKey = widget.studyTabKey;
    if (stepIndex == 2) targetKey = widget.flashcardsTabKey;

    if (targetKey != null) {
      final context = targetKey.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize && renderBox.attached) {
          final offset = renderBox.localToGlobal(Offset.zero);
          return offset & renderBox.size;
        }
      }
    }

    // High-fidelity responsive fallbacks
    if (stepIndex == 0) {
      // Session format selector row (middle-upper part of screen)
      return Rect.fromLTWH(
        16,
        screenSize.height * 0.38,
        screenSize.width - 32,
        48,
      );
    } else if (stepIndex == 1) {
      // Bottom navigation bar: Study tab (index 1 of 4)
      final tabWidth = screenSize.width / 4;
      return Rect.fromLTWH(tabWidth, screenSize.height - 68, tabWidth, 68);
    } else {
      // Bottom navigation bar: Flashcards tab (index 2 of 4)
      final tabWidth = screenSize.width / 4;
      return Rect.fromLTWH(tabWidth * 2, screenSize.height - 68, tabWidth, 68);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final step = _steps[_currentStep];
    final targetRect = _calculateTargetRect(_currentStep, screenSize);

    // Box dimensions
    final boxWidth = math.min(screenSize.width - 32.0, 310.0);
    const boxHeight = 142.0;

    // Determine arrow direction & box vertical position
    final pointsUp = step.arrowPointsUp || targetRect.top <= screenSize.height * 0.50;
    final double boxTop;
    final double arrowTipY;

    if (pointsUp) {
      // Target is above: box sits below target, arrow points UP
      boxTop = math.min(
        screenSize.height - boxHeight - mediaQuery.padding.bottom - 16.0,
        targetRect.bottom + 18.0,
      );
      arrowTipY = targetRect.bottom + 4.0;
    } else {
      // Target is below: box sits above target, arrow points DOWN
      boxTop = math.max(
        mediaQuery.padding.top + 16.0,
        targetRect.top - boxHeight - 18.0,
      );
      arrowTipY = targetRect.top - 4.0;
    }

    // Horizontal placement of box
    final targetCenterX = targetRect.center.dx;
    final boxLeft = (targetCenterX - boxWidth / 2.0).clamp(
      16.0,
      screenSize.width - boxWidth - 16.0,
    );
    final arrowX = targetCenterX.clamp(boxLeft + 24.0, boxLeft + boxWidth - 24.0);

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Semi-transparent backdrop with spotlight cutout
            Positioned.fill(
              child: GestureDetector(
                onTap: _nextStep,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _pulseController ?? const AlwaysStoppedAnimation(0.0),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SpotlightBackdropPainter(
                        targetRect: targetRect,
                        pulse: _pulseController?.value ?? 0.0,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Pointing Arrow linked directly from Box to Target
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController ?? const AlwaysStoppedAnimation(0.0),
                  builder: (context, _) {
                    final pulseBounce = (_pulseController?.value ?? 0.0) * 4.0;
                    final effectiveTipY = pointsUp
                        ? arrowTipY - pulseBounce
                        : arrowTipY + pulseBounce;

                    return CustomPaint(
                      painter: _LinkedArrowPainter(
                        boxRect: Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
                        arrowX: arrowX,
                        arrowTipY: effectiveTipY,
                        pointsUp: pointsUp,
                      ),
                    );
                  },
                ),
              ),
            ),

          // 3. Compact, Professional Tooltip Card
          Positioned(
            left: boxLeft,
            top: boxTop,
            width: boxWidth,
            height: boxHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.7),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header Row: Step Pill + Skip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF312E81),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${step.stepNumber} of ${_steps.length}',
                          style: const TextStyle(
                            color: Color(0xFFA5B4FC),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismissTour,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Title
                  Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),

                  // Description
                  Text(
                    step.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  // Footer: Dots + Next Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots Indicator
                      Row(
                        children: List.generate(_steps.length, (idx) {
                          final isActive = idx == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 5),
                            width: isActive ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF818CF8)
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),

                      // Action Button (Next / Got It)
                      GestureDetector(
                        onTap: _nextStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentStep == _steps.length - 1
                                    ? 'Got It'
                                    : 'Next',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _currentStep == _steps.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

/// Paints the dimmed background with a spotlight cutout and glowing outline
/// around the targeted widget.
class _SpotlightBackdropPainter extends CustomPainter {
  const _SpotlightBackdropPainter({
    required this.targetRect,
    required this.pulse,
  });

  final Rect targetRect;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final paddedRect = targetRect.inflate(6.0);
    final rrect = RRect.fromRectAndRadius(paddedRect, const Radius.circular(14));

    // EvenOdd fill clears the spotlight cutout from the darkened backdrop
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect);
    path.fillType = PathFillType.evenOdd;

    final backdropPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, backdropPaint);

    // Glowing border around the highlighted element
    final glowAlpha = (0.70 + 0.30 * pulse).clamp(0.0, 1.0);
    final borderPaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // Corner accent pings
    final pingPaint = Paint()
      ..color = const Color(0xFF818CF8).withValues(alpha: glowAlpha * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    const cornerLength = 12.0;

    // Top-left ping
    canvas.drawLine(
      Offset(paddedRect.left, paddedRect.top + cornerLength),
      Offset(paddedRect.left, paddedRect.top),
      pingPaint,
    );
    canvas.drawLine(
      Offset(paddedRect.left, paddedRect.top),
      Offset(paddedRect.left + cornerLength, paddedRect.top),
      pingPaint,
    );

    // Bottom-right ping
    canvas.drawLine(
      Offset(paddedRect.right - cornerLength, paddedRect.bottom),
      Offset(paddedRect.right, paddedRect.bottom),
      pingPaint,
    );
    canvas.drawLine(
      Offset(paddedRect.right, paddedRect.bottom - cornerLength),
      Offset(paddedRect.right, paddedRect.bottom),
      pingPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightBackdropPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.pulse != pulse;
  }
}

/// Paints the physical arrow connected from the tooltip card pointing at the target
class _LinkedArrowPainter extends CustomPainter {
  const _LinkedArrowPainter({
    required this.boxRect,
    required this.arrowX,
    required this.arrowTipY,
    required this.pointsUp,
  });

  final Rect boxRect;
  final double arrowX;
  final double arrowTipY;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    const arrowBaseHalfWidth = 10.0;
    final path = Path();

    if (pointsUp) {
      // Arrow protrudes from top of box and points UP
      final baseY = boxRect.top;
      path.moveTo(arrowX - arrowBaseHalfWidth, baseY);
      path.lineTo(arrowX, arrowTipY);
      path.lineTo(arrowX + arrowBaseHalfWidth, baseY);
      path.close();
    } else {
      // Arrow protrudes from bottom of box and points DOWN
      final baseY = boxRect.bottom;
      path.moveTo(arrowX - arrowBaseHalfWidth, baseY);
      path.lineTo(arrowX, arrowTipY);
      path.lineTo(arrowX + arrowBaseHalfWidth, baseY);
      path.close();
    }

    final fillPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, strokePaint);

    // Glowing tip dot
    final dotPaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(arrowX, arrowTipY), 2.8, dotPaint);
  }

  @override
  bool shouldRepaint(_LinkedArrowPainter oldDelegate) {
    return oldDelegate.boxRect != boxRect ||
        oldDelegate.arrowX != arrowX ||
        oldDelegate.arrowTipY != arrowTipY ||
        oldDelegate.pointsUp != pointsUp;
  }
}
