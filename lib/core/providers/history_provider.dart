import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history_log.dart';
import '../storage/storage_repository.dart';
import 'storage_provider.dart';

/// StateNotifier managing the stream and list of historical block logs.
class HistoryNotifier extends StateNotifier<List<HistoryLog>> {
  final StorageRepository _storage;
  Future<void>? _ready;

  HistoryNotifier(this._storage) : super([]) {
    _ready = loadHistory();
  }

  Future<void> loadHistory({int limit = 100}) async {
    final logs = await _storage.getHistoryLogs(limit: limit);
    if (!mounted) return;
    state = logs;
  }

  Future<void> addLog(HistoryLog log) async {
    // Serialize behind initial load so a late-loading empty box can never
    // clobber freshly appended entries.
    final ready = _ready;
    if (ready != null) {
      await ready;
    }
    state = [log, ...state];
    await _storage.addHistoryLog(log);
  }

  Future<void> clearHistory() async {
    final ready = _ready;
    if (ready != null) {
      await ready;
    }
    state = [];
    await _storage.clearHistory();
  }
}

/// Provider for [HistoryNotifier] exposing recent historical block occurrences.
final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryLog>>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  return HistoryNotifier(storage);
});
