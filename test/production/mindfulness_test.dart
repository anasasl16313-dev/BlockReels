import 'package:block_reels/features/mindfulness/mindfulness.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completed hold unlocks and grants a native allowance',
      (tester) async {
    final bridge = FakePlatformBridge();
    final controller = MindfulnessController(
      bridge: bridge,
      packageName: 'com.instagram.android',
      holdDurationSeconds: 1,
    );

    controller.startHold();
    expect(controller.state.isHolding, isTrue);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    expect(controller.state.isUnlocked, isTrue);
    expect(controller.state.holdProgress, 1.0);
    expect(controller.unlockCallbackCalled, isTrue);
    expect(bridge.grantAllowanceCalls, hasLength(1));
    expect(
      bridge.grantAllowanceCalls.single.packageName,
      'com.instagram.android',
    );

    controller.dispose();
    await bridge.dispose();
  });

  testWidgets('early release resets progress and does not unlock',
      (tester) async {
    final bridge = FakePlatformBridge();
    final controller = MindfulnessController(
      bridge: bridge,
      packageName: 'com.instagram.android',
      holdDurationSeconds: 2,
    );

    controller.startHold();
    await tester.pump(const Duration(milliseconds: 200));
    controller.cancelHold();
    await tester.pump(const Duration(seconds: 2));

    expect(controller.state.isUnlocked, isFalse);
    expect(controller.state.isHolding, isFalse);
    expect(controller.state.holdProgress, 0.0);
    expect(bridge.grantAllowanceCalls, isEmpty);

    controller.dispose();
    await bridge.dispose();
  });
}
