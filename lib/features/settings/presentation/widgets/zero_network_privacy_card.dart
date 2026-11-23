import 'package:flutter/material.dart';

import '../../../../core/privacy/accessibility_disclosure.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';

/// Local privacy summary with access to the bundled policy.
class ZeroNetworkPrivacyCard extends StatelessWidget {
  const ZeroNetworkPrivacyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final info = StatusThemeExtension.of(context).info;

    return Card(
      key: const Key('card_zero_network_trust'),
      color: info.container,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: info.accent),
      ),
      child: Padding(
        padding: AppSpacing.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: info.accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: Text(
                  '100% On-Device Privacy',
                  style: TextStyle(
                    color: info.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Zero network permissions. BlockReels operates completely offline on your device.',
              style: TextStyle(color: info.foreground),
            ),
            TextButton(
              key: const Key('btn_local_privacy_policy'),
              onPressed: () => showLocalPrivacyPolicy(context),
              child: const Text('Read privacy policy'),
            ),
          ],
        ),
      ),
    );
  }
}
