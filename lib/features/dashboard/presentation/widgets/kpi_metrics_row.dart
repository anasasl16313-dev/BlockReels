import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adaptive_metrics.dart';
import '../../domain/models/dashboard_state.dart';

/// Row displaying today's recorded blocks and the lifetime saved-time estimate.
class KpiMetricsRow extends StatelessWidget {
  final DashboardState state;

  const KpiMetricsRow({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final statusColors = StatusThemeExtension.of(context);

    return AdaptiveMetrics(children: [
      Card(
        key: const Key('card_blocked_today'),
        child: Padding(
          padding: AppSpacing.cardContent,
          child: Column(
            children: [
              Icon(
                Icons.block_outlined,
                color: statusColors.success.accent,
                semanticLabel: 'Blocked reels',
              ),
              const SizedBox(height: AppSpacing.xxs),
              MetricValue(
                number: state.totalBlockedToday,
                semanticLabel:
                    '${state.totalBlockedToday} recorded blocks today',
                textKey: const Key('counter_blocked_today'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: statusColors.success.accent,
                ),
              ),
              const Text('Reels blocked\nToday',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
      Card(
        key: const Key('card_time_saved'),
        child: Padding(
          padding: AppSpacing.cardContent,
          child: Column(
            children: [
              Icon(
                Icons.hourglass_bottom_outlined,
                color: statusColors.info.accent,
                semanticLabel: 'Estimated time saved, all time',
              ),
              const SizedBox(height: AppSpacing.xxs),
              MetricValue(
                number: state.totalTimeSavedSeconds < 60
                    ? state.totalTimeSavedSeconds
                    : state.totalTimeSavedMinutes >= 60
                        ? state.totalTimeSavedMinutes / 60
                        : state.totalTimeSavedMinutes,
                unit: state.totalTimeSavedSeconds < 60
                    ? 'sec'
                    : state.totalTimeSavedMinutes >= 60
                        ? 'hr'
                        : 'min',
                decimalDigits: 1,
                semanticLabel:
                    'Estimated time saved, all time: ${state.totalTimeSavedSeconds} seconds',
                textKey: const Key('counter_time_saved'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: statusColors.info.accent,
                ),
              ),
              const Text('Estimated time saved\nAll time',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ]);
  }
}
