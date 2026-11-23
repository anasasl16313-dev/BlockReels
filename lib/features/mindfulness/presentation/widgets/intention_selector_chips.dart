import 'package:flutter/material.dart';

/// Chips widget allowing the user to label their current emotional intention for opening the app.
class IntentionSelectorChips extends StatelessWidget {
  final String? selectedIntention;
  final ValueChanged<String> onSelected;

  const IntentionSelectorChips({
    super.key,
    required this.selectedIntention,
    required this.onSelected,
  });

  static const List<String> defaultIntentions = [
    'Habit',
    'Boredom',
    'Procrastinating',
    'Important',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: defaultIntentions.map((intention) {
        final isSelected = selectedIntention == intention;
        return ChoiceChip(
          key: Key('chip_$intention'),
          label: Text(intention),
          selected: isSelected,
          onSelected: (_) => onSelected(intention),
        );
      }).toList(),
    );
  }
}
