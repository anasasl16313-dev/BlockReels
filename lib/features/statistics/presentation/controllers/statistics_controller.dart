import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/history_log.dart';
import '../../../../core/models/metrics_load_state.dart';
import '../../../../core/providers/block_event_recorder_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/services/block_event_recorder.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../domain/models/block_record.dart';
import '../../domain/models/statistics_summary.dart';
import '../../domain/models/stats_timeframe.dart';
import '../../domain/services/statistics_analytics_engine.dart';

/// Controller managing statistics records, timeframe filtering, and insights computation.
class StatisticsController extends ChangeNotifier {
  final StorageRepository? _storage;
  final BlockEventRecorder? _recorder;
  final List<BlockRecord> _records = [];
  StatsTimeframe _selectedTimeframe = StatsTimeframe.today;
  DateTime? _mockNow;
  StreamSubscription<HistoryLog?>? _recordSub;
  Future<void>? _loading;
  int _historyRevision = 0;
  int _bulkRevision = 0;
  final _summaries = <StatsTimeframe, StatisticsSummary>{};
  DateTime? _summaryDate;
  Future<void>? _ready;
  bool _disposed = false;
  MetricsLoadState _loadState = MetricsLoadState.loading;

  StatsTimeframe get selectedTimeframe => _selectedTimeframe;
  List<BlockRecord> get records => List.unmodifiable(_records);
  DateTime get currentNow => _mockNow ?? DateTime.now();
  MetricsLoadState get loadState => _loadState;

  StatisticsController([this._storage, this._recorder]) {
    if (_storage != null) {
      _ready = loadFromStorage();
    } else {
      _loadState = MetricsLoadState.ready;
    }
    _recordSub = (_storage?.historyChanges ?? _recorder?.recordedLogs)?.listen(
      _handleHistoryChange,
    );
  }

  Future<void> _handleHistoryChange(HistoryLog? log) async {
    _historyRevision++;
    if (log == null) _bulkRevision++;
    final bulkRevision = _bulkRevision;
    _summaries.clear();
    await _ready;
    if (_disposed) return;
    if (log == null) {
      await loadFromStorage();
    } else {
      await _loading;
      // A bulk reload includes the latest state; don't replay an older append
      // over a clear/import that completed while this handler waited.
      if (!_disposed && bulkRevision == _bulkRevision) {
        _upsert(BlockRecord.fromHistoryLog(log));
      }
    }
  }

  void _upsert(BlockRecord record) {
    final index = _records.indexWhere((existing) => existing.id == record.id);
    if (index < 0) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
    _summaries.clear();
    notifyListeners();
  }

  Future<void> loadFromStorage() {
    if (_storage == null || _disposed) return Future<void>.value();
    return _loading ??= _loadFromStorage().whenComplete(() => _loading = null);
  }

  Future<void> _loadFromStorage() async {
    _loadState = MetricsLoadState.loading;
    notifyListeners();
    try {
      List<HistoryLog> logs;
      int revision;
      do {
        revision = _historyRevision;
        // Read all records, not the repository's default recent-history page.
        logs = await _storage!.getHistoryLogs(limit: 0x7fffffff);
        if (_disposed) return;
      } while (revision != _historyRevision);
      _records
        ..clear()
        ..addAll(logs.map(BlockRecord.fromHistoryLog));
      _summaries.clear();
      _loadState = MetricsLoadState.ready;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _loadState = MetricsLoadState.error;
      notifyListeners();
    }
  }

  /// Refresh date-dependent summaries after returning from the background.
  void refreshCalendar() {
    final now = currentNow;
    final date = DateTime(now.year, now.month, now.day);
    if (_summaryDate == date) return;
    _summaryDate = date;
    _summaries.clear();
    notifyListeners();
  }

  void setMockNow(DateTime now) {
    _mockNow = now;
    refreshCalendar();
  }

  Future<void> ingestRecord(BlockRecord record) async {
    await _ready;
    if (_disposed || _records.any((existing) => existing.id == record.id)) {
      return;
    }
    if (_storage != null) {
      await _storage.addHistoryLog(record.toHistoryLog());
    }
    if (!_disposed) _upsert(record);
  }

  void setTimeframe(StatsTimeframe timeframe) {
    _selectedTimeframe = timeframe;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _ready;
    if (_disposed) return;
    if (_storage != null) {
      await (_recorder?.clearHistory() ?? _storage.clearHistory());
      await loadFromStorage();
    } else {
      _records.clear();
      _summaries.clear();
      notifyListeners();
    }
  }

  StatisticsSummary get summary {
    final now = currentNow;
    final date = DateTime(now.year, now.month, now.day);
    if (_summaryDate != date) {
      _summaryDate = date;
      _summaries.clear();
    }
    return _summaries.putIfAbsent(
      _selectedTimeframe,
      () => StatisticsAnalyticsEngine.compute(
        records: _records,
        timeframe: _selectedTimeframe,
        now: now,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _recordSub?.cancel();
    super.dispose();
  }
}

/// Riverpod ChangeNotifierProvider for [StatisticsController].
final statisticsControllerProvider =
    ChangeNotifierProvider<StatisticsController>((ref) {
  return StatisticsController(
    ref.watch(storageRepositoryProvider),
    ref.watch(blockEventRecorderProvider),
  );
});
