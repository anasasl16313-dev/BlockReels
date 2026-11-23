import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/block_diagnostic_code.dart';
import '../models/history_log.dart';
import '../models/intervention_mode.dart';
import '../platform_channel/dtos/platform_event.dart';
import '../platform_channel/platform_bridge.dart';
import '../storage/storage_repository.dart';

/// Persists native block events exactly once and fans them out to UI listeners.
class BlockEventRecorder {
  final PlatformBridge _bridge;
  final StorageRepository _storage;

  final StreamController<HistoryLog> _recordedLogs =
      StreamController<HistoryLog>.broadcast();
  final Uuid _uuid = const Uuid();

  StreamSubscription<PlatformEvent>? _subscription;
  Future<void> _writeQueue = Future<void>.value();
  bool _started = false;
  bool _disposed = false;
  int _pendingWrites = 0;
  Future<void>? _drain;
  bool _drainAgain = false;

  BlockEventRecorder(this._bridge, this._storage);

  Stream<HistoryLog> get recordedLogs => _recordedLogs.stream;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscription = _bridge.eventStream.listen((event) {
      if (event is BlockEvent && event.durablyQueued) {
        // A delayed notification may belong to a cleared outbox. Read its current rows.
        unawaited(drainPending());
      } else if (event is BlockEvent) {
        unawaited(_serialize(() async {
          await _save(event);
          final id = event.eventId;
          if (id != null) await _bridge.acknowledgeBlockEvents([id]);
        }));
      } else if (event.eventType == 'BLOCK_EVENTS_CONNECTED') {
        unawaited(drainPending());
      }
    }, onError: (Object error) {
      unawaited(drainPending());
    });
    unawaited(drainPending());
  }

  Future<void> clearHistory() => _serialize(() async {
        if (!await _bridge.clearPendingBlockEvents()) {
          throw StateError('Could not clear pending block events');
        }
        await _storage.clearHistory();
      }, propagateError: true);

  Future<void> _serialize(Future<void> Function() operation,
      {bool propagateError = false}) {
    final wasIdle = _pendingWrites == 0;
    _pendingWrites++;
    Future<void> run() async {
      try {
        await operation();
      } catch (_) {
        if (propagateError) rethrow;
        debugPrint(
            '[BlockEventRecorder] Block event delivery will be retried.');
      } finally {
        _pendingWrites--;
      }
    }

    final result = wasIdle ? run() : _writeQueue.then((_) => run());
    _writeQueue = propagateError ? result.catchError((Object _) {}) : result;
    return result;
  }

  /// Drains only real native events; counters are never converted into history.
  Future<void> drainPending() {
    if (_disposed) return Future<void>.value();
    if (_drain != null) {
      _drainAgain = true;
      return _drain!;
    }
    final task = _serialize(() async {
      do {
        _drainAgain = false;
        while (!_disposed) {
          final batch = await _bridge.readPendingBlockEvents(limit: 100);
          if (batch.isEmpty) break;
          final savedIds = <String>[];
          var allSaved = true;
          for (final event in batch) {
            try {
              await _save(event);
              final id = event.eventId;
              if (id != null) {
                savedIds.add(id);
              } else {
                allSaved = false;
              }
            } catch (_) {
              allSaved = false;
            }
          }
          final acknowledged = savedIds.isNotEmpty &&
              await _bridge.acknowledgeBlockEvents(savedIds);
          // Avoid spinning on a failed save or acknowledgement. Resume/reconnect retries it.
          if (!allSaved || !acknowledged) {
            _drainAgain = false;
            return;
          }
          if (batch.length < 100) break;
        }
      } while (_drainAgain && !_disposed);
    });
    _drain = task.whenComplete(() {
      _drain = null;
      // A connection can arrive after the last read but before this completion.
      if (_drainAgain && !_disposed) return drainPending();
    });
    return _drain!;
  }

  Future<void> _save(BlockEvent event) async {
    final timestamp = event.timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
        : DateTime.now();
    final log = HistoryLog(
      id: event.eventId ?? _uuid.v4(),
      timestamp: timestamp,
      packageName: event.packageName,
      appName: _displayName(event.appType, event.packageName),
      interventionMode: _modeFromWire(event.interventionMode),
      detectionReason: blockDiagnosticCode(event.detectionReason),
    );

    final inserted = await _storage.addHistoryLogIfAbsent(log);
    if (inserted && !_recordedLogs.isClosed) {
      _recordedLogs.add(log);
    }
  }

  String _displayName(String appType, String packageName) {
    switch (appType.toUpperCase()) {
      case 'INSTAGRAM':
        return 'Instagram';
      case 'YOUTUBE':
        return 'YouTube';
      case 'FACEBOOK':
        return 'Facebook';
      case 'TIKTOK':
      case 'DOUYIN':
        return 'TikTok';
      default:
        if (packageName.isEmpty) return 'Unknown app';
        final segment = packageName.split('.').last;
        return segment.isEmpty
            ? packageName
            : segment[0].toUpperCase() + segment.substring(1);
    }
  }

  InterventionMode _modeFromWire(String wireName) {
    final normalized = wireName.trim().toUpperCase();
    if (normalized == 'STRICT_BLOCK' || normalized == 'STRICTBLOCK') {
      return InterventionMode.strictBlock;
    }
    if (normalized == 'MINDFUL_PAUSE' || normalized == 'MINDFULPAUSE') {
      return InterventionMode.mindfulPause;
    }
    return InterventionMode.immediateBack;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _writeQueue;
    await _recordedLogs.close();
  }
}
