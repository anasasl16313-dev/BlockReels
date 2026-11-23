import '../../../../core/models/quick_boost_window.dart';
import '../../../../core/models/schedule_model.dart';

enum ProtectionStatusKind {
  verifying,
  setupRequired,
  paused,
  active,
  scheduled,
  unavailable,
}

enum ProtectionStatusAction {
  none,
  openAccessibility,
  openAppControls,
  openSchedules,
  retry,
}

/// A truthful summary of whether blocking can affect any supported app now.
class ProtectionStatus {
  final ProtectionStatusKind kind;
  final String title;
  final String reason;
  final ProtectionStatusAction action;
  final String? actionLabel;
  final int selectedAppCount;
  final List<String> activeScheduleNames;

  const ProtectionStatus({
    required this.kind,
    required this.title,
    required this.reason,
    this.action = ProtectionStatusAction.none,
    this.actionLabel,
    this.selectedAppCount = 0,
    this.activeScheduleNames = const [],
  });

  const ProtectionStatus.verifying()
      : this(
          kind: ProtectionStatusKind.verifying,
          title: 'Checking protection',
          reason: 'Reading Accessibility, app selections, and schedules…',
        );

  const ProtectionStatus.unavailable()
      : this(
          kind: ProtectionStatusKind.unavailable,
          title: 'Status unavailable',
          reason: 'BlockReels could not verify the current protection state.',
          action: ProtectionStatusAction.retry,
          actionLabel: 'Check again',
        );

  bool get canBlockNow =>
      kind == ProtectionStatusKind.active ||
      kind == ProtectionStatusKind.scheduled;
}

/// Mirrors the native `NativeStateStore.isAppBlockingActive` priority.
///
/// Decision table, in priority order:
///
/// | Ready | Accessibility | Master | Active schedule/boost | Selected app | Result |
/// |-------|---------------|--------|-----------------------|--------------|--------|
/// | No    | any           | any    | any                   | any          | Verifying |
/// | Yes   | Off           | any    | any                   | any          | Setup required |
/// | Yes   | On            | Off    | any                   | any          | Paused |
/// | Yes   | On            | On     | Yes                   | any          | Scheduled |
/// | Yes   | On            | On     | No                    | Yes          | Active |
/// | Yes   | On            | On     | No                    | No           | Paused |
///
/// Native schedules override individual app toggles only while the master
/// switch remains on. An empty schedule target list means all supported apps.
class ProtectionStatusResolver {
  ProtectionStatusResolver._();

  static const Set<String> nativeTargetPackages = {
    'com.instagram.android',
    'com.google.android.youtube',
    'com.facebook.katana',
    'com.facebook.lite',
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.trill',
    'com.ss.android.ugc.aweme',
    'com.ss.android.ugc.aweme.lite',
  };

  static ProtectionStatus resolve({
    required bool isReady,
    required bool isAccessibilityServiceActive,
    required bool isMasterEnabled,
    required Map<String, bool> selectedApps,
    required List<ScheduleModel> schedules,
    required DateTime now,
  }) {
    if (!isReady) return const ProtectionStatus.verifying();

    final selectedCount =
        selectedApps.values.where((selected) => selected).length;
    if (!isAccessibilityServiceActive) {
      return ProtectionStatus(
        kind: ProtectionStatusKind.setupRequired,
        title: 'Setup required',
        reason:
            'Accessibility access is off, so BlockReels cannot detect Reels or Shorts.',
        action: ProtectionStatusAction.openAccessibility,
        actionLabel: 'Open Accessibility settings',
        selectedAppCount: selectedCount,
      );
    }

    final activeSchedules = schedules
        .where((schedule) => schedule.isCurrentlyActive(now))
        .where(_canAffectNativeTarget)
        .toList();

    if (!isMasterEnabled) {
      return ProtectionStatus(
        kind: ProtectionStatusKind.paused,
        title: 'Blocking paused',
        reason: activeSchedules.isEmpty
            ? 'The master switch is off. App selections are not being applied.'
            : 'The master switch is off. Android does not apply app selections or active schedules.',
        action: ProtectionStatusAction.openAppControls,
        actionLabel: 'Review app controls',
        selectedAppCount: selectedCount,
        activeScheduleNames:
            activeSchedules.map((schedule) => schedule.name).toList(),
      );
    }

    if (activeSchedules.isNotEmpty) {
      final names = activeSchedules.map((schedule) => schedule.name).toList();
      final affected = _affectedPackages(activeSchedules);
      final appliesToAll = activeSchedules.any(
        (schedule) => schedule.targetPackageNames.isEmpty,
      );
      final scheduleLabel = names.length == 1
          ? '“${names.first}” is active'
          : '${names.length} schedules are active';
      final targetLabel = appliesToAll
          ? 'all supported target apps'
          : affected
              .map((package) => switch (package) {
                    'com.instagram.android' => 'Instagram',
                    'com.google.android.youtube' => 'YouTube',
                    'com.facebook.katana' => 'Facebook',
                    'com.facebook.lite' => 'Facebook Lite',
                    _ => 'TikTok',
                  })
              .toSet()
              .join(', ');
      final onlyQuickBoosts = activeSchedules.every(
        (schedule) => schedule.id.startsWith(quickBoostIdPrefix),
      );

      return ProtectionStatus(
        kind: ProtectionStatusKind.scheduled,
        title: 'Scheduled protection',
        reason:
            '$scheduleLabel for $targetLabel. It overrides individual app selections while the master switch is on.',
        action: onlyQuickBoosts
            ? ProtectionStatusAction.none
            : ProtectionStatusAction.openSchedules,
        actionLabel: onlyQuickBoosts ? null : 'Review schedules',
        selectedAppCount: selectedCount,
        activeScheduleNames: names,
      );
    }

    if (selectedCount > 0) {
      return ProtectionStatus(
        kind: ProtectionStatusKind.active,
        title: 'Blocking active',
        reason:
            '$selectedCount ${selectedCount == 1 ? 'app is' : 'apps are'} selected. Only Reels and Shorts viewers are affected.',
        action: ProtectionStatusAction.openAppControls,
        actionLabel: 'Review selected apps',
        selectedAppCount: selectedCount,
      );
    }

    final hasEnabledSchedules = schedules.any((schedule) => schedule.isActive);
    return ProtectionStatus(
      kind: ProtectionStatusKind.paused,
      title: 'Blocking paused',
      reason: hasEnabledSchedules
          ? 'No apps are selected and no schedule is active now. Configured schedules can still turn protection on during their windows.'
          : 'No apps are selected and no schedule is active.',
      action: ProtectionStatusAction.openAppControls,
      actionLabel: 'Choose apps',
    );
  }

  static bool _canAffectNativeTarget(ScheduleModel schedule) {
    if (schedule.targetPackageNames.isEmpty) return true;
    return schedule.targetPackageNames.any(nativeTargetPackages.contains);
  }

  static Set<String> _affectedPackages(List<ScheduleModel> schedules) {
    if (schedules.any((schedule) => schedule.targetPackageNames.isEmpty)) {
      return nativeTargetPackages;
    }
    return schedules
        .expand((schedule) => schedule.targetPackageNames)
        .where(nativeTargetPackages.contains)
        .toSet();
  }
}
