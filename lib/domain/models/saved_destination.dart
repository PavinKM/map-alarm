class SavedDestination {
  static const double defaultLatitude = 13.0827;
  static const double defaultLongitude = 80.2707;

  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime lastUsedAt;

  SavedDestination({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lastUsedAt,
  });

  SavedDestination copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? lastUsedAt,
  }) {
    return SavedDestination(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  factory SavedDestination.fromMap(Map<String, dynamic> map) {
    return SavedDestination(
      id: map['id'] as int?,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      lastUsedAt: DateTime.parse(map['lastUsedAt'] as String),
    );
  }
}
