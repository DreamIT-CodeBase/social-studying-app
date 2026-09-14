import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus {
  online,
  slow,
  offline,
}

@immutable
class NetworkStatusState {
  const NetworkStatusState({
    this.status = NetworkStatus.online,
    this.message,
    this.userDismissed = false,
    this.lastUpdated,
  });

  final NetworkStatus status;
  final String? message;
  final bool userDismissed;
  final DateTime? lastUpdated;

  bool get isSlow => status == NetworkStatus.slow && !userDismissed;
  bool get isOffline => status == NetworkStatus.offline && !userDismissed;
  bool get hasIssues => (isSlow || isOffline);

  NetworkStatusState copyWith({
    NetworkStatus? status,
    String? message,
    bool? userDismissed,
    DateTime? lastUpdated,
  }) {
    return NetworkStatusState(
      status: status ?? this.status,
      message: message ?? this.message,
      userDismissed: userDismissed ?? this.userDismissed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class NetworkStatusService extends ValueNotifier<NetworkStatusState> {
  NetworkStatusService._() : super(const NetworkStatusState());

  static final NetworkStatusService instance = NetworkStatusService._();

  static const Duration slowRequestThreshold = Duration(milliseconds: 3500);

  final Map<String, Timer> _pendingTimers = {};
  final Set<String> _activeSlowRequests = {};
  VoidCallback? onRetryCallback;

  void reportRequestStarted(String requestId, {String? url}) {
    _pendingTimers[requestId]?.cancel();

    _pendingTimers[requestId] = Timer(slowRequestThreshold, () {
      _activeSlowRequests.add(requestId);
      _updateStatus(
        NetworkStatus.slow,
        message:
            'Your internet connection is slow. We\'re keeping your study progress safe.',
      );
    });
  }

  void reportRequestFinished(String requestId) {
    _pendingTimers[requestId]?.cancel();
    _pendingTimers.remove(requestId);
    _activeSlowRequests.remove(requestId);

    if (_activeSlowRequests.isEmpty && value.status == NetworkStatus.slow) {
      _updateStatus(NetworkStatus.online);
    }
  }

  void reportSlowConnection({String? message}) {
    _updateStatus(
      NetworkStatus.slow,
      message: message ??
          'Your internet connection is slow. Please wait while content loads.',
    );
  }

  void reportOffline({String? message}) {
    _updateStatus(
      NetworkStatus.offline,
      message: message ??
          'No internet connection. Offline study content will be used.',
    );
  }

  void dismiss() {
    value = value.copyWith(userDismissed: true);
  }

  void retry() {
    value = value.copyWith(userDismissed: false);
    onRetryCallback?.call();
  }

  void simulateSlowConnection() {
    _updateStatus(
      NetworkStatus.slow,
      message:
          'Slow internet connection detected. Content is taking longer to load.',
    );
  }

  void reset() {
    _pendingTimers.forEach((_, timer) => timer.cancel());
    _pendingTimers.clear();
    _activeSlowRequests.clear();
    value = const NetworkStatusState();
  }

  void _updateStatus(NetworkStatus newStatus, {String? message}) {
    value = NetworkStatusState(
      status: newStatus,
      message: message,
      userDismissed: false,
      lastUpdated: DateTime.now(),
    );
  }
}

final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, NetworkStatusState>(
  NetworkStatusNotifier.new,
);

class NetworkStatusNotifier extends Notifier<NetworkStatusState> {
  VoidCallback? _removeListener;

  @override
  NetworkStatusState build() {
    final service = NetworkStatusService.instance;
    _removeListener?.call();
    void listener() {
      state = service.value;
    }

    service.addListener(listener);
    ref.onDispose(() {
      service.removeListener(listener);
    });

    return service.value;
  }

  void dismiss() => NetworkStatusService.instance.dismiss();
  void retry() => NetworkStatusService.instance.retry();
}
