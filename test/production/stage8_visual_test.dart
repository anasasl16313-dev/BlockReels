import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/theme/app_theme.dart';
import 'package:block_reels/features/navigation/presentation/screens/main_shell_screen.dart';
import 'package:block_reels/features/statistics/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/fake_services.dart';
import '../test_helpers/visual_test_support.dart';

void main() {
  setUpAll(loadDeviceTestFonts);
  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
    'amoled': AppTheme.amoledTheme
  }.entries) {
    testWidgets('visual review ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = FakeStorageRepository();
      final bridge = FakePlatformBridge();
      for (final item in const {
        'com.instagram.android': 'Instagram',
        'com.google.android.youtube': 'YouTube Shorts',
        'com.facebook.katana': 'Facebook Reels',
        'com.zhiliaoapp.musically': 'TikTok',
      }.entries) {
        await storage.saveRule(RuleModel(
            id: item.key,
            packageName: item.key,
            appName: item.value,
            isEnabled: true));
      }
      await storage.addHistoryLog(HistoryLog(
          id: 'preview',
          timestamp: DateTime.now(),
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          interventionMode: InterventionMode.mindfulPause));
      final container = ProviderContainer(overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge)
      ]);
      addTearDown(() async {
        container.dispose();
        await bridge.dispose();
      });
      await container.read(settingsProvider.notifier).loadSettings();
      final boundary = GlobalKey();
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: entry.value,
                  home: const MainShellScreen()))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Focus session'), findsOneWidget);
      for (final platform in ['instagram', 'youtube', 'facebook', 'tiktok']) {
        expect(
            tester
                .widget<FilterChip>(find.byKey(Key('quick_chip_$platform')))
                .selected,
            isTrue);
      }
      await saveLayoutPreview(
          tester, find.byKey(boundary), '${entry.key}-home');
      await tester.tap(find.byKey(const Key('chip_boost_25m')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('banner_active_boost')), findsOneWidget);
      expect(find.byKey(const Key('button_end_boost')), findsOneWidget);
      await saveLayoutPreview(
          tester, find.byKey(boundary), '${entry.key}-active');
      await tester.tap(find.byKey(const Key('button_end_boost')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('destination_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('details_com.instagram.android')),
          findsOneWidget);
      expect(find.byKey(const Key('dropdown_com.instagram.android')),
          findsNothing);
      await saveLayoutPreview(
          tester, find.byKey(boundary), '${entry.key}-apps');
      await tester.tap(find.byKey(const Key('details_com.instagram.android')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('dropdown_com.instagram.android')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await saveLayoutPreview(
          tester, find.byKey(boundary), '${entry.key}-apps-expanded');
      await tester.tap(find.byKey(const Key('destination_2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('empty_add_schedule')), findsOneWidget);
      await saveLayoutPreview(
          tester, find.byKey(boundary), '${entry.key}-empty-schedules');
      await storage.clearHistory();
      await tester.runAsync(
          () => container.read(statisticsControllerProvider).loadFromStorage());
      await tester.tap(find.byKey(const Key('destination_3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('statistics_empty')), findsOneWidget);
      await saveLayoutPreview(
          tester, find.byKey(boundary), '${entry.key}-empty-statistics');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
