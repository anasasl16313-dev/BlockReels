import 'package:flutter/material.dart';
import '../controllers/pin_security_controller.dart';

/// Screen guiding the user through initial PIN creation and confirmation.
class PinSetupScreen extends StatefulWidget {
  final PinSecurityController controller;
  final VoidCallback? onPinConfigured;

  const PinSetupScreen({
    super.key,
    required this.controller,
    this.onPinConfigured,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _saving = false;
  String? _errorMessage;

  void _onDigitPress(String digit) {
    if (_saving || widget.controller.isBusy) return;
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_firstPin.length < 4) {
          _firstPin += digit;
          if (_firstPin.length == 4) {
            _isConfirming = true;
          }
        }
      } else if (_confirmPin.length < 4) {
        _confirmPin += digit;
      }
    });
    if (_isConfirming && _confirmPin.length == 4) {
      _evaluatePin();
    }
  }

  void _onBackspace() {
    if (_saving || widget.controller.isBusy) return;
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _firstPin = '';
        }
      }
    });
  }

  Future<void> _evaluatePin() async {
    if (_firstPin == _confirmPin) {
      if (_saving) return;
      setState(() => _saving = true);
      final saved = await widget.controller.setupPin(_firstPin);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!saved) {
        setState(() {
          _errorMessage = 'Could not save PIN. Please try again.';
          _firstPin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
        return;
      }
      widget.onPinConfigured?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN successfully configured')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } else {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _firstPin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePin = _isConfirming ? _confirmPin : _firstPin;
    final titleText =
        _isConfirming ? 'Confirm your 4-digit PIN' : 'Create a 4-digit PIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Set up PIN')),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    titleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // PIN Dots
                  Semantics(
                      label: '${activePin.length} of 4 digits entered',
                      liveRegion: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < activePin.length;
                          return Container(
                            key: Key('setup_pin_dot_$index'),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isFilled ? Colors.blue : Colors.grey.shade300,
                            ),
                          );
                        }),
                      )),
                  const SizedBox(height: 32),
                  if (_saving) const CircularProgressIndicator(),
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
                                key: Key('btn_setup_numpad_$key'),
                                onPressed: _saving
                                    ? null
                                    : key == '⌫'
                                        ? _onBackspace
                                        : () => _onDigitPress(key),
                                child: key == '⌫'
                                    ? const Icon(Icons.backspace_outlined,
                                        semanticLabel: 'Delete last digit')
                                    : Text(key,
                                        style: const TextStyle(fontSize: 20)),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ],
              ))),
    );
  }
}
