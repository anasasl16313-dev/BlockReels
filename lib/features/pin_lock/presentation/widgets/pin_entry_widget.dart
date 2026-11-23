import 'package:flutter/material.dart';
import '../controllers/pin_security_controller.dart';

/// Fullscreen or embedded PIN entry numpad and dot indicator widget.
class PinEntryWidget extends StatefulWidget {
  final PinSecurityController controller;
  final ValueChanged<bool> onResult;

  const PinEntryWidget({
    super.key,
    required this.controller,
    required this.onResult,
  });

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  String _enteredPin = '';
  bool _submitting = false;

  Future<void> _onDigitPress(String digit) async {
    if (_submitting || widget.controller.isBusy) return;
    if (widget.controller.state.isLockedOut(widget.controller.currentNow)) {
      return;
    }

    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        setState(() => _submitting = true);
        final success = await widget.controller.verifyPin(_enteredPin);
        if (!mounted) return;
        widget.onResult(success && widget.controller.hasCurrentAuthentication);
        setState(() {
          _enteredPin = '';
          _submitting = false;
        });
      }
    }
  }

  void _onBackspace() {
    if (!_submitting && !widget.controller.isBusy && _enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final isLocked = state.isLockedOut(widget.controller.currentNow);

        return Scaffold(
          appBar: AppBar(title: const Text('Enter PIN')),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLocked) ...[
                        Text(
                          'Locked out. Try again in ${state.lockoutSecondsRemaining(widget.controller.currentNow)}s',
                          key: const Key('lockout_warning_text'),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // PIN Dots
                      Semantics(
                          label: '${_enteredPin.length} of 4 digits entered',
                          liveRegion: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final isFilled = index < _enteredPin.length;
                              return Container(
                                key: Key('pin_dot_$index'),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                ),
                              );
                            }),
                          )),
                      const SizedBox(height: 32),
                      if (_submitting || widget.controller.isBusy)
                        const CircularProgressIndicator(),
                      // Numpad
                      Column(
                        children: [
                          for (var row in [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                            ['', '0', '⌫'],
                          ])
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: row.map((key) {
                                if (key.isEmpty) {
                                  return const SizedBox(width: 80, height: 60);
                                }
                                return Container(
                                  margin: const EdgeInsets.all(6),
                                  width: 70,
                                  height: 60,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero),
                                    key: Key('btn_numpad_$key'),
                                    onPressed: isLocked ||
                                            _submitting ||
                                            widget.controller.isBusy
                                        ? null
                                        : key == '⌫'
                                            ? _onBackspace
                                            : () => _onDigitPress(key),
                                    child: key == '⌫'
                                        ? const Icon(Icons.backspace_outlined,
                                            semanticLabel: 'Delete last digit')
                                        : Text(key,
                                            style:
                                                const TextStyle(fontSize: 20)),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ],
                  ))),
        );
      },
    );
  }
}
