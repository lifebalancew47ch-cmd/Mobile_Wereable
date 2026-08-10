import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../../models/vital_sign.dart';
import '../../models/active_break.dart';
import '../../core/security/encryption_service.dart';

class SecureDatabaseService {
  static final SecureDatabaseService instance = SecureDatabaseService._init();
  static Database? _database;
  static Future<Database>? _initFuture;

  SecureDatabaseService._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _initFuture ??= _initDB('lifebalance_secure.db');
    try {
      _database = await _initFuture!;
      return _database!;
    } finally {
      _initFuture = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Retrieve AES-256 key from Secure Storage
    final encryptionKey = await EncryptionService.getEncryptionKey();

    try {
      return await openDatabase(
        path,
        version: 4,
        password: encryptionKey,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          try { await db.execute('PRAGMA synchronous = NORMAL;'); } catch (_) {}
        },
      );
    } catch (e) {
      // If encryption key is lost or DB is corrupted, SQLCipher throws a logic error
      if (e.toString().contains('SQL logic error') || e.toString().contains('file is not a database')) {
        await deleteDatabase(path);
        return await openDatabase(
          path,
          version: 4,
          password: encryptionKey,
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
          onOpen: (db) async {
            await db.rawQuery('PRAGMA journal_mode = WAL;');
            await db.execute('PRAGMA synchronous = NORMAL;');
          },
        );
      }
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS active_breaks (
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
      await _addColumnIfMissing(db, 'alerts_log', 'synced_to_cloud', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Acelerómetro/giroscopio crudos del reloj (antes se descartaban).
      for (final column in ['accel_x', 'accel_y', 'accel_z', 'gyro_x', 'gyro_y', 'gyro_z']) {
        await _addColumnIfMissing(db, 'vital_signs', column, 'REAL');
      }
    }
    if (oldVersion < 4) {
      // Antes solo existía `acknowledged` (leída). Se separa "descartada" para
      // que el Centro de notificaciones pueda ocultar alertas descartadas sin
      // perder el estado de "leída pero visible".
      await _addColumnIfMissing(db, 'alerts_log', 'dismissed', 'INTEGER DEFAULT 0');
    }
  }

  /// Agrega una columna solo si no existe todavía. `onUpgrade` puede
  /// re-ejecutarse sobre una base que ya tiene la columna (p. ej. si un
  /// intento anterior se interrumpió por "database is locked" antes de
  /// persistir el nuevo `user_version`, pero ya había aplicado el ALTER
  /// TABLE) — sin esta guarda, sqflite lanza "duplicate column name" y la
  /// apertura de la base falla permanentemente en cada arranque.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
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
  accel_x REAL,
  accel_y REAL,
  accel_z REAL,
  gyro_x REAL,
  gyro_y REAL,
  gyro_z REAL,
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
  dismissed INTEGER DEFAULT 0,
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
    await db.insert(
      'activity_sessions',
      {
        'start_time': start,
        'end_time': end,
        'type': type,
        'duration_minutes': duration,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertVitalSign(VitalSign vitalSign) async {
    final db = await instance.database;
    await db.insert(
      'vital_signs',
      vitalSign.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  /// Marca como leída una alerta local del FogEngine (sigue visible, solo
  /// deja de mostrarse en negrita). Estas alertas viven solo en SQLite (nunca
  /// en el backend de Alerts), por lo que "leer" desde el Centro de
  /// notificaciones debe actualizar esta tabla en vez de llamar a la nube.
  Future<void> acknowledgeLocalAlert(int id) async {
    final db = await instance.database;
    await db.update(
      'alerts_log',
      {'acknowledged': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Descarta una alerta local del FogEngine: deja de aparecer en el listado
  /// (a diferencia de "leída", que solo la desmarca en negrita).
  Future<void> dismissLocalAlert(int id) async {
    final db = await instance.database;
    await db.update(
      'alerts_log',
      {'acknowledged': 1, 'dismissed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Alertas de sedentarismo registradas hoy (fecha local), sin las que el
  /// usuario ya descartó desde el Centro de notificaciones.
  Future<List<Map<String, Object?>>> getAlertsToday() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    return db.query(
      'alerts_log',
      where: 'timestamp >= ? AND (dismissed IS NULL OR dismissed = 0)',
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

  /// Marca múltiples entidades como sincronizadas en una sola transacción atómica SQLite.
  Future<void> markBatchAsSynced({
    List<int> sessionIds = const [],
    List<int> vitalIds = const [],
    List<int> alertIds = const [],
    List<int> breakIds = const [],
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final id in sessionIds) {
        await txn.update('activity_sessions', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
      }
      for (final id in vitalIds) {
        await txn.update('vital_signs', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
      }
      for (final id in alertIds) {
        await txn.update('alerts_log', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
      }
      for (final id in breakIds) {
        await txn.update('active_breaks', {'synced_to_cloud': 1}, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  /// Elimina registros que ya fueron sincronizados (`synced_to_cloud = 1`) y que superan
  /// el umbral de antigüedad especificado (por defecto 7 días) para evitar crecimiento desmedido.
  Future<void> purgeSyncedData({Duration ageThreshold = const Duration(days: 7)}) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(ageThreshold).toIso8601String();
    await db.delete('activity_sessions', where: 'synced_to_cloud = 1 AND start_time < ?', whereArgs: [cutoff]);
    await db.delete('vital_signs', where: 'synced_to_cloud = 1 AND timestamp < ?', whereArgs: [cutoff]);
    await db.delete('alerts_log', where: 'synced_to_cloud = 1 AND timestamp < ?', whereArgs: [cutoff]);
    await db.delete('active_breaks', where: 'synced_to_cloud = 1 AND timestamp < ?', whereArgs: [cutoff]);
  }

  /// Purga física completa de la base de datos SQLCipher (SessionWiper).
  Future<void> purgeAllData() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lifebalance_secure.db');
    await deleteDatabase(path);
  }
}
