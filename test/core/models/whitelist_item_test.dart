import 'package:block_reels/core/models/whitelist_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhitelistItem Model Tests', () {
    test('instantiates with defaults and custom properties', () {
      final item = WhitelistItem(
        id: 'ig_dm',
        packageName: 'com.instagram.android',
        componentId: 'direct_thread',
        reason: 'Allow private messaging',
      );

      expect(item.id, 'ig_dm');
      expect(item.packageName, 'com.instagram.android');
      expect(item.componentId, 'direct_thread');
      expect(item.reason, 'Allow private messaging');
      expect(item.isEnabled, isTrue);
      expect(item.isSystemProtected, isTrue);
    });

    test('copyWith updates fields accurately', () {
      final item = WhitelistItem(
        id: 'ig_dm',
        packageName: 'com.instagram.android',
        componentId: 'direct_thread',
        reason: 'Allow private messaging',
      );

      final updated = item.copyWith(
        isEnabled: false,
        viewIdPattern: 'com.instagram.android:id/direct_recycler',
      );

      expect(updated.isEnabled, isFalse);
      expect(updated.viewIdPattern, 'com.instagram.android:id/direct_recycler');
      expect(updated.packageName, 'com.instagram.android');
    });

    test('JSON serialization roundtrip maintains properties', () {
      final item = WhitelistItem(
        id: 'custom_1',
        packageName: 'com.facebook.katana',
        componentId: 'messages_tab',
        viewIdPattern: 'com.facebook.katana:id/tab_messages',
        reason: 'Allow Messenger in Facebook',
        isEnabled: true,
        isSystemProtected: false,
      );

      final json = item.toJson();
      final restored = WhitelistItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.packageName, item.packageName);
      expect(restored.componentId, item.componentId);
      expect(restored.viewIdPattern, item.viewIdPattern);
      expect(restored.reason, item.reason);
      expect(restored.isEnabled, item.isEnabled);
      expect(restored.isSystemProtected, item.isSystemProtected);
    });
  });
}
