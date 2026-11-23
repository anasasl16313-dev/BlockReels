import 'package:flutter/material.dart';

/// All destinations remain labelled; large text gets a second row.
class AdaptiveNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AdaptiveNavigationBar(
      {super.key, required this.selectedIndex, required this.onSelected});

  static const destinations = [
    ('Home', 'Dashboard', Icons.shield_outlined),
    ('Apps', 'App controls', Icons.block_outlined),
    ('Plans', 'Schedules', Icons.schedule_outlined),
    ('Stats', 'Statistics', Icons.insights_outlined),
    ('Settings', 'Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium!;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final painter = TextPainter(
              text: TextSpan(text: 'Settings', style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final twoRows =
                painter.width + 16 > constraints.maxWidth / destinations.length;
            painter.dispose();

            Widget destination(int index) {
              final item = destinations[index];
              final selected = index == selectedIndex;
              return Expanded(
                  child: Semantics(
                container: true,
                button: true,
                selected: selected,
                label: item.$2,
                onTap: () => onSelected(index),
                excludeSemantics: true,
                child: Tooltip(
                    message: item.$2,
                    child: InkWell(
                      key: Key('destination_$index'),
                      onTap: () => onSelected(index),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.secondaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 2),
                                  child: Icon(item.$3,
                                      color: selected
                                          ? theme
                                              .colorScheme.onSecondaryContainer
                                          : theme
                                              .colorScheme.onSurfaceVariant)),
                            ),
                            const SizedBox(height: 4),
                            Text(item.$1,
                                style: style, textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    )),
              ));
            }

            return Column(
                mainAxisSize: MainAxisSize.min,
                children: twoRows
                    ? [
                        Row(children: [
                          for (var i = 0; i < 3; i++) destination(i)
                        ]),
                        Row(children: [
                          for (var i = 3; i < 5; i++) destination(i)
                        ])
                      ]
                    : [
                        Row(children: [
                          for (var i = 0; i < 5; i++) destination(i)
                        ])
                      ]);
          })),
    );
  }
}
