import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/screen_time/widgets/accessibility_disclosure_dialog.dart';

// ─── Colours matching the reference exactly ───────────────────────────────
const _kSkyTop = Color(0xFFB8EBF7); // pale sky blue
const _kSkyBottom = Color(0xFF7DD5EE); // deeper sky at horizon
const _kCream = Color(0xFFFFFFFF); // clean white body
const _kAmberL = Color(0xFFFFBF3C); // amber card left
const _kAmberR = Color(0xFFFFD86B); // amber card right (lighter)
const _kMenuBg = Color(0xFFFFFFFF);
const _kMenuText = Color(0xFF2C2C2C);
const _kChevron = Color(0xFFCCCCCC);
const _kNameColor = Color(0xFF1A1A2E);
const _kSubColor = Color(0xFF7A7A8C);
const _kTreeGreen = Color(0xFF4CAF50);
const _kTreeDark = Color(0xFF388E3C);
const _kTrunk = Color(0xFF8D6E63);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appThemeModeProvider) == AppThemeMode.mature) {
      return const _CollegeProfileScreen();
    }

    final authState = ref.watch(authNotifierProvider).valueOrNull;

    final (displayName, email) = authState?.maybeWhen(
          authenticated: (user) => (user.displayName, user.email),
          orElse: () => ('User', 'user@example.com'),
        ) ??
        ('User', 'user@example.com');

    // avatar initial
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF070714) : _kCream;

    // Sky section height
    const double skyH = 260;
    // Avatar radius
    const double avatarR = 48.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── Cream body (full height) ───────────────────────────────────
          Positioned.fill(
            child: Container(color: bgColor),
          ),

          // ── Sky header ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyH,
            child: CustomPaint(
              painter: _SkyPainter(isDark: isDark),
            ),
          ),

          // ── Left tree decoration ──────────────────────────────────────
          Positioned(
            top: skyH - 100,
            left: -10,
            child: _TreeDecoration(mirrored: false, isDark: isDark),
          ),

          // ── Right tree decoration ─────────────────────────────────────
          Positioned(
            top: skyH - 100,
            right: -10,
            child: _TreeDecoration(mirrored: true, isDark: isDark),
          ),

          // ── Content ───────────────────────────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // top bar sits inside sky area
                  SizedBox(
                    height: MediaQuery.of(context).padding.top + 14,
                  ),
                  _TopBar(
                    onBack: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    onEdit: () {},
                  ),

                  // space before avatar — leaves room for sky section
                  const SizedBox(height: 36),

                  // Avatar centred
                  _AvatarBadge(
                      initial: initial, radius: avatarR, isDark: isDark),

                  const SizedBox(height: 14),

                  // Name
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _kNameColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Email (user requested email instead of ID)
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF8888AA) : _kSubColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: Spacing.xl + 4),

                  // ── Amber promo card ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PromoCard(isDark: isDark),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // ── Menu list ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MenuCard(
                      isDark: isDark,
                      items: [
                        _MenuItem(
                          icon: Icons.palette_rounded,
                          label: 'Experience Style',
                          onTap: () => context.push(AppRoutes.themeSelection),
                        ),
                        _MenuItem(
                          icon: Icons.accessibility_new_rounded,
                          label: 'Accessibility & Study Protection',
                          onTap: () {
                            showAccessibilityProminentDisclosureDialog(
                              context,
                              onAccept: () {
                                context
                                    .push(AppRoutes.studentScreenTimeSettings);
                              },
                            );
                          },
                        ),
                        _MenuItem(
                          icon: Icons.screen_lock_portrait_rounded,
                          label: 'Screen Time & Focus Controls',
                          onTap: () =>
                              context.push(AppRoutes.studentScreenTimeSettings),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // ── Sign out ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SignOutTile(
                      onTap: () => _confirmSignOut(context, ref),
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// A quiet, professional account page for the Teen & College experience.
/// The kids experience intentionally keeps the illustrated profile above.
class _CollegeProfileScreen extends ConsumerWidget {
  const _CollegeProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final (displayName, email) = authState?.maybeWhen(
          authenticated: (user) => (user.displayName, user.email),
          orElse: () => ('User', 'user@example.com'),
        ) ??
        ('User', 'user@example.com');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surface = isDark ? const Color(0xFF172033) : Colors.white;
    final border = isDark ? const Color(0xFF26344D) : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_circle_rounded,
                      size: 46, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryText)),
                      const SizedBox(height: 4),
                      Text(email,
                          style: TextStyle(fontSize: 13, color: secondaryText),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Preferences',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: secondaryText)),
          const SizedBox(height: 8),
          _CollegeSettingsCard(
            surface: surface,
            border: border,
            children: [
              _CollegeSettingsTile(
                icon: Icons.palette_outlined,
                title: 'Experience style',
                subtitle: 'Change your study environment',
                onTap: () => context.push(AppRoutes.themeSelection),
              ),
              _CollegeSettingsTile(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility & Study Protection',
                subtitle: 'View permission disclosure & focus settings',
                onTap: () {
                  showAccessibilityProminentDisclosureDialog(
                    context,
                    onAccept: () {
                      context.push(AppRoutes.studentScreenTimeSettings);
                    },
                  );
                },
              ),
              _CollegeSettingsTile(
                icon: Icons.screen_lock_portrait_outlined,
                title: 'Screen Time & Focus Controls',
                subtitle: 'Manage apps, shields, and study conversion',
                onTap: () => context.push(AppRoutes.studentScreenTimeSettings),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _CollegeSettingsCard(
            surface: surface,
            border: border,
            children: [
              _CollegeSettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'Sign out of this account',
                isDestructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _CollegeSettingsCard extends StatelessWidget {
  const _CollegeSettingsCard(
      {required this.surface, required this.border, required this.children});
  final Color surface;
  final Color border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        child: Column(children: children),
      );
}

class _CollegeSettingsTile extends StatelessWidget {
  const _CollegeSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? const Color(0xFFDC2626)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
    );
  }
}

// ─── Sky painter ───
class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final skyTop = isDark ? const Color(0xFF13132A) : _kSkyTop;
    final skyBottom = isDark ? const Color(0xFF1E1B4B) : _kSkyBottom;

    final gradient = LinearGradient(
      colors: [skyTop, skyBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 28)
      ..quadraticBezierTo(size.width / 2, size.height + 10, 0, size.height - 28)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Decorative tree ────────────────────────────────────────────────────────
class _TreeDecoration extends StatelessWidget {
  const _TreeDecoration({required this.mirrored, required this.isDark});
  final bool mirrored;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: mirrored ? -1 : 1,
      child: CustomPaint(
        size: const Size(80, 110),
        painter: _TreePainter(isDark: isDark),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  const _TreePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()
      ..color = isDark ? const Color(0xFF475569) : _kTrunk;
    final leafPaint1 = Paint()
      ..color = isDark ? const Color(0xFF312E81) : _kTreeGreen;
    final leafPaint2 = Paint()
      ..color = isDark ? const Color(0xFF1E1B4B) : _kTreeDark;

    // trunk
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height * 0.6, size.width * 0.12,
            size.height * 0.4),
        const Radius.circular(4),
      ),
      trunkPaint,
    );

    // Bottom foliage layer (widest)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.7),
        width: size.width * 0.9,
        height: size.height * 0.35,
      ),
      leafPaint1,
    );

    // Middle foliage
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.52),
        width: size.width * 0.7,
        height: size.height * 0.32,
      ),
      leafPaint2,
    );

    // Top foliage
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.32),
        width: size.width * 0.5,
        height: size.height * 0.28,
      ),
      leafPaint1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Top bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onEdit});
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCol = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final btnIconCol = isDark ? Colors.white : const Color(0xFF2C2C2C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _CircleBtn(
            onTap: onBack,
            child:
                Icon(Icons.chevron_left_rounded, color: btnIconCol, size: 24),
          ),
          Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: titleCol,
              ),
            ),
          ),
          _CircleBtn(
            onTap: onEdit,
            child: Icon(Icons.edit_outlined, color: btnIconCol, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol =
        isDark ? const Color(0xFF1A1A3A) : Colors.white.withValues(alpha: 0.55);
    final borderColor = isDark ? const Color(0xFF2A2A50) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgCol,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: isDark ? 1.2 : 0.0),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── Avatar ─────────────────────────────────────────────────────────────────
class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge(
      {required this.initial, required this.radius, required this.isDark});
  final String initial;
  final double radius;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ringBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final badgeBg = isDark ? const Color(0xFF312E81) : const Color(0xFFFDE8C8);
    final textCol = isDark ? const Color(0xFF818CF8) : const Color(0xFFE65100);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ringBg,
        boxShadow: const [
          BoxShadow(
              color: Color(0x30000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: badgeBg,
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: radius * 0.9,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Promo amber card ───────────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final gradientColors = isDark
        ? const [Color(0xFF3B0764), Color(0xFF1E1B4B)]
        : const [_kAmberL, _kAmberR];

    final shadowColor = isDark
        ? const Color(0xFF3B0764).withValues(alpha: 0.4)
        : const Color(0x55FFA000);

    final titleCol = isDark ? Colors.white : const Color(0xFF3E2000);
    final descCol = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF5A3300);
    final btnBg = isDark ? const Color(0xFF7C5CFC) : Colors.white;
    final btnText = isDark ? Colors.white : const Color(0xFFCC6B00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('⭐ ', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 4),
              Text(
                'Grow Your Study Power',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: titleCol,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Unlock your full study superpower! Get access to\nAI questions, adaptive flashcards, and live\nanalytics from the engine.',
            style: TextStyle(
              fontSize: 12,
              color: descCol,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                'Start My Quest Now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: btnText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu card ──────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items, required this.isDark});
  final List<_MenuItem> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF13132A) : _kMenuBg;
    final borderColor =
        isDark ? const Color(0xFF2A2A50) : const Color(0xFFF0F0F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isDark ? 1.5 : 0.0),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, thickness: 1, color: borderColor, indent: 54),
          ],
        ],
      ),
    );
  }
}

// ─── Menu item ──────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconBg = isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF2F2F2);
    final iconCol = isDark ? const Color(0xFFA78BFA) : const Color(0xFF555555);
    final textCol = isDark ? Colors.white : _kMenuText;
    final chevronCol = isDark ? const Color(0xFF475569) : _kChevron;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconCol),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textCol,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: chevronCol, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Sign-out tile ───────────────────────────────────────────────────────────
class _SignOutTile extends StatelessWidget {
  const _SignOutTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF13132A) : _kMenuBg;
    final borderColor =
        isDark ? const Color(0xFF2A2A50) : const Color(0xFFF0F0F0);
    final iconBg = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEEAEA);
    final iconColor = const Color(0xFFE53935);
    final textCol = const Color(0xFFE53935);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isDark ? 1.5 : 0.0),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textCol,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF475569) : _kChevron, size: 22),
          ],
        ),
      ),
    );
  }
}
