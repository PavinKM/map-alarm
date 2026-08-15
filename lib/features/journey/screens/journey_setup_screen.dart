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
  late double _latitude;
  late double _longitude;

  @override
  void initState() {
    super.initState();
    _latitude = widget.destination?.latitude ?? SavedDestination.defaultLatitude;
    _longitude = widget.destination?.longitude ?? SavedDestination.defaultLongitude;
    _nameController.text = widget.destination?.name ?? 'My destination';
  }

  Future<void> _pickArrivalTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 30)));
    if (!mounted || date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (!mounted || time == null) return;
    setState(() => _earliestArrival = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination ?? SavedDestination(name: 'Custom destination', latitude: _latitude, longitude: _longitude, lastUsedAt: DateTime.now());
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set your alarm')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Text('Almost there', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Choose how close you want to be before the alarm rings.'),
        const SizedBox(height: 20),
        Card(color: theme.colorScheme.primaryContainer, elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          CircleAvatar(backgroundColor: theme.colorScheme.primary, child: const Icon(Icons.place, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Destination', style: theme.textTheme.labelMedium), const SizedBox(height: 3), Text(destination.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))])),
        ]))),
        const SizedBox(height: 18),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Journey name', prefixIcon: Icon(Icons.edit_outlined))),
        const SizedBox(height: 24),
        Text('Alarm distance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${_radiusMeters.round()} meters before destination', style: theme.textTheme.bodyMedium),
        Slider(value: _radiusMeters, min: 100, max: 2000, divisions: 19, label: '${_radiusMeters.round()} m', onChanged: (value) => setState(() => _radiusMeters = value)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('100 m'), Text('2 km')]),
        const SizedBox(height: 20),
        Card(elevation: 0, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: const Icon(Icons.schedule_outlined), title: const Text('Earliest arrival', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(_earliestArrival == null ? 'No time constraint' : '${_earliestArrival!.day}/${_earliestArrival!.month} • ${TimeOfDay.fromDateTime(_earliestArrival!).format(context)}'), trailing: const Icon(Icons.chevron_right), onTap: _pickArrivalTime)),
        const SizedBox(height: 20),
        Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_outlined, color: theme.colorScheme.primary), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Smart monitoring', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('The app keeps monitoring your location in the background so you can travel without watching the map.')])),])),
        const SizedBox(height: 28),
        SizedBox(height: 54, child: FilledButton.icon(onPressed: () async {
          await ref.read(journeyProvider.notifier).startJourney(
            name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : destination.name,
            latitude: widget.destination?.latitude ?? _latitude,
            longitude: widget.destination?.longitude ?? _longitude,
            radiusMeters: _radiusMeters,
            earliestArrivalTime: _earliestArrival,
          );
          if (context.mounted) Navigator.of(context).pop();
        }, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Start monitoring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
      ])),
    );
  }

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }
}
