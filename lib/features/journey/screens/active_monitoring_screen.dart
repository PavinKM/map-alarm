import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/logic/journey_state_machine.dart';
import '../../../domain/models/journey.dart';
import '../providers/journey_provider.dart';
import 'alarm_screen.dart';

class ActiveMonitoringScreen extends ConsumerWidget {
  const ActiveMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyProvider);

    if (journey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monitoring')),
        body: const Center(child: Text('No active journey')),
      );
    }

    if (journey.status == JourneyStatus.alarmTriggered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AlarmScreen()),
          );
        }
      });
    }

    final lastLat = journey.lastKnownLat ?? journey.latitude;
    final lastLng = journey.lastKnownLng ?? journey.longitude;
    final distanceMeters = JourneyStateMachine.calculateDistance(
      lastLat,
      lastLng,
      journey.latitude,
      journey.longitude,
    );
    final progressValue = journey.radiusMeters <= 0
        ? 0.0
        : ((journey.radiusMeters - distanceMeters) / journey.radiusMeters)
            .clamp(0.0, 1.0)
            .toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Active monitoring')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journey.destinationName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${journey.status.name}'),
                      Text('Remaining: ${distanceMeters.round()} m'),
                      if (journey.earliestArrivalTime != null)
                        Text(
                          'Earliest: ${journey.earliestArrivalTime!.toLocal().toString()}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progressValue,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(journeyProvider.notifier).cancelJourney();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(journeyProvider.notifier).completeJourney();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.done),
                      label: const Text('Complete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
