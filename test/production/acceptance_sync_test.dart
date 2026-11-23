import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/features/app_blocker/app_blocker.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/fake_services.dart';

class RejectingAppBridge extends FakePlatformBridge {
  bool reject = false;
  @override
  Future<bool> syncAppToggles(Map<String, bool> appToggles) async {
    await super.syncAppToggles(appToggles);
    return !reject;
  }
}

void main() {
  testWidgets('failed app sync makes protection status unavailable until retry',
      (tester) async {
    final storage = FakeStorageRepository();
    await storage.saveRule(RuleModel(
      id: 'instagram', packageName: 'com.instagram.android', appName: 'Instagram',
    ));
    final bridge = RejectingAppBridge();
    final blocker = AppBlockerController(bridge, storage: storage);
    await tester.runAsync(pumpEventQueue);
    final dashboard = DashboardController(
      bridge,
      storage: storage,
      appBlockerListenable: blocker,
      readAppToggles: () => {
        for (final entry in blocker.state.appConfigs.entries)
          entry.key: entry.value.isEnabled
      },
      readMasterEnabled: () => blocker.state.isMasterEnabled,
      readSynchronizationHealthy: () => blocker.syncHealthy,
      retrySynchronization: blocker.retrySync,
    );
    await tester.runAsync(dashboard.refresh);
    bridge.reject = true;
    await tester
        .runAsync(() => blocker.toggleApp('com.instagram.android', false));
    expect(blocker.syncHealthy, isFalse);
    expect(dashboard.state.protectionStatus.kind,
        ProtectionStatusKind.unavailable);
    await tester
        .pumpWidget(MaterialApp(home: AppBlockerScreen(controller: blocker)));
    expect(find.textContaining('Protection status is unavailable'),
        findsOneWidget);
    bridge.reject = false;
    await tester.runAsync(dashboard.retryProtectionStatus);
    await tester.pump();
    expect(blocker.syncHealthy, isTrue);
    expect(dashboard.state.protectionStatus.kind,
        isNot(ProtectionStatusKind.unavailable));
    expect(storage.rules['com.instagram.android']!.isEnabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    dashboard.dispose();
    blocker.dispose();
    await tester.runAsync(bridge.dispose);
  });
}
