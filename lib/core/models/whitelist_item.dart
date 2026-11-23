/// Defines surgical disambiguation whitelist entries to prevent false-positive blocks
/// inside messaging, search, or profile screens of target apps.
class WhitelistItem {
  final String id;
  final String packageName;
  final String componentId;
  final String? viewIdPattern;
  final String reason;
  final DateTime addedAt;
  final bool isEnabled;
  final bool isSystemProtected;

  WhitelistItem({
    required this.id,
    required this.packageName,
    required this.componentId,
    this.viewIdPattern,
    required this.reason,
    DateTime? addedAt,
    this.isEnabled = true,
    this.isSystemProtected = true,
  }) : addedAt = addedAt ?? DateTime.now();

  WhitelistItem copyWith({
    String? id,
    String? packageName,
    String? componentId,
    String? viewIdPattern,
    String? reason,
    DateTime? addedAt,
    bool? isEnabled,
    bool? isSystemProtected,
  }) {
    return WhitelistItem(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      componentId: componentId ?? this.componentId,
      viewIdPattern: viewIdPattern ?? this.viewIdPattern,
      reason: reason ?? this.reason,
      addedAt: addedAt ?? this.addedAt,
      isEnabled: isEnabled ?? this.isEnabled,
      isSystemProtected: isSystemProtected ?? this.isSystemProtected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageName': packageName,
      'componentId': componentId,
      'viewIdPattern': viewIdPattern,
      'reason': reason,
      'addedAt': addedAt.toIso8601String(),
      'isEnabled': isEnabled,
      'isSystemProtected': isSystemProtected,
    };
  }

  factory WhitelistItem.fromJson(Map<String, dynamic> json) {
    return WhitelistItem(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      componentId: json['componentId'] as String? ??
          (json['exclusionType'] as String? ?? ''),
      viewIdPattern: json['viewIdPattern'] as String?,
      reason:
          json['reason'] as String? ?? (json['description'] as String? ?? ''),
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isEnabled: json['isEnabled'] as bool? ?? true,
      isSystemProtected: json['isSystemProtected'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhitelistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName &&
          componentId == other.componentId &&
          viewIdPattern == other.viewIdPattern &&
          reason == other.reason &&
          isEnabled == other.isEnabled &&
          isSystemProtected == other.isSystemProtected;

  @override
  int get hashCode =>
      id.hashCode ^
      packageName.hashCode ^
      componentId.hashCode ^
      (viewIdPattern?.hashCode ?? 0) ^
      reason.hashCode ^
      isEnabled.hashCode ^
      isSystemProtected.hashCode;

  @override
  String toString() =>
      'WhitelistItem(id: $id, app: $packageName, component: $componentId, protected: $isSystemProtected)';
}
