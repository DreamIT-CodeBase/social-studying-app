import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';

// ─── Colours matching the reference exactly ───────────────────────────────
const _kSkyTop    = Color(0xFFB8EBF7); // pale sky blue
const _kSkyBottom = Color(0xFF7DD5EE); // deeper sky at horizon
const _kCream     = Color(0xFFF7EDD8); // warm parchment body
const _kAmberL    = Color(0xFFFFBF3C); // amber card left
const _kAmberR    = Color(0xFFFFD86B); // amber card right (lighter)
const _kMenuBg    = Color(0xFFFFFFFF);
const _kMenuText  = Color(0xFF2C2C2C);
const _kChevron   = Color(0xFFCCCCCC);
const _kDivider   = Color(0xFFF0F0F0);
const _kNameColor = Color(0xFF1A1A2E);
const _kSubColor  = Color(0xFF7A7A8C);
const _kTreeGreen = Color(0xFF4CAF50);
const _kTreeDark  = Color(0xFF388E3C);
const _kTrunk     = Color(0xFF8D6E63);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;

    final (displayName, email) = authState?.maybeWhen(
          authenticated: (user) => (user.displayName, user.email),
          orElse: () => ('User', 'user@example.com'),
        ) ??
        ('User', 'user@example.com');

    final isStudent = currentFlavor == AppFlavor.student;
    // avatar initial
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    // Sky section height
    const double skyH = 260;
    // Avatar radius
    const double avatarR = 48.0;

    return Scaffold(
      backgroundColor: _kCream,
      body: Stack(
        children: [
          // ── Cream body (full height) ───────────────────────────────────
          Positioned.fill(
            child: Container(color: _kCream),
          ),

          // ── Sky header ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: skyH,
            child: CustomPaint(
              painter: _SkyPainter(),
            ),
          ),

          // ── Left tree decoration ──────────────────────────────────────
          Positioned(
            top: skyH - 100,
            left: -10,
            child: const _TreeDecoration(mirrored: false),
          ),

          // ── Right tree decoration ─────────────────────────────────────
          Positioned(
            top: skyH - 100,
            right: -10,
            child: const _TreeDecoration(mirrored: true),
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
                  _AvatarBadge(initial: initial, radius: avatarR),

                  const SizedBox(height: 14),

                  // Name
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kNameColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Email (user requested email instead of ID)
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kSubColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: Spacing.xl + 4),

                  // ── Amber promo card ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PromoCard(),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // ── Menu list ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MenuCard(
                      items: [
                        if (!isStudent)
                          _MenuItem(
                            icon: Icons.screen_lock_portrait_rounded,
                            label: 'Screen Time Controls',
                            onTap: () => context.push('/student/screen-time-settings'),
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
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
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

// ─── Sky painter (replaces boxdecoration for gradient + no hard corners) ───
class _SkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = const LinearGradient(
      colors: [_kSkyTop, _kSkyBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    // flat at top, rounded at bottom
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
  const _TreeDecoration({required this.mirrored});
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: mirrored ? -1 : 1,
      child: CustomPaint(
        size: const Size(80, 110),
        painter: _TreePainter(),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()..color = _kTrunk;
    final leafPaint1 = Paint()..color = _kTreeGreen;
    final leafPaint2 = Paint()..color = _kTreeDark;

    // trunk
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height * 0.6, size.width * 0.12, size.height * 0.4),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _CircleBtn(
            onTap: onBack,
            child: const Icon(Icons.chevron_left_rounded, color: Color(0xFF2C2C2C), size: 24),
          ),
          const Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          _CircleBtn(
            onTap: onEdit,
            child: const Icon(Icons.edit_outlined, color: Color(0xFF2C2C2C), size: 18),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── Avatar ─────────────────────────────────────────────────────────────────
class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.initial, required this.radius});
  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Color(0x30000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // Soft peach/orange tint like reference avatar bg
          color: Color(0xFFFDE8C8),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: radius * 0.9,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE65100),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Promo amber card ───────────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAmberL, _kAmberR],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55FFA000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text('⭐ ', style: TextStyle(fontSize: 15)),
              SizedBox(width: 4),
              Text(
                'Grow Your Study Power',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3E2000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Unlock your full study superpower! Get access to\nAI questions, adaptive flashcards, and live\nanalytics from the engine.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF5A3300),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          // CTA button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Text(
                'Start My Quest Now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFCC6B00),
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
  const _MenuCard({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kMenuBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, thickness: 1, color: _kDivider, indent: 54),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // icon circle — light grey tint like reference
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF555555)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kMenuText,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kChevron, size: 22),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kMenuBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFEEAEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE53935)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kChevron, size: 22),
          ],
        ),
      ),
    );
  }
}
