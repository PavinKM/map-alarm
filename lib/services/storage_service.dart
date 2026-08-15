import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/models/journey.dart';
import '../domain/models/saved_destination.dart';

class StorageService {
  static final StorageService instance = StorageService._init();
  static Database? _database;

  StorageService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('travel_stop_alarm.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journeys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destinationName TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radiusMeters REAL NOT NULL,
        earliestArrivalTime TEXT,
        preAlertDistanceMeters REAL NOT NULL,
        activeMonitoringThresholdMeters REAL NOT NULL,
        status TEXT NOT NULL,
        startedAt TEXT NOT NULL,
        nextScheduledCheckAt TEXT,
        activeMonitoringEnteredAt TEXT,
        preAlertSentAt TEXT,
        triggeredAt TEXT,
        stoppedAt TEXT,
        lastKnownLat REAL,
        lastKnownLng REAL,
        lastKnownAccuracy REAL,
        lastKnownTimestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_destinations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        lastUsedAt TEXT NOT NULL
      )
    ''');
  }

  // --- Journey Operations ---

  Future<int> insertJourney(Journey journey) async {
    final db = await instance.database;
    return await db.insert('journeys', journey.toMap());
  }

  Future<int> updateJourney(Journey journey) async {
    final db = await instance.database;
    return await db.update(
      'journeys',
      journey.toMap(),
      where: 'id = ?',
      whereArgs: [journey.id],
    );
  }

  Future<Journey?> getActiveJourney() async {
    final db = await instance.database;
    final maps = await db.query(
      'journeys',
      where: 'status NOT IN (?, ?)',
      whereArgs: [JourneyStatus.journeyCompleted.name, JourneyStatus.cancelled.name],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Journey.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Journey>> getAllJourneys() async {
    final db = await instance.database;
    final result = await db.query('journeys', orderBy: 'startedAt DESC');
    return result.map((json) => Journey.fromMap(json)).toList();
  }

  Future<int> deleteJourney(int id) async {
    final db = await instance.database;
    return await db.delete(
      'journeys',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Saved Destination Operations ---

  Future<int> insertSavedDestination(SavedDestination dest) async {
    final db = await instance.database;
    return await db.insert('saved_destinations', dest.toMap());
  }

  Future<List<SavedDestination>> getAllSavedDestinations() async {
    final db = await instance.database;
    final result = await db.query('saved_destinations', orderBy: 'lastUsedAt DESC');
    return result.map((json) => SavedDestination.fromMap(json)).toList();
  }

  Future<int> deleteSavedDestination(int id) async {
    final db = await instance.database;
    return await db.delete(
      'saved_destinations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
