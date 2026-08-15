import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/logic/journey_state_machine.dart';
import '../../../domain/models/journey.dart';
import '../../../services/native_bridge_service.dart';
import '../../../services/storage_service.dart';

final journeyProvider = StateNotifierProvider<JourneyNotifier, Journey?>((ref) {
  return JourneyNotifier();
});

class JourneyNotifier extends StateNotifier<Journey?> {
  final List<PositionFix> _history = [];
  StreamSubscription<PositionFix>? _locationSubscription;

  JourneyNotifier() : super(null) {
    _listenToLocationUpdates();
    loadActiveJourney();
  }

  void _listenToLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = NativeBridgeService.locationUpdates.listen(
      (fix) async {
        if (state == null) return;
        await handleLocationUpdate(
          latitude: fix.latitude,
          longitude: fix.longitude,
          accuracy: fix.accuracy,
          timestamp: fix.timestamp,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  List<PositionFix> get history => List.unmodifiable(_history);

  /// Loads the active journey from local SQLite database (for app startup or reboot recovery)
  Future<void> loadActiveJourney() async {
    final active = await StorageService.instance.getActiveJourney();
    if (active != null) {
      state = active;
      _history.clear();
      _listenToLocationUpdates();
      // If we recovered a journey, make sure we resume the monitoring state
      _resumeMonitoring(active);
    }
  }

  /// Starts a new tracking journey
  Future<void> startJourney({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    DateTime? earliestArrivalTime,
    double preAlertDistanceMeters = 8000.0,
    double activeMonitoringThresholdMeters = 20000.0,
  }) async {
    // If there is already an active journey, cancel it first
    if (state != null) {
      await cancelJourney();
    }

    final now = DateTime.now();
    JourneyStatus initialStatus;

    if (earliestArrivalTime != null && earliestArrivalTime.isAfter(now)) {
      initialStatus = JourneyStatus.waitingForEarliestArrival;
    } else {
      initialStatus = JourneyStatus.occasionalChecks;
    }

    final newJourney = Journey(
      destinationName: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      earliestArrivalTime: earliestArrivalTime,
      preAlertDistanceMeters: preAlertDistanceMeters,
      activeMonitoringThresholdMeters: activeMonitoringThresholdMeters,
      status: initialStatus,
      startedAt: now,
    );

    final id = await StorageService.instance.insertJourney(newJourney);
    final savedJourney = newJourney.copyWith(id: id);
    state = savedJourney;
    _history.clear();
    _listenToLocationUpdates();

    await _resumeMonitoring(savedJourney);
  }

  /// Resumes native-side triggers based on current journey state
  Future<void> _resumeMonitoring(Journey journey) async {
    final now = DateTime.now();

    if (journey.status == JourneyStatus.waitingForEarliestArrival) {
      if (journey.earliestArrivalTime != null) {
        await NativeBridgeService.instance.scheduleNextCheck(
          journey.earliestArrivalTime!,
          journey.id!,
        );
      }
    } else if (journey.status == JourneyStatus.occasionalChecks) {
      // Schedule occasional checks ~10 minutes
      final scheduledTime = now.add(const Duration(minutes: 10));
      state = journey.copyWith(nextScheduledCheckAt: scheduledTime);
      await StorageService.instance.updateJourney(state!);
      await NativeBridgeService.instance.scheduleNextCheck(scheduledTime, journey.id!);
    } else if (journey.status == JourneyStatus.activeMonitoring ||
        journey.status == JourneyStatus.preAlertSent ||
        journey.status == JourneyStatus.finalApproach) {
      // We are within 20km (or fallback active), start the location Foreground Service
      await NativeBridgeService.instance.startForegroundService(
        destinationName: journey.destinationName,
        destinationLat: journey.latitude,
        destinationLng: journey.longitude,
        radiusMeters: journey.radiusMeters,
      );
    } else if (journey.status == JourneyStatus.alarmTriggered) {
      // Re-trigger alarm UI if we recover into alarmTriggered state
      await NativeBridgeService.instance.startAlarmAudio();
      await NativeBridgeService.instance.launchAlarmActivity(journey.destinationName);
    }
  }

  /// Cancels the current journey
  Future<void> cancelJourney() async {
    if (state == null) return;

    await NativeBridgeService.instance.stopForegroundService();
    await NativeBridgeService.instance.cancelScheduledChecks();
    await NativeBridgeService.instance.stopAlarmAudio();

    final updated = state!.copyWith(
      status: JourneyStatus.cancelled,
      stoppedAt: DateTime.now(),
    );
    await StorageService.instance.updateJourney(updated);

    _locationSubscription?.cancel();
    _locationSubscription = null;
    state = null;
    _history.clear();
  }

  /// Marks the current journey completed
  Future<void> completeJourney() async {
    if (state == null) return;

    await NativeBridgeService.instance.stopForegroundService();
    await NativeBridgeService.instance.cancelScheduledChecks();
    await NativeBridgeService.instance.stopAlarmAudio();

    final updated = state!.copyWith(
      status: JourneyStatus.journeyCompleted,
      stoppedAt: DateTime.now(),
    );
    await StorageService.instance.updateJourney(updated);

    _locationSubscription?.cancel();
    _locationSubscription = null;
    state = null;
    _history.clear();
  }

  /// Stops alarm audio playback and marks journey completed
  Future<void> stopAlarm() async {
    await NativeBridgeService.instance.stopAlarmAudio();
    await completeJourney();
  }

  /// Core location update handler called from platform channel triggers or Geolocator streams
  Future<void> handleLocationUpdate({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) async {
    if (state == null) return;

    final fix = PositionFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: timestamp,
    );

    // Run state machine
    final result = JourneyStateMachine.processLocation(state!, fix, _history);

    // Keep history bounded to last 15 elements
    _history.add(fix);
    if (_history.length > 15) {
      _history.removeAt(0);
    }

    // Persist updated journey to local DB
    await StorageService.instance.updateJourney(result.journey);

    // Update state to trigger UI rebuilds
    final oldStatus = state!.status;
    state = result.journey;

    // Handle transition side-effects
    if (result.action == StateMachineAction.triggerPreAlert) {
      final double distanceKm = JourneyStateMachine.calculateDistance(
        latitude,
        longitude,
        result.journey.latitude,
        result.journey.longitude,
      ) / 1000.0;
      await NativeBridgeService.instance.firePreAlertNotification(
        result.journey.destinationName,
        distanceKm,
      );
    } else if (result.action == StateMachineAction.triggerAlarm) {
      await NativeBridgeService.instance.startAlarmAudio();
      await NativeBridgeService.instance.launchAlarmActivity(result.journey.destinationName);
    }

    // Handle scheduling transition changes
    if (result.journey.status == JourneyStatus.activeMonitoring &&
        oldStatus != JourneyStatus.activeMonitoring) {
      // Transitioned into active monitoring (e.g. crossed 20km or buffer elapsed)
      // Cancel AlarmManager checks, and launch Foreground Service
      await NativeBridgeService.instance.cancelScheduledChecks();
      await NativeBridgeService.instance.startForegroundService(
        destinationName: result.journey.destinationName,
        destinationLat: result.journey.latitude,
        destinationLng: result.journey.longitude,
        radiusMeters: result.journey.radiusMeters,
      );
    } else if (result.journey.status == JourneyStatus.occasionalChecks ||
        result.journey.status == JourneyStatus.waitingForEarliestArrival) {
      // Make sure next AlarmManager check is scheduled
      if (result.journey.nextScheduledCheckAt != null) {
        await NativeBridgeService.instance.scheduleNextCheck(
          result.journey.nextScheduledCheckAt!,
          result.journey.id!,
        );
      }
    }
  }
}
