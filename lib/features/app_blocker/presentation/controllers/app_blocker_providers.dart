import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/platform_bridge_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import 'app_blocker_controller.dart';

/// Riverpod provider for [AppBlockerController].
final appBlockerControllerProvider =
    ChangeNotifierProvider<AppBlockerController>((ref) {
  return AppBlockerController(
    ref.watch(platformBridgeProvider),
    storage: ref.watch(storageRepositoryProvider),
    settingsNotifier: ref.watch(settingsProvider.notifier),
  );
});
