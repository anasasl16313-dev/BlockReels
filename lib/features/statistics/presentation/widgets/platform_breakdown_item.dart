import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Row widget displaying the percentage distribution and count for a specific platform.
class PlatformBreakdownItem extends StatelessWidget {
  final String appType;
  final double percentage;
  final int count;

  const PlatformBreakdownItem({
    super.key,
    required this.appType,
    required this.percentage,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(appType,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${percentage.toStringAsFixed(1)}% (${NumberFormat.decimalPattern().format(count)} blocks)',
                key: Key('breakdown_$appType'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            semanticsLabel: '$appType share of recorded blocks',
            key: Key('breakdown_bar_$appType'),
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
