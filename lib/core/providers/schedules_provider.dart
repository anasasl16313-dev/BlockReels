import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_model.dart';
import '../platform_channel/dtos/schedule_dto.dart';
import '../platform_channel/platform_bridge.dart';
import '../storage/storage_repository.dart';
import 'platform_bridge_provider.dart';
import 'storage_provider.dart';

/// StateNotifier managing focus schedule rules and synchronizing with the native service.
class SchedulesNotifier extends StateNotifier<List<ScheduleModel>> {
  final StorageRepository _storage;
  final PlatformBridge _bridge;

  SchedulesNotifier(this._storage, this._bridge) : super([]) {
    loadSchedules();
  }

  Future<void> loadSchedules() async {
    final schedules = await _storage.getSchedules();
    state = schedules;
  }

  Future<void> addSchedule(ScheduleModel schedule) async {
    final updatedList = [...state, schedule];
    state = updatedList;
    await _storage.saveSchedule(schedule);
    await _syncBridge();
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    final index = state.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      final updatedList = List<ScheduleModel>.from(state);
      updatedList[index] = schedule;
      state = updatedList;
      await _storage.saveSchedule(schedule);
      await _syncBridge();
    }
  }

  Future<void> toggleSchedule(String id, bool isActive) async {
    final index = state.indexWhere((s) => s.id == id);
    if (index != -1) {
      final updated = state[index].copyWith(isActive: isActive);
      final updatedList = List<ScheduleModel>.from(state);
      updatedList[index] = updated;
      state = updatedList;
      await _storage.saveSchedule(updated);
      await _syncBridge();
    }
  }

  Future<void> deleteSchedule(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _storage.deleteSchedule(id);
    await _syncBridge();
  }

  Future<void> _syncBridge() async {
    final dtos = state.map((s) => ScheduleDto.fromModel(s)).toList();
    await _bridge.syncSchedules(dtos);
  }
}

/// Provider for [SchedulesNotifier] managing focus schedules.
final schedulesProvider =
    StateNotifierProvider<SchedulesNotifier, List<ScheduleModel>>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  final bridge = ref.watch(platformBridgeProvider);
  return SchedulesNotifier(storage, bridge);
});

/// Computes the list of schedules that are currently active right now.
final activeSchedulesProvider = Provider<List<ScheduleModel>>((ref) {
  final schedules = ref.watch(schedulesProvider);
  final now = DateTime.now();
  return schedules.where((s) => s.isCurrentlyActive(now)).toList();
});
