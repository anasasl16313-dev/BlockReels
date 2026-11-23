import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/app_target_config_model.dart';
import '../../domain/models/intervention_mode.dart';
import '../../../pin_lock/pin_lock.dart';
import '../controllers/app_blocker_controller.dart';

/// A compact app selection with optional intervention details.
class AppTargetCard extends StatefulWidget {
  final AppTargetConfigModel config;
  final AppBlockerController controller;

  final PinSecurityController? pinController;

  const AppTargetCard({
    super.key,
    required this.config,
    required this.controller,
    this.pinController,
  });

  @override
  State<AppTargetCard> createState() => _AppTargetCardState();
}

class _AppTargetCardState extends State<AppTargetCard> {
  bool Function()? _modeAuthorization;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final controller = widget.controller;
    final isMasterEnabled = controller.state.isMasterEnabled;
    final availability = controller.availabilityLabel(config.packageName);
    final isProtected =
        config.isEnabled && isMasterEnabled && availability == null;
    final isPaused = config.isEnabled && !isMasterEnabled;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statuses = StatusThemeExtension.of(context);
    final palette = isProtected
        ? statuses.success
        : isPaused
            ? statuses.warning
            : null;
    final foreground = palette?.foreground ?? colors.onSurface;
    final icon = switch (config.packageName) {
      'com.instagram.android' => Icons.camera_alt_outlined,
      'com.google.android.youtube' => Icons.play_circle_outline,
      'com.facebook.katana' => Icons.people_outline,
      'com.zhiliaoapp.musically' => Icons.music_note_outlined,
      _ => Icons.apps_outlined,
    };
    Widget showDetails(Widget child) => MediaQuery.disableAnimationsOf(context)
        ? child
        : AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: child,
          );

    return Card(
      key: Key('card_${config.packageName}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: palette?.container,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: palette?.accent ?? colors.outlineVariant),
      ),
      child: Padding(
        padding: AppSpacing.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: palette?.accent ?? colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isProtected
                                ? Icons.check_circle_outline
                                : isPaused
                                    ? Icons.pause_circle_outline
                                    : Icons.remove_circle_outline,
                            size: 16,
                            color: palette?.accent ?? colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              availability ??
                                  (isProtected
                                      ? 'Selected · manual blocking is on'
                                      : isPaused
                                          ? 'Selected · master protection is off'
                                          : 'Not selected for manual blocking'),
                              key: Key('status_${config.packageName}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mode: ${config.interventionMode.displayName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  label: 'Select ${config.appName} for manual blocking',
                  child: Switch(
                    key: Key('switch_${config.packageName}'),
                    value: config.isEnabled && isMasterEnabled,
                    onChanged: isMasterEnabled
                        ? (val) => controller.toggleApp(config.packageName, val)
                        : null,
                  ),
                ),
              ],
            ),
            if (config.isEnabled) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                key: Key('details_${config.packageName}'),
                style: TextButton.styleFrom(foregroundColor: foreground),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Hide options' : 'Blocking options'),
              ),
              showDetails(
                _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            label: 'Intervention mode for ${config.appName}',
                            child: DropdownButton<InterventionMode>(
                              isExpanded: true,
                              key: Key('dropdown_${config.packageName}'),
                              value: config.interventionMode,
                              dropdownColor: colors.surface,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: foreground,
                              ),
                              items: InterventionMode.values
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode.displayName),
                                    ),
                                  )
                                  .toList(),
                              onTap: () {
                                _modeAuthorization = widget.pinController?.captureRestrictionAuthorization();
                              },
                              onChanged: (mode) {
                                final authorized = _modeAuthorization;
                                _modeAuthorization = null;
                                if (mode != null && (authorized?.call() ?? widget.pinController == null)) {
                                  controller.setInterventionMode(
                                    config.packageName,
                                    mode,
                                  );
                                }
                              },
                            ),
                          ),
                          Text(
                            switch (config.interventionMode) {
                              InterventionMode.autoBack =>
                                'Leaves the short-video feed immediately.',
                              InterventionMode.mindfulPause =>
                                'Hold for ${controller.holdDurationSeconds}s to get temporary access.',
                              InterventionMode.strictBlock =>
                                'Leaves the feed with no unlock button. PIN protects settings changes.',
                            },
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
