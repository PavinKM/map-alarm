import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/journey.dart';
import '../providers/journey_provider.dart';
import 'home_screen.dart';

class AlarmScreen extends ConsumerWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyProvider);

    if (journey == null || journey.status != JourneyStatus.alarmTriggered) {
      return const Scaffold(
        body: Center(child: Text('No active alarm')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, size: 120, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'STOP',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You are near ${journey.destinationName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 52),
                ),
                onPressed: () {
                  ref.read(journeyProvider.notifier).stopAlarm();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.stop_circle),
                label: const Text('Stop alarm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
