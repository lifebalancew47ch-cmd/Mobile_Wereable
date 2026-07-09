import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vital_sign.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lifebalance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final dbFullPath = join(dbPath, filePath);
    return await openDatabase(dbFullPath, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE activity_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time TEXT NOT NULL,
  end_time TEXT,
  status TEXT NOT NULL,
  inactive_minutes INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE vital_signs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  heart_rate REAL NOT NULL,
  hrv REAL NOT NULL,
  spo2 REAL NOT NULL,
  steps INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE alerts_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  triggered_at TEXT NOT NULL,
  inactive_minutes INTEGER NOT NULL,
  was_dismissed INTEGER NOT NULL
)
''');
  }

  Future<void> insertVitalSign(VitalSign vitalSign) async {
    final db = await instance.database;
    await db.insert('vital_signs', vitalSign.toMap());
  }

  Future<void> insertActivitySession(
      String startTime, String? endTime, String status, int inactiveMinutes) async {
    final db = await instance.database;
    await db.insert('activity_sessions', {
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'inactive_minutes': inactiveMinutes,
    });
  }

  Future<void> logAlert(
      String triggeredAt, int inactiveMinutes, bool wasDismissed) async {
    final db = await instance.database;
    await db.insert('alerts_log', {
      'triggered_at': triggeredAt,
      'inactive_minutes': inactiveMinutes,
      'was_dismissed': wasDismissed ? 1 : 0,
    });
  }
}
