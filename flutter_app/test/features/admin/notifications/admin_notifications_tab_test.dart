import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/features/admin/notifications/admin_notifications_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'admin_enable_progress_notifications': true,
    });
  });

  testWidgets('AdminNotificationsTab renders progress banner, filter chips, and progress items',
      (tester) async {
    final mockFeed = AdminActivityFeed(
      items: [
        const AdminActivityItem(
          id: 'item_progress_1',
          type: 'child_progress',
          title: '🎯 Alice: Chemistry Progress',
          body: "Alice finished a Chemistry study session on 'Atomic Structure'.",
          timestamp: '2026-09-01T10:00:00Z',
          subject: 'Chemistry',
          metric: '85% Acc • +40 XP',
        ),
        const AdminActivityItem(
          id: 'item_streak_1',
          type: 'streak_milestone',
          title: '🔥 Alice Streak Milestone!',
          body: 'Alice is on a 5-day active study streak!',
          timestamp: '2026-09-01T09:00:00Z',
          metric: '5-Day Streak',
        ),
        const AdminActivityItem(
          id: 'item_doc_1',
          type: 'document_ready',
          title: '📄 Document Ready',
          body: "'Algebra_Notes.pdf' finished processing.",
          timestamp: '2026-09-01T08:00:00Z',
        ),
      ],
      unreadCount: 3,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminActivityFeedProvider.overrideWith((ref) => mockFeed),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminNotificationsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Progress Notifications Banner
    expect(find.text('Progress Notifications'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Verify Category Filter Chips
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('🎯 Progress (2)'), findsOneWidget);
    expect(find.text('📄 Documents (1)'), findsOneWidget);

    // Verify Cards
    expect(find.text('🎯 Alice: Chemistry Progress'), findsOneWidget);
    expect(find.text('85% Acc • +40 XP'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('5-Day Streak'), findsOneWidget);
    expect(find.text('📄 Document Ready'), findsOneWidget);

    // Tap on Progress filter chip
    await tester.tap(find.text('🎯 Progress (2)'));
    await tester.pumpAndSettle();

    // Only progress items should be visible
    expect(find.text('🎯 Alice: Chemistry Progress'), findsOneWidget);
    expect(find.text('🔥 Alice Streak Milestone!'), findsOneWidget);
    expect(find.text('📄 Document Ready'), findsNothing);
  });
}
