import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/block_event_recorder.dart';
import 'platform_bridge_provider.dart';
import 'storage_provider.dart';

/// Owns the single subscription that persists native block events to Hive.
final blockEventRecorderProvider = Provider<BlockEventRecorder>((ref) {
  final recorder = BlockEventRecorder(
    ref.watch(platformBridgeProvider),
    ref.watch(storageRepositoryProvider),
  );
  recorder.start();
  ref.onDispose(recorder.dispose);
  return recorder;
});
