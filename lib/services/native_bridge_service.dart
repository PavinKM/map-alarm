import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/logic/journey_state_machine.dart';

class NativeBridgeService {
  static const MethodChannel _channel = MethodChannel('com.example.map_app/native_bridge');
  static const EventChannel _eventChannel = EventChannel('com.example.map_app/location_events');

  // Singleton instance
  static final NativeBridgeService instance = NativeBridgeService._();
  NativeBridgeService._();

  static Stream<PositionFix>? _locationUpdates;

  static Stream<PositionFix> get locationUpdates {
    _locationUpdates ??= _eventChannel.receiveBroadcastStream().map((event) {
      final map = event as Map;
      final timestampMs = (map['timestampMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      return PositionFix(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num? ?? 0).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      );
    });
    return _locationUpdates!;
  }

  /// Starts the native Android location foreground service with a persistent notification
  Future<void> startForegroundService({
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
    required double radiusMeters,
  }) async {
    try {
      await _channel.invokeMethod('startForegroundService', {
        'destinationName': destinationName,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'radiusMeters': radiusMeters,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to start native foreground service: ${e.message}');
    }
  }

  /// Stops the native Android location foreground service
  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop native foreground service: ${e.message}');
    }
  }

  /// Schedules a time-based check wake-up via AlarmManager.setExactAndAllowWhileIdle
  Future<void> scheduleNextCheck(DateTime scheduledTime, int journeyId) async {
    try {
      await _channel.invokeMethod('scheduleNextCheck', {
        'timestampMs': scheduledTime.millisecondsSinceEpoch,
        'journeyId': journeyId,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to schedule AlarmManager check: ${e.message}');
    }
  }

  /// Cancels all pending AlarmManager check wake-ups scheduled by this app
  Future<void> cancelScheduledChecks() async {
    try {
      await _channel.invokeMethod('cancelScheduledChecks');
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel AlarmManager checks: ${e.message}');
    }
  }

  /// Triggers the native AlarmActivity (full-screen overlay above lockscreen)
  Future<void> launchAlarmActivity(String destinationName) async {
    try {
      await _channel.invokeMethod('launchAlarmActivity', {
        'destinationName': destinationName,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to launch AlarmActivity: ${e.message}');
    }
  }

  /// Starts the alarm audio loop on STREAM_ALARM
  Future<void> startAlarmAudio() async {
    try {
      await _channel.invokeMethod('startAlarmAudio');
    } on PlatformException catch (e) {
      debugPrint('Failed to start alarm audio: ${e.message}');
    }
  }

  /// Stops the alarm audio loop and vibrations
  Future<void> stopAlarmAudio() async {
    try {
      await _channel.invokeMethod('stopAlarmAudio');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop alarm audio: ${e.message}');
    }
  }

  /// Fires a user-facing "Get Ready" soft notification and short vibration
  Future<void> firePreAlertNotification(String destinationName, double distanceKm) async {
    try {
      await _channel.invokeMethod('firePreAlertNotification', {
        'destinationName': destinationName,
        'distanceKm': distanceKm,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to fire pre-alert notification: ${e.message}');
    }
  }

  /// Returns whether battery optimizations are currently ignored for this app
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool? result = await _channel.invokeMethod('isBatteryOptimizationIgnored');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check battery optimization state: ${e.message}');
      return false;
    }
  }

  /// Requests the user to disable battery optimizations, deep-linking to system settings
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (e) {
      debugPrint('Failed to request ignore battery optimization: ${e.message}');
    }
  }
}
