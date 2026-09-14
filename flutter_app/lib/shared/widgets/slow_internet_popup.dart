import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/shared/services/network_status_service.dart';

/// Global overlay that watches [networkStatusProvider] and displays a floating
/// slow internet / connectivity warning banner across any screen in the app.
class NetworkStatusOverlay extends ConsumerWidget {
  const NetworkStatusOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusState = ref.watch(networkStatusProvider);
    final isVisible = statusState.hasIssues;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          if (isVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    tween: Tween<double>(begin: -0.8, end: 0.0),
                    builder: (context, slideY, childWidget) {
                      return Transform.translate(
                        offset: Offset(0, slideY * 100),
                        child: childWidget,
                      );
                    },
                    child: SlowInternetPopup(
                      state: statusState,
                      onDismiss: () =>
                          ref.read(networkStatusProvider.notifier).dismiss(),
                      onRetry: () =>
                          ref.read(networkStatusProvider.notifier).retry(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating glassmorphic notification banner for slow internet / network lag.
class SlowInternetPopup extends StatefulWidget {
  const SlowInternetPopup({
    super.key,
    required this.state,
    this.onDismiss,
    this.onRetry,
  });

  final NetworkStatusState state;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  @override
  State<SlowInternetPopup> createState() => _SlowInternetPopupState();
}

class _SlowInternetPopupState extends State<SlowInternetPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Only loop pulsing animation in real runtime, not in automated test harness
    if (!const bool.hasEnvironment('FLUTTER_TEST_MODE')) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOffline = widget.state.status == NetworkStatus.offline;

    final primaryAccent = isOffline
        ? const Color(0xFFEF4444) // Red for offline
        : const Color(0xFFF59E0B); // Warm amber for slow internet

    final bgColor = isDark
        ? const Color(0xE61E293B) // Dark frosted slate
        : const Color(0xF2FFFBEB); // Light frosted amber-cream

    final borderColor = isDark
        ? primaryAccent.withValues(alpha: 0.45)
        : primaryAccent.withValues(alpha: 0.6);

    final title =
        isOffline ? 'No Internet Connection' : 'Slow Internet Detected';

    final message = widget.state.message ??
        (isOffline
            ? 'You\'re currently offline. Offline study progress is safely stored.'
            : 'Loading is taking longer than usual. Your answers are saved safely.');

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pulsing Icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 1.0 + (_pulseController.value * 0.12);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: primaryAccent.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          isOffline
                              ? Icons.wifi_off_rounded
                              : Icons.wifi_tethering_error_rounded,
                          color: primaryAccent,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Text details
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOffline ? 'OFFLINE' : 'SLOW',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: primaryAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Actions: Retry & Dismiss
                if (widget.onRetry != null)
                  IconButton(
                    onPressed: widget.onRetry,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: primaryAccent,
                      size: 20,
                    ),
                    tooltip: 'Retry connection',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),

                IconButton(
                  onPressed: widget.onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white60 : Colors.black45,
                    size: 18,
                  ),
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
