import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/domain/models/protection_status.dart';
import '../../domain/models/schedule_rule_model.dart';

/// Card widget displaying a single focus schedule configuration item.
class ScheduleCard extends StatelessWidget {
  final ScheduleRuleModel schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final ProtectionStatus? protectionStatus;
  final bool syncPending;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
    this.protectionStatus,
    this.syncPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final error = StatusThemeExtension.of(context).error;
    final startStr =
        '${schedule.startHour.toString().padLeft(2, '0')}:${schedule.startMinute.toString().padLeft(2, '0')}';
    final endStr =
        '${schedule.endHour.toString().padLeft(2, '0')}:${schedule.endMinute.toString().padLeft(2, '0')}';

    const apps = {
      'com.instagram.android': 'Instagram',
      'com.google.android.youtube': 'YouTube',
      'com.facebook.katana': 'Facebook',
      'com.zhiliaoapp.musically': 'TikTok',
    };
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sortedDays = schedule.daysOfWeek.toSet().toList()..sort();
    final listedDays = sortedDays
        .where((day) => day >= 1 && day <= 7)
        .map((day) => weekdays[day])
        .join(', ');
    final days = listedDays.isEmpty ? 'No days selected' : listedDays;
    final targets = schedule.enabledPackageNames.isEmpty
        ? 'All supported apps'
        : schedule.enabledPackageNames
            .map((name) => apps[name] ?? name)
            .join(', ');
    final overnight = schedule.endHour * 60 + schedule.endMinute <
        schedule.startHour * 60 + schedule.startMinute;
    final window = schedule.isCurrentlyActive();
    final affectsSupportedApps = schedule.enabledPackageNames.isEmpty ||
        schedule.enabledPackageNames
            .any(ProtectionStatusResolver.nativeTargetPackages.contains);
    final isEffective =
        protectionStatus?.kind == ProtectionStatusKind.scheduled &&
            affectsSupportedApps &&
            protectionStatus!.activeScheduleNames.contains(schedule.name);

    return Card(
      key: Key('schedule_card_${schedule.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        child: Padding(
            padding: AppSpacing.cardContent,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                hint: 'Edit schedule',
                child: Text(
                  schedule.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$days · $startStr–$endStr${overnight ? ' (ends next day)' : ''}',
              ),
              Text('Apps: $targets'),
              Text(!schedule.isActive
                  ? 'Repeat paused'
                  : !window
                      ? 'Enabled for repeat · outside scheduled window'
                      : syncPending
                          ? 'In scheduled window now · protection sync is pending'
                          : isEffective
                              ? 'Blocking during this schedule now'
                              : protectionStatus == null ||
                                      protectionStatus?.kind ==
                                          ProtectionStatusKind.verifying
                                  ? 'In scheduled window now · checking protection'
                                  : 'In scheduled window now · this schedule is not currently applied'),
              const Text(
                  'May block these apps even when manual blocking is off; master protection must be on.'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child:
                          Text(schedule.isActive ? 'Repeat on' : 'Repeat off')),
                  Semantics(
                      label: 'Enable ${schedule.name} schedule',
                      child: Switch(
                        key: Key('switch_schedule_${schedule.id}'),
                        value: schedule.isActive,
                        onChanged: onToggle,
                      )),
                  IconButton(
                    key: Key('btn_delete_${schedule.id}'),
                    icon: Icon(Icons.delete, color: error.accent),
                    tooltip: 'Delete ${schedule.name} schedule',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ])),
      ),
    );
  }
}
