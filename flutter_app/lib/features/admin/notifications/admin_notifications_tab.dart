import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class AdminActivityItem {
  const AdminActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.workspaceId,
    this.workspaceName,
    required this.timestamp,
    this.read = false,
    this.subject,
    this.metric,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? workspaceId;
  final String? workspaceName;
  final String timestamp;
  final bool read;
  final String? subject;
  final String? metric;

  factory AdminActivityItem.fromJson(Map<String, dynamic> json) {
    return AdminActivityItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      workspaceId: json['workspace_id'] as String?,
      workspaceName: json['workspace_name'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      subject: json['subject'] as String?,
      metric: json['metric'] as String?,
    );
  }

  bool get isProgressItem =>
      type == 'child_progress' ||
      type == 'session_completed' ||
      type == 'streak_milestone' ||
      type == 'mastery_milestone' ||
      type == 'badge_unlocked';

  bool get isFlaggedItem => type == 'document_flagged';

  bool get isDocumentItem =>
      type == 'document_ready' || type == 'generation_error';
}

class AdminActivityFeed {
  const AdminActivityFeed({required this.items, required this.unreadCount});
  final List<AdminActivityItem> items;
  final int unreadCount;

  factory AdminActivityFeed.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return AdminActivityFeed(
      items: rawItems
          .map((e) => AdminActivityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

// ── Providers (standard Riverpod — no code generation required) ───────────────

/// Fetches the admin activity feed from the backend.
final adminActivityFeedProvider =
    FutureProvider.autoDispose<AdminActivityFeed>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/admin/notifications/activity-feed',
  );
  return AdminActivityFeed.fromJson(response.data ?? {});
});

/// Badge count for the Notifications tab icon — 0 when loading or on error.
final adminNotificationBadgeProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(adminActivityFeedProvider).valueOrNull?.unreadCount ?? 0;
});

/// Persistent toggle for Progress Notifications in Admin/Parent app.
final adminProgressNotificationsEnabledProvider =
    StateNotifierProvider<AdminProgressNotificationsNotifier, bool>((ref) {
  return AdminProgressNotificationsNotifier();
});

class AdminProgressNotificationsNotifier extends StateNotifier<bool> {
  AdminProgressNotificationsNotifier() : super(true) {
    _load();
  }

  static const _key = 'admin_enable_progress_notifications';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

/// Category filter selection ('all', 'progress', 'flagged', 'documents').
final adminNotificationFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

// ── UI ───────────────────────────────────────────────────────────────────────

const _surface = Color(0xFF101828);
const _surfaceAlt = Color(0xFF162032);
const _border = Color(0xFF1E2D45);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF3B82F6);
const _cyan = Color(0xFF06B6D4);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _orange = Color(0xFFF97316);
const _purple = Color(0xFF8B5CF6);

/// Admin notification feed shown in the Notifications tab of the admin
/// bottom navigation bar.
class AdminNotificationsTab extends ConsumerWidget {
  const AdminNotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(adminActivityFeedProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminActivityFeedProvider.future),
      child: feedAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (feed) => feed.items.isEmpty
            ? const _EmptyView()
            : _FeedList(items: feed.items),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: _muted, size: 48),
                const SizedBox(height: Spacing.md),
                const Text(
                  'Could not load notifications',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  message,
                  style: const TextStyle(color: _muted, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Padding(
            padding: EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _surface,
                  child: Icon(Icons.notifications_none_rounded,
                      color: _muted, size: 36),
                ),
                SizedBox(height: Spacing.lg),
                Text(
                  'All caught up!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: Spacing.xs),
                Text(
                  'Workspace activity and document\nprocessing updates appear here.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.items});
  final List<AdminActivityItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressEnabled = ref.watch(adminProgressNotificationsEnabledProvider);
    final activeFilter = ref.watch(adminNotificationFilterProvider);

    final progressCount = items.where((e) => e.isProgressItem).length;
    final flaggedCount = items.where((e) => e.isFlaggedItem).length;
    final docCount = items.where((e) => e.isDocumentItem).length;

    final visibleItems = items.where((item) {
      if (item.isProgressItem && !progressEnabled) {
        return false;
      }
      switch (activeFilter) {
        case 'progress':
          return item.isProgressItem;
        case 'flagged':
          return item.isFlaggedItem;
        case 'documents':
          return item.isDocumentItem;
        default:
          return true;
      }
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Progress Notifications Status Banner ──
                _ProgressNotificationBanner(
                  enabled: progressEnabled,
                  onChanged: (val) {
                    ref
                        .read(adminProgressNotificationsEnabledProvider.notifier)
                        .setEnabled(val);
                  },
                ),
                const SizedBox(height: Spacing.md),
                // ── Category Filter Chips Bar ──
                _CategoryFilterBar(
                  selected: activeFilter,
                  allCount: progressEnabled ? items.length : items.length - progressCount,
                  progressCount: progressCount,
                  flaggedCount: flaggedCount,
                  docCount: docCount,
                  onSelected: (filter) {
                    ref.read(adminNotificationFilterProvider.notifier).state = filter;
                  },
                ),
              ],
            ),
          ),
        ),
        if (visibleItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !progressEnabled && activeFilter == 'progress'
                          ? Icons.notifications_off_rounded
                          : Icons.filter_list_off_rounded,
                      color: _muted,
                      size: 40,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      !progressEnabled && activeFilter == 'progress'
                          ? 'Progress notifications are paused'
                          : 'No notifications in this category',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      !progressEnabled && activeFilter == 'progress'
                          ? 'Toggle the switch above to enable student study and milestone alerts.'
                          : 'Recent alerts and updates will appear here.',
                      style: const TextStyle(color: _muted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xs,
              Spacing.lg,
              Spacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: _NotificationCard(item: visibleItems[index]),
                ),
                childCount: visibleItems.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressNotificationBanner extends StatelessWidget {
  const _ProgressNotificationBanner({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? _cyan.withAlpha(80) : _border,
          width: enabled ? 1.5 : 1.0,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _cyan.withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: enabled ? _cyan.withAlpha(40) : _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? _cyan.withAlpha(100) : _border,
              ),
            ),
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: enabled ? _cyan : _muted,
              size: 22,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Progress Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? _cyan.withAlpha(30)
                            : Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        enabled ? 'ACTIVE' : 'PAUSED',
                        style: TextStyle(
                          color: enabled ? _cyan : _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? 'Real-time alerts for student sessions, streaks & mastery'
                      : 'Child progress alerts are currently paused',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: _cyan,
            activeTrackColor: _cyan.withAlpha(80),
            inactiveThumbColor: _muted,
            inactiveTrackColor: _surface,
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.selected,
    required this.allCount,
    required this.progressCount,
    required this.flaggedCount,
    required this.docCount,
    required this.onSelected,
  });

  final String selected;
  final int allCount;
  final int progressCount;
  final int flaggedCount;
  final int docCount;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All ($allCount)',
            isSelected: selected == 'all',
            accentColor: _blue,
            onTap: () => onSelected('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '🎯 Progress ($progressCount)',
            isSelected: selected == 'progress',
            accentColor: _cyan,
            onTap: () => onSelected('progress'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '⚠️ Flagged ($flaggedCount)',
            isSelected: selected == 'flagged',
            accentColor: _amber,
            onTap: () => onSelected('flagged'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '📄 Documents ($docCount)',
            isSelected: selected == 'documents',
            accentColor: _green,
            onTap: () => onSelected('documents'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withAlpha(40) : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : _border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _muted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final AdminActivityItem item;

  IconData get _icon {
    switch (item.type) {
      case 'child_progress':
        return Icons.trending_up_rounded;
      case 'session_completed':
        return Icons.school_rounded;
      case 'streak_milestone':
        return Icons.local_fire_department_rounded;
      case 'mastery_milestone':
        return Icons.military_tech_rounded;
      case 'badge_unlocked':
        return Icons.stars_rounded;
      case 'document_ready':
        return Icons.description_rounded;
      case 'generation_error':
        return Icons.warning_amber_rounded;
      case 'document_flagged':
        return Icons.flag_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _accentColor {
    switch (item.type) {
      case 'child_progress':
        return _cyan;
      case 'session_completed':
        return _blue;
      case 'streak_milestone':
        return _orange;
      case 'mastery_milestone':
        return _amber;
      case 'badge_unlocked':
        return _purple;
      case 'document_ready':
        return _green;
      case 'generation_error':
        return _red;
      case 'document_flagged':
        return _amber;
      default:
        return _cyan;
    }
  }

  String get _relativeTime {
    if (item.timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(item.timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent left stripe
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            // Icon bubble
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: accent, size: 22),
              ),
            ),
            const SizedBox(width: Spacing.md),
            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            _relativeTime,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Metric & Subject Pills
                    if (item.metric != null || item.subject != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.subject != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                item.subject!,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (item.metric != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withAlpha(30),
                                ),
                              ),
                              child: Text(
                                item.metric!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (item.workspaceName != null &&
                        item.workspaceName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.workspaces_rounded,
                            size: 11,
                            color: _muted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              item.workspaceName!,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
          ],
        ),
      ),
    );
  }
}
