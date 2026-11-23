import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoryLog Model Tests', () {
    test('instantiates with defaults and custom properties', () {
      final now = DateTime(2026, 8, 15, 14, 30);
      final log = HistoryLog(
        id: 'log_1',
        timestamp: now,
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        interventionMode: InterventionMode.mindfulPause,
        estimatedTimeSavedSeconds: 45,
        wasDismissedWithHold: true,
      );

      expect(log.id, 'log_1');
      expect(log.timestamp, now);
      expect(log.packageName, 'com.instagram.android');
      expect(log.appName, 'Instagram');
      expect(log.interventionMode, InterventionMode.mindfulPause);
      expect(log.estimatedTimeSavedSeconds, 45);
      expect(log.wasDismissedWithHold, isTrue);
      expect(log.detectionReason, 'SURGICAL_HEURISTIC');
    });

    test('copyWith updates specified fields', () {
      final log = HistoryLog(
        id: 'log_1',
        timestamp: DateTime.now(),
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        interventionMode: InterventionMode.mindfulPause,
      );

      final updated = log.copyWith(
        wasDismissedWithHold: true,
        wasOverridden: true,
        estimatedTimeSavedSeconds: 60,
      );

      expect(updated.wasDismissedWithHold, isTrue);
      expect(updated.wasOverridden, isTrue);
      expect(updated.estimatedTimeSavedSeconds, 60);
      expect(updated.packageName, 'com.instagram.android');
    });

    test('JSON serialization roundtrip maintains fidelity', () {
      final now = DateTime.now();
      final log = HistoryLog(
        id: 'log_abc',
        timestamp: now,
        packageName: 'com.google.android.youtube',
        appName: 'YouTube Shorts',
        interventionMode: InterventionMode.immediateBack,
        estimatedTimeSavedSeconds: 40,
        wasDismissedWithHold: false,
        detectionReason: 'PIVOT_REEL_CONTAINER',
        wasOverridden: false,
      );

      final json = log.toJson();
      final restored = HistoryLog.fromJson(json);

      expect(restored.id, log.id);
      expect(restored.packageName, log.packageName);
      expect(restored.appName, log.appName);
      expect(restored.interventionMode, log.interventionMode);
      expect(restored.estimatedTimeSavedSeconds, log.estimatedTimeSavedSeconds);
      expect(restored.wasDismissedWithHold, log.wasDismissedWithHold);
      expect(restored.detectionReason, log.detectionReason);
      expect(restored.wasOverridden, log.wasOverridden);
    });
  });
}
