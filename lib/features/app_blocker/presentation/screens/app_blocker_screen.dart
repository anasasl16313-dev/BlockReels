import 'package:flutter/material.dart';

import '../../../pin_lock/pin_lock.dart';
import '../controllers/app_blocker_controller.dart';
import '../widgets/app_target_card.dart';

/// Screen providing granular and master controls for app blocking.
class AppBlockerScreen extends StatelessWidget {
  final AppBlockerController controller;

  final PinSecurityController? pinController;

  const AppBlockerScreen({super.key, required this.controller, this.pinController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('App Controls', maxLines: 2, softWrap: true),
            actions: [
              Semantics(
                  label: 'Master protection switch',
                  child: Switch(
                    key: const Key('master_blocker_switch'),
                    value: state.isMasterEnabled,
                    onChanged: controller.setMasterToggle,
                  )),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!controller.syncHealthy) ...[
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Changes may not be saved or synced. Protection status is unavailable.'),
                        TextButton(
                            onPressed: controller.retrySync,
                            child: const Text('Retry sync')),
                      ]),
                )),
                const SizedBox(height: 16),
              ],
              Text('Choose the apps you want to protect.',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                  'Only short-video feeds are blocked. Messages, profiles, search and regular videos remain available. Active schedules may also apply when manual blocking is off.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              ...state.appConfigs.values.map((config) => AppTargetCard(
                    key: Key('target_${config.packageName}'),
                    config: config,
                    pinController: pinController,
                    controller: controller,
                  )),
            ],
          ),
        );
      },
    );
  }
}
