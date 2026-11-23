import 'dart:async';

import 'package:flutter/material.dart';

/// Modal dialog for strict mode authentication gating.
class PinEntryDialog extends StatefulWidget {
  final FutureOr<bool> Function(String pin) onVerifyPin;
  final FutureOr<void> Function() onAuthenticated;
  final bool Function()? isAuthenticationCurrent;
  final VoidCallback? onCancelled;
  final String prompt;
  final String title;

  const PinEntryDialog({
    super.key,
    required this.onVerifyPin,
    required this.onAuthenticated,
    this.isAuthenticationCurrent,
    this.onCancelled,
    this.prompt = 'Enter PIN to Modify Restrictions',
    this.title = 'PIN Security',
  });

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _cancelled = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final valid = await widget.onVerifyPin(_pinController.text);
      if (!mounted || _cancelled || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (valid && (widget.isAuthenticationCurrent?.call() ?? true)) {
        await widget.onAuthenticated();
        if (mounted &&
            !_cancelled &&
            ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
        return;
      }
      _error = 'Incorrect PIN or authorization expired. Please try again.';
    } catch (_) {
      _error = 'Could not complete PIN verification. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.prompt),
          const SizedBox(height: 16),
          TextField(
            key: const Key('pin_input_field'),
            controller: _pinController,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '4-digit PIN',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.of(context).pop();
            widget.onCancelled?.call();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('pin_submit_button'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator())
              : const Text('Verify'),
        ),
      ],
    );
  }
}
