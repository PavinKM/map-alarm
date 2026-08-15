import 'dart:math';
import '../models/journey.dart';

class PositionFix {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  PositionFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PositionFix.fromMap(Map<String, dynamic> map) {
    return PositionFix(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

enum StateMachineAction {
  none,
  triggerPreAlert,
  triggerAlarm,
}

class StateMachineResult {
  final Journey journey;
  final StateMachineAction action;

  StateMachineResult(this.journey, this.action);
}

class JourneyStateMachine {
  // Constant thresholds
  static const double activeThresholdMeters = 20000.0; // 20 km
  static const double preAlertThresholdMeters = 8000.0; // 8 km
  static const double hysteresisMeters = 1000.0; // 1 km buffer for moving back out

  /// Calculates the Haversine distance in meters between two points.
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // pi / 180
    final double a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
        (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R; R = 6371000 m
  }

  /// Processes a new location fix and returns the updated Journey and any action to trigger.
  /// [history] represents recent location fixes inside the active phase for trend & debounce calculation.
  static StateMachineResult processLocation(
    Journey journey,
    PositionFix fix,
    List<PositionFix> history,
  ) {
    // If the journey is already in a terminal state, do not change it
    if (journey.status == JourneyStatus.journeyCompleted ||
        journey.status == JourneyStatus.cancelled) {
      return StateMachineResult(journey, StateMachineAction.none);
    }

    final double distance = calculateDistance(
      fix.latitude,
      fix.longitude,
      journey.latitude,
      journey.longitude,
    );

    JourneyStatus newStatus = journey.status;
    StateMachineAction action = StateMachineAction.none;

    DateTime? nextScheduledCheckAt = journey.nextScheduledCheckAt;
    DateTime? activeMonitoringEnteredAt = journey.activeMonitoringEnteredAt;
    DateTime? preAlertSentAt = journey.preAlertSentAt;
    DateTime? triggeredAt = journey.triggeredAt;

    switch (journey.status) {
      case JourneyStatus.waitingForEarliestArrival:
        final now = fix.timestamp;
        final hasTimePassed = journey.earliestArrivalTime == null ||
            now.isAfter(journey.earliestArrivalTime!);

        if (hasTimePassed) {
          if (distance <= activeThresholdMeters) {
            newStatus = JourneyStatus.activeMonitoring;
            activeMonitoringEnteredAt = now;
            nextScheduledCheckAt = null; // No longer scheduled, FGS will take over
          } else {
            newStatus = JourneyStatus.occasionalChecks;
            // Schedule check for ~10 minutes from now
            nextScheduledCheckAt = now.add(const Duration(minutes: 10));
          }
        }
        break;

      case JourneyStatus.occasionalChecks:
        if (distance <= activeThresholdMeters) {
          newStatus = JourneyStatus.activeMonitoring;
          activeMonitoringEnteredAt = fix.timestamp;
          nextScheduledCheckAt = null;
        } else {
          // Keep scheduling occasional checks (~10 minutes)
          nextScheduledCheckAt = fix.timestamp.add(const Duration(minutes: 10));
        }
        break;

      case JourneyStatus.activeMonitoring:
        if (distance <= preAlertThresholdMeters) {
          newStatus = JourneyStatus.preAlertSent;
          preAlertSentAt = fix.timestamp;
          action = StateMachineAction.triggerPreAlert;
        } else if (distance > activeThresholdMeters + hysteresisMeters) {
          // Moved back out, drop down to occasional checks if Earliest Arrival is configured
          if (journey.earliestArrivalTime != null) {
            newStatus = JourneyStatus.occasionalChecks;
            nextScheduledCheckAt = fix.timestamp.add(const Duration(minutes: 10));
            activeMonitoringEnteredAt = null;
          }
        }
        break;

      case JourneyStatus.preAlertSent:
        if (distance <= journey.radiusMeters) {
          newStatus = JourneyStatus.finalApproach;
        } else if (distance > preAlertThresholdMeters + hysteresisMeters) {
          // Moved back out, reset to active monitoring state
          newStatus = JourneyStatus.activeMonitoring;
          preAlertSentAt = null;
        }
        break;

      case JourneyStatus.finalApproach:
        if (distance > journey.radiusMeters + hysteresisMeters) {
          // Jumped/moved back out of alarm radius
          newStatus = JourneyStatus.preAlertSent;
        } else {
          // Evaluate debounce and distance trend
          final bool isDebounced = evaluateDebounceWithTarget(
            journey.latitude,
            journey.longitude,
            journey.radiusMeters,
            history,
            fix,
          );
          final bool isApproaching = _evaluateTrend(journey.latitude, journey.longitude, history, fix);

          if (isDebounced && isApproaching) {
            newStatus = JourneyStatus.alarmTriggered;
            triggeredAt = fix.timestamp;
            action = StateMachineAction.triggerAlarm;
          }
        }
        break;

      case JourneyStatus.alarmTriggered:
        // Handled via explicit user "Stop Alarm" action
        break;

      case JourneyStatus.journeyCompleted:
      case JourneyStatus.cancelled:
        break;
    }

    final updatedJourney = journey.copyWith(
      status: newStatus,
      nextScheduledCheckAt: nextScheduledCheckAt,
      activeMonitoringEnteredAt: activeMonitoringEnteredAt,
      preAlertSentAt: preAlertSentAt,
      triggeredAt: triggeredAt,
      lastKnownLat: fix.latitude,
      lastKnownLng: fix.longitude,
      lastKnownAccuracy: fix.accuracy,
      lastKnownTimestamp: fix.timestamp,
    );

    return StateMachineResult(updatedJourney, action);
  }


  /// Evaluates debounce with destination context.
  static bool evaluateDebounceWithTarget(
    double destinationLat,
    double destinationLng,
    double radius,
    List<PositionFix> history,
    PositionFix currentFix,
  ) {
    final allFixes = [...history, currentFix];
    if (allFixes.isEmpty) return false;

    // Count how many consecutive recent fixes are inside the radius
    int consecutiveInsideCount = 0;
    DateTime? firstInsideTime;

    for (int i = allFixes.length - 1; i >= 0; i--) {
      final f = allFixes[i];
      final d = calculateDistance(f.latitude, f.longitude, destinationLat, destinationLng);
      if (d <= radius) {
        consecutiveInsideCount++;
        firstInsideTime = f.timestamp;
      } else {
        // Broke the consecutive streak
        break;
      }
    }

    if (consecutiveInsideCount >= 3) {
      return true;
    }

    if (firstInsideTime != null) {
      final durationInside = currentFix.timestamp.difference(firstInsideTime);
      if (durationInside >= const Duration(seconds: 15)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if the distance to target is generally decreasing (approaching).
  static bool _evaluateTrend(
    double destLat,
    double destLng,
    List<PositionFix> history,
    PositionFix currentFix,
  ) {
    final allFixes = [...history, currentFix];
    if (allFixes.length < 2) return true; // Not enough history to confirm a trend, assume true for safety

    // Calculate distances for the last few fixes (up to 5)
    final recentFixes = allFixes.length > 5 ? allFixes.sublist(allFixes.length - 5) : allFixes;
    final distances = recentFixes.map((f) => calculateDistance(f.latitude, f.longitude, destLat, destLng)).toList();

    // Check if we are approaching. A simple trend calculation:
    // If the latest distance is smaller than the distance 2 or 3 samples ago, or if it is generally decreasing.
    // We allow a small noise margin.
    double netChange = distances.last - distances.first;
    
    // If net change is negative, we are getting closer.
    // Or if the distance is extremely small (e.g. less than 150m), we bypass the trend check to prevent missing the stop.
    if (distances.last < 150.0) {
      return true;
    }

    return netChange <= 0;
  }

}
