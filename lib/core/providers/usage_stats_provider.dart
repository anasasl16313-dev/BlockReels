import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/usage_stats.dart';
import 'history_provider.dart';
import 'storage_provider.dart';

/// Reactive provider computing real-time [UsageStats] across stored block events.
final usageStatsProvider = FutureProvider<UsageStats>((ref) async {
  // Recompute whenever history changes
  ref.watch(historyProvider);
  final storage = ref.watch(storageRepositoryProvider);
  return await storage.getUsageStats();
});
