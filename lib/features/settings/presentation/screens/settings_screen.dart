import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../pin_lock/pin_lock.dart';
import '../../domain/models/app_theme_mode.dart';
import '../controllers/settings_controller.dart';
import '../widgets/zero_network_privacy_card.dart';

/// Screen displaying settings, appearance, security, backup, and privacy controls.
class SettingsScreen extends StatelessWidget {
  final SettingsController controller;
  final PinSecurityController? pinController;

  const SettingsScreen({
    super.key,
    required this.controller,
    this.pinController,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = pinController == null
        ? controller
        : Listenable.merge([controller, pinController!]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final settings = controller.settings;
        return Scaffold(
          appBar: AppBar(
              title: const Text('Settings & Privacy',
                  maxLines: 2, softWrap: true)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ZeroNetworkPrivacyCard(),
              const SizedBox(height: 16),
              const Text(
                'APPEARANCE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final mode in AppThemeMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: settings.themeMode == mode,
                        onSelected: (selected) {
                          if (selected) controller.setThemeMode(mode);
                        },
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                key: const Key('switch_haptics'),
                title: const Text('Haptic Feedback'),
                value: settings.hapticsEnabled,
                onChanged: controller.setHaptics,
              ),
              SwitchListTile(
                key: const Key('switch_foreground_service'),
                title: const Text('Monitoring Notification'),
                subtitle: const Text(
                  'Keep a visible foreground notification while protection is active.',
                ),
                value: settings.isForegroundServiceEnabled,
                onChanged: controller.setForegroundService,
              ),
              const SizedBox(height: 16),
              const Text(
                'INTERVENTION FRICTION',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              _ProtectedHoldDuration(
                  controller: controller, pin: pinController),
              if (pinController != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'SECURITY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SwitchListTile(
                  key: const Key('switch_pin_lock'),
                  title: const Text('PIN Lock'),
                  subtitle: Text(
                    settings.isPinEnabled
                        ? 'PIN protection is enabled'
                        : 'Protect blocker settings with a 4-digit PIN',
                  ),
                  value: settings.isPinEnabled,
                  onChanged: (enabled) => _togglePin(context, enabled),
                ),
                if (settings.isPinEnabled)
                  SwitchListTile(
                    key: const Key('switch_strict_mode'),
                    title: const Text('Strict Mode'),
                    subtitle: const Text(
                      'Require the PIN before changing restrictions.',
                    ),
                    value: pinController!.state.isStrictModeActive,
                    onChanged: (enabled) => _toggleStrictMode(context, enabled),
                  ),
              ],
              const SizedBox(height: 16),
              const Text(
                'BACKUP & RESTORE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              ListTile(
                key: const Key('btn_export_backup'),
                title: const Text('Copy Backup to Clipboard'),
                subtitle: const Text(
                    'Copies app rules, schedules, settings and allowed apps. PIN and activity history are not included.'),
                trailing: const Icon(Icons.copy),
                onTap: () => _exportBackup(context),
              ),
              ListTile(
                key: const Key('btn_import_backup'),
                title: const Text('Restore Backup from Clipboard'),
                trailing: const Icon(Icons.restore),
                onTap: () => _importBackup(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _authorizeRestrictionChange(
    BuildContext context, {
    String prompt = 'Enter PIN to change blocking restrictions',
  }) {
    return authorizeRestrictionChange(context, pinController, prompt: prompt);
  }

  Future<void> _togglePin(BuildContext context, bool enabled) async {
    final pin = pinController!;
    if (enabled) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PinSetupScreen(controller: pin),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => PinEntryDialog(
        prompt: 'Enter PIN to disable PIN Lock',
        onVerifyPin: pin.verifyPin,
        isAuthenticationCurrent: () => pin.hasCurrentAuthentication,
        onAuthenticated: () async {
          if (!await pin.disableVerifiedPin()) {
            throw StateError('PIN update failed');
          }
        },
      ),
    );
  }

  Future<void> _toggleStrictMode(BuildContext context, bool enabled) async {
    final pin = pinController!;
    await showDialog<void>(
      context: context,
      builder: (_) => PinEntryDialog(
        prompt: enabled
            ? 'Enter PIN to enable Strict Mode'
            : 'Enter PIN to disable Strict Mode',
        onVerifyPin: pin.verifyPin,
        isAuthenticationCurrent: () => pin.hasCurrentAuthentication,
        onAuthenticated: () async {
          if (!await pin.setStrictMode(enabled)) {
            throw StateError('PIN update failed');
          }
        },
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    if (!await _authorizeRestrictionChange(
      context,
      prompt: 'Enter PIN to export backup',
    )) {
      return;
    }
    try {
      final authorized = pinController?.captureRestrictionAuthorization();
      final backup = await controller.exportBackup();
      if (!context.mounted || !(authorized?.call() ?? true)) return;
      await Clipboard.setData(ClipboardData(text: backup));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup copied to clipboard')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not copy the backup. Please try again.')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    if (!await _authorizeRestrictionChange(
      context,
      prompt: 'Enter PIN to restore backup',
    )) {
      return;
    }
    try {
      final authorized = pinController?.captureRestrictionAuthorization();
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (!context.mounted || !(authorized?.call() ?? true)) return;
      if (text == null || text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Clipboard is empty. Copy a backup first.')));
        return;
      }
      final backup = controller.validateBackup(text);
      if (backup == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This backup is invalid or damaged. Nothing was changed.')));
        return;
      }
      final sections = <String>[
        if (backup.rules != null) 'app blocking rules',
        if (backup.schedules != null) 'schedules',
        if (backup.settings != null) 'app settings',
        if (backup.whitelist != null) 'allowed apps',
      ];
      final history = backup.history == null
          ? 'Existing activity history will stay unchanged.'
          : backup.history!.isEmpty
              ? 'This backup has no activity history. Restoring it will clear your existing activity history.'
              : 'Existing activity history will be replaced by ${backup.history!.length} records from this backup.';
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                scrollable: true,
                title: const Text('Restore this backup?'),
                content: Text(
                    'This will replace ${sections.isEmpty ? "no settings or rules" : sections.join(", ")}. $history Your current PIN and PIN protection will stay unchanged.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Cancel')),
                  TextButton(
                      key: const Key('confirm_restore_backup'),
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Restore')),
                ],
              ));
      if (confirmed != true || !context.mounted || !(authorized?.call() ?? true)) return;
      final success = await controller.importValidatedBackup(backup);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Backup restored'
              : 'Could not restore this backup. Please try again.')));
    } on BackupSyncException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Backup restored locally, but protection could not be synced. Please check protection settings.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not read or restore the backup. Please try again.')),
        );
      }
    }
  }
}

class _ProtectedHoldDuration extends StatefulWidget {
  final SettingsController controller;
  final PinSecurityController? pin;
  const _ProtectedHoldDuration({required this.controller, this.pin});

  @override
  State<_ProtectedHoldDuration> createState() => _ProtectedHoldDurationState();
}

class _ProtectedHoldDurationState extends State<_ProtectedHoldDuration>
    with WidgetsBindingObserver {
  double? _draft;
  int? _savedAtStart;
  bool _committing = false;
  bool _saving = false;
  int _editEpoch = 0;

  int get _saved => widget.controller.settings.defaultHoldDurationSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ProtectedHoldDuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && _savedAtStart != null && _saved != _savedAtStart) {
      _editEpoch++;
      _draft = null;
      _savedAtStart = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _editEpoch++;
    if (mounted) {
      setState(() {
        _draft = null;
        _savedAtStart = null;
      });
    }
  }

  Future<void> _commit(double value) async {
    if (_committing || _savedAtStart == null) return;
    final epoch = _editEpoch;
    final seconds = value.round();
    if (seconds == _savedAtStart) {
      setState(() {
        _draft = null;
        _savedAtStart = null;
      });
      return;
    }
    setState(() => _committing = true);
    try {
      final allowed = await authorizeRestrictionChange(context, widget.pin);
      if (!allowed ||
          !mounted ||
          epoch != _editEpoch ||
          _saved != _savedAtStart) {
        return;
      }
      _saving = true;
      await widget.controller.setHoldDuration(seconds);
    } finally {
      _saving = false;
      if (mounted) {
        setState(() {
          _committing = false;
          _draft = null;
          _savedAtStart = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _draft ?? _saved.toDouble();
    return ListTile(
      title: Text('Hold duration: ${value.round()}s for all selected apps'),
      subtitle: Slider(
        key: const Key('slider_hold_duration'),
        min: 5,
        max: 30,
        divisions: 25,
        value: value,
        semanticFormatterCallback: (value) => '${value.round()} seconds',
        onChangeStart: _committing
            ? null
            : (_) {
                _savedAtStart = _saved;
                _editEpoch++;
              },
        onChanged: _committing
            ? null
            : (value) => setState(() {
                  _savedAtStart ??= _saved;
                  _draft = value;
                }),
        onChangeEnd: _committing ? null : _commit,
      ),
    );
  }
}
