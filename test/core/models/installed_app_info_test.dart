import 'dart:typed_data';
import 'package:block_reels/core/models/installed_app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstalledAppInfo Model Tests', () {
    test('instantiates with defaults and custom properties', () {
      final app = InstalledAppInfo(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isSystemApp: false,
        iconBytes: Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(app.packageName, 'com.instagram.android');
      expect(app.appName, 'Instagram');
      expect(app.isSystemApp, isFalse);
      expect(app.iconBytes, isNotNull);
      expect(app.iconBytes!.length, 4);
    });

    test('copyWith updates properties', () {
      const app = InstalledAppInfo(
        packageName: 'com.example.app',
        appName: 'Example',
      );

      final updated = app.copyWith(
        appName: 'Example Updated',
        isSystemApp: true,
      );

      expect(updated.packageName, 'com.example.app');
      expect(updated.appName, 'Example Updated');
      expect(updated.isSystemApp, isTrue);
    });

    test('toMap and fromMap serialization maintains fields', () {
      final app = InstalledAppInfo(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        isSystemApp: true,
        iconBytes: Uint8List.fromList([10, 20, 30]),
      );

      final map = app.toMap();
      final restored = InstalledAppInfo.fromMap(map);

      expect(restored.packageName, app.packageName);
      expect(restored.appName, app.appName);
      expect(restored.isSystemApp, app.isSystemApp);
      expect(restored.iconBytes, equals(app.iconBytes));
    });
  });
}
