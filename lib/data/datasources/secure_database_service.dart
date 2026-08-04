import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../../models/vital_sign.dart';
import '../../models/active_break.dart';
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
      version: 2,
      password: encryptionKey,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE active_breaks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  steps_taken INTEGER NOT NULL,
  points INTEGER NOT NULL,
  completed INTEGER NOT NULL,
  synced_to_cloud INTEGER DEFAULT 0
)
''');
      await db.execute(
        'ALTER TABLE alerts_log ADD COLUMN synced_to_cloud INTEGER DEFAULT 0',
      );
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE activity_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time TEXT NOT NULL UNIQUE,
  end_time TEXT NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  synced_to_cloud INTEGER DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE vital_signs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL UNIQUE,
  heart_rate REAL NOT NULL,
  hrv REAL NOT NULL,
  spo2 REAL NOT NULL,
  steps INTEGER NOT NULL,
  synced_to_cloud INTEGER DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE alerts_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  acknowledged INTEGER NOT NULL,
  synced_to_cloud INTEGER DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE active_breaks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  type TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  steps_taken INTEGER NOT NULL,
  points INTEGER NOT NULL,
  completed INTEGER NOT NULL,
  synced_to_cloud INTEGER DEFAULT 0
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

  /// Número de sesiones de actividad registradas hoy (fecha local).
  Future<int> countActivitySessionsToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM activity_sessions WHERE start_time >= ?',
      [startOfDay],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// Número de signos vitales registrados hoy (fecha local).
  Future<int> countVitalSignsToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM vital_signs WHERE timestamp >= ?',
      [startOfDay],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// Número de alertas de sedentarismo registradas hoy (fecha local).
  Future<int> countAlertsToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM alerts_log WHERE timestamp >= ?',
      [startOfDay],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// Alertas de sedentarismo registradas hoy (fecha local).
  Future<List<Map<String, Object?>>> getAlertsToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    return db.query(
      'alerts_log',
      where: 'timestamp >= ?',
      whereArgs: [startOfDay],
      orderBy: 'timestamp DESC',
    );
  }

  /// Última sesión de actividad registrada (o null si no hay datos).
  Future<Map<String, Object?>?> getLastActivitySession() async {
    final db = await instance.database;
    final rows = await db.query('activity_sessions', orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Todas las sesiones de actividad registradas en el día indicado (fecha local).
  Future<List<Map<String, Object?>>> getActivitySessionsForDay(DateTime day) async {
    final db = await instance.database;
    final start = DateTime(day.year, day.month, day.day).toIso8601String();
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).toIso8601String();
    final rows = await db.query(
      'activity_sessions',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start, end],
      orderBy: 'start_time ASC',
    );
    return rows;
  }

  /// Todas las sesiones de actividad registradas (para historial y estadísticas).
  Future<List<Map<String, Object?>>> getAllActivitySessions({int limit = 100}) async {
    final db = await instance.database;
    final rows = await db.query('activity_sessions', orderBy: 'start_time DESC', limit: limit);
    return rows;
  }

  /// Sesiones de los últimos [days] días (para el gráfico semanal), agrupadas por día.
  Future<List<Map<String, Object?>>> getActivitySessionsLastDays(int days) async {
    final db = await instance.database;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - (days - 1)).toIso8601String();
    final rows = await db.query(
      'activity_sessions',
      where: 'start_time >= ?',
      whereArgs: [from],
      orderBy: 'start_time ASC',
    );
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Pausas activas (gamificación)
  // ---------------------------------------------------------------------------

  Future<void> insertActiveBreak(ActiveBreak activeBreak) async {
    final db = await instance.database;
    await db.insert('active_breaks', activeBreak.toMap());
  }

  Future<List<ActiveBreak>> getActiveBreaks({int limit = 50}) async {
    final db = await instance.database;
    final rows = await db.query(
      'active_breaks',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ActiveBreak.fromMap).toList();
  }

  Future<int> countActiveBreaksToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM active_breaks WHERE timestamp >= ?',
      [startOfDay],
    );
    return rows.first['total'] as int? ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Cola Offline-First -> sincronización cloud (synced_to_cloud = 0)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getUnsyncedVitalSigns() async {
    final db = await instance.database;
    return db.query('vital_signs', where: 'synced_to_cloud = 0', orderBy: 'timestamp ASC');
  }

  /// Signos vitales registrados después de [from] (útil para la subida
  /// médica incremental con cursor temporal).
  Future<List<Map<String, Object?>>> getVitalSignsAfter(DateTime from) async {
    final db = await instance.database;
    return db.query(
      'vital_signs',
      where: 'timestamp > ?',
      whereArgs: [from.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, Object?>>> getUnsyncedActivitySessions() async {
    final db = await instance.database;
    return db.query('activity_sessions', where: 'synced_to_cloud = 0', orderBy: 'start_time ASC');
  }

  Future<List<Map<String, Object?>>> getUnsyncedAlerts() async {
    final db = await instance.database;
    return db.query('alerts_log', where: 'synced_to_cloud = 0', orderBy: 'timestamp ASC');
  }

  Future<List<ActiveBreak>> getUnsyncedActiveBreaks() async {
    final db = await instance.database;
    final rows = await db.query('active_breaks', where: 'synced_to_cloud = 0', orderBy: 'timestamp ASC');
    return rows.map(ActiveBreak.fromMap).toList();
  }

  Future<void> markVitalSignSynced(int id) async {
    final db = await instance.database;
    await db.update('vital_signs', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markActivitySessionSynced(int id) async {
    final db = await instance.database;
    await db.update('activity_sessions', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAlertSynced(int id) async {
    final db = await instance.database;
    await db.update('alerts_log', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markActiveBreakSynced(int id) async {
    final db = await instance.database;
    await db.update('active_breaks', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
