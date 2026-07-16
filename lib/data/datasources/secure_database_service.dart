import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../../models/vital_sign.dart';
import '../../core/security/encryption_service.dart';

class SecureDatabaseService {
  static final SecureDatabaseService instance = SecureDatabaseService._init();
  static Database? _database;

  SecureDatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lifebalance_secure.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Retrieve AES-256 key from Secure Storage
    final encryptionKey = await EncryptionService.getEncryptionKey();

    return await openDatabase(
      path,
      version: 1,
      password: encryptionKey,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE activity_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL
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
  timestamp TEXT NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  acknowledged INTEGER NOT NULL
)
''');
  }

  Future<void> insertActivitySession(String start, String end, String type, int duration) async {
    final db = await instance.database;
    await db.insert('activity_sessions', {
      'start_time': start,
      'end_time': end,
      'type': type,
      'duration_minutes': duration,
    });
  }

  Future<void> insertVitalSign(VitalSign vitalSign) async {
    final db = await instance.database;
    await db.insert('vital_signs', vitalSign.toMap());
  }

  Future<void> logAlert(String timestamp, int duration, bool acknowledged) async {
    final db = await instance.database;
    await db.insert('alerts_log', {
      'timestamp': timestamp,
      'type': 'sedentary',
      'duration_minutes': duration,
      'acknowledged': acknowledged ? 1 : 0,
    });
  }
}
