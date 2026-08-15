import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/saved_destination.dart';
import '../providers/journey_provider.dart';

class JourneySetupScreen extends ConsumerStatefulWidget {
  final SavedDestination? destination;

  const JourneySetupScreen({super.key, this.destination});

  @override
  ConsumerState<JourneySetupScreen> createState() => _JourneySetupScreenState();
}

class _JourneySetupScreenState extends ConsumerState<JourneySetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  double _radiusMeters = 500;
  DateTime? _earliestArrival;
  late double _destinationLatitude;
  late double _destinationLongitude;

  @override
  void initState() {
    super.initState();
    _destinationLatitude = widget.destination?.latitude ?? SavedDestination.defaultLatitude;
    _destinationLongitude = widget.destination?.longitude ?? SavedDestination.defaultLongitude;
    _nameController.text = widget.destination?.name ?? 'My destination';
  }

  Future<void> _pickArrivalTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );

    if (!mounted || time == null) return;

    setState(() {
      _earliestArrival = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination ??
        SavedDestination(
          name: 'Custom destination',
          latitude: _destinationLatitude,
          longitude: _destinationLongitude,
          lastUsedAt: DateTime.now(),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Journey setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Destination',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Journey name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.destination == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _destinationLatitude.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null) {
                            setState(() => _destinationLatitude = parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _destinationLongitude.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null) {
                            setState(() => _destinationLongitude = parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Text('Alert radius: ${_radiusMeters.round()} m'),
              Slider(
                min: 100,
                max: 2000,
                value: _radiusMeters,
                divisions: 19,
                onChanged: (value) => setState(() => _radiusMeters = value),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Earliest arrival time (optional)'),
                subtitle: Text(
                  _earliestArrival == null
                      ? 'No time constraint'
                      : _earliestArrival!.toLocal().toString(),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: _pickArrivalTime,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Checklist'),
                      SizedBox(height: 8),
                      Text('• Location permission enabled'),
                      Text('• Background location allowed'),
                      Text('• Battery optimization excluded'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final notifier = ref.read(journeyProvider.notifier);
                  await notifier.startJourney(
                    name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : destination.name,
                    latitude: widget.destination?.latitude ?? _destinationLatitude,
                    longitude: widget.destination?.longitude ?? _destinationLongitude,
                    radiusMeters: _radiusMeters,
                    earliestArrivalTime: _earliestArrival,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start monitoring'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
