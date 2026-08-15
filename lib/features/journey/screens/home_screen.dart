import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../domain/models/journey.dart';
import '../../../services/storage_service.dart';
import '../providers/journey_provider.dart';
import 'active_monitoring_screen.dart';
import 'destination_select_screen.dart';
import 'journey_setup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Stop Alarm'),
        actions: [
          IconButton(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.security_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (journey != null)
                _JourneyStatusCard(journey: journey)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No active journey',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        const Text('Set a destination and start smart monitoring.'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final destination = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DestinationSelectScreen(),
                              ),
                            );

                            if (destination != null && context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => JourneySetupScreen(destination: destination),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Plan a journey'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final destination = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DestinationSelectScreen(),
                          ),
                        );

                        if (destination != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JourneySetupScreen(destination: destination),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Choose destination'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (journey != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ActiveMonitoringScreen()),
                          );
                        }
                      },
                      icon: const Icon(Icons.route),
                      label: const Text('Monitor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Saved destinations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FutureBuilder(
                future: StorageService.instance.getAllSavedDestinations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final destinations = snapshot.data ?? <dynamic>[];
                  if (destinations.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No saved destinations yet.'),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final destination = destinations[index] as dynamic;
                      return ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(destination.name),
                        subtitle: Text(
                          '${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}',
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JourneySetupScreen(destination: destination),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyStatusCard extends StatelessWidget {
  final Journey journey;

  const _JourneyStatusCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Text('Radius: ${journey.radiusMeters.round()} m'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActiveMonitoringScreen()),
                );
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Open journey'),
            ),
          ],
        ),
      ),
    );
  }
}
