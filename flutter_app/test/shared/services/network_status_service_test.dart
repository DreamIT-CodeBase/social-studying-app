import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/shared/services/network_status_service.dart';

void main() {
  setUp(() {
    NetworkStatusService.instance.reset();
  });

  tearDown(() {
    NetworkStatusService.instance.reset();
  });

  group('NetworkStatusService', () {
    test('initial state is online with no issues', () {
      final state = NetworkStatusService.instance.value;
      expect(state.status, NetworkStatus.online);
      expect(state.isSlow, isFalse);
      expect(state.isOffline, isFalse);
      expect(state.hasIssues, isFalse);
    });

    test('manual slow connection triggers slow state', () {
      NetworkStatusService.instance.simulateSlowConnection();
      final state = NetworkStatusService.instance.value;
      expect(state.status, NetworkStatus.slow);
      expect(state.isSlow, isTrue);
      expect(state.hasIssues, isTrue);
      expect(state.message, contains('Slow internet'));
    });

    test('manual offline triggers offline state', () {
      NetworkStatusService.instance.reportOffline(message: 'No internet');
      final state = NetworkStatusService.instance.value;
      expect(state.status, NetworkStatus.offline);
      expect(state.isOffline, isTrue);
      expect(state.hasIssues, isTrue);
      expect(state.message, 'No internet');
    });

    test('dismiss hides hasIssues until next update', () {
      NetworkStatusService.instance.simulateSlowConnection();
      expect(NetworkStatusService.instance.value.hasIssues, isTrue);

      NetworkStatusService.instance.dismiss();
      expect(NetworkStatusService.instance.value.userDismissed, isTrue);
      expect(NetworkStatusService.instance.value.hasIssues, isFalse);
    });

    test('retry clears userDismissed and invokes onRetryCallback', () {
      var retryCalled = false;
      NetworkStatusService.instance.onRetryCallback = () => retryCalled = true;

      NetworkStatusService.instance.simulateSlowConnection();
      NetworkStatusService.instance.dismiss();
      expect(NetworkStatusService.instance.value.userDismissed, isTrue);

      NetworkStatusService.instance.retry();
      expect(NetworkStatusService.instance.value.userDismissed, isFalse);
      expect(retryCalled, isTrue);
    });
  });
}
