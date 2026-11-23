import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InterventionMode Model Tests', () {
    test('fromString parses known and alias string formats correctly', () {
      expect(InterventionMode.fromString('immediateBack'),
          InterventionMode.immediateBack);
      expect(InterventionMode.fromString('immediate_back'),
          InterventionMode.immediateBack);
      expect(InterventionMode.fromString('AUTO_BACK'),
          InterventionMode.immediateBack);
      expect(
          InterventionMode.fromString('back'), InterventionMode.immediateBack);

      expect(InterventionMode.fromString('mindfulPause'),
          InterventionMode.mindfulPause);
      expect(InterventionMode.fromString('mindful_pause'),
          InterventionMode.mindfulPause);
      expect(InterventionMode.fromString('MINDFUL_PAUSE'),
          InterventionMode.mindfulPause);
      expect(InterventionMode.fromString('mindful'),
          InterventionMode.mindfulPause);

      expect(InterventionMode.fromString('strictBlock'),
          InterventionMode.strictBlock);
      expect(InterventionMode.fromString('strict_block'),
          InterventionMode.strictBlock);
      expect(InterventionMode.fromString('STRICT_BLOCK'),
          InterventionMode.strictBlock);
      expect(
          InterventionMode.fromString('strict'), InterventionMode.strictBlock);
    });

    test('fromString falls back to immediateBack for null or unknown strings',
        () {
      expect(InterventionMode.fromString(null), InterventionMode.immediateBack);
      expect(InterventionMode.fromString('unknown_value'),
          InterventionMode.immediateBack);
      expect(InterventionMode.fromString(''), InterventionMode.immediateBack);
    });

    test('displayName and description return informative text', () {
      for (final mode in InterventionMode.values) {
        expect(mode.displayName.isNotEmpty, isTrue);
        expect(mode.description.isNotEmpty, isTrue);
      }
    });

    test('toJson returns enum name', () {
      expect(InterventionMode.immediateBack.toJson(), 'immediateBack');
      expect(InterventionMode.mindfulPause.toJson(), 'mindfulPause');
      expect(InterventionMode.strictBlock.toJson(), 'strictBlock');
    });
  });
}
