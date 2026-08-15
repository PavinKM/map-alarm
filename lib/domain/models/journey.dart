enum JourneyStatus {
  waitingForEarliestArrival,
  occasionalChecks,
  activeMonitoring,
  preAlertSent,
  finalApproach,
  alarmTriggered,
  journeyCompleted,
  cancelled,
}

class Journey {
  final int? id;
  final String destinationName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime? earliestArrivalTime;
  final double preAlertDistanceMeters;
  final double activeMonitoringThresholdMeters;
  final JourneyStatus status;
  final DateTime startedAt;
  final DateTime? nextScheduledCheckAt;
  final DateTime? activeMonitoringEnteredAt;
  final DateTime? preAlertSentAt;
  final DateTime? triggeredAt;
  final DateTime? stoppedAt;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final double? lastKnownAccuracy;
  final DateTime? lastKnownTimestamp;

  Journey({
    this.id,
    required this.destinationName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.earliestArrivalTime,
    this.preAlertDistanceMeters = 8000.0,
    this.activeMonitoringThresholdMeters = 20000.0,
    required this.status,
    required this.startedAt,
    this.nextScheduledCheckAt,
    this.activeMonitoringEnteredAt,
    this.preAlertSentAt,
    this.triggeredAt,
    this.stoppedAt,
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastKnownAccuracy,
    this.lastKnownTimestamp,
  });

  Journey copyWith({
    int? id,
    String? destinationName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    DateTime? earliestArrivalTime,
    double? preAlertDistanceMeters,
    double? activeMonitoringThresholdMeters,
    JourneyStatus? status,
    DateTime? startedAt,
    DateTime? nextScheduledCheckAt,
    DateTime? activeMonitoringEnteredAt,
    DateTime? preAlertSentAt,
    DateTime? triggeredAt,
    DateTime? stoppedAt,
    double? lastKnownLat,
    double? lastKnownLng,
    double? lastKnownAccuracy,
    DateTime? lastKnownTimestamp,
  }) {
    return Journey(
      id: id ?? this.id,
      destinationName: destinationName ?? this.destinationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      earliestArrivalTime: earliestArrivalTime ?? this.earliestArrivalTime,
      preAlertDistanceMeters: preAlertDistanceMeters ?? this.preAlertDistanceMeters,
      activeMonitoringThresholdMeters: activeMonitoringThresholdMeters ?? this.activeMonitoringThresholdMeters,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      nextScheduledCheckAt: nextScheduledCheckAt ?? this.nextScheduledCheckAt,
      activeMonitoringEnteredAt: activeMonitoringEnteredAt ?? this.activeMonitoringEnteredAt,
      preAlertSentAt: preAlertSentAt ?? this.preAlertSentAt,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      lastKnownLat: lastKnownLat ?? this.lastKnownLat,
      lastKnownLng: lastKnownLng ?? this.lastKnownLng,
      lastKnownAccuracy: lastKnownAccuracy ?? this.lastKnownAccuracy,
      lastKnownTimestamp: lastKnownTimestamp ?? this.lastKnownTimestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destinationName': destinationName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'earliestArrivalTime': earliestArrivalTime?.toIso8601String(),
      'preAlertDistanceMeters': preAlertDistanceMeters,
      'activeMonitoringThresholdMeters': activeMonitoringThresholdMeters,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'nextScheduledCheckAt': nextScheduledCheckAt?.toIso8601String(),
      'activeMonitoringEnteredAt': activeMonitoringEnteredAt?.toIso8601String(),
      'preAlertSentAt': preAlertSentAt?.toIso8601String(),
      'triggeredAt': triggeredAt?.toIso8601String(),
      'stoppedAt': stoppedAt?.toIso8601String(),
      'lastKnownLat': lastKnownLat,
      'lastKnownLng': lastKnownLng,
      'lastKnownAccuracy': lastKnownAccuracy,
      'lastKnownTimestamp': lastKnownTimestamp?.toIso8601String(),
    };
  }

  factory Journey.fromMap(Map<String, dynamic> map) {
    return Journey(
      id: map['id'] as int?,
      destinationName: map['destinationName'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: (map['radiusMeters'] as num).toDouble(),
      earliestArrivalTime: map['earliestArrivalTime'] != null
          ? DateTime.parse(map['earliestArrivalTime'] as String)
          : null,
      preAlertDistanceMeters: (map['preAlertDistanceMeters'] as num).toDouble(),
      activeMonitoringThresholdMeters: (map['activeMonitoringThresholdMeters'] as num).toDouble(),
      status: JourneyStatus.values.byName(map['status'] as String),
      startedAt: DateTime.parse(map['startedAt'] as String),
      nextScheduledCheckAt: map['nextScheduledCheckAt'] != null
          ? DateTime.parse(map['nextScheduledCheckAt'] as String)
          : null,
      activeMonitoringEnteredAt: map['activeMonitoringEnteredAt'] != null
          ? DateTime.parse(map['activeMonitoringEnteredAt'] as String)
          : null,
      preAlertSentAt: map['preAlertSentAt'] != null
          ? DateTime.parse(map['preAlertSentAt'] as String)
          : null,
      triggeredAt: map['triggeredAt'] != null
          ? DateTime.parse(map['triggeredAt'] as String)
          : null,
      stoppedAt: map['stoppedAt'] != null
          ? DateTime.parse(map['stoppedAt'] as String)
          : null,
      lastKnownLat: map['lastKnownLat'] != null ? (map['lastKnownLat'] as num).toDouble() : null,
      lastKnownLng: map['lastKnownLng'] != null ? (map['lastKnownLng'] as num).toDouble() : null,
      lastKnownAccuracy: map['lastKnownAccuracy'] != null ? (map['lastKnownAccuracy'] as num).toDouble() : null,
      lastKnownTimestamp: map['lastKnownTimestamp'] != null
          ? DateTime.parse(map['lastKnownTimestamp'] as String)
          : null,
    );
  }
}
