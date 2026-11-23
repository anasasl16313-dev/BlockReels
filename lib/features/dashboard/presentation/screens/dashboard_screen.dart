import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/metrics_load_state.dart';
import '../../../../core/privacy/accessibility_disclosure.dart';
import '../../domain/models/protection_status.dart';
import '../../../pin_lock/pin_lock.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/focus_streak_card.dart';
import '../widgets/kpi_metrics_row.dart';
import '../widgets/quick_app_toggles_row.dart';
import '../widgets/quick_boost_row.dart';
import '../widgets/recent_interceptions_list.dart';
import '../widgets/service_status_card.dart';

/// Main Dashboard screen presenting effective protection and live controls.
class DashboardScreen extends StatefulWidget {
  final DashboardController controller;
  final PinSecurityController? pinController;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAppControls;
  final VoidCallback? onOpenSchedules;
  final VoidCallback? onOpenStatistics;

  const DashboardScreen({
    super.key,
    required this.controller,
    this.pinController,
    this.onOpenSettings,
    this.onOpenAppControls,
    this.onOpenSchedules,
    this.onOpenStatistics,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.startProtectionMonitoring();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.stopProtectionMonitoring();
      widget.controller.startProtectionMonitoring();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.stopProtectionMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refresh());
    }
  }

  Future<bool> _authorizeRestrictionChange(BuildContext context) {
    return authorizeRestrictionChange(context, widget.pinController);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('BlockReels'),
            actions: [
              IconButton(
                key: const Key('btn_open_settings'),
                tooltip: 'Open settings',
                onPressed: widget.onOpenSettings,
                icon: const Icon(
                  Icons.settings,
                  key: Key('icon_settings'),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ServiceStatusCard(
                controller: widget.controller,
                onOpenAppControls: widget.onOpenAppControls,
                onOpenSchedules: widget.onOpenSchedules,
                authorizeRetry: () => _authorizeRestrictionChange(context),
              ),
              const SizedBox(height: 16),
              if (state.protectionStatus.kind == ProtectionStatusKind.verifying)
                const Text('Loading app selections…')
              else if (state.protectionStatus.kind ==
                  ProtectionStatusKind.unavailable)
                const Text(
                    'App selections are unavailable. Try refreshing protection status.')
              else
                QuickAppTogglesRow(
                  controller: widget.controller,
                  authorizeChange: () => _authorizeRestrictionChange(context),
                ),
              const SizedBox(height: 16),
              QuickBoostRow(
                controller: widget.controller,
                authorizeChange: () => _authorizeRestrictionChange(context),
              ),
              const SizedBox(height: 24),
              Text('Today', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (state.metricsLoadState == MetricsLoadState.loading)
                const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Loading recorded activity…'),
                )
              else if (state.metricsLoadState == MetricsLoadState.error)
                ListTile(
                  title: const Text('Could not read recorded activity.'),
                  trailing: TextButton(
                    onPressed: widget.controller.refresh,
                    child: const Text('Try again'),
                  ),
                )
              else if (state.totalRecordedBlocks == 0)
                Card(
                  key: const Key('dashboard_empty'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.insights_outlined, size: 32),
                        const SizedBox(height: 12),
                        const Text('No recorded blocks yet'),
                        const SizedBox(height: 8),
                        const Text(
                            'Activity appears after the first recorded block.'),
                        if (state.protectionStatus.kind ==
                            ProtectionStatusKind.setupRequired) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('btn_empty_accessibility_setup'),
                            onPressed: () =>
                                openAccessibilitySettingsWithConsent(
                                    context,
                                    widget
                                        .controller.requestAccessibilitySetup),
                            child: const Text('Set up protection'),
                          ),
                        ] else if (state.protectionStatus.kind ==
                                ProtectionStatusKind.paused &&
                            widget.onOpenAppControls != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: widget.onOpenAppControls,
                            child: const Text('Review app controls'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                KpiMetricsRow(state: state),
                const SizedBox(height: 8),
                Text(
                  'Estimated time saved adds 45 seconds per recorded block by default; it is not measured screen time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FocusStreakCard(state: state),
              ],
              const SizedBox(height: 16),
              if (state.metricsLoadState == MetricsLoadState.ready)
                RecentInterceptionsList(
                    state: state, onViewStatistics: widget.onOpenStatistics),
            ],
          ),
        );
      },
    );
  }
}
