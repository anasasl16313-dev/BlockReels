import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/platform_bridge_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import 'mindfulness_controller.dart';

/// Riverpod provider for [MindfulnessController].
final mindfulnessControllerProvider =
    ChangeNotifierProvider<MindfulnessController>((ref) {
  final settings = ref.read(settingsProvider);
  return MindfulnessController(
    bridge: ref.read(platformBridgeProvider),
    holdDurationSeconds: settings.defaultHoldDurationSeconds,
  );
});
