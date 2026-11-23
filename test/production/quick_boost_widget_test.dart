import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quick boost banner counts down and can be ended early',
      (tester) async {
    var now = DateTime(2026, 1, 1, 10);
    final bridge = FakePlatformBridge();
    final storage = FakeStorageRepository();
    final controller = DashboardController(
      bridge,
      storage: storage,
      clock: () => now,
      boostTickInterval: const Duration(milliseconds: 10),
    );

    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => QuickBoostRow(controller: controller),
          ),
        ),
      ),
    );

    await controller.activateQuickBoost('Pomodoro', 25);
    await tester.pump();

    expect(find.text('Pomodoro · 25:00 left'), findsOneWidget);

    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Pomodoro · 15:00 left'), findsOneWidget);

    await tester.tap(find.byKey(const Key('button_end_boost')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const Key('banner_active_boost')), findsNothing);
    expect(controller.state.activeBoostSessionName, isNull);

    controller.dispose();
    await bridge.dispose();
  });
}
