import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/widgets/adaptive_metrics.dart';

/// Card widget displaying a single key performance indicator (KPI) metric.
class KpiCard extends StatelessWidget {
  final num value;
  final String unit;
  final Key valueKey;
  final String label;
  final Color? valueColor;

  const KpiCard({
    super.key,
    required this.value,
    this.unit = '',
    required this.valueKey,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardContent,
        child: Column(
          children: [
            MetricValue(
              number: value,
              unit: unit,
              semanticLabel: '$label: $value $unit',
              textKey: valueKey,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
