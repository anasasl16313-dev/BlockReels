import 'package:flutter/material.dart';
import '../../../../core/widgets/adaptive_metrics.dart';

import '../../../../core/models/metrics_load_state.dart';
import '../../../dashboard/domain/models/protection_status.dart';
import '../../../pin_lock/pin_lock.dart';
import '../controllers/statistics_controller.dart';
import '../../domain/models/stats_timeframe.dart';
import '../widgets/kpi_card.dart';
import '../widgets/platform_breakdown_item.dart';

/// Screen displaying statistics, KPI cards, peak temptation window, and platform breakdowns.
class StatisticsScreen extends StatelessWidget {
  final StatisticsController controller;
  final PinSecurityController? pinController;
  final ProtectionStatus? protectionStatus;
  final VoidCallback? onReviewProtection;
  final Future<void> Function()? onHistoryCleared;

  const StatisticsScreen({
    super.key,
    required this.controller,
    this.pinController,
    this.protectionStatus,
    this.onReviewProtection,
    this.onHistoryCleared,
  });

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This permanently deletes saved interception history and pending events. Today’s native counters are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('btn_confirm_clear_history'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!await authorizeRestrictionChange(
      context,
      pinController,
      prompt: 'Enter PIN to clear interception history',
    )) {
      return;
    }
    try {
      await controller.clearHistory();
      await onHistoryCleared?.call();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not finish clearing history. Please try again.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final summary = controller.summary;
        final timeframe = controller.selectedTimeframe;
        final period = switch (timeframe) {
          StatsTimeframe.today => 'today',
          StatsTimeframe.thisWeek => 'this week',
          StatsTimeframe.thisMonth => 'this month',
          StatsTimeframe.allTime => 'all time',
        };
        final needsSetup =
            protectionStatus?.kind == ProtectionStatusKind.setupRequired ||
                protectionStatus?.kind == ProtectionStatusKind.paused;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Statistics'),
            actions: [
              IconButton(
                key: const Key('btn_clear_history'),
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear recorded history',
                onPressed: controller.loadState == MetricsLoadState.ready
                    ? () => _clearHistory(context)
                    : null,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Timeframe selector
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final period in const [
                    (StatsTimeframe.today, 'Today'),
                    (StatsTimeframe.thisWeek, 'Week'),
                    (StatsTimeframe.thisMonth, 'Month'),
                    (StatsTimeframe.allTime, 'All'),
                  ])
                    ChoiceChip(
                      label: Text(period.$2),
                      selected: controller.selectedTimeframe == period.$1,
                      onSelected: (_) => controller.setTimeframe(period.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (controller.loadState == MetricsLoadState.loading)
                const ListTile(
                  key: Key('statistics_loading'),
                  leading: CircularProgressIndicator(),
                  title: Text('Loading recorded activity…'),
                )
              else if (controller.loadState == MetricsLoadState.error)
                ListTile(
                  key: const Key('statistics_error'),
                  title: const Text('Could not read recorded activity.'),
                  subtitle: const Text('Try reading your local history again.'),
                  trailing: TextButton(
                    onPressed: controller.loadFromStorage,
                    child: const Text('Try again'),
                  ),
                )
              else if (summary.totalBlocks == 0)
                Card(
                  key: const Key('statistics_empty'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.insights_outlined, size: 32),
                        const SizedBox(height: 12),
                        Text(controller.records.isEmpty
                            ? 'No recorded blocks yet'
                            : 'No recorded blocks $period'),
                        const SizedBox(height: 8),
                        Text(controller.records.isEmpty
                            ? 'Statistics appear after the first recorded block.'
                            : 'No blocks recorded $period. Choose another period.'),
                        if (controller.records.isNotEmpty &&
                            timeframe != StatsTimeframe.allTime) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('statistics_view_all'),
                            onPressed: () =>
                                controller.setTimeframe(StatsTimeframe.allTime),
                            child: const Text('View all activity'),
                          ),
                        ],
                        if (needsSetup && onReviewProtection != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('statistics_review_protection'),
                            onPressed: onReviewProtection,
                            child: const Text('Review protection setup'),
                          ),
                        ] else if (controller.records.isEmpty &&
                            onReviewProtection != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('statistics_view_protection'),
                            onPressed: onReviewProtection,
                            child: const Text('View protection'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                AdaptiveMetrics(children: [
                  KpiCard(
                    value: summary.totalBlocks,
                    valueKey: const Key('stat_total_blocks'),
                    label: 'Blocked $period',
                  ),
                  KpiCard(
                    value: summary.totalTimeSavedSeconds < 60
                        ? summary.totalTimeSavedSeconds
                        : summary.totalTimeSavedMinutes,
                    unit: summary.totalTimeSavedSeconds < 60 ? 'sec' : 'min',
                    valueKey: const Key('stat_time_saved'),
                    label: 'Estimated time saved $period',
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Estimate: 45 seconds per recorded block by default, summed and rounded down to whole minutes. This is not measured screen time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (summary.peakHour case final peakHour?) ...[
                  Text(
                    'Most recorded blocks by hour $period: ${peakHour.toString().padLeft(2, '0')}:00–${(peakHour + 1).toString().padLeft(2, '0')}:00 (${summary.hourlyBins[peakHour]} blocks)',
                    key: const Key('stat_peak_window'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'BLOCKS BY APP · ${period.toUpperCase()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...summary.appPercentages.entries
                    .map((e) => PlatformBreakdownItem(
                          appType: e.key,
                          percentage: e.value,
                          count: summary.blocksByApp[e.key] ?? 0,
                        )),
              ],
            ],
          ),
        );
      },
    );
  }
}
