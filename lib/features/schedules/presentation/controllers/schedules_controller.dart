import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/quick_boost_window.dart';
import '../../../../core/models/schedule_model.dart';
import '../../../../core/platform_channel/platform_bridge.dart';
import '../../../../core/providers/platform_bridge_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../domain/models/schedule_rule_model.dart';

enum ScheduleWriteResult { success, syncFailed, failed, busy }

/// Controller managing focus schedules state and synchronization with native background service.
class SchedulesController extends ChangeNotifier {
  final PlatformBridge bridge;
  final StorageRepository? _storage;
  final List<ScheduleRuleModel> _schedules = [];
  bool _disposed = false;
  Future<void>? _initialLoad;
  Future<void> _pending = Future<void>.value();
  int _pendingOperations = 0;

  List<ScheduleRuleModel> get schedules => List.unmodifiable(
        _schedules.where((schedule) => !isQuickBoostId(schedule.id)),
      );

  /// Includes quick boosts so protection summaries can mirror native state.
  List<ScheduleRuleModel> get allSchedules => List.unmodifiable(_schedules);

  SchedulesController(this.bridge, [this._storage]) {
    if (_storage != null) {
      _initialLoad = loadSchedules();
    }
  }

  Future<void> loadSchedules() => _serialize(() async {
        if (_storage == null) return;
        final coreList = await _storage.getSchedules();
        if (_disposed) return;
        _schedules.clear();
        _schedules
            .addAll(coreList.map((c) => ScheduleRuleModel.fromCoreModel(c)));
        await _syncBridge();
      });

  bool _busy = false;
  bool _unsynced = false;
  bool get isBusy => _busy;
  bool get hasUnsyncedChanges => _unsynced;

  Future<ScheduleWriteResult> retrySync() => _serialize(() async {
        if (_disposed) return ScheduleWriteResult.failed;
        try {
          await _initialLoad;
          return await _syncBridge()
              ? ScheduleWriteResult.success
              : ScheduleWriteResult.syncFailed;
        } catch (_) {
          return ScheduleWriteResult.failed;
        }
      });

  Future<ScheduleWriteResult> addSchedule(ScheduleRuleModel schedule) =>
      _serialize(() => _write(schedule.id, schedule));

  Future<ScheduleWriteResult> toggleSchedule(String id, bool active) =>
      _serialize(() async {
        final index = _schedules.indexWhere((s) => s.id == id);
        if (index < 0) return ScheduleWriteResult.failed;
        return _write(id, _schedules[index].copyWith(isActive: active));
      });

  Future<ScheduleWriteResult> deleteSchedule(String id) =>
      _serialize(() => _write(id, null));

  Future<ScheduleWriteResult> updateSchedule(ScheduleRuleModel schedule) =>
      _serialize(() => _write(schedule.id, schedule));

  /// Replaces only the one-shot session, rolling back if it cannot be synced.
  Future<ScheduleWriteResult> replaceQuickBoost(ScheduleModel? next) =>
      _serialize(() async {
        if (_disposed) return ScheduleWriteResult.failed;
        try {
          await _initialLoad;
        } catch (_) {
          return ScheduleWriteResult.failed;
        }
        final before = List<ScheduleRuleModel>.from(_schedules);
        final previousBoosts =
            before.where((s) => isQuickBoostId(s.id)).toList();
        try {
          for (final old in previousBoosts) {
            await _storage?.deleteSchedule(old.id);
          }
          if (next != null) await _storage?.saveSchedule(next);
          _schedules
            ..clear()
            ..addAll(before.where((s) => !isQuickBoostId(s.id)))
            ..addAll([
              if (next != null) ScheduleRuleModel.fromCoreModel(next),
            ]);
          if (!await _syncBridge()) {
            throw StateError('Schedule sync failed');
          }
          return ScheduleWriteResult.success;
        } catch (_) {
          _schedules
            ..clear()
            ..addAll(before);
          _unsynced = true;
          try {
            if (next != null) await _storage?.deleteSchedule(next.id);
            for (final old in previousBoosts) {
              await _storage?.saveSchedule(old.toCoreModel());
            }
            await _syncBridge();
          } catch (_) {
            _unsynced = true;
          }
          return ScheduleWriteResult.syncFailed;
        }
      });

  /// Queue reads, mutations, retries and rollback as complete transactions.
  Future<T> _serialize<T>(Future<T> Function() operation) {
    final wasIdle = _pendingOperations == 0;
    _pendingOperations++;
    _busy = true;
    Future<T> run() async {
      try {
        return await operation();
      } finally {
        _pendingOperations--;
        _busy = _pendingOperations > 0;
        if (!_disposed) notifyListeners();
      }
    }

    final result = wasIdle ? run() : _pending.then((_) => run());
    // A failed transaction must not prevent the next transaction from running.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    if (!_disposed) notifyListeners();
    return result;
  }

  Future<ScheduleWriteResult> _write(
      String id, ScheduleRuleModel? schedule) async {
    if (_disposed) return ScheduleWriteResult.failed;
    try {
      await _initialLoad;
      if (schedule == null) {
        await _storage?.deleteSchedule(id);
      } else {
        await _storage?.saveSchedule(schedule.toCoreModel());
      }
      final index = _schedules.indexWhere((s) => s.id == id);
      if (schedule == null) {
        if (index >= 0) _schedules.removeAt(index);
      } else if (index >= 0) {
        _schedules[index] = schedule;
      } else {
        _schedules.add(schedule);
      }
      _unsynced = true;
      if (!_disposed) notifyListeners();
      return await _syncBridge()
          ? ScheduleWriteResult.success
          : ScheduleWriteResult.syncFailed;
    } catch (_) {
      return ScheduleWriteResult.failed;
    }
  }

  Future<bool> _syncBridge() async {
    if (_disposed) return false;
    try {
      _unsynced = !await bridge
          .syncSchedules(_schedules.map((s) => s.toDto()).toList());
    } catch (_) {
      _unsynced = true;
    }
    if (!_disposed) notifyListeners();
    return !_unsynced;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Riverpod ChangeNotifierProvider for [SchedulesController].
final schedulesControllerProvider =
    ChangeNotifierProvider<SchedulesController>((ref) {
  final bridge = ref.watch(platformBridgeProvider);
  final storage = ref.watch(storageRepositoryProvider);
  return SchedulesController(bridge, storage);
});
