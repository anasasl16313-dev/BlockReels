import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/platform_bridge_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import 'onboarding_controller.dart';

/// Riverpod ChangeNotifierProvider for [OnboardingController].
final onboardingControllerProvider =
    ChangeNotifierProvider<OnboardingController>((ref) {
  return OnboardingController(
    ref.watch(platformBridgeProvider),
    storage: ref.watch(storageRepositoryProvider),
  );
});
