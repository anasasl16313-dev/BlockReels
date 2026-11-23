import 'dart:async';
import 'dart:convert';

import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flush both worker/settings futures and the dialog's route transition.
Future<void> settlePinUi(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(pumpEventQueue);
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}

/// Fast, injectable worker for interaction tests only; no production cryptography.
class FakePinWorker implements PinCryptoWorker {
  Completer<void>? verificationGate;
  Completer<void>? hashingGate;
  int verificationCalls = 0;
  int hashingCalls = 0;

  String _hash(String pin, String salt) =>
      'pbkdf2_sha256\$120000\$${sha256.convert(utf8.encode('$salt:$pin'))}';

  @override
  Future<String> hashPin(String pin, String salt) async {
    hashingCalls++;
    await hashingGate?.future;
    return _hash(pin, salt);
  }

  @override
  Future<bool> verifyPin(String pin, String hash, String salt) async {
    verificationCalls++;
    await verificationGate?.future;
    return hash == _hash(pin, salt);
  }
}
