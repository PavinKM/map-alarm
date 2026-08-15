import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/saved_destination.dart';

class DestinationSelectScreen extends StatefulWidget {
  const DestinationSelectScreen({super.key});

  @override
  State<DestinationSelectScreen> createState() => _DestinationSelectScreenState();
}

class _DestinationSelectScreenState extends State<DestinationSelectScreen> {
  final TextEditingController _searchController = TextEditingController();

  SavedDestination _buildCustomDestination(double latitude, double longitude) {
    return SavedDestination(
      name: 'Custom point',
      latitude: latitude,
      longitude: longitude,
      lastUsedAt: DateTime.now(),
    );
  }

  final List<SavedDestination> _sampleDestinations = [
    SavedDestination(
      name: 'Home',
      latitude: 13.0827,
      longitude: 80.2707,
      lastUsedAt: DateTime.now(),
    ),
    SavedDestination(
      name: 'Office',
      latitude: 13.0732,
      longitude: 80.1945,
      lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    SavedDestination(
      name: 'Airport',
      latitude: 12.9716,
      longitude: 77.5946,
      lastUsedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  SavedDestination? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _sampleDestinations.first;
    _searchController.text = _selected!.name;
  }

  @override
  Widget build(BuildContext context) {
    final filteredDestinations = _sampleDestinations.where((destination) {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return destination.name.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select destination'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search destination',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    _selected?.latitude ?? SavedDestination.defaultLatitude,
                    _selected?.longitude ?? SavedDestination.defaultLongitude,
                  ),
                  initialZoom: 10,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selected = _buildCustomDestination(point.latitude, point.longitude);
                      _searchController.text = _selected!.name;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.map_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _selected?.latitude ?? SavedDestination.defaultLatitude,
                          _selected?.longitude ?? SavedDestination.defaultLongitude,
                        ),
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filteredDestinations.length,
                itemBuilder: (context, index) {
                  final destination = filteredDestinations[index];
                  final isSelected = destination.name == _selected?.name;

                  return ListTile(
                    title: Text(destination.name),
                    subtitle: Text(
                      '${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}',
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selected = destination;
                        _searchController.text = destination.name;
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  icon: const Icon(Icons.check),
                  label: const Text('Use selected destination'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
