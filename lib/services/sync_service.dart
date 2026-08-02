import 'dart:async';
import 'package:flutter/foundation.dart';
import 'watch_service.dart';
import '../data/datasources/secure_database_service.dart';

/// SyncService (SyncManager) responsible for orchestrating data flow between
/// the Wearable (Health Connect) and the local Secure SQLite database.
///
/// Implements retry logic and prepares data for future Cloud synchronization.
class SyncService {
  final IWatchService _watchService;
  final SecureDatabaseService _dbService = SecureDatabaseService.instance;

  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._watchService);

  /// Starts the periodic synchronization cycle (Sección 15.2)
  void startPeriodicSync() {
    _syncTimer?.cancel();
    // Scheduled every 5 minutes as per PDF requirements
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await performSync();
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  /// Main synchronization logic
  Future<void> performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('Starting Health Connect sync...');

      // 1. Fetch latest metrics from Health Connect
      final vitalSign = await _watchService.getLatestMetrics();

      if (vitalSign != null) {
        // 2. Ensure data consistency:
        // Unique timestamps are enforced via SQLite UNIQUE constraint in SecureDatabaseService.

        // 3. Save to local secure database
        await _dbService.insertVitalSign(vitalSign);
        debugPrint('Sync successful: Data persisted to Secure SQLite.');
      } else {
        debugPrint('Sync: No new data available from Health Connect.');
      }
    } catch (e) {
      debugPrint('Sync failed: $e. Retrying in next cycle.');
      // The 5-minute periodic timer ensures automatic retries.
    } finally {
      _isSyncing = false;
    }
  }

  /// Future-proofing: Method to sync pending local data to Cloud
  Future<void> syncLocalDataToCloud() async {
    // This will be implemented when Cloud Layer (Firebase) is added.
    // Logic:
    // 1. Query Secure DB for records where synced_to_cloud = 0
    // 2. Upload to Firebase
    // 3. Update local records status to synced_to_cloud = 1
  }
}
