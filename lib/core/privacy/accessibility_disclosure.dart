import 'package:flutter/material.dart';

/// Shipped locally; also available without requesting Accessibility access.
const localPrivacyPolicy = '''Screen access and use
BlockReels uses Android Accessibility window events for Instagram, YouTube, Facebook and TikTok/Douyin, including supported regional versions. When protection applies, it inspects screen information Android exposes: app/window identity, view types, structure and bounds, resource identifiers, text and accessibility descriptions. This may include captions and other content shown in those apps.

Detection uses this information on your device to recognize short-video feeds and avoid ordinary app areas such as messages and profiles. Your chosen intervention uses Android Back/Home navigation or a blocking/mindful-pause overlay. Screen information is processed in memory; new block records do not save screen trees, captions or accessibility text.

Local records
Activity records contain an event ID, time, app/package, intervention mode, stable diagnostic code, estimates and outcome flags. Pending events stay locally until saved to history. Rules, schedules, allowed apps, preferences, PIN hashes/salts and lockout state are stored locally too. Older history may contain detection descriptions from earlier versions and remains readable.

Offline operation and control
BlockReels transmits none of this data. There are no accounts, analytics or remote services. You can cancel this request, skip setup, select protected apps/schedules, disable the service in Android settings, and clear recorded history in Insights. History remains until cleared or app data is removed; clearing also removes pending events; daily counters are retained. Optional backups copy settings/rules to your device clipboard, without PIN credentials or activity history; BlockReels does not send them anywhere.''';

/// Every app entry point opens system Accessibility settings only after consent.
Future<void> openAccessibilitySettingsWithConsent(
  BuildContext context,
  Future<void> Function() openSettings,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (_) => const _PrivacyDialog(requestAccess: true),
  );
  if (accepted == true && context.mounted) await openSettings();
}

Future<void> showLocalPrivacyPolicy(BuildContext context) async {
  await showDialog<bool>(
    context: context,
    builder: (_) => const _PrivacyDialog(requestAccess: false),
  );
}

class _PrivacyDialog extends StatefulWidget {
  final bool requestAccess;
  const _PrivacyDialog({required this.requestAccess});

  @override
  State<_PrivacyDialog> createState() => _PrivacyDialogState();
}

class _PrivacyDialogState extends State<_PrivacyDialog> {
  bool _closed = false;

  void _finish(bool accepted) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(accepted);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('accessibility_privacy_dialog'),
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(widget.requestAccess
            ? 'Accessibility access & privacy'
            : 'Privacy policy'),
        content: const Text(localPrivacyPolicy),
        actions: [
          TextButton(
            key: const Key('btn_accessibility_consent_cancel'),
            onPressed: () => _finish(false),
            child: Text(widget.requestAccess ? 'Not now' : 'Close'),
          ),
          if (widget.requestAccess)
            FilledButton(
              key: const Key('btn_accessibility_consent_accept'),
              onPressed: () => _finish(true),
              child: const Text('Agree & open settings'),
            ),
        ],
      );
}
