import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../../domain/models/protection_status.dart';

/// Row providing 1-tap temporary Pomodoro & Deep Work focus boosts.
class QuickBoostRow extends StatelessWidget {
  final DashboardController controller;
  final Future<bool> Function()? authorizeChange;

  const QuickBoostRow({
    super.key,
    required this.controller,
    this.authorizeChange,
  });

  Future<void> _boost(String name, int minutes) async {
    final authorize = authorizeChange;
    if (authorize != null && !await authorize()) return;
    await controller.activateQuickBoost(name, minutes);
  }

  String _formatRemaining(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final colors = Theme.of(context).colorScheme;

    final active = state.activeBoostSessionName != null;
    final ready =
        state.protectionStatus.kind != ProtectionStatusKind.verifying &&
            state.protectionStatus.kind != ProtectionStatusKind.unavailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus session',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                active
                    ? (controller.boostUncertain
                        ? 'Session status could not be confirmed'
                        : 'Your session is running')
                    : !ready
                        ? 'Waiting for protection status.'
                        : state.activeToggles.values.any((selected) => selected)
                            ? 'Applies to selected apps while the master switch is on.'
                            : 'With no apps selected, the session applies to all supported apps while the master switch is on.',
                style: Theme.of(context).textTheme.bodySmall),
            if (controller.boostError != null) ...[
              const SizedBox(height: 8),
              Semantics(
                  liveRegion: true,
                  child: Text(controller.boostError!,
                      style: TextStyle(color: colors.error))),
            ],
            if (active) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('banner_active_boost'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14)),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined,
                        color: colors.onPrimaryContainer),
                    Text(
                        '${state.activeBoostSessionName} · ${_formatRemaining(state.activeBoostRemainingSeconds ?? 0)} left',
                        key: const Key('text_active_boost_remaining'),
                        style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600)),
                    TextButton(
                      key: const Key('button_end_boost'),
                      style: TextButton.styleFrom(
                          foregroundColor: colors.onPrimaryContainer),
                      onPressed: controller.boostBusy
                          ? null
                          : () async {
                              final authorize = authorizeChange;
                              if (authorize != null && !await authorize()) {
                                return;
                              }
                              await controller.endQuickBoost();
                            },
                      child: const Text('End session'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(
                key: const Key('chip_boost_25m'),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Start 25 min'),
                onPressed: ready && !controller.boostBusy
                    ? () => _boost('25m Pomodoro', 25)
                    : null,
              ),
              OutlinedButton.icon(
                key: const Key('chip_boost_1h'),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Start 1 hour'),
                onPressed: ready && !controller.boostBusy
                    ? () => _boost('1h Deep Work', 60)
                    : null,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
