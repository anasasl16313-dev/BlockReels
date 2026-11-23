import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleModel Model Tests', () {
    test('instantiates with defaults and custom parameters', () {
      final rule = RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
      );

      expect(rule.id, 'instagram');
      expect(rule.packageName, 'com.instagram.android');
      expect(rule.appName, 'Instagram');
      expect(rule.isEnabled, isTrue);
      expect(rule.interventionMode, InterventionMode.mindfulPause);
      expect(rule.holdDurationSeconds, 7);
      expect(rule.dailyQuotaMinutes, 0);
      expect(rule.dailyReelLimit, 0);
      expect(rule.allowChatAndDMs, isTrue);
      expect(rule.allowProfileGrids, isTrue);
      expect(rule.blockEntireApp, isFalse);
      expect(rule.customMessage, isNull);
    });

    test('copyWith updates specified fields only', () {
      final rule = RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
      );

      final updated = rule.copyWith(
        isEnabled: false,
        interventionMode: InterventionMode.strictBlock,
        holdDurationSeconds: 12,
        dailyQuotaMinutes: 30,
        customMessage: 'Stay focused on work',
      );

      expect(updated.id, 'instagram');
      expect(updated.packageName, 'com.instagram.android');
      expect(updated.isEnabled, isFalse);
      expect(updated.interventionMode, InterventionMode.strictBlock);
      expect(updated.holdDurationSeconds, 12);
      expect(updated.dailyQuotaMinutes, 30);
      expect(updated.customMessage, 'Stay focused on work');
      expect(updated.allowChatAndDMs, isTrue);
    });

    test('JSON serialization roundtrip maintains data integrity', () {
      final original = RuleModel(
        id: 'yt_shorts',
        packageName: 'com.google.android.youtube',
        appName: 'YouTube Shorts',
        isEnabled: true,
        interventionMode: InterventionMode.strictBlock,
        holdDurationSeconds: 10,
        dailyQuotaMinutes: 15,
        dailyReelLimit: 5,
        allowChatAndDMs: false,
        allowProfileGrids: true,
        blockEntireApp: false,
        customMessage: 'No shorts allowed',
      );

      final json = original.toJson();
      final restored = RuleModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.packageName, original.packageName);
      expect(restored.appName, original.appName);
      expect(restored.isEnabled, original.isEnabled);
      expect(restored.interventionMode, original.interventionMode);
      expect(restored.holdDurationSeconds, original.holdDurationSeconds);
      expect(restored.dailyQuotaMinutes, original.dailyQuotaMinutes);
      expect(restored.dailyReelLimit, original.dailyReelLimit);
      expect(restored.allowChatAndDMs, original.allowChatAndDMs);
      expect(restored.allowProfileGrids, original.allowProfileGrids);
      expect(restored.blockEntireApp, original.blockEntireApp);
      expect(restored.customMessage, original.customMessage);
    });

    test('equality and hashCode evaluate properly', () {
      final rule1 = RuleModel(
        id: 'tiktok',
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
      );
      final rule2 = RuleModel(
        id: 'tiktok',
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
      );
      final rule3 = RuleModel(
        id: 'tiktok',
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        isEnabled: false,
      );

      expect(rule1, equals(rule2));
      expect(rule1.hashCode, equals(rule2.hashCode));
      expect(rule1 == rule3, isFalse);
    });
  });
}
