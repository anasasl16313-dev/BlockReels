import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Keeps metric cards readable at the user's chosen text size.
class AdaptiveMetrics extends StatelessWidget {
  final List<Widget> children;

  const AdaptiveMetrics({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final minimumWidth =
              180 * MediaQuery.textScalerOf(context).scale(16) / 16;
          final columns = ((constraints.maxWidth + 8) / (minimumWidth + 8))
              .floor()
              .clamp(1, children.length);
          final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in children) SizedBox(width: width, child: child)
            ],
          );
        },
      );
}

/// Abbreviates only when necessary, without shrinking or splitting the unit.
/// Assistive technology always gets the unabbreviated value.
class MetricValue extends StatelessWidget {
  final num number;
  final String unit;
  final String semanticLabel;
  final TextStyle style;
  final Key? textKey;
  final int decimalDigits;

  const MetricValue({
    super.key,
    required this.number,
    this.unit = '',
    required this.semanticLabel,
    required this.style,
    this.textKey,
    this.decimalDigits = 0,
  });

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final format = NumberFormat.decimalPattern()
          ..maximumFractionDigits = decimalDigits;
        final suffix = unit.isEmpty ? '' : '\u00a0$unit';
        final full = '${format.format(number)}$suffix';
        final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
        final compact = NumberFormat.compact()..maximumFractionDigits = 1;
        final compactInteger = NumberFormat.compact()
          ..maximumFractionDigits = 0;
        final candidates = [
          full,
          '${compact.format(number)}$suffix',
          '${compactInteger.format(number)}$suffix',
          '${number.toStringAsExponential(1).replaceFirst('e+', 'e')}$suffix',
          '${number.toStringAsExponential(0).replaceFirst('e+', 'e')}$suffix',
        ];
        bool fits(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: effectiveStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final result = painter.width <= constraints.maxWidth;
          painter.dispose();
          return result;
        }

        final displayed =
            candidates.firstWhere(fits, orElse: () => candidates.last);
        return Semantics(
          label: semanticLabel,
          excludeSemantics: true,
          child: Text(
            displayed,
            key: textKey,
            style: style,
            textAlign: TextAlign.center,
            softWrap: false,
          ),
        );
      });
}
