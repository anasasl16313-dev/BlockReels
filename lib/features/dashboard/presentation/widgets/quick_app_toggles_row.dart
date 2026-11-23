import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';

/// Row of fast per-platform blocker toggles (IG, YT, FB, TT).
class QuickAppTogglesRow extends StatelessWidget {
  final DashboardController controller;
  final Future<bool> Function()? authorizeChange;

  const QuickAppTogglesRow({
    super.key,
    required this.controller,
    this.authorizeChange,
  });

  Future<void> _toggle(String packageName, bool enabled) async {
    final authorize = authorizeChange;
    if (authorize != null && !await authorize()) return;
    await controller.toggleApp(packageName, enabled);
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App selections',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Manual selections. Active schedules can also apply while the master switch is on.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              key: const Key('quick_chip_instagram'),
              tooltip: 'Instagram selection',
              label: const Text('Instagram'),
              selected: state.activeToggles['com.instagram.android'] ?? false,
              onSelected: (val) => _toggle('com.instagram.android', val),
            ),
            FilterChip(
              key: const Key('quick_chip_youtube'),
              tooltip: 'YouTube selection',
              label: const Text('YouTube'),
              selected:
                  state.activeToggles['com.google.android.youtube'] ?? false,
              onSelected: (val) => _toggle('com.google.android.youtube', val),
            ),
            FilterChip(
              key: const Key('quick_chip_facebook'),
              tooltip: 'Facebook selection',
              label: const Text('Facebook'),
              selected: state.activeToggles['com.facebook.katana'] ?? false,
              onSelected: (val) => _toggle('com.facebook.katana', val),
            ),
            FilterChip(
              key: const Key('quick_chip_tiktok'),
              tooltip: 'TikTok selection',
              label: const Text('TikTok'),
              selected:
                  state.activeToggles['com.zhiliaoapp.musically'] ?? false,
              onSelected: (val) => _toggle('com.zhiliaoapp.musically', val),
            ),
          ],
        ),
      ],
    );
  }
}
