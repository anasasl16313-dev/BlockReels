import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/dashboard_state.dart';

/// Card showing consecutive days with recorded blocks and this week's dots.
class FocusStreakCard extends StatelessWidget {
  final DashboardState state;

  const FocusStreakCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusColors = FocusThemeExtension.of(context);

    return Card(
      key: const Key('card_focus_streak'),
      child: Padding(
        padding: AppSpacing.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: focusColors.streakColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${state.currentStreakDays} ${state.currentStreakDays == 1 ? 'day' : 'days'} with recorded blocks',
                    key: const Key('streak_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Consecutive days with at least one recorded block. Dots show this week (Mon–Sun).',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final isFilled = index < state.weeklyStreakDots.length
                    ? state.weeklyStreakDots[index]
                    : false;
                const days = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday'
                ];
                return Semantics(
                    label:
                        '${days[index]}: ${isFilled ? 'recorded blocks' : 'no recorded blocks'}',
                    child: CircleAvatar(
                      key: Key('dot_streak_$index'),
                      radius: 8,
                      backgroundColor: isFilled
                          ? focusColors.streakColor
                          : theme.colorScheme.outline,
                    ));
              }),
            ),
          ],
        ),
      ),
    );
  }
}
