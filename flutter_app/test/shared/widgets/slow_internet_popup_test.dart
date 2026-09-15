import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/shared/services/network_status_service.dart';
import 'package:social_study_app/shared/widgets/slow_internet_popup.dart';

void main() {
  setUp(() {
    NetworkStatusService.instance.reset();
  });

  tearDown(() {
    NetworkStatusService.instance.reset();
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        home: NetworkStatusOverlay(
          child: Scaffold(
            body: Center(child: Text('App Main Screen')),
          ),
        ),
      ),
    );
  }

  testWidgets('renders child content normally when online', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('App Main Screen'), findsOneWidget);
    expect(find.text('Slow Internet Detected'), findsNothing);
  });

  testWidgets('displays Slow Internet popup when slow connection occurs',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    NetworkStatusService.instance.simulateSlowConnection();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Slow Internet Detected'), findsOneWidget);
    expect(find.text('SLOW'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering_error_rounded), findsOneWidget);
  });

  testWidgets('tapping dismiss hides the slow internet popup', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    NetworkStatusService.instance.simulateSlowConnection();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Slow Internet Detected'), findsOneWidget);

    final dismissButton = find.byTooltip('Dismiss');
    expect(dismissButton, findsOneWidget);

    await tester.tap(dismissButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(NetworkStatusService.instance.value.userDismissed, isTrue);
  });

  testWidgets('tapping retry triggers callback and clears dismissed state',
      (tester) async {
    var retryCalled = false;
    NetworkStatusService.instance.onRetryCallback = () => retryCalled = true;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    NetworkStatusService.instance.simulateSlowConnection();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final retryButton = find.byTooltip('Retry connection');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(retryCalled, isTrue);
  });
}
