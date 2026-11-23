import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/app_settings.dart';
import 'core/providers/block_event_recorder_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/storage_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/screens/main_shell_screen.dart';
import 'features/onboarding/onboarding.dart';

/// Root Application widget configuring Material 3 design and dynamic theme switching,
/// with a bootstrap gate routing first-run users into onboarding before the main shell.
class BlockReelsApp extends ConsumerStatefulWidget {
  const BlockReelsApp({super.key});

  @override
  ConsumerState<BlockReelsApp> createState() => _BlockReelsAppState();
}

class _BlockReelsAppState extends ConsumerState<BlockReelsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(blockEventRecorderProvider).drainPending());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(blockEventRecorderProvider);
    final themeMode =
        ref.watch(settingsProvider.select((settings) => settings.themeMode));

    return MaterialApp(
      title: 'BlockReels',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: themeMode.toLowerCase() == 'amoled'
          ? AppTheme.amoledTheme
          : AppTheme.darkTheme,
      themeMode: _resolveThemeMode(themeMode),
      home: const AppBootstrapGate(),
    );
  }

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'amoled':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

/// Decides the landing experience: onboarding on first launch, otherwise the main shell.
class AppBootstrapGate extends ConsumerStatefulWidget {
  const AppBootstrapGate({super.key});

  @override
  ConsumerState<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends ConsumerState<AppBootstrapGate> {
  Future<AppSettings>? _initialSettings;
  bool? _onboardingCompletedOverride;

  Future<void> _handleOnboardingFinished() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.loadSettings();
    if (mounted) {
      setState(() => _onboardingCompletedOverride = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompletedOverride == true) {
      return const MainShellScreen(key: Key('app_main_shell'));
    }

    return FutureBuilder<AppSettings>(
      future: _initialSettings ??=
          ref.read(storageRepositoryProvider).getSettings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return StartupErrorView(
            onRetry: () => setState(() => _initialSettings = null),
          );
        }
        final completed = snapshot.data?.isOnboardingCompleted ?? false;
        if (!completed && snapshot.data?.pinLockEnabled != true && snapshot.data?.strictModeEnabled != true) {
          return OnboardingWizardScreen(
            key: const Key('app_onboarding_gate'),
            controller: ref.watch(onboardingControllerProvider),
            onFinished: _handleOnboardingFinished,
          );
        }
        return const MainShellScreen(key: Key('app_main_shell'));
      },
    );
  }
}

class StartupErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const StartupErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not open your saved data. Please try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('startup_retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
}
