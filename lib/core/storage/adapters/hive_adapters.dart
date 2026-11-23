import 'package:hive/hive.dart';

import '../../models/app_settings.dart';
import '../../models/history_log.dart';
import '../../models/intervention_mode.dart';
import '../../models/rule_model.dart';
import '../../models/schedule_model.dart';
import '../../models/whitelist_item.dart';

/// Hive TypeAdapter for [InterventionMode] (typeId: 0)
class InterventionModeAdapter extends TypeAdapter<InterventionMode> {
  @override
  final int typeId = 0;

  @override
  InterventionMode read(BinaryReader reader) {
    final index = reader.readByte();
    if (index >= 0 && index < InterventionMode.values.length) {
      return InterventionMode.values[index];
    }
    return InterventionMode.mindfulPause;
  }

  @override
  void write(BinaryWriter writer, InterventionMode obj) {
    writer.writeByte(obj.index);
  }
}

/// Hive TypeAdapter for [RuleModel] (typeId: 1)
class RuleModelAdapter extends TypeAdapter<RuleModel> {
  @override
  final int typeId = 1;

  @override
  RuleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return RuleModel(
      id: fields[0] as String? ?? (fields[1] as String? ?? ''),
      packageName: fields[1] as String? ?? '',
      appName: fields[2] as String? ?? '',
      isEnabled: fields[3] as bool? ?? true,
      interventionMode: fields[4] is InterventionMode
          ? fields[4] as InterventionMode
          : InterventionMode.fromString(fields[4] as String?),
      dailyQuotaMinutes: fields[5] as int? ?? 0,
      holdDurationSeconds: fields[6] as int? ?? 7,
      blockEntireApp: fields[7] as bool? ?? false,
      createdAt: fields[8] is DateTime
          ? fields[8] as DateTime
          : (fields[8] != null ? DateTime.tryParse(fields[8] as String) : null),
      updatedAt: fields[9] is DateTime
          ? fields[9] as DateTime
          : (fields[9] != null ? DateTime.tryParse(fields[9] as String) : null),
      dailyReelLimit: fields[10] as int? ?? 0,
      allowChatAndDMs: fields[11] as bool? ?? true,
      allowProfileGrids: fields[12] as bool? ?? true,
      customMessage: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RuleModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.appName)
      ..writeByte(3)
      ..write(obj.isEnabled)
      ..writeByte(4)
      ..write(obj.interventionMode.name)
      ..writeByte(5)
      ..write(obj.dailyQuotaMinutes)
      ..writeByte(6)
      ..write(obj.holdDurationSeconds)
      ..writeByte(7)
      ..write(obj.blockEntireApp)
      ..writeByte(8)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(9)
      ..write(obj.updatedAt.toIso8601String())
      ..writeByte(10)
      ..write(obj.dailyReelLimit)
      ..writeByte(11)
      ..write(obj.allowChatAndDMs)
      ..writeByte(12)
      ..write(obj.allowProfileGrids)
      ..writeByte(13)
      ..write(obj.customMessage);
  }
}

/// Hive TypeAdapter for [ScheduleModel] (typeId: 2)
class ScheduleModelAdapter extends TypeAdapter<ScheduleModel> {
  @override
  final int typeId = 2;

  @override
  ScheduleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final rawDays = fields[2];
    final List<int> daysOfWeek = rawDays is List
        ? rawDays.map((e) => e as int).toList()
        : const [1, 2, 3, 4, 5];

    final rawPackages = fields[7];
    final List<String> targetPackages = rawPackages is List
        ? rawPackages.map((e) => e as String).toList()
        : const [];

    return ScheduleModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      daysOfWeek: daysOfWeek,
      startHour: fields[3] as int? ?? 9,
      startMinute: fields[4] as int? ?? 0,
      endHour: fields[5] as int? ?? 17,
      endMinute: fields[6] as int? ?? 0,
      targetPackageNames: targetPackages,
      isActive: fields[8] as bool? ?? true,
      overrideMode: fields[9] is InterventionMode
          ? fields[9] as InterventionMode
          : (fields[9] != null
              ? InterventionMode.fromString(fields[9] as String?)
              : null),
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.daysOfWeek)
      ..writeByte(3)
      ..write(obj.startHour)
      ..writeByte(4)
      ..write(obj.startMinute)
      ..writeByte(5)
      ..write(obj.endHour)
      ..writeByte(6)
      ..write(obj.endMinute)
      ..writeByte(7)
      ..write(obj.targetPackageNames)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.overrideMode?.name);
  }
}

/// Hive TypeAdapter for [HistoryLog] (typeId: 3)
class HistoryLogAdapter extends TypeAdapter<HistoryLog> {
  @override
  final int typeId = 3;

  @override
  HistoryLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    DateTime parsedTime;
    final rawTs = fields[1];
    if (rawTs is DateTime) {
      parsedTime = rawTs;
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return HistoryLog(
      id: fields[0] as String? ?? '',
      timestamp: parsedTime,
      packageName: fields[2] as String? ?? '',
      appName: fields[3] as String? ?? '',
      interventionMode: fields[4] is InterventionMode
          ? fields[4] as InterventionMode
          : InterventionMode.fromString(fields[4] as String?),
      estimatedTimeSavedSeconds: fields[5] as int? ?? 45,
      wasDismissedWithHold: fields[6] as bool? ?? false,
      detectionReason: fields[7] as String? ?? 'SURGICAL_HEURISTIC',
      wasOverridden: fields[8] as bool? ?? (fields[6] as bool? ?? false),
    );
  }

  @override
  void write(BinaryWriter writer, HistoryLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp.toIso8601String())
      ..writeByte(2)
      ..write(obj.packageName)
      ..writeByte(3)
      ..write(obj.appName)
      ..writeByte(4)
      ..write(obj.interventionMode.name)
      ..writeByte(5)
      ..write(obj.estimatedTimeSavedSeconds)
      ..writeByte(6)
      ..write(obj.wasDismissedWithHold)
      ..writeByte(7)
      ..write(obj.detectionReason)
      ..writeByte(8)
      ..write(obj.wasOverridden);
  }
}

/// Hive TypeAdapter for [AppSettings] (typeId: 4)
class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 4;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    DateTime? parsedLockout;
    final rawLockout = fields[6];
    if (rawLockout is DateTime) {
      parsedLockout = rawLockout;
    } else if (rawLockout is String) {
      parsedLockout = DateTime.tryParse(rawLockout);
    } else if (rawLockout is int) {
      parsedLockout = DateTime.fromMillisecondsSinceEpoch(rawLockout);
    }

    DateTime? parsedBackup;
    final rawBackup = fields[12];
    if (rawBackup is DateTime) {
      parsedBackup = rawBackup;
    } else if (rawBackup is String) {
      parsedBackup = DateTime.tryParse(rawBackup);
    }

    return AppSettings(
      isMasterEnabled: fields[0] as bool? ?? true,
      themeMode: fields[1] as String? ?? 'system',
      pinLockEnabled: fields[2] as bool? ?? false,
      pinHash: fields[3] as String?,
      pinSalt: fields[4] as String?,
      failedPinAttempts: fields[5] as int? ?? 0,
      lockoutUntil: parsedLockout,
      defaultHoldDurationSeconds: fields[7] as int? ?? 7,
      breathingTechnique: fields[8] as String? ?? 'box_4_4_4_4',
      hapticFeedbackEnabled: fields[9] as bool? ?? true,
      soundDuckingEnabled: fields[10] as bool? ?? true,
      isOnboardingCompleted: fields[11] as bool? ?? false,
      lastBackupDate: parsedBackup,
      schemaVersion: fields[13] as int? ?? 1,
      isForegroundServiceEnabled: fields[14] as bool? ?? false,
      dailyTimeSavedGoalMinutes: fields[15] as int? ?? 60,
      defaultInterventionMode: fields[16] is InterventionMode
          ? fields[16] as InterventionMode
          : InterventionMode.fromString(fields[16] as String?),
      strictModeEnabled: fields[17] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.isMasterEnabled)
      ..writeByte(1)
      ..write(obj.themeMode)
      ..writeByte(2)
      ..write(obj.pinLockEnabled)
      ..writeByte(3)
      ..write(obj.pinHash)
      ..writeByte(4)
      ..write(obj.pinSalt)
      ..writeByte(5)
      ..write(obj.failedPinAttempts)
      ..writeByte(6)
      ..write(obj.lockoutUntil?.toIso8601String())
      ..writeByte(7)
      ..write(obj.defaultHoldDurationSeconds)
      ..writeByte(8)
      ..write(obj.breathingTechnique)
      ..writeByte(9)
      ..write(obj.hapticFeedbackEnabled)
      ..writeByte(10)
      ..write(obj.soundDuckingEnabled)
      ..writeByte(11)
      ..write(obj.isOnboardingCompleted)
      ..writeByte(12)
      ..write(obj.lastBackupDate?.toIso8601String())
      ..writeByte(13)
      ..write(obj.schemaVersion)
      ..writeByte(14)
      ..write(obj.isForegroundServiceEnabled)
      ..writeByte(15)
      ..write(obj.dailyTimeSavedGoalMinutes)
      ..writeByte(16)
      ..write(obj.defaultInterventionMode.name)
      ..writeByte(17)
      ..write(obj.strictModeEnabled);
  }
}

/// Hive TypeAdapter for [WhitelistItem] (typeId: 5)
class WhitelistItemAdapter extends TypeAdapter<WhitelistItem> {
  @override
  final int typeId = 5;

  @override
  WhitelistItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    DateTime parsedDate;
    final rawDate = fields[4];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return WhitelistItem(
      id: fields[0] as String? ?? '',
      packageName: fields[1] as String? ?? '',
      componentId: fields[2] as String? ?? '',
      reason: fields[3] as String? ?? '',
      addedAt: parsedDate,
      isEnabled: fields[5] as bool? ?? true,
      viewIdPattern: fields[6] as String?,
      isSystemProtected: fields[7] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, WhitelistItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.componentId)
      ..writeByte(3)
      ..write(obj.reason)
      ..writeByte(4)
      ..write(obj.addedAt.toIso8601String())
      ..writeByte(5)
      ..write(obj.isEnabled)
      ..writeByte(6)
      ..write(obj.viewIdPattern)
      ..writeByte(7)
      ..write(obj.isSystemProtected);
  }
}
