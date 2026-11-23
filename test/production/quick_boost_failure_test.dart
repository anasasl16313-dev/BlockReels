import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/fake_services.dart';

class RejectingBridge extends FakePlatformBridge {
  bool reject = false;
  @override
  Future<bool> syncSchedules(List<ScheduleDto> schedules) async {
    await super.syncSchedules(schedules);
    return !reject;
  }
}

void main() {
  test(
      'failed start never claims an active session and restores local schedules',
      () async {
    final storage = FakeStorageRepository();
    final bridge = RejectingBridge();
    final controller = DashboardController(bridge, storage: storage);
    await controller.refresh();
    bridge.reject = true;
    await controller.activateQuickBoost('Focus', 25);
    expect(controller.state.activeBoostSessionName, isNull);
    expect(controller.boostUncertain, isTrue);
    expect(controller.boostError, contains('Could not start'));
    expect(controller.state.protectionStatus.kind,
        ProtectionStatusKind.unavailable);
    expect(storage.schedules, isEmpty);
    controller.dispose();
    await bridge.dispose();
  });

  test('failed end does not claim the active session ended', () async {
    final storage = FakeStorageRepository();
    final bridge = RejectingBridge();
    final controller = DashboardController(bridge, storage: storage);
    await controller.refresh();
    await controller.activateQuickBoost('Focus', 25);
    bridge.reject = true;
    await controller.endQuickBoost();
    expect(controller.state.activeBoostSessionName, 'Focus');
    expect(controller.boostUncertain, isTrue);
    expect(controller.boostError, contains('Could not end'));
    expect(storage.schedules.values.single.name, 'Focus');
    bridge.reject = false;
    await controller.endQuickBoost();
    expect(controller.state.activeBoostSessionName, isNull);
    expect(storage.schedules, isEmpty);
    controller.dispose();
    await bridge.dispose();
  });
}
