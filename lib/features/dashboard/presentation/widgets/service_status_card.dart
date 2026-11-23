import 'package:flutter/material.dart';

import '../../../../core/privacy/accessibility_disclosure.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/protection_status.dart';
import '../controllers/dashboard_controller.dart';

/// Card summarizing effective blocking, not merely Accessibility availability.
class ServiceStatusCard extends StatelessWidget {
  final DashboardController controller;
  final VoidCallback? onOpenAppControls;
  final VoidCallback? onOpenSchedules;
  final Future<bool> Function()? authorizeRetry;

  const ServiceStatusCard({
    super.key,
    required this.controller,
    this.onOpenAppControls,
    this.onOpenSchedules,
    this.authorizeRetry,
  });

  @override
  Widget build(BuildContext context) {
    final status = controller.state.protectionStatus;
    final statusColors = StatusThemeExtension.of(context);
    final palette = switch (status.kind) {
      ProtectionStatusKind.active => statusColors.success,
      ProtectionStatusKind.scheduled => statusColors.info,
      ProtectionStatusKind.paused => statusColors.warning,
      ProtectionStatusKind.verifying => statusColors.info,
      ProtectionStatusKind.setupRequired => statusColors.error,
      ProtectionStatusKind.unavailable => statusColors.error,
    };
    final icon = switch (status.kind) {
      ProtectionStatusKind.active => Icons.shield,
      ProtectionStatusKind.scheduled => Icons.event_available_outlined,
      ProtectionStatusKind.paused => Icons.pause_circle_outline,
      ProtectionStatusKind.verifying => Icons.sync,
      ProtectionStatusKind.setupRequired => Icons.gpp_bad_outlined,
      ProtectionStatusKind.unavailable => Icons.error_outline,
    };
    final canRunAction = switch (status.action) {
      ProtectionStatusAction.none => false,
      ProtectionStatusAction.openAppControls => onOpenAppControls != null,
      ProtectionStatusAction.openSchedules => onOpenSchedules != null,
      ProtectionStatusAction.openAccessibility ||
      ProtectionStatusAction.retry =>
        true,
    };

    return Card(
      key: const Key('card_service_status'),
      color: palette.container,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: palette.accent),
      ),
      child: Padding(
        padding: AppSpacing.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  key: const Key('protection_status_icon'),
                  color: palette.accent,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.title,
                        key: const Key('service_status_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        status.reason,
                        key: const Key('service_status_reason'),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canRunAction && status.actionLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('btn_protection_action'),
                onPressed: () => _runAction(context, status.action),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.foreground,
                  side: BorderSide(color: palette.accent),
                ),
                icon: Icon(_actionIcon(status.action)),
                label: Text(status.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(
      BuildContext context, ProtectionStatusAction action) async {
    switch (action) {
      case ProtectionStatusAction.openAccessibility:
        await openAccessibilitySettingsWithConsent(
            context, controller.requestAccessibilitySetup);
        return;
      case ProtectionStatusAction.openAppControls:
        onOpenAppControls?.call();
        return;
      case ProtectionStatusAction.openSchedules:
        onOpenSchedules?.call();
        return;
      case ProtectionStatusAction.retry:
        if (authorizeRetry != null && !await authorizeRetry!()) return;
        await controller.retryProtectionStatus();
        return;
      case ProtectionStatusAction.none:
        return;
    }
  }

  IconData _actionIcon(ProtectionStatusAction action) {
    return switch (action) {
      ProtectionStatusAction.openAccessibility => Icons.settings_accessibility,
      ProtectionStatusAction.openAppControls => Icons.tune,
      ProtectionStatusAction.openSchedules => Icons.schedule,
      ProtectionStatusAction.retry => Icons.refresh,
      ProtectionStatusAction.none => Icons.info_outline,
    };
  }
}
