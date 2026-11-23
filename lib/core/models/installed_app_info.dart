import 'dart:typed_data';

/// Represents metadata for an application installed on the host Android device.
class InstalledAppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final bool isInstalled;
  final Uint8List? iconBytes;

  const InstalledAppInfo({
    required this.packageName,
    required this.appName,
    this.isSystemApp = false,
    this.isInstalled = true,
    this.iconBytes,
  });

  InstalledAppInfo copyWith({
    String? packageName,
    String? appName,
    bool? isSystemApp,
    bool? isInstalled,
    Uint8List? iconBytes,
  }) {
    return InstalledAppInfo(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      isInstalled: isInstalled ?? this.isInstalled,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }

  factory InstalledAppInfo.fromMap(Map<String, dynamic> map) {
    return InstalledAppInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      isSystemApp: map['isSystemApp'] as bool? ?? false,
      isInstalled: map['isInstalled'] as bool? ?? true,
      iconBytes: map['iconBytes'] != null
          ? Uint8List.fromList(List<int>.from(map['iconBytes'] as List))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'isSystemApp': isSystemApp,
        'isInstalled': isInstalled,
        'iconBytes': iconBytes?.toList(),
      };

  factory InstalledAppInfo.fromJson(Map<String, dynamic> json) =>
      InstalledAppInfo.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledAppInfo &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName &&
          appName == other.appName &&
          isSystemApp == other.isSystemApp &&
          isInstalled == other.isInstalled;

  @override
  int get hashCode =>
      packageName.hashCode ^
      appName.hashCode ^
      isSystemApp.hashCode ^
      isInstalled.hashCode;

  @override
  String toString() =>
      'InstalledAppInfo(packageName: $packageName, appName: $appName)';
}
