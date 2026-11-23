import 'intervention_mode.dart';

/// Configuration for a targeted app's blocking behaviors and granularity.
class AppTargetConfigModel {
  final String packageName;
  final String appName;
  final bool isEnabled;
  final bool
      isSurgicalOnly; // true = surgical short-form feed block, false = full app
  final InterventionMode interventionMode;
  final int holdDurationSeconds;
  final bool allowChatAndDMs;
  final bool allowProfileGrids;

  const AppTargetConfigModel({
    required this.packageName,
    required this.appName,
    this.isEnabled = true,
    this.isSurgicalOnly = true,
    this.interventionMode = InterventionMode.mindfulPause,
    this.holdDurationSeconds = 10,
    this.allowChatAndDMs = true,
    this.allowProfileGrids = true,
  });

  AppTargetConfigModel copyWith({
    String? packageName,
    String? appName,
    bool? isEnabled,
    bool? isSurgicalOnly,
    InterventionMode? interventionMode,
    int? holdDurationSeconds,
    bool? allowChatAndDMs,
    bool? allowProfileGrids,
  }) {
    return AppTargetConfigModel(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      isEnabled: isEnabled ?? this.isEnabled,
      isSurgicalOnly: isSurgicalOnly ?? this.isSurgicalOnly,
      interventionMode: interventionMode ?? this.interventionMode,
      holdDurationSeconds: holdDurationSeconds ?? this.holdDurationSeconds,
      allowChatAndDMs: allowChatAndDMs ?? this.allowChatAndDMs,
      allowProfileGrids: allowProfileGrids ?? this.allowProfileGrids,
    );
  }

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'isEnabled': isEnabled,
        'isSurgicalOnly': isSurgicalOnly,
        'interventionMode': interventionMode.wireName,
        'holdDurationSeconds': holdDurationSeconds,
        'allowChatAndDMs': allowChatAndDMs,
        'allowProfileGrids': allowProfileGrids,
      };

  factory AppTargetConfigModel.fromMap(Map<String, dynamic> map) =>
      AppTargetConfigModel(
        packageName: map['packageName'] as String,
        appName: map['appName'] as String,
        isEnabled: map['isEnabled'] as bool? ?? true,
        isSurgicalOnly: map['isSurgicalOnly'] as bool? ?? true,
        interventionMode: map['interventionMode'] == 'AUTO_BACK'
            ? InterventionMode.autoBack
            : map['interventionMode'] == 'STRICT_BLOCK'
                ? InterventionMode.strictBlock
                : InterventionMode.mindfulPause,
        holdDurationSeconds: map['holdDurationSeconds'] as int? ?? 10,
        allowChatAndDMs: map['allowChatAndDMs'] as bool? ?? true,
        allowProfileGrids: map['allowProfileGrids'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTargetConfigModel &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName &&
          appName == other.appName &&
          isEnabled == other.isEnabled &&
          isSurgicalOnly == other.isSurgicalOnly &&
          interventionMode == other.interventionMode &&
          holdDurationSeconds == other.holdDurationSeconds &&
          allowChatAndDMs == other.allowChatAndDMs &&
          allowProfileGrids == other.allowProfileGrids;

  @override
  int get hashCode =>
      packageName.hashCode ^
      appName.hashCode ^
      isEnabled.hashCode ^
      isSurgicalOnly.hashCode ^
      interventionMode.hashCode ^
      holdDurationSeconds.hashCode ^
      allowChatAndDMs.hashCode ^
      allowProfileGrids.hashCode;
}
