import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_settings.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../domain/models/pin_security_state.dart';
import '../../domain/services/crypto_pin_utils.dart';

/// Controller managing asynchronous PIN authentication and persisted lockout state.
class PinSecurityController extends ChangeNotifier {
  final StorageRepository? _storage;
  final SettingsNotifier? _settings;
  final PinCryptoWorker _worker;
  late final void Function()? _removeSettingsListener;
  late final Future<void> _initialLoad;
  PinSecurityState _state = const PinSecurityState();
  DateTime? _mockNow;
  bool _busy = false;
  bool _disposed = false;
  int _securityRevision = 0;
  int _authenticationEpoch = 0;
  int? _verifiedRevision;
  int? _verifiedEpoch;

  PinSecurityState get state => _state;
  DateTime get currentNow => _mockNow ?? DateTime.now();
  /// Valid only for the security settings and foreground session that opened a dialog.
  bool Function() captureRestrictionAuthorization() {
    final revision = _securityRevision;
    final epoch = _authenticationEpoch;
    final protected = _state.isPinEnabled || _state.isStrictModeActive;
    return () => _current(revision, epoch) &&
        (!protected || hasCurrentAuthentication);
  }

  bool get isBusy => _busy;
  int get securityRevision => _securityRevision;
  Future<void> get ready => _settings?.ready ?? _initialLoad;
  bool get hasCurrentAuthentication =>
      !_busy &&
      _verifiedRevision == _securityRevision &&
      _verifiedEpoch == _authenticationEpoch &&
      !_state.isLockedOut(currentNow);

  PinSecurityController(
      [this._storage, this._settings, PinCryptoWorker? worker])
      : _worker = worker ?? const IsolatePinCryptoWorker() {
    if (_settings != null) {
      _applySettings(_settings.currentSettings);
      _initialLoad = Future<void>.value();
      _removeSettingsListener = _settings.addListener(
        _onSettingsChanged,
        fireImmediately: false,
      );
    } else {
      _removeSettingsListener = null;
      _initialLoad =
          _storage == null ? Future<void>.value() : _loadFromStorage();
    }
  }

  Future<void> _loadFromStorage() async {
    final settings = await _storage!.getSettings();
    if (_disposed) return;
    _applySettings(settings);
    notifyListeners();
  }

  void _onSettingsChanged(AppSettings settings) {
    if (_disposed) return;
    _applySettings(settings);
    notifyListeners();
  }

  static PinSecurityState _security(AppSettings settings) => PinSecurityState(
        isPinEnabled: settings.pinLockEnabled,
        pinHash: settings.pinHash,
        pinSalt: settings.pinSalt,
        failedAttempts: settings.failedPinAttempts,
        lockoutUntil: settings.lockoutUntil,
        isStrictModeActive: settings.strictModeEnabled,
      );

  static AppSettings _withSecurity(
          AppSettings settings, PinSecurityState security) =>
      settings.copyWith(
        pinLockEnabled: security.isPinEnabled,
        pinHash: security.pinHash,
        pinSalt: security.pinSalt,
        failedPinAttempts: security.failedAttempts,
        lockoutUntil: security.lockoutUntil,
        strictModeEnabled: security.isStrictModeActive,
      );

  void _applySettings(AppSettings settings) =>
      _applySecurity(_security(settings));

  void _applySecurity(PinSecurityState next) {
    if (next != _state) {
      _securityRevision++;
      _verifiedRevision = null;
      _verifiedEpoch = null;
      _state = next;
    }
  }

  void invalidateAuthentication() {
    _authenticationEpoch++;
    _verifiedRevision = null;
    _verifiedEpoch = null;
    if (!_disposed) notifyListeners();
  }

  void setMockNow(DateTime now) {
    _mockNow = now;
    if (!_disposed) notifyListeners();
  }

  bool _begin() {
    if (_busy || _disposed) return false;
    _busy = true;
    _verifiedRevision = null;
    _verifiedEpoch = null;
    notifyListeners();
    return true;
  }

  void _finish() {
    _busy = false;
    if (!_disposed) notifyListeners();
  }

  bool _current(int revision, int epoch) =>
      !_disposed &&
      _securityRevision == revision &&
      _authenticationEpoch == epoch;

  Future<bool> _commitSecurity(
      PinSecurityState before, PinSecurityState next) async {
    if (_disposed || _state != before) return false;
    final revision = _securityRevision;
    final epoch = _authenticationEpoch;
    final expectedRevision = revision + (before == next ? 0 : 1);
    if (_settings != null) {
      final base = _settings.currentSettings;
      final saved = await _settings.updatePinSecurity(
        _withSecurity(base, before),
        _withSecurity(base, next),
      );
      return saved &&
          !_disposed &&
          _securityRevision == expectedRevision &&
          _state == next;
    }
    if (_storage != null) {
      final latest = await _storage.getSettings();
      if (!_current(revision, epoch) || _security(latest) != before) {
        if (!_disposed) _applySettings(latest);
        return false;
      }
      await _storage.saveSettings(_withSecurity(latest, next));
      final saved = await _storage.getSettings();
      if (_disposed) return false;
      _applySettings(saved);
      return _securityRevision == expectedRevision && _state == next;
    }
    _applySecurity(next);
    return true;
  }

  Future<bool> setupPin(String pin, {String? salt}) async {
    if (!_begin()) return false;
    try {
      await ready;
      final before = _state;
      final revision = _securityRevision;
      final epoch = _authenticationEpoch;
      if (before.isPinEnabled) return false;
      final effectiveSalt = salt ?? CryptoPinUtils.generateSecureSalt();
      final hash = await _worker.hashPin(pin, effectiveSalt);
      if (!_current(revision, epoch)) return false;
      final saved = await _commitSecurity(
          before,
          before.copyWith(
            isPinEnabled: true,
            pinHash: hash,
            pinSalt: effectiveSalt,
            failedAttempts: 0,
            lockoutUntil: null,
          ));
      return saved && !_disposed && _authenticationEpoch == epoch;
    } catch (_) {
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> verifyPin(String enteredPin) async {
    if (!_begin()) return false;
    try {
      await ready;
      final before = _state;
      if (before.isLockedOut(currentNow) ||
          before.pinHash == null ||
          before.pinSalt == null) {
        return false;
      }
      final revision = _securityRevision;
      final epoch = _authenticationEpoch;
      final valid =
          await _worker.verifyPin(enteredPin, before.pinHash!, before.pinSalt!);
      if (!_current(revision, epoch)) return false;
      PinSecurityState next;
      if (valid) {
        if (CryptoPinUtils.isLegacyHash(before.pinHash!)) {
          final salt = CryptoPinUtils.generateSecureSalt();
          final hash = await _worker.hashPin(enteredPin, salt);
          if (!_current(revision, epoch)) return false;
          next = before.copyWith(
              pinHash: hash,
              pinSalt: salt,
              failedAttempts: 0,
              lockoutUntil: null);
        } else {
          next = before.copyWith(failedAttempts: 0, lockoutUntil: null);
        }
      } else {
        final failures = before.failedAttempts + 1;
        final lockout = failures >= 10
            ? currentNow.add(const Duration(minutes: 30))
            : failures >= 5
                ? currentNow.add(const Duration(minutes: 5))
                : failures >= 3
                    ? currentNow.add(const Duration(seconds: 30))
                    : null;
        next = before.copyWith(failedAttempts: failures, lockoutUntil: lockout);
      }
      final saved = await _commitSecurity(before, next);
      if (!saved || _disposed || _authenticationEpoch != epoch) return false;
      if (valid) {
        _verifiedRevision = _securityRevision;
        _verifiedEpoch = epoch;
      }
      return valid;
    } catch (_) {
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> setStrictMode(bool active) async {
    if (!_begin()) return false;
    try {
      await ready;
      if (active && !_state.isPinEnabled) return false;
      return await _commitSecurity(
          _state, _state.copyWith(isStrictModeActive: active));
    } catch (_) {
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> disablePin(String currentPin) async {
    if (!await verifyPin(currentPin)) return false;
    return disableVerifiedPin();
  }

  /// Consumes the current verification; callers cannot disable with an old result.
  Future<bool> disableVerifiedPin() async {
    if (!hasCurrentAuthentication) return false;
    final revision = _securityRevision;
    final epoch = _authenticationEpoch;
    if (!_begin()) return false;
    try {
      await ready;
      if (!_current(revision, epoch)) return false;
      return await _commitSecurity(
          _state, const PinSecurityState(isPinEnabled: false));
    } catch (_) {
      return false;
    } finally {
      _finish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    invalidateAuthentication();
    _removeSettingsListener?.call();
    super.dispose();
  }
}

final pinCryptoWorkerProvider =
    Provider<PinCryptoWorker>((ref) => const IsolatePinCryptoWorker());

/// Riverpod ChangeNotifierProvider for [PinSecurityController].
final pinSecurityControllerProvider =
    ChangeNotifierProvider<PinSecurityController>((ref) {
  return PinSecurityController(
    ref.watch(storageRepositoryProvider),
    ref.watch(settingsProvider.notifier),
    ref.watch(pinCryptoWorkerProvider),
  );
});
