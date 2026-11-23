import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform_channel/dtos/platform_event.dart';
import '../platform_channel/platform_bridge.dart';

/// Provider for the [PlatformBridge] singleton.
/// Default provides [MethodChannelPlatformBridge], easily overridden with [MockPlatformBridge] in tests.
final platformBridgeProvider = Provider<PlatformBridge>((ref) {
  throw UnimplementedError(
    'platformBridgeProvider must be initialized with a PlatformBridge implementation.',
  );
});

/// Reactive stream provider emitting all platform events.
final platformEventsStreamProvider =
    StreamProvider.autoDispose<PlatformEvent>((ref) {
  final bridge = ref.watch(platformBridgeProvider);
  return bridge.eventStream;
});

/// Reactive stream provider specifically filtering for short-form feed block events.
final blockEventsStreamProvider = StreamProvider.autoDispose<BlockEvent>((ref) {
  final bridge = ref.watch(platformBridgeProvider);
  return bridge.blockEventsStream;
});

/// Reactive stream provider emitting native Accessibility Service enabled/disabled state changes.
final serviceStatusStreamProvider = StreamProvider.autoDispose<bool>((ref) {
  final bridge = ref.watch(platformBridgeProvider);
  return bridge.serviceStatusStream;
});
