import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/domain/models/protection_status.dart';
import '../../domain/models/schedule_rule_model.dart';
import '../controllers/schedules_controller.dart';
import '../widgets/schedule_card.dart';
import '../../../pin_lock/pin_lock.dart';

/// Screen displaying the list of focus schedules with toggles and an editor.
class SchedulesScreen extends StatelessWidget {
  final SchedulesController controller;
  final PinSecurityController? pinController;
  final VoidCallback? onAddTap;
  final ProtectionStatus? protectionStatus;

  const SchedulesScreen({
    super.key,
    required this.controller,
    this.onAddTap,
    this.pinController,
    this.protectionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
        stream:
            Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()),
        builder: (context, snapshot) => AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final schedules = controller.schedules;
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Focus Schedules',
                        maxLines: 2, softWrap: true),
                  ),
                  floatingActionButton: schedules.isEmpty
                      ? null
                      : FloatingActionButton(
                          key: const Key('fab_add_schedule'),
                          tooltip: 'Add schedule',
                          onPressed: onAddTap ??
                              () => _showScheduleEditor(context,
                                  controller: controller, pin: pinController),
                          child: const Icon(Icons.add),
                        ),
                  body: schedules.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_available_outlined,
                                      size: 32,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 8),
                                  Text('No schedules yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Choose when protection should repeat.',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  FilledButton.tonalIcon(
                                      key: const Key('empty_add_schedule'),
                                      onPressed: onAddTap ??
                                          () => _showScheduleEditor(context,
                                              controller: controller, pin: pinController),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create schedule')),
                                ]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: schedules.length,
                          itemBuilder: (context, index) {
                            final schedule = schedules[index];
                            return ScheduleCard(
                              schedule: schedule,
                              protectionStatus: protectionStatus,
                              syncPending: controller.hasUnsyncedChanges,
                              onToggle: (val) async {
                                final messenger = ScaffoldMessenger.of(context);
                                final result = await controller.toggleSchedule(
                                    schedule.id, val);
                                _reportTo(
                                    messenger, result, 'Schedule updated');
                              },
                              onDelete: () async {
                                final authorized = pinController?.captureRestrictionAuthorization();
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialog) => AlertDialog(
                                          title: const Text("Delete schedule?"),
                                          content: Text(
                                              "Delete ${schedule.name}? This cannot be undone."),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    dialog, false),
                                                child: const Text("Cancel")),
                                            TextButton(
                                                key: const Key(
                                                    "confirm_delete_schedule"),
                                                onPressed: () =>
                                                    Navigator.pop(dialog, true),
                                                child: const Text("Delete"))
                                          ],
                                        ));
                                if (confirmed == true && context.mounted && (authorized?.call() ?? true)) {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final result = await controller
                                      .deleteSchedule(schedule.id);
                                  _reportTo(
                                      messenger, result, 'Schedule deleted');
                                }
                              },
                              onTap: () => _showScheduleEditor(
                                context,
                                controller: controller,
                                existing: schedule,
                                pin: pinController,
                              ),
                            );
                          },
                        ),
                );
              },
            ));
  }
}

void _report(BuildContext context, ScheduleWriteResult result, String success) {
  if (!context.mounted || result == ScheduleWriteResult.busy) return;
  _reportTo(ScaffoldMessenger.of(context), result, success);
}

void _reportTo(ScaffoldMessengerState messenger, ScheduleWriteResult result,
    String success) {
  if (!messenger.mounted || result == ScheduleWriteResult.busy) return;
  final message = switch (result) {
    ScheduleWriteResult.success => success,
    ScheduleWriteResult.syncFailed =>
      "Saved locally, but protection could not be synced. Try again.",
    ScheduleWriteResult.failed =>
      "Could not save the schedule. Please try again.",
    ScheduleWriteResult.busy => "",
  };
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showScheduleEditor(
  BuildContext context, {
  required SchedulesController controller,
  ScheduleRuleModel? existing,
  PinSecurityController? pin,
}) async {
  final authorized = pin?.captureRestrictionAuthorization();
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) =>
        _ScheduleEditorDialog(existing: existing, controller: controller, authorized: authorized),
  );
  if (saved == true && context.mounted) {
    _report(context, ScheduleWriteResult.success, 'Schedule saved');
  }
}

class _ScheduleEditorDialog extends StatefulWidget {
  final ScheduleRuleModel? existing;
  final SchedulesController controller;

  final bool Function()? authorized;
  const _ScheduleEditorDialog({this.existing, required this.controller, this.authorized});

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  static const _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const _apps = {
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.facebook.katana': 'Facebook',
    'com.zhiliaoapp.musically': 'TikTok',
  };

  late final TextEditingController _nameController;
  late final Set<int> _days;
  late final Set<String> _packages;
  late TimeOfDay _start;
  late TimeOfDay _end;
  String? _error;
  bool _saving = false;
  late final String _id;
  late bool _allApps;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _id = existing?.id ?? const Uuid().v4();
    _allApps = existing == null || existing.enabledPackageNames.isEmpty;
    _nameController = TextEditingController(
      text: existing?.name ?? 'Focus Session',
    );
    _days =
        existing == null ? {1, 2, 3, 4, 5} : Set<int>.from(existing.daysOfWeek);
    _packages = existing == null
        ? <String>{}
        : Set<String>.from(existing.enabledPackageNames);
    _start = TimeOfDay(
      hour: existing?.startHour ?? 9,
      minute: existing?.startMinute ?? 0,
    );
    _end = TimeOfDay(
      hour: existing?.endHour ?? 17,
      minute: existing?.endMinute ?? 0,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(widget.authorized?.call() ?? true)) {
      Navigator.of(context).pop(false);
      return;
    }
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a schedule name.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Select at least one day.');
      return;
    }
    if (_start.hour == _end.hour && _start.minute == _end.minute) {
      setState(() => _error = 'Start and end times must differ.');
      return;
    }

    if (!_allApps && _packages.isEmpty) {
      setState(() =>
          _error = "Select at least one app, or choose all supported apps.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final schedule = ScheduleRuleModel(
      id: _id,
      name: name,
      daysOfWeek: _days.toList()..sort(),
      startHour: _start.hour,
      startMinute: _start.minute,
      endHour: _end.hour,
      endMinute: _end.minute,
      enabledPackageNames: _allApps ? const [] : _packages.toList(),
      isActive: widget.existing?.isActive ?? true,
      overrideMode: widget.existing?.overrideMode,
    );
    final result = await widget.controller.addSchedule(schedule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == ScheduleWriteResult.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = result == ScheduleWriteResult.syncFailed
          ? "Saved locally, but protection could not be synced. Try again."
          : "Could not save the schedule. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColors = StatusThemeExtension.of(context).error;
    final appChoices = {
      ..._apps,
      for (final package in _packages)
        if (!_apps.containsKey(package)) package: package,
    };

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      scrollable: true,
      title: Text(widget.existing == null ? 'New Schedule' : 'Edit Schedule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('field_schedule_name'),
            controller: _nameController,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: _dayLabels.entries.map((entry) {
              final selected = _days.contains(entry.key);
              return FilterChip(
                key: Key('day_chip_${entry.key}'),
                label: Text(entry.value),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (value) => setState(() {
                          if (value) {
                            _days.add(entry.key);
                          } else {
                            _days.remove(entry.key);
                          }
                        }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                key: const Key('btn_schedule_start_time'),
                onPressed: _saving ? null : () => _pickTime(isStart: true),
                child: Text('Start ${_start.format(context)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_schedule_end_time'),
                onPressed: _saving ? null : () => _pickTime(isStart: false),
                child: Text('End ${_end.format(context)}'),
              ),
            ],
          ),
          if (_end.hour * 60 + _end.minute < _start.hour * 60 + _start.minute)
            const Text('Ends the next day after each selected start day.'),
          const SizedBox(height: 12),
          const Text(
            'Applies to',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          RadioGroup<bool>(
            groupValue: _allApps,
            onChanged: (value) {
              if (!_saving) setState(() => _allApps = value ?? true);
            },
            child: Column(children: [
              RadioListTile<bool>(
                  enabled: !_saving,
                  value: true,
                  title: const Text('All supported apps')),
              RadioListTile<bool>(
                  enabled: !_saving,
                  value: false,
                  title: const Text('Choose specific apps')),
            ]),
          ),
          if (!_allApps)
            ...appChoices.entries.map(
              (entry) => CheckboxListTile(
                key: Key('schedule_app_${entry.key}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: _packages.contains(entry.key),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          if (value ?? false) {
                            _packages.add(entry.key);
                          } else {
                            _packages.remove(entry.key);
                          }
                        }),
              ),
            ),
          const Text(
              'During this schedule, selected apps can be blocked even if their manual switch is off. Accessibility and the master switch must be on.'),
        ],
      ),
      actions: [
        if (_error != null)
          SizedBox(
            width: double.infinity,
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: TextStyle(color: errorColors.accent)),
            ),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('btn_save_schedule'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
