import 'validated_backup.dart';

import '../models/app_settings.dart';
import '../models/history_log.dart';
import '../models/rule_model.dart';
import '../models/schedule_model.dart';
import '../models/usage_stats.dart';
import '../models/whitelist_item.dart';

typedef PendingProtectionSnapshot = ({
  String revision,
  List<RuleModel> rules,
  List<ScheduleModel> schedules,
  AppSettings settings,
});

/// Abstract persistence contract defining offline storage operations for BlockReels.
abstract class StorageRepository {
  /// Initializes local storage boxes, registers TypeAdapters, and seeds default records.
  Future<void> init({String? customPath});

  // ---------------------------------------------------------------------------
  // Target App Rules CRUD
  // ---------------------------------------------------------------------------

  /// Retrieves all configured target app blocking rules.
  Future<List<RuleModel>> getRules();

  /// Retrieves a specific rule by package name or unique ID.
  Future<RuleModel?> getRule(String idOrPackageName);

  /// Persists or updates a blocking rule.
  Future<void> saveRule(RuleModel rule);

  /// Deletes a blocking rule by its ID.
  Future<void> deleteRule(String id);

  // ---------------------------------------------------------------------------
  // Focus Schedules CRUD
  // ---------------------------------------------------------------------------

  /// Retrieves all configured focus schedules.
  Future<List<ScheduleModel>> getSchedules();

  /// Retrieves a specific schedule by unique ID.
  Future<ScheduleModel?> getSchedule(String id);

  /// Persists or updates a focus schedule.
  Future<void> saveSchedule(ScheduleModel schedule);

  /// Deletes a focus schedule by ID.
  Future<void> deleteSchedule(String id);

  // ---------------------------------------------------------------------------
  // App Settings & Preferences
  // ---------------------------------------------------------------------------

  /// Retrieves singleton application settings.
  Future<AppSettings> getSettings();

  /// Persists updated application settings.
  Future<void> saveSettings(AppSettings settings);

  // ---------------------------------------------------------------------------
  // Block History Logs
  // ---------------------------------------------------------------------------

  /// Saved/upserted log, or null after a bulk replacement, clear or recovery.
  Stream<HistoryLog?> get historyChanges;

  /// Retrieves block event history logs with optional pagination and time range filters.
  Future<List<HistoryLog>> getHistoryLogs({int limit = 100, DateTime? since});

  /// Appends a new block event to the persistent log.
  Future<void> addHistoryLog(HistoryLog log);

  /// Atomically inserts by ID and ensures durability, returning false for a duplicate.
  Future<bool> addHistoryLogIfAbsent(HistoryLog log);

  /// Clears all historical block logs.
  Future<void> clearHistory();

  // ---------------------------------------------------------------------------
  // Surgical Whitelist Items
  // ---------------------------------------------------------------------------

  /// Retrieves all surgical disambiguation whitelist exclusions.
  Future<List<WhitelistItem>> getWhitelistItems();

  /// Saves a surgical whitelist item.
  Future<void> saveWhitelistItem(WhitelistItem item);

  /// Deletes a whitelist item by ID.
  Future<void> deleteWhitelistItem(String id);

  // ---------------------------------------------------------------------------
  // Aggregated Analytics & Streak Calculations
  // ---------------------------------------------------------------------------

  /// Computes real-time offline statistics across recorded block events.
  Future<UsageStats> getUsageStats();

  /// Calculates the current consecutive day focus streak.
  Future<int> calculateCurrentStreak();

  /// Calculates the longest consecutive day focus streak all-time.
  Future<int> calculateBestStreak();

  // ---------------------------------------------------------------------------
  // Backup, Restore & Reset
  // ---------------------------------------------------------------------------

  /// Exports configuration and rules to a checksummed JSON payload. PIN secrets and history are excluded.
  Future<String> exportBackup();

  /// Validates checksum and restores configuration from an exported JSON payload.
  Future<bool> importBackup(String jsonString);
  Future<bool> importValidatedBackup(ValidatedBackup backup);
  String? get pendingProtectionSync;
  Future<PendingProtectionSnapshot?> readPendingProtectionSnapshot();
  Future<void> acknowledgeProtectionSync(String revision);

  /// Clears all stored data and reseeds initial default configurations.
  Future<void> clearAllData();

  /// Closes all open storage boxes.
  Future<void> close();
}
