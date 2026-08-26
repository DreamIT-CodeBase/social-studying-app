import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? workspaceId;
  final String? workspaceName;
  final String timestamp;
  final bool read;

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
    );
  }
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

// ── UI ───────────────────────────────────────────────────────────────────────

const _surface = Color(0xFF101828);
const _border = Color(0xFF1E2D45);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF3B82F6);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);

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

class _FeedList extends StatelessWidget {
  const _FeedList({required this.items});
  final List<AdminActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (context, index) =>
          _NotificationCard(item: items[index]),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final AdminActivityItem item;

  IconData get _icon {
    switch (item.type) {
      case 'document_ready':
        return Icons.description_rounded;
      case 'generation_error':
        return Icons.warning_amber_rounded;
      case 'session_completed':
        return Icons.school_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _accentColor {
    switch (item.type) {
      case 'document_ready':
        return _green;
      case 'generation_error':
        return _red;
      case 'session_completed':
        return _blue;
      default:
        return _amber;
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: accent, size: 20),
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
                              fontSize: 13,
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
                    if (item.workspaceName != null &&
                        item.workspaceName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.workspaces_rounded,
                              size: 11, color: _muted),
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
