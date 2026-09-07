import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/features/screen_time/data/telemetry_repository.dart';

/// Telemetry logger service for client-side events.
class TelemetryService with WidgetsBindingObserver {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  late WidgetRef _ref;
  bool _initialized = false;
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  DateTime? _appSessionStart;

  // Track active tab view time
  String? _currentTab;
  DateTime? _tabStartTime;

  void initialize(WidgetRef ref) {
    if (_initialized) return;
    _ref = ref;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);
    _appSessionStart = DateTime.now();

    // Periodically flush events every 30 seconds
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());

    logEvent('login_activity', {'status': 'session_start'});
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    flush();
  }

  /// Appends a new telemetry log to the buffer.
  void logEvent(String eventType, Map<String, dynamic> details) {
    final event = {
      'event_type': eventType,
      'details': details,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    };
    _buffer.add(event);

    // Immediate flush if buffer reaches 20 events
    if (_buffer.length >= 20) {
      flush();
    }
  }

  /// Logs a button click event.
  void logButtonClick(String buttonId, String screenName) {
    logEvent('button_click', {
      'button_id': buttonId,
      'screen': screenName,
    });
  }

  /// Logs when the user switches tabs.
  void logTabSwitch(String fromTab, String toTab) {
    final now = DateTime.now();
    if (_currentTab != null && _tabStartTime != null) {
      final seconds = now.difference(_tabStartTime!).inSeconds;
      logEvent('tab_view_time', {
        'tab': _currentTab,
        'duration_seconds': seconds,
      });
    }
    _currentTab = toTab;
    _tabStartTime = now;
    logEvent('tab_switch', {
      'from_tab': fromTab,
      'to_tab': toTab,
    });
  }

  /// Flush all buffered events to the backend.
  Future<void> flush() async {
    if (_buffer.isEmpty || !_initialized) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      final repo = _ref.read(telemetryRepositoryProvider);
      await repo.sendEvents(eventsToSend);
    } catch (_) {
      // Re-insert failed logs back to buffer (prepend)
      _buffer.insertAll(0, eventsToSend);
    }
  }

  // ── WidgetsBindingObserver Implementation ─────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App went to background
        if (_appSessionStart != null) {
          final seconds = now.difference(_appSessionStart!).inSeconds;
          logEvent('app_lifecycle', {
            'state': 'background',
            'duration_seconds': seconds,
          });
        }
        logEvent('app_switch', {'event': 'app_paused'});
        flush(); // Flush immediately on backgrounding
        break;
      case AppLifecycleState.resumed:
        // App returned to foreground
        _appSessionStart = now;
        _tabStartTime = now;
        logEvent('app_lifecycle', {'state': 'foreground'});
        logEvent('app_switch', {'event': 'app_resumed'});
        break;
      default:
        break;
    }
  }
}
