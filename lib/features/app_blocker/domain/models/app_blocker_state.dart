import 'app_target_config_model.dart';

/// State representation of the app blocker control plane.
class AppBlockerState {
  final bool isMasterEnabled;
  final Map<String, AppTargetConfigModel> appConfigs;

  const AppBlockerState({
    this.isMasterEnabled = true,
    this.appConfigs = const {},
  });

  AppBlockerState copyWith({
    bool? isMasterEnabled,
    Map<String, AppTargetConfigModel>? appConfigs,
  }) {
    return AppBlockerState(
      isMasterEnabled: isMasterEnabled ?? this.isMasterEnabled,
      appConfigs: appConfigs ?? this.appConfigs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppBlockerState &&
          runtimeType == other.runtimeType &&
          isMasterEnabled == other.isMasterEnabled &&
          appConfigs == other.appConfigs;

  @override
  int get hashCode => isMasterEnabled.hashCode ^ appConfigs.hashCode;
}
