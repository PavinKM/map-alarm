import 'package:flutter_test/flutter_test.dart';
import 'package:map_app/domain/logic/journey_state_machine.dart';
import 'package:map_app/domain/models/journey.dart';

void main() {
  group('Distance calculation (Haversine)', () {
    test('Calculates distance between two known coordinates', () {
      // Chennai Central to Koyambedu Metro (~9.6 km)
      final centralLat = 13.0827;
      final centralLng = 80.2707;
      final koyambeduLat = 13.0732;
      final koyambeduLng = 80.1945;

      final dist = JourneyStateMachine.calculateDistance(
        centralLat,
        centralLng,
        koyambeduLat,
        koyambeduLng,
      );

      // Verify it's around 8.2 km - 8.3 km straight-line distance
      expect(dist / 1000, closeTo(8.28, 0.2));
    });
  });

  group('JourneyStateMachine Transitions', () {
    late Journey testJourney;
    final double destLat = 13.0732;
    final double destLng = 80.1945;
    final double startLat = 13.1500;
    final double startLng = 80.4000; // Far away (>25 km)

    setUp(() {
      testJourney = Journey(
        id: 1,
        destinationName: 'Koyambedu',
        latitude: destLat,
        longitude: destLng,
        radiusMeters: 500.0,
        status: JourneyStatus.waitingForEarliestArrival,
        startedAt: DateTime(2026, 8, 15, 12, 0),
        earliestArrivalTime: DateTime(2026, 8, 15, 13, 0),
      );
    });

    test('Status remains waitingForEarliestArrival before the earliest arrival time', () {
      final fix = PositionFix(
        latitude: startLat,
        longitude: startLng,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 12, 30), // before 13:00
      );

      final result = JourneyStateMachine.processLocation(testJourney, fix, []);
      expect(result.journey.status, JourneyStatus.waitingForEarliestArrival);
      expect(result.action, StateMachineAction.none);
    });

    test('Transitions to occasionalChecks after earliest arrival time if distance is > 20km', () {
      final fix = PositionFix(
        latitude: startLat,
        longitude: startLng,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 5), // after 13:00
      );

      final result = JourneyStateMachine.processLocation(testJourney, fix, []);
      expect(result.journey.status, JourneyStatus.occasionalChecks);
      expect(result.journey.nextScheduledCheckAt, isNotNull);
      expect(result.action, StateMachineAction.none);
    });

    test('Transitions directly to activeMonitoring if earliest arrival time is met and distance <= 20km', () {
      // 13.0827, 80.2707 is ~8.2km away from destination (<= 20km)
      final fix = PositionFix(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 5),
      );

      final result = JourneyStateMachine.processLocation(testJourney, fix, []);
      expect(result.journey.status, JourneyStatus.activeMonitoring);
      expect(result.journey.nextScheduledCheckAt, isNull);
    });

    test('Transitions from occasionalChecks to activeMonitoring when crossing 20km', () {
      final journeyInChecks = testJourney.copyWith(status: JourneyStatus.occasionalChecks);

      final fix = PositionFix(
        latitude: 13.0827,
        longitude: 80.2707, // ~8.2km away
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 10),
      );

      final result = JourneyStateMachine.processLocation(journeyInChecks, fix, []);
      expect(result.journey.status, JourneyStatus.activeMonitoring);
    });

    test('Transitions from activeMonitoring to preAlertSent when crossing 8km', () {
      final journeyInActive = testJourney.copyWith(status: JourneyStatus.activeMonitoring);

      // Chennai Central is ~8.28km away (still activeMonitoring)
      var fix = PositionFix(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 15),
      );
      var result = JourneyStateMachine.processLocation(journeyInActive, fix, []);
      expect(result.journey.status, JourneyStatus.activeMonitoring);

      // Move to a spot closer, e.g. ~7.0km away
      // Koyambedu is 13.0732, 80.1945. Aminjikarai is ~13.075, 80.220 (~2.7km)
      fix = PositionFix(
        latitude: 13.075,
        longitude: 80.220,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 16),
      );
      result = JourneyStateMachine.processLocation(journeyInActive, fix, []);
      expect(result.journey.status, JourneyStatus.preAlertSent);
      expect(result.action, StateMachineAction.triggerPreAlert);
    });

    test('Enforces hysteresis when moving back out of pre-alert radius (>9km)', () {
      final journeyInPreAlert = testJourney.copyWith(status: JourneyStatus.preAlertSent);

      // Move back out to Chennai Central (~8.28km) - should remain in preAlertSent due to hysteresis
      var fix = PositionFix(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 20),
      );
      var result = JourneyStateMachine.processLocation(journeyInPreAlert, fix, []);
      expect(result.journey.status, JourneyStatus.preAlertSent);

      // Move way out (>25km) - should drop back to activeMonitoring
      fix = PositionFix(
        latitude: startLat,
        longitude: startLng,
        accuracy: 10.0,
        timestamp: DateTime(2026, 8, 15, 13, 21),
      );
      result = JourneyStateMachine.processLocation(journeyInPreAlert, fix, []);
      expect(result.journey.status, JourneyStatus.activeMonitoring);
    });

    test('Transitions from preAlertSent to finalApproach when crossing destination radius', () {
      final journeyInPreAlert = testJourney.copyWith(status: JourneyStatus.preAlertSent);

      // Destination is 13.0732, 80.1945. Alert radius is 500m.
      // 13.0730, 80.1950 is ~70 meters away (inside radius)
      final fix = PositionFix(
        latitude: 13.0730,
        longitude: 80.1950,
        accuracy: 5.0,
        timestamp: DateTime(2026, 8, 15, 13, 25),
      );

      final result = JourneyStateMachine.processLocation(journeyInPreAlert, fix, []);
      expect(result.journey.status, JourneyStatus.finalApproach);
    });

    test('Triggers final alarm only after debouncing and verifying approach trend', () {
      final journeyInApproach = testJourney.copyWith(status: JourneyStatus.finalApproach);

      // Simulating history:
      // Point 1: 13.0750, 80.1980 (~250m)
      // Point 2: 13.0740, 80.1960 (~150m) - getting closer
      // Current Point: 13.0732, 80.1946 (~10m) - inside and approaching
      final history = [
        PositionFix(latitude: 13.0750, longitude: 80.1980, accuracy: 5.0, timestamp: DateTime(2026, 8, 15, 13, 26, 0)),
        PositionFix(latitude: 13.0740, longitude: 80.1960, accuracy: 5.0, timestamp: DateTime(2026, 8, 15, 13, 26, 5)),
      ];

      final currentFix = PositionFix(
        latitude: 13.0732,
        longitude: 80.1946,
        accuracy: 5.0,
        timestamp: DateTime(2026, 8, 15, 13, 26, 10),
      );

      final result = JourneyStateMachine.processLocation(journeyInApproach, currentFix, history);
      expect(result.journey.status, JourneyStatus.alarmTriggered);
      expect(result.action, StateMachineAction.triggerAlarm);
    });

    test('Bypasses approach trend check if extremely close to target (< 150m)', () {
      final journeyInApproach = testJourney.copyWith(status: JourneyStatus.finalApproach);

      // Simulating a history where we are moving away slightly but are very close
      // Point 1: 13.0732, 80.1945 (0m)
      // Current Point: 13.0732, 80.1950 (~50m) - moving away slightly, but inside 150m
      final history = [
        PositionFix(latitude: 13.0732, longitude: 80.1945, accuracy: 5.0, timestamp: DateTime(2026, 8, 15, 13, 25, 55)),
        PositionFix(latitude: 13.0732, longitude: 80.1945, accuracy: 5.0, timestamp: DateTime(2026, 8, 15, 13, 26, 0)),
      ];

      final currentFix = PositionFix(
        latitude: 13.0732,
        longitude: 80.1950,
        accuracy: 5.0,
        timestamp: DateTime(2026, 8, 15, 13, 26, 5),
      );

      final result = JourneyStateMachine.processLocation(journeyInApproach, currentFix, history);
      expect(result.journey.status, JourneyStatus.alarmTriggered);
      expect(result.action, StateMachineAction.triggerAlarm);
    });
  });

  group('Reboot and state recovery', () {
    test('Serializes and deserializes Journey state correctly', () {
      final original = Journey(
        id: 42,
        destinationName: 'Work',
        latitude: 12.9716,
        longitude: 77.5946,
        radiusMeters: 1000.0,
        status: JourneyStatus.activeMonitoring,
        startedAt: DateTime(2026, 8, 15, 8, 0),
        activeMonitoringEnteredAt: DateTime(2026, 8, 15, 8, 30),
      );

      final serialized = original.toMap();
      final deserialized = Journey.fromMap(serialized);

      expect(deserialized.id, original.id);
      expect(deserialized.destinationName, original.destinationName);
      expect(deserialized.latitude, original.latitude);
      expect(deserialized.longitude, original.longitude);
      expect(deserialized.radiusMeters, original.radiusMeters);
      expect(deserialized.status, original.status);
      expect(deserialized.startedAt, original.startedAt);
      expect(deserialized.activeMonitoringEnteredAt, original.activeMonitoringEnteredAt);
    });
  });
}
