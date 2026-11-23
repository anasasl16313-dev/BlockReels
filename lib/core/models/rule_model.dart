import 'intervention_mode.dart';

/// Represents surgical blocking rules and behavioral configuration for a target application.
class RuleModel {
  final String id;
  final String packageName;
  final String appName;
  final bool isEnabled;
  final InterventionMode interventionMode;
  final int holdDurationSeconds;
  final int dailyQuotaMinutes;
  final int dailyReelLimit;
  final bool allowChatAndDMs;
  final bool allowProfileGrids;
  final bool blockEntireApp;
  final String? customMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  RuleModel({
    required this.id,
    required this.packageName,
    required this.appName,
    this.isEnabled = true,
    this.interventionMode = InterventionMode.mindfulPause,
    this.holdDurationSeconds = 7,
    this.dailyQuotaMinutes = 0,
    this.dailyReelLimit = 0,
    this.allowChatAndDMs = true,
    this.allowProfileGrids = true,
    this.blockEntireApp = false,
    this.customMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  RuleModel copyWith({
    String? id,
    String? packageName,
    String? appName,
    bool? isEnabled,
    InterventionMode? interventionMode,
    int? holdDurationSeconds,
    int? dailyQuotaMinutes,
    int? dailyReelLimit,
    bool? allowChatAndDMs,
    bool? allowProfileGrids,
    bool? blockEntireApp,
    String? customMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RuleModel(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      isEnabled: isEnabled ?? this.isEnabled,
      interventionMode: interventionMode ?? this.interventionMode,
      holdDurationSeconds: holdDurationSeconds ?? this.holdDurationSeconds,
      dailyQuotaMinutes: dailyQuotaMinutes ?? this.dailyQuotaMinutes,
      dailyReelLimit: dailyReelLimit ?? this.dailyReelLimit,
      allowChatAndDMs: allowChatAndDMs ?? this.allowChatAndDMs,
      allowProfileGrids: allowProfileGrids ?? this.allowProfileGrids,
      blockEntireApp: blockEntireApp ?? this.blockEntireApp,
      customMessage: customMessage ?? this.customMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'isEnabled': isEnabled,
      'interventionMode': interventionMode.name,
      'holdDurationSeconds': holdDurationSeconds,
      'dailyQuotaMinutes': dailyQuotaMinutes,
      'dailyReelLimit': dailyReelLimit,
      'allowChatAndDMs': allowChatAndDMs,
      'allowProfileGrids': allowProfileGrids,
      'blockEntireApp': blockEntireApp,
      'customMessage': customMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RuleModel.fromJson(Map<String, dynamic> json) {
    return RuleModel(
      id: json['id'] as String? ?? (json['packageName'] as String? ?? ''),
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? true,
      interventionMode: InterventionMode.fromString(
        (json['interventionMode'] ?? json['mode']) as String?,
      ),
      holdDurationSeconds: json['holdDurationSeconds'] as int? ?? 7,
      dailyQuotaMinutes: json['dailyQuotaMinutes'] as int? ?? 0,
      dailyReelLimit: json['dailyReelLimit'] as int? ?? 0,
      allowChatAndDMs: json['allowChatAndDMs'] as bool? ?? true,
      allowProfileGrids: json['allowProfileGrids'] as bool? ?? true,
      blockEntireApp: json['blockEntireApp'] as bool? ?? false,
      customMessage: json['customMessage'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName &&
          appName == other.appName &&
          isEnabled == other.isEnabled &&
          interventionMode == other.interventionMode &&
          holdDurationSeconds == other.holdDurationSeconds &&
          dailyQuotaMinutes == other.dailyQuotaMinutes &&
          dailyReelLimit == other.dailyReelLimit &&
          allowChatAndDMs == other.allowChatAndDMs &&
          allowProfileGrids == other.allowProfileGrids &&
          blockEntireApp == other.blockEntireApp &&
          customMessage == other.customMessage;

  @override
  int get hashCode =>
      id.hashCode ^
      packageName.hashCode ^
      appName.hashCode ^
      isEnabled.hashCode ^
      interventionMode.hashCode ^
      holdDurationSeconds.hashCode ^
      dailyQuotaMinutes.hashCode ^
      dailyReelLimit.hashCode ^
      allowChatAndDMs.hashCode ^
      allowProfileGrids.hashCode ^
      blockEntireApp.hashCode ^
      (customMessage?.hashCode ?? 0);

  @override
  String toString() =>
      'RuleModel(id: $id, packageName: $packageName, isEnabled: $isEnabled, mode: $interventionMode)';
}
