import 'dart:io';
import 'package:block_reels/core/platform_channel/mock_platform_bridge.dart';
import 'package:block_reels/core/providers/dashboard_provider.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
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
    tempDir = await Directory.systemTemp.createTemp('dashboard_notifier_test_');
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

  group('DashboardNotifier State Management Tests', () {
    test('initializes and queries service health and stats', () async {
      final notifier = container.read(dashboardProvider.notifier);
      await notifier.refresh();

      final state = container.read(dashboardProvider);
      expect(state.isMasterEnabled, isTrue);
      expect(state.isAccessibilityServiceActive, isTrue);
      expect(state.isBatteryOptimizationDisabled, isTrue);
    });

    test('listens to simulated block events and updates real-time counter',
        () async {
      final notifier = container.read(dashboardProvider.notifier);
      await notifier.refresh();

      final initialBlocks = container.read(dashboardProvider).totalBlocksToday;

      bridge.simulateBlockEvent(
        packageName: 'com.instagram.android',
        appType: 'Instagram',
      );

      await pumpEventQueue();

      final updatedState = container.read(dashboardProvider);
      expect(updatedState.totalBlocksToday, initialBlocks + 1);
      expect(updatedState.lastBlockedApp, 'Instagram');
    });

    test('listens to service status changes', () async {
      final notifier = container.read(dashboardProvider.notifier);
      await notifier.refresh();

      bridge.simulateServiceStatusChanged(false);
      await pumpEventQueue();

      expect(container.read(dashboardProvider).isAccessibilityServiceActive,
          isFalse);

      bridge.simulateServiceStatusChanged(true);
      await pumpEventQueue();

      expect(container.read(dashboardProvider).isAccessibilityServiceActive,
          isTrue);
    });

    test('toggleMasterSwitch updates state and persisted setting', () async {
      final notifier = container.read(dashboardProvider.notifier);
      await notifier.refresh();

      await notifier.toggleMasterSwitch(false);
      expect(container.read(dashboardProvider).isMasterEnabled, isFalse);

      final settings = await storage.getSettings();
      expect(settings.isMasterEnabled, isFalse);
    });
  });
}
