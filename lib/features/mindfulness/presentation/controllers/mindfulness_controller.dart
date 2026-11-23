import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/platform_channel/platform_bridge.dart';
import '../../domain/models/breathing_phase.dart';
import '../../domain/models/mindfulness_state.dart';

/// Controller coordinating mindful breathing phases and hold-to-unlock friction.
class MindfulnessController extends ChangeNotifier {
  final PlatformBridge? bridge;
  final String? packageName;

  MindfulnessState _state;
  MindfulnessState get state => _state;

  set state(MindfulnessState newState) {
    _state = newState;
    notifyListeners();
  }

  Timer? _holdTimer;
  final int _tickMs = 50;
  int _elapsedMs = 0;
  bool unlockCallbackCalled = false;
  bool leaveAppCallbackCalled = false;

  MindfulnessController({
    this.bridge,
    this.packageName,
    int holdDurationSeconds = 10,
  }) : _state = MindfulnessState(holdDurationSeconds: holdDurationSeconds);

  void setBreathingPhase(BreathingPhase phase, int seconds) {
    _state = _state.copyWith(
      breathingPhase: phase,
      breathingSecondsRemaining: seconds,
    );
    notifyListeners();
  }

  void selectIntention(String intention) {
    _state = _state.copyWith(selectedIntention: intention);
    notifyListeners();
  }

  void startHold() {
    if (_state.isUnlocked) return;

    _elapsedMs = 0;
    _state = _state.copyWith(isHolding: true, holdProgress: 0.0);
    notifyListeners();

    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(Duration(milliseconds: _tickMs), (timer) {
      _elapsedMs += _tickMs;
      final totalMs = _state.holdDurationSeconds * 1000;
      final progress = (_elapsedMs / totalMs).clamp(0.0, 1.0);

      if (progress >= 1.0) {
        timer.cancel();
        _state = _state.copyWith(
          isHolding: false,
          holdProgress: 1.0,
          isUnlocked: true,
        );
        unlockCallbackCalled = true;
        final target = packageName;
        if (bridge != null && target != null) {
          bridge!.grantTemporaryAllowance(target);
        }
        notifyListeners();
      } else {
        _state = _state.copyWith(
          holdProgress: progress,
        );
        notifyListeners();
      }
    });
  }

  void cancelHold() {
    if (_state.isUnlocked) return;

    _holdTimer?.cancel();
    _elapsedMs = 0;
    _state = _state.copyWith(
      isHolding: false,
      holdProgress: 0.0,
    );
    notifyListeners();
  }

  void leaveApp() {
    leaveAppCallbackCalled = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }
}
