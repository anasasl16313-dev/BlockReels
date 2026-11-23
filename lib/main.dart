import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/restored_protection_sync.dart';
import 'core/platform_channel/method_channel_platform_bridge.dart';
import 'core/platform_channel/platform_bridge.dart';
import 'core/providers/platform_bridge_provider.dart';
import 'core/providers/storage_provider.dart';
import 'core/storage/hive_storage_repository.dart';
import 'core/storage/storage_repository.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(AppStartup(
    storageRepository: HiveStorageRepository(),
    platformBridge: MethodChannelPlatformBridge(),
  ));
}

/// Keeps the application behind initialization until saved settings are readable.
class AppStartup extends StatefulWidget {
  final StorageRepository storageRepository;
  final PlatformBridge platformBridge;

  const AppStartup({
    super.key,
    required this.storageRepository,
    required this.platformBridge,
  });

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Future<void>? _initialization;

  Future<void> _initialize() async {
    await widget.storageRepository.init();
    await RestoredProtectionSync.reconcile(
        widget.storageRepository, widget.platformBridge);
    final settings = await widget.storageRepository.getSettings();
    if (settings.isForegroundServiceEnabled) {
      await widget.platformBridge.startForegroundService();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _initialization ??= _initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError) {
            return ProviderScope(
              overrides: [
                storageRepositoryProvider
                    .overrideWithValue(widget.storageRepository),
                platformBridgeProvider.overrideWithValue(widget.platformBridge),
              ],
              child: const BlockReelsApp(),
            );
          }
          return MaterialApp(
            title: 'BlockReels',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: snapshot.connectionState == ConnectionState.done
                ? StartupErrorView(
                    onRetry: () => setState(() => _initialization = null),
                  )
                : const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
          );
        },
      );
}
