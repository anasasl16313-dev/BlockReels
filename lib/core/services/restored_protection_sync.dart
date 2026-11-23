import '../platform_channel/dtos/intervention_config_dto.dart';
import '../platform_channel/dtos/schedule_dto.dart';
import '../platform_channel/platform_bridge.dart';
import '../storage/storage_repository.dart';

/// Replay the current committed revision after an interrupted or partial restore.
class RestoredProtectionSync {
  static final _queues = Expando<Future<void>>();

  static Future<void> reconcile(
      StorageRepository storage, PlatformBridge bridge) {
    final previous = _queues[storage] ?? Future<void>.value();
    final operation = previous.then((_) => _apply(storage, bridge));
    _queues[storage] = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> _apply(
      StorageRepository storage, PlatformBridge bridge) async {
    while (true) {
      final snapshot = await storage.readPendingProtectionSnapshot();
      if (snapshot == null) return;
      final settings = snapshot.settings;
      final config = InterventionConfigDto(
        defaultMode: settings.defaultInterventionMode.name,
        holdDurationSeconds: settings.defaultHoldDurationSeconds,
        pinProtected: settings.pinLockEnabled,
        soundEnabled: settings.soundDuckingEnabled,
        hapticsEnabled: settings.hapticFeedbackEnabled,
      );
      if (!await bridge.syncRestoredProtection(
        rules: snapshot.rules,
        schedules: snapshot.schedules.map(ScheduleDto.fromModel).toList(),
        config: config,
        settings: settings,
      )) {
        throw StateError(
            'Restored protection settings are awaiting Android confirmation');
      }
      await storage.acknowledgeProtectionSync(snapshot.revision);
    }
  }
}
