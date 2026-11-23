import 'package:flutter/material.dart';

import '../controllers/pin_security_controller.dart';
import '../dialogs/pin_entry_dialog.dart';

Future<bool> authorizeRestrictionChange(
  BuildContext context,
  PinSecurityController? pin, {
  String prompt = 'Enter PIN to change blocking restrictions',
}) async {
  if (pin == null) return true;
  await pin.ready;
  if (!context.mounted || pin.isBusy) return false;
  if (!pin.state.isPinEnabled && !pin.state.isStrictModeActive) return true;

  int? authenticatedRevision;
  await showDialog<void>(
    context: context,
    builder: (_) => PinEntryDialog(
      prompt: prompt,
      onVerifyPin: pin.verifyPin,
      isAuthenticationCurrent: () => pin.hasCurrentAuthentication,
      onAuthenticated: () {
        authenticatedRevision = pin.securityRevision;
      },
    ),
  );
  return authenticatedRevision == pin.securityRevision &&
      pin.hasCurrentAuthentication;
}
