import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';
import 'package:social_study_app/features/mascot/widgets/study_buddy.dart';


class LoadingIndicator extends ConsumerStatefulWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.useMascot = true,
    this.subMessage,
  });

  final String? message;
  final String? subMessage;
  final bool useMascot;

  @override
  ConsumerState<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends ConsumerState<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 8.0, end: 24.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final showMascot = widget.useMascot && !Platform.environment.containsKey('FLUTTER_TEST');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF13132A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final textMuted = isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(isDark ? 0.15 : 0.06),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Loading Illustration / Mascot ──────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing rings
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 106,
                        height: 106,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(isDark ? 0.22 : 0.12),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: _glowAnimation.value / 3,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Background circle for mascot / indicator
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Decorative sparkles
                  Positioned(
                    top: 2,
                    right: 4,
                    child: Icon(Icons.auto_awesome, size: 14, color: primaryColor.withOpacity(0.8)),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 2,
                    child: Icon(Icons.auto_awesome, size: 10, color: Colors.amber.withOpacity(0.7)),
                  ),
                  // Pulsing Mascot or Spinner
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      );
                    },
                    child: showMascot
                        ? (themeMode == AppThemeMode.mature
                            ? Icon(
                                Icons.school_rounded,
                                size: 52,
                                color: primaryColor,
                              )
                            : const StudyBuddy(state: MascotState.loading, size: 76))
                        : CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 4,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Loading Title ──────────────────────────────────────────────
              if (widget.message != null) ...[
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],

              // ── Loading Sub-message ─────────────────────────────────────────
              if (widget.subMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Micro linear status pulse ──────────────────────────────────
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: primaryColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
