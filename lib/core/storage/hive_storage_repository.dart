import 'validated_backup.dart';

import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/block_diagnostic_code.dart';
import '../models/history_log.dart';
import '../models/intervention_mode.dart';
import '../models/rule_model.dart';
import '../models/schedule_model.dart';
import '../models/usage_stats.dart';
import '../models/whitelist_item.dart';
import 'adapters/hive_adapters.dart';
import 'storage_repository.dart';

typedef HiveBoxOpener = Future<Box<T>> Function<T>(String name);

/// Production offline persistence repository backed by high-performance Hive boxes.
class HiveStorageRepository implements StorageRepository {
  static const String boxRulesName = 'box_rules';
  static const String boxSchedulesName = 'box_schedules';
  static const String boxHistoryName = 'box_history';
  static const String boxSettingsName = 'box_settings';
  static const String boxWhitelistName = 'box_whitelist';

  static const String _settingsKey = 'singleton_settings';
  static const String _journalBoxName = 'box_restore_journal';
  static const String _journalKey = 'pending_restore';

  Box<RuleModel>? _rulesBox;
  Box<ScheduleModel>? _schedulesBox;
  Box<HistoryLog>? _historyBox;
  Box<AppSettings>? _settingsBox;
  Box<WhitelistItem>? _whitelistBox;
  Box<String>? _restoreJournal;
  bool _initialized = false;
  final HiveBoxOpener _boxOpener;
  Future<void> _pendingWrite = Future<void>.value();
  int _pendingWrites = 0;

  final Uuid _uuid = const Uuid();
  final DateTime Function() _clock;
  final _historyChanges = StreamController<HistoryLog?>.broadcast();
  UsageStats? _cachedUsage;
  DateTime? _usageDate;

  @override
  Stream<HistoryLog?> get historyChanges => _historyChanges.stream;

  void _historyChanged([HistoryLog? log]) {
    _cachedUsage = null;
    _historyChanges.add(log);
  }

  HiveStorageRepository({HiveBoxOpener? openBox, DateTime Function()? clock})
      : _boxOpener = openBox ?? _openPreservingFiles,
        _clock = clock ?? DateTime.now;

  static Future<Box<T>> _openPreservingFiles<T>(String name) =>
      // Hive's automatic crash recovery can truncate the original file.
      Hive.openBox<T>(name, crashRecovery: false);

  @override
  Future<void> init({String? customPath}) => _writeExclusive(() async {
        _initialized = false;
        _cachedUsage = null;
        if (customPath != null) {
          Hive.init(customPath);
        } else {
          await Hive.initFlutter();
        }

        _registerAdapters();

        _rulesBox = await _openBoxIfNeeded<RuleModel>(boxRulesName);
        _schedulesBox = await _openBoxIfNeeded<ScheduleModel>(boxSchedulesName);
        _historyBox = await _openBoxIfNeeded<HistoryLog>(boxHistoryName);
        _settingsBox = await _openBoxIfNeeded<AppSettings>(boxSettingsName);
        _whitelistBox = await _openBoxIfNeeded<WhitelistItem>(boxWhitelistName);
        _restoreJournal = await _openBoxIfNeeded<String>(_journalBoxName);

        await _recoverInterruptedRestore();
        if (_settingsBox!.isEmpty) await _seedDefaultsIfEmpty();
        _initialized = true;
        _historyChanged();
      });

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(InterventionModeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RuleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ScheduleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HistoryLogAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WhitelistItemAdapter());
    }
  }

  Future<Box<T>> _openBoxIfNeeded<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    return _boxOpener<T>(boxName);
  }

  Future<T> _writeExclusive<T>(Future<T> Function() operation) {
    final wasIdle = _pendingWrites == 0;
    _pendingWrites++;
    Future<T> run() async {
      try {
        return await operation();
      } finally {
        _pendingWrites--;
      }
    }

    final result = wasIdle ? run() : _pendingWrite.then((_) => run());
    _pendingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _seedDefaultsIfEmpty() async {
    if (_rulesBox != null && _rulesBox!.isEmpty) {
      final defaultRules = [
        RuleModel(
          id: 'instagram',
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isEnabled: true,
          interventionMode: InterventionMode.mindfulPause,
          holdDurationSeconds: 7,
          allowChatAndDMs: true,
          allowProfileGrids: true,
        ),
        RuleModel(
          id: 'youtube',
          packageName: 'com.google.android.youtube',
          appName: 'YouTube Shorts',
          isEnabled: true,
          interventionMode: InterventionMode.mindfulPause,
          holdDurationSeconds: 7,
          allowChatAndDMs: true,
          allowProfileGrids: true,
        ),
        RuleModel(
          id: 'facebook',
          packageName: 'com.facebook.katana',
          appName: 'Facebook Reels',
          isEnabled: false,
          interventionMode: InterventionMode.mindfulPause,
          holdDurationSeconds: 7,
          allowChatAndDMs: true,
          allowProfileGrids: true,
        ),
        RuleModel(
          id: 'tiktok_global',
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isEnabled: true,
          interventionMode: InterventionMode.mindfulPause,
          holdDurationSeconds: 7,
          allowChatAndDMs: true,
          allowProfileGrids: true,
        ),
        RuleModel(
          id: 'tiktok_regional',
          packageName: 'com.ss.android.ugc.trill',
          appName: 'TikTok (Regional)',
          isEnabled: false,
          interventionMode: InterventionMode.mindfulPause,
          holdDurationSeconds: 7,
          allowChatAndDMs: true,
          allowProfileGrids: true,
        ),
      ];

      for (final rule in defaultRules) {
        await _rulesBox!.put(rule.packageName, rule);
      }
    }

    if (_whitelistBox != null && _whitelistBox!.isEmpty) {
      final defaultWhitelist = [
        WhitelistItem(
          id: 'ig_dm',
          packageName: 'com.instagram.android',
          componentId: 'direct_thread',
          reason: 'Allow Direct Messages and private conversations',
          isSystemProtected: true,
        ),
        WhitelistItem(
          id: 'ig_profile',
          packageName: 'com.instagram.android',
          componentId: 'profile_grid',
          reason: 'Allow browsing user profiles and photo grids',
          isSystemProtected: true,
        ),
        WhitelistItem(
          id: 'yt_search',
          packageName: 'com.google.android.youtube',
          componentId: 'search_results',
          reason: 'Allow searching for educational and standard videos',
          isSystemProtected: true,
        ),
        WhitelistItem(
          id: 'yt_watch',
          packageName: 'com.google.android.youtube',
          componentId: 'standard_watch_player',
          reason: 'Allow standard non-short video playback',
          isSystemProtected: true,
        ),
        WhitelistItem(
          id: 'fb_messages',
          packageName: 'com.facebook.katana',
          componentId: 'messages_tab',
          reason: 'Allow Facebook messages and inbox communication',
          isSystemProtected: true,
        ),
      ];

      for (final item in defaultWhitelist) {
        await _whitelistBox!.put(item.id, item);
      }
    }

    if (_settingsBox != null && _settingsBox!.isEmpty) {
      final defaultSettings = AppSettings(
        isMasterEnabled: true,
        themeMode: 'system',
        defaultHoldDurationSeconds: 7,
        breathingTechnique: 'box_4_4_4_4',
        hapticFeedbackEnabled: true,
        soundDuckingEnabled: true,
        isOnboardingCompleted: false,
        schemaVersion: 1,
      );
      await _settingsBox!.put(_settingsKey, defaultSettings);
    }
  }

  // ---------------------------------------------------------------------------
  // Rules CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<RuleModel>> getRules() async {
    _ensureInitialized();
    return _rulesBox!.values.toList();
  }

  @override
  Future<RuleModel?> getRule(String idOrPackageName) async {
    _ensureInitialized();
    if (_rulesBox!.containsKey(idOrPackageName)) {
      return _rulesBox!.get(idOrPackageName);
    }
    for (final rule in _rulesBox!.values) {
      if (rule.id == idOrPackageName || rule.packageName == idOrPackageName) {
        return rule;
      }
    }
    return null;
  }

  @override
  Future<void> saveRule(RuleModel rule) => _writeExclusive(() async {
        _ensureInitialized();
        await _rulesBox!.put(rule.packageName, rule);
      });

  @override
  Future<void> deleteRule(String id) => _writeExclusive(() async {
        _ensureInitialized();
        final rule = await getRule(id);
        if (rule != null) {
          await _rulesBox!.delete(rule.packageName);
        } else {
          await _rulesBox!.delete(id);
        }
      });

  // ---------------------------------------------------------------------------
  // Schedules CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<ScheduleModel>> getSchedules() async {
    _ensureInitialized();
    return _schedulesBox!.values.toList();
  }

  @override
  Future<ScheduleModel?> getSchedule(String id) async {
    _ensureInitialized();
    return _schedulesBox!.get(id);
  }

  @override
  Future<void> saveSchedule(ScheduleModel schedule) =>
      _writeExclusive(() async {
        _ensureInitialized();
        final scheduleId = schedule.id.isEmpty ? _uuid.v4() : schedule.id;
        final updated = schedule.copyWith(id: scheduleId);
        await _schedulesBox!.put(scheduleId, updated);
      });

  @override
  Future<void> deleteSchedule(String id) => _writeExclusive(() async {
        _ensureInitialized();
        await _schedulesBox!.delete(id);
      });

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  @override
  Future<AppSettings> getSettings() async {
    _ensureInitialized();
    return _settingsBox!.get(_settingsKey) ?? AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) => _writeExclusive(() async {
        _ensureInitialized();
        await _settingsBox!.put(_settingsKey, settings);
      });

  // ---------------------------------------------------------------------------
  // History Logs
  // ---------------------------------------------------------------------------

  @override
  Future<List<HistoryLog>> getHistoryLogs({
    int limit = 100,
    DateTime? since,
  }) async {
    _ensureInitialized();
    var logs = _historyBox!.values.toList();

    if (since != null) {
      logs = logs.where((l) => l.timestamp.isAfter(since)).toList();
    }

    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (logs.length > limit) {
      return logs.sublist(0, limit);
    }
    return logs;
  }

  @override
  Future<void> addHistoryLog(HistoryLog log) => _writeExclusive(() async {
        _ensureInitialized();
        final logId = log.id.isEmpty ? _uuid.v4() : log.id;
        final entry = log.copyWith(
          id: logId,
          detectionReason: blockDiagnosticCode(log.detectionReason),
        );
        _cachedUsage = null;
        await _historyBox!.put(logId, entry);
        _historyChanged(entry);
      });

  @override
  Future<bool> addHistoryLogIfAbsent(
    HistoryLog log,
  ) =>
      _writeExclusive(() async {
        _ensureInitialized();
        if (log.id.isEmpty) {
          throw ArgumentError('History event ID must not be empty');
        }
        final inserted = !_historyBox!.containsKey(log.id);
        if (inserted) {
          _cachedUsage = null;
          await _historyBox!.put(
            log.id,
            log.copyWith(
                detectionReason: blockDiagnosticCode(log.detectionReason)),
          );
        }
        // Flush duplicates too: an earlier save may have failed during its flush.
        await _historyBox!.flush();
        if (inserted) {
          _historyChanged(log.copyWith(
              detectionReason: blockDiagnosticCode(log.detectionReason)));
        }
        return inserted;
      });

  @override
  Future<void> clearHistory() => _writeExclusive(() async {
        _ensureInitialized();
        _cachedUsage = null;
        await _historyBox!.clear();
        await _historyBox!.flush();
        _historyChanged();
      });

  // ---------------------------------------------------------------------------
  // Whitelist CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<WhitelistItem>> getWhitelistItems() async {
    _ensureInitialized();
    return _whitelistBox!.values.toList();
  }

  @override
  Future<void> saveWhitelistItem(WhitelistItem item) =>
      _writeExclusive(() async {
        _ensureInitialized();
        final itemId = item.id.isEmpty ? _uuid.v4() : item.id;
        final updated = item.copyWith(id: itemId);
        await _whitelistBox!.put(itemId, updated);
      });

  @override
  Future<void> deleteWhitelistItem(String id) => _writeExclusive(() async {
        _ensureInitialized();
        await _whitelistBox!.delete(id);
      });

  // ---------------------------------------------------------------------------
  // Computed Analytics & Streak Logic
  // ---------------------------------------------------------------------------

  @override
  Future<UsageStats> getUsageStats() async {
    _ensureInitialized();
    final now = _clock();
    final date = DateTime(now.year, now.month, now.day);
    if (_cachedUsage != null && _usageDate == date) return _cachedUsage!;
    final logs = _historyBox!.values.toList();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
    // Week start: Monday
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final weekEnd = DateTime(now.year, now.month, now.day - now.weekday + 8);

    int todayCount = 0;
    int weekCount = 0;
    int totalSavedSeconds = 0;
    final Map<String, int> appCounts = {};
    final Map<int, int> hourCounts = {};
    final Map<String, int> dailyCounts = {};
    final Map<String, int> dailySaved = {};
    final distinctDates = <DateTime>{};

    for (final log in logs) {
      final ts = log.timestamp;
      distinctDates.add(DateTime(ts.year, ts.month, ts.day));
      totalSavedSeconds += log.estimatedTimeSavedSeconds;

      if (!ts.isBefore(todayStart) && ts.isBefore(tomorrowStart)) {
        todayCount++;
      }
      if (!ts.isBefore(weekStart) && ts.isBefore(weekEnd)) {
        weekCount++;
      }

      final appKey = log.appName.isNotEmpty ? log.appName : log.packageName;
      appCounts[appKey] = (appCounts[appKey] ?? 0) + 1;

      hourCounts[ts.hour] = (hourCounts[ts.hour] ?? 0) + 1;

      final dateKey =
          '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      dailySaved[dateKey] =
          (dailySaved[dateKey] ?? 0) + log.estimatedTimeSavedSeconds;
    }

    final sortedDates = distinctDates.toList()..sort();
    final currentStreak = _currentStreak(distinctDates, sortedDates, now);
    final bestStreak = _bestStreak(sortedDates);

    // Construct 7-day trend history
    final List<DailyTrendPoint> trends = [];
    for (int i = 6; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      trends.add(
        DailyTrendPoint(
          date: day,
          count: dailyCounts[key] ?? 0,
          timeSavedSeconds: dailySaved[key] ?? 0,
        ),
      );
    }

    _usageDate = date;
    return _cachedUsage = UsageStats(
      totalBlockedLifetime: logs.length,
      totalBlockedToday: todayCount,
      totalBlockedThisWeek: weekCount,
      totalTimeSavedMinutes: totalSavedSeconds ~/ 60,
      totalTimeSavedSeconds: totalSavedSeconds,
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
      blocksByApp: appCounts,
      blocksByHour: hourCounts,
      dailyTrends: trends,
    );
  }

  @override
  Future<int> calculateCurrentStreak() async =>
      (await getUsageStats()).currentStreakDays;

  @override
  Future<int> calculateBestStreak() async =>
      (await getUsageStats()).bestStreakDays;

  static int _currentStreak(
    Set<DateTime> dates,
    List<DateTime> sortedDates,
    DateTime now,
  ) {
    if (sortedDates.isEmpty) return 0;
    var checkDate = sortedDates.last;
    if (checkDate.isBefore(DateTime(now.year, now.month, now.day - 1))) {
      return 0;
    }
    var streak = 0;
    while (dates.contains(checkDate)) {
      streak++;
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }
    return streak;
  }

  static int _bestStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < sortedDates.length; i++) {
      final previous = sortedDates[i - 1];
      final next = sortedDates[i];
      final days = DateTime.utc(next.year, next.month, next.day)
          .difference(DateTime.utc(previous.year, previous.month, previous.day))
          .inDays;
      run = days == 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Backup & Restore Engine
  // ---------------------------------------------------------------------------

  @override
  Future<String> exportBackup() => _writeExclusive(() async {
        _ensureInitialized();
        final rules = _rulesBox!.values.map((e) => e.toJson()).toList();
        final schedules = _schedulesBox!.values.map((e) => e.toJson()).toList();
        final settings = (await getSettings()).toBackupJson();
        final whitelist = _whitelistBox!.values.map((e) => e.toJson()).toList();

        final dataPayload = {
          'rules': rules,
          'schedules': schedules,
          'settings': settings,
          'whitelist': whitelist,
        };

        final jsonEncodedData = jsonEncode(dataPayload);
        final checksum =
            sha256.convert(utf8.encode(jsonEncodedData)).toString();

        final fullBackup = {
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'data': dataPayload,
          'checksum': checksum,
        };

        final encoded = jsonEncode(fullBackup);
        if (ValidatedBackup.parse(encoded) == null) {
          throw const FormatException('Stored settings exceed the backup format limits');
        }
        return encoded;
      });

  Map<String, dynamic> _captureRestoreSnapshot(ValidatedBackup backup) {
    List<dynamic> capture<T>(
      Box<T> box,
      Map<String, dynamic> Function(T) encode,
    ) =>
        box
            .toMap()
            .entries
            .map((entry) => [entry.key, encode(entry.value)])
            .toList();
    return {
      if (backup.rules != null) boxRulesName: capture(_rulesBox!, (rule) => rule.toJson()),
      if (backup.schedules != null) boxSchedulesName: capture(
        _schedulesBox!,
        (schedule) => schedule.toJson(),
      ),
      if (backup.history != null) boxHistoryName: capture(_historyBox!, (log) => log.toJson()),
      if (backup.settings != null) boxSettingsName: capture(_settingsBox!, (settings) => settings.toJson()),
      if (backup.whitelist != null) boxWhitelistName: capture(_whitelistBox!, (item) => item.toJson()),
    };
  }

  Future<void> _replaceBox<T>(Box<T> box, Map<dynamic, T> entries) async {
    await box.clear();
    await box.putAll(entries);
    await box.flush();
  }

  Future<void> _restoreSnapshot(Map<String, dynamic> snapshot) async {
    Future<void> restore<T>(
      String name,
      Box<T> box,
      T Function(Map<String, dynamic>) decode,
    ) async {
      if (!snapshot.containsKey(name)) return;
      final entries = <dynamic, T>{};
      for (final entry in snapshot[name] as List) {
        entries[entry[0]] = decode(Map<String, dynamic>.from(entry[1] as Map));
      }
      if (name == boxSettingsName) {
        // Keep PIN settings present throughout rollback; never clear them first.
        await box.putAll(entries);
        await box.deleteAll(
          box.keys.where((key) => !entries.containsKey(key)).toList(),
        );
        await box.flush();
      } else {
        await _replaceBox(box, entries);
      }
    }

    await restore(boxRulesName, _rulesBox!, RuleModel.fromJson);
    await restore(boxSchedulesName, _schedulesBox!, ScheduleModel.fromJson);
    await restore(boxHistoryName, _historyBox!, HistoryLog.fromJson);
    await restore(boxSettingsName, _settingsBox!, AppSettings.fromJson);
    await restore(boxWhitelistName, _whitelistBox!, WhitelistItem.fromJson);
  }

  Future<void> _persistRestoreSnapshot(Map<String, dynamic> snapshot) async {
    // This private snapshot includes security state and must never be exported.
    await _restoreJournal!.put(_journalKey, jsonEncode(snapshot));
    await _restoreJournal!.flush();
  }

  Future<void> _clearRestoreJournal() async {
    await _restoreJournal!.delete(_journalKey);
    await _restoreJournal!.flush();
  }

  Future<void> _recoverInterruptedRestore() async {
    final pending = _restoreJournal!.get(_journalKey);
    if (pending == null) return;
    await _restoreSnapshot(jsonDecode(pending) as Map<String, dynamic>);
    await _clearRestoreJournal();
  }

  @override
  Future<bool> importBackup(String jsonString) async {
    final backup = ValidatedBackup.parse(jsonString);
    return backup != null && await importValidatedBackup(backup);
  }

  static const _syncKey = 'pending_protection_sync';

  @override
  String? get pendingProtectionSync => _restoreJournal!.get(_syncKey);

  @override
  Future<PendingProtectionSnapshot?> readPendingProtectionSnapshot() =>
      _writeExclusive(() async {
        _ensureInitialized();
        final revision = pendingProtectionSync;
        if (revision == null) return null;
        return (
          revision: revision,
          rules: await getRules(),
          schedules: await getSchedules(),
          settings: await getSettings(),
        );
      });

  @override
  Future<void> acknowledgeProtectionSync(String revision) => _writeExclusive(() async {
    if (pendingProtectionSync == revision) {
      await _restoreJournal!.delete(_syncKey);
      await _restoreJournal!.flush();
    }
  });

  @override
  Future<bool> importValidatedBackup(ValidatedBackup backup) => _writeExclusive(() async {
        _ensureInitialized();
        final snapshot = _captureRestoreSnapshot(backup);
        final currentSettings = await getSettings();
        var journalReady = false;
        try {
          await _persistRestoreSnapshot(snapshot);
          journalReady = true;
          if (backup.rules != null) {
            await _replaceBox(_rulesBox!, {
              for (final rule in backup.rules!) rule.packageName: rule,
            });
          }
          if (backup.schedules != null) {
            await _replaceBox(_schedulesBox!, {
              for (final schedule in backup.schedules!) schedule.id: schedule,
            });
          }
          if (backup.settings != null) {
            await _settingsBox!.put(
              _settingsKey,
              backup.settings!.copyWith(
                isOnboardingCompleted: currentSettings.isOnboardingCompleted,
                pinLockEnabled: currentSettings.pinLockEnabled,
                strictModeEnabled: currentSettings.strictModeEnabled,
                pinHash: currentSettings.pinHash,
                pinSalt: currentSettings.pinSalt,
                failedPinAttempts: currentSettings.failedPinAttempts,
                lockoutUntil: currentSettings.lockoutUntil,
                lastBackupDate: DateTime.now(),
              ),
            );
            await _settingsBox!.flush();
          }
          if (backup.whitelist != null) {
            await _replaceBox(_whitelistBox!, {
              for (final item in backup.whitelist!) item.id: item,
            });
          }
          if (backup.history != null) {
            await _replaceBox(_historyBox!, {
              for (final log in backup.history!) log.id: log,
            });
          }
          await _restoreJournal!.put(_syncKey, _uuid.v4());
          await _restoreJournal!.flush();
          await _clearRestoreJournal();
          return true;
        } catch (_) {
          if (journalReady) {
            try {
              // Re-establish the marker even if committing its removal failed.
              await _persistRestoreSnapshot(snapshot);
              await _restoreSnapshot(snapshot);
              await _clearRestoreJournal();
              return false;
            } catch (_) {
              // Leave the durable snapshot for startup recovery; block further writes.
            }
          }
          _initialized = false;
          return false;
        } finally {
          if (backup.history != null) _historyChanged();
        }
      });

  @override
  Future<void> clearAllData() => _writeExclusive(() async {
        _ensureInitialized();
        _cachedUsage = null;
        await _rulesBox!.clear();
        await _schedulesBox!.clear();
        await _historyBox!.clear();
        _historyChanged();
        await _settingsBox!.clear();
        await _whitelistBox!.clear();
        await _restoreJournal!.delete(_syncKey);
        await _seedDefaultsIfEmpty();
      });

  @override
  Future<void> close() => _writeExclusive(() async {
        _initialized = false;
        await _rulesBox?.close();
        await _schedulesBox?.close();
        await _historyBox?.close();
        await _settingsBox?.close();
        await _whitelistBox?.close();
        await _restoreJournal?.close();
      });

  void _ensureInitialized() {
    if (!_initialized ||
        _rulesBox == null ||
        _schedulesBox == null ||
        _historyBox == null ||
        _settingsBox == null ||
        _whitelistBox == null ||
        _restoreJournal == null) {
      throw StateError(
        'HiveStorageRepository has not been initialized. Call init() before performing operations.',
      );
    }
  }
}
