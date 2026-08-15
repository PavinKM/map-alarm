import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../domain/models/saved_destination.dart';

class DestinationSelectScreen extends StatefulWidget {
  const DestinationSelectScreen({super.key});
  @override
  State<DestinationSelectScreen> createState() => _DestinationSelectScreenState();
}

class _DestinationSelectScreenState extends State<DestinationSelectScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  SavedDestination? _selected;
  List<_SearchResult> _results = [];
  bool _searching = false;
  bool _locating = false;
  Timer? _debounce;

  final List<SavedDestination> _recent = [
    SavedDestination(name: 'Home', latitude: 13.0827, longitude: 80.2707, lastUsedAt: DateTime.now()),
    SavedDestination(name: 'Office', latitude: 13.0732, longitude: 80.1945, lastUsedAt: DateTime.now().subtract(const Duration(days: 1))),
    SavedDestination(name: 'Airport', latitude: 12.9941, longitude: 80.1709, lastUsedAt: DateTime.now().subtract(const Duration(days: 2))),
  ];

  @override
  void initState() {
    super.initState();
    _selected = _recent.first;
  }

  Future<void> _search(String value) async {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': query, 'format': 'jsonv2', 'limit': '6', 'countrycodes': 'in',
        });
        final response = await http.get(uri, headers: {'User-Agent': 'TravelStopAlarm/1.0'});
        if (response.statusCode != 200 || !mounted) return;
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _results = data.map((item) {
            final map = item as Map<String, dynamic>;
            return _SearchResult(
              name: (map['display_name'] as String? ?? 'Selected place').split(',').take(2).join(', '),
              latitude: double.parse(map['lat'] as String),
              longitude: double.parse(map['lon'] as String),
            );
          }).toList();
        });
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _select(double latitude, double longitude, String name) {
    final destination = SavedDestination(name: name, latitude: latitude, longitude: longitude, lastUsedAt: DateTime.now());
    setState(() {
      _selected = destination;
      _results = [];
      _searchController.text = name;
    });
    _mapController.move(LatLng(latitude, longitude), 15);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      _select(position.latitude, position.longitude, 'Current location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: .94),
            shape: const CircleBorder(),
            child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
          ),
        ),
        title: const Text('Choose destination'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(selected?.latitude ?? SavedDestination.defaultLatitude, selected?.longitude ?? SavedDestination.defaultLongitude),
              initialZoom: 11,
              onTap: (_, point) => _select(point.latitude, point.longitude, 'Pinned location'),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.map_app'),
              if (selected != null)
                MarkerLayer(markers: [Marker(
                  point: LatLng(selected.latitude, selected.longitude),
                  width: 52,
                  height: 64,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 52),
                )]),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 62, 16, 0),
                  child: Column(
                    children: [
                      Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(18),
                        color: theme.colorScheme.surface,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: 'Search a place or address',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searching
                                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                                : (_searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _searchController.clear(); setState(() => _results = []); }) : null),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                            filled: true,
                          ),
                        ),
                      ),
                      if (_results.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)]),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final result = _results[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(result.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _select(result.latitude, result.longitude, result.name),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 14),
                    child: FloatingActionButton.small(
                      heroTag: 'my-location',
                      onPressed: _locating ? null : _useCurrentLocation,
                      child: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SafeArea(
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(22),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(
                      children: [
                        Container(width: 46, height: 46, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.place, color: theme.colorScheme.onPrimaryContainer)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Destination', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 2),
                          Text(selected.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ])),
                        FilledButton(onPressed: () => Navigator.of(context).pop(selected), child: const Text('Confirm')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class _SearchResult {
  final String name;
  final double latitude;
  final double longitude;
  const _SearchResult({required this.name, required this.latitude, required this.longitude});
}
