import 'package:flutter/material.dart';

import '../../domain/models/dashboard_state.dart';

/// Recent recorded blocks from the current session.
class RecentInterceptionsList extends StatelessWidget {
  final DashboardState state;
  final VoidCallback? onViewStatistics;

  const RecentInterceptionsList(
      {super.key, required this.state, this.onViewStatistics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (state.recentEvents.isEmpty)
          Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('No blocks recorded in this session yet.'),
              if (onViewStatistics != null)
                TextButton(
                    onPressed: onViewStatistics,
                    child: const Text('View statistics')),
            ]),
          ))
        else
          ...state.recentEvents.map((log) {
            final local = log.timestamp.toLocal();
            final time = MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(local));
            final date =
                MaterialLocalizations.of(context).formatMediumDate(local);
            return ListTile(
              key: Key(
                  'event_${log.appName}_${log.timestamp.millisecondsSinceEpoch}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline,
                  color: theme.colorScheme.primary),
              title: Text(log.appName),
              subtitle: Text('Feed blocked · $date, $time'),
            );
          }),
      ],
    );
  }
}
