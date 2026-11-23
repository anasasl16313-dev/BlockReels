import 'dart:io';
import 'package:block_reels/core/platform_channel/mock_platform_bridge.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/providers/theme_provider.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository storage;
  late MockPlatformBridge bridge;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('theme_notifier_test_');
    storage = HiveStorageRepository();
    await storage.init(customPath: tempDir.path);
    bridge = MockPlatformBridge();

    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    bridge.dispose();
    await storage.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ThemeModeNotifier State Management Tests', () {
    test('switches theme mode and persists update', () async {
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.setThemeMode('amoled');
      expect(container.read(themeModeProvider), 'amoled');

      await notifier.setThemeMode('light');
      expect(container.read(themeModeProvider), 'light');

      await notifier.setThemeMode('dark');
      expect(container.read(themeModeProvider), 'dark');
    });
  });
}
